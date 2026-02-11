#[allow(unused_field, unused_mut_parameter)]
module lending_core::pool_manager {

    use sui::bag::{Self, Bag};
    use sui::event::emit;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{TxContext};
    use sui::vec_map::{VecMap};

    use std::u64;
    use lending_core::error::{Self};

    use sui_system::sui_system::{SuiSystemState};
    use liquid_staking::stake_pool::{Self, StakePool, OperatorCap};
    use liquid_staking::cert::{Metadata, CERT};

    use sui::sui::{SUI};

    friend lending_core::pool;
    use lending_core::event;

    // The treasury pool, which is used to hold all the funds
    struct SuiPoolManager has key, store {
        id: UID,
        // the theoretical sui amount of the pool
        // original_sui_amount = sum(sui_deposit) - sum(sui_withdraw)
        original_sui_amount: u64, 
        vsui_balance: Balance<CERT>,
        temp_sui_balance: Bag,
        enabled_manage: bool,
        // a target sui amount for the pool, 
        // the extra sui amount will be staked to vsui
        target_sui_amount: u64,
        vsui_stake_pool: StakePool,
        vsui_metadata: Metadata<CERT>,
    }

    // Event
    struct FundUpdated has copy, drop {
        original_sui_amount: u64,
        current_sui_amount: u64,
        vsui_balance_amount: u64,
        // treasury_amount: u64,
        target_sui_amount: u64,
    }

    struct StakingTreasuryWithdrawn has copy, drop {
        taken_vsui_balance_amount: u64,
        equal_sui_balance_amount: u64
    }

    struct SuiKey has store, copy, drop {}

    const MIN_OPERATION_AMOUNT: u64 = 1_000_000_000;

    public(friend) fun new(stake_pool: StakePool, metadata: Metadata<CERT>, original_sui_amount: u64, target_sui_amount: u64, ctx: &mut TxContext): SuiPoolManager {
        let manager = SuiPoolManager {
            id: object::new(ctx),
            original_sui_amount: original_sui_amount,
            vsui_balance: balance::zero<CERT>(),
            temp_sui_balance: bag::new(ctx),
            enabled_manage: false,
            target_sui_amount: target_sui_amount,
            vsui_stake_pool: stake_pool,
            vsui_metadata: metadata,
        };
        bag::add(&mut manager.temp_sui_balance, SuiKey {}, balance::zero<SUI>());
        manager
    }

    public(friend) fun enable_manage(manager: &mut SuiPoolManager) {
        assert!(manager.enabled_manage == false, error::paused());
        manager.enabled_manage = true;
    }

    public(friend) fun disable_manage(manager: &mut SuiPoolManager, pool_sui_amount: u64) {
        assert!(manager.enabled_manage == true, error::paused());
        assert!(pool_sui_amount >= manager.original_sui_amount, error::insufficient_balance());
        manager.enabled_manage = false;
    }

    public(friend) fun update_deposit(manager: &mut SuiPoolManager, new_deposit_amount: u64) {
        manager.original_sui_amount = manager.original_sui_amount + new_deposit_amount;
    }

    public(friend) fun update_withdraw(manager: &mut SuiPoolManager, new_withdraw_amount: u64) {
        manager.original_sui_amount = manager.original_sui_amount - new_withdraw_amount;
    }

    // refresh stake
    // 1. if pool_sui_amount > target, stake sui to vsui
    // 2. if pool_sui_amount < target, unstake vsui to sui
    public(friend) fun refresh_stake(manager: &mut SuiPoolManager, pool_balance: &mut Balance<SUI>, system_state: &mut SuiSystemState, ctx: &mut TxContext) {
        if (!manager.enabled_manage) {
            return
        };

        let pool_sui_amount = balance::value(pool_balance);
        let pool_vsui_balance = &mut manager.vsui_balance;
        let pool_vsui_amount = balance::value(pool_vsui_balance);
        let stake_pool = &mut manager.vsui_stake_pool;
        let metadata = &mut manager.vsui_metadata;

        stake_pool::refresh(stake_pool, metadata, system_state, ctx);

        let target = if (manager.original_sui_amount > manager.target_sui_amount) {
            manager.target_sui_amount
        } else {
            manager.original_sui_amount
        };

        if (pool_sui_amount + MIN_OPERATION_AMOUNT < target) { // if pool sui amount doesn't meet target, unstake vsui
            let difference = target - pool_sui_amount;
            let vsui_to_unstake = stake_pool::sui_amount_to_lst_amount(stake_pool, metadata, difference);

            // sanity check to gurantee enough vsui to unstake
            if (vsui_to_unstake > pool_vsui_amount) {
                vsui_to_unstake = pool_vsui_amount
            };
            // skip if the unstake amount is too small
            if (vsui_to_unstake > MIN_OPERATION_AMOUNT) {
                // unstake all if left vsui is less than MIN_OPERATION_AMOUNT
                // otherwise, the left vsui will not meet the threshold for an unstake in the future 
                if (balance::value(pool_vsui_balance) < vsui_to_unstake + MIN_OPERATION_AMOUNT) {
                    vsui_to_unstake = balance::value(pool_vsui_balance);
                };
                
                let vsui_balance = balance::split(pool_vsui_balance, vsui_to_unstake);
                let vsui_coin = coin::from_balance(vsui_balance, ctx);
                let sui_coin = stake_pool::unstake(stake_pool, metadata, system_state, vsui_coin, ctx);
                let sui_balance = coin::into_balance(sui_coin);
                balance::join(pool_balance, sui_balance);
            };
        } else if (pool_sui_amount > target + MIN_OPERATION_AMOUNT) { // if pool has extra sui over target, stake sui to vsui
                let sui_to_stake = pool_sui_amount - target;
                let sui_balance = balance::split(pool_balance, sui_to_stake);
                let sui_coin = coin::from_balance(sui_balance, ctx);
                let vsui_coin = stake_pool::stake(stake_pool, metadata, system_state, sui_coin, ctx);
                let vsui_balance = coin::into_balance(vsui_coin);
                balance::join(pool_vsui_balance, vsui_balance);
        };

        event::emit_fund_updated(
            manager.original_sui_amount,
            balance::value(pool_balance),
            balance::value(pool_vsui_balance),
            manager.target_sui_amount,
            object::uid_to_address(&manager.id)
        );
    }

    public(friend) fun prepare_before_withdraw<CoinType>(manager: &mut SuiPoolManager, withdraw_amount: u64, pool_sui_amount: u64, system_state: &mut SuiSystemState, ctx: &mut TxContext): Balance<CoinType> {
        let pool_vsui_balance: &mut Balance<CERT> = &mut manager.vsui_balance;
        let stake_pool = &mut manager.vsui_stake_pool;
        let metadata = &mut manager.vsui_metadata;

        if (!manager.enabled_manage || pool_sui_amount >= withdraw_amount) {
            return balance::zero<CoinType>()
        };

        stake_pool::refresh(stake_pool, metadata, system_state, ctx);

        // require extra 1000 mist to avoid rounding issues
        let required_sui_amount = u64::max(withdraw_amount - pool_sui_amount, MIN_OPERATION_AMOUNT) + 1000;

        let vsui_to_unstake = stake_pool::sui_amount_to_lst_amount(stake_pool, metadata, required_sui_amount);

        // A sanity check if we have no enough vsui
        // This should not happen as the vsui will keep growing 
        // Also, if the vsui is too small, unstake it all
        if (vsui_to_unstake + MIN_OPERATION_AMOUNT > balance::value(pool_vsui_balance)) {
            vsui_to_unstake = balance::value(pool_vsui_balance);
        };

        let vsui_balance = balance::split(pool_vsui_balance, vsui_to_unstake);
        let vsui_coin = coin::from_balance(vsui_balance, ctx);
        let sui_coin = stake_pool::unstake(stake_pool, metadata, system_state, vsui_coin, ctx);
        let sui_balance = coin::into_balance(sui_coin);

        // Casting: use a bag to convert SUI to CoinType
        let convert_amount = balance::value(&sui_balance); 
        let principal_in_sui: &mut Balance<SUI> = bag::borrow_mut(&mut manager.temp_sui_balance, SuiKey {});
        balance::join(principal_in_sui, sui_balance);
        let principal_in_raw: &mut Balance<CoinType> = bag::borrow_mut(&mut manager.temp_sui_balance, SuiKey {});
        let principal_in_raw_balance = balance::split(principal_in_raw, convert_amount);

        event::emit_fund_updated(
            manager.original_sui_amount,
            pool_sui_amount,
            balance::value(&manager.vsui_balance),
            manager.target_sui_amount,
            object::uid_to_address(&manager.id)
        );

        principal_in_raw_balance
    }

    public(friend) fun set_target_sui_amount(manager: &mut SuiPoolManager, target_sui_amount: u64) {
        manager.target_sui_amount = target_sui_amount;
    }

    public(friend) fun get_treasury_sui_amount(manager: &SuiPoolManager, pool_sui_amount: u64): u64 {
        let pool_vsui_amount = balance::value(&manager.vsui_balance);
        let total_sui = pool_sui_amount + stake_pool::lst_amount_to_sui_amount(&manager.vsui_stake_pool,  &manager.vsui_metadata, pool_vsui_amount);
        if (total_sui > manager.original_sui_amount) {
            return total_sui - manager.original_sui_amount
        };
        0
    }

    // Take the vsui from staking reward
    // It only takes the excess amount to make sure users' fund is safe
    // In a special case, if most of the vsui are in the sui pool due to target setting, it takes all.
    public(friend) fun take_vsui_from_treasury(manager: &mut SuiPoolManager, pool_sui_amount: u64, system_state: &mut SuiSystemState, ctx: &mut TxContext): Balance<CERT> {
        stake_pool::refresh(&mut manager.vsui_stake_pool, &manager.vsui_metadata, system_state, ctx);
        let treasury_sui_amount = get_treasury_sui_amount(manager, pool_sui_amount);
        let vsui_to_take = stake_pool::sui_amount_to_lst_amount(&manager.vsui_stake_pool, &manager.vsui_metadata, treasury_sui_amount);
        if (vsui_to_take > balance::value(&manager.vsui_balance)) {
            vsui_to_take = balance::value(&manager.vsui_balance);
        };    
        let vsui_balance = balance::split(&mut manager.vsui_balance, vsui_to_take);

        // check if left vsui is enough for unstake, if not, abort
        assert!(balance::value(&manager.vsui_balance) == 0 
        || balance::value(&manager.vsui_balance) > MIN_OPERATION_AMOUNT, error::insufficient_balance());

        event::emit_staking_treasury_withdrawn(
            balance::value(&vsui_balance),
            treasury_sui_amount,
            object::uid_to_address(&manager.id)
        );

        vsui_balance
    }

    public(friend) fun unstake_vsui(manager: &mut SuiPoolManager, system_state: &mut SuiSystemState, vsui_coin: Coin<CERT>, ctx: &mut TxContext): Coin<SUI> {
        stake_pool::unstake(&mut manager.vsui_stake_pool, &mut manager.vsui_metadata, system_state, vsui_coin, ctx)
    }

    public(friend) fun set_validator_weights_vsui(
        manager: &mut SuiPoolManager,
        system_state: &mut SuiSystemState,
        vsui_operator_cap: &OperatorCap,
        validator_weights: VecMap<address, u64>,
        ctx: &mut TxContext
    ) {
        stake_pool::set_validator_weights(
            &mut manager.vsui_stake_pool,
            &mut manager.vsui_metadata,
            system_state,
            vsui_operator_cap,
            validator_weights,
            ctx
        )
    }

    #[test_only]
    public fun create_for_testing(stake_pool: StakePool, metadata: Metadata<CERT>, original_sui_amount: u64, target_sui_amount: u64, ctx: &mut TxContext): SuiPoolManager {
        new(stake_pool, metadata, original_sui_amount, target_sui_amount, ctx)
    }

    #[test_only]
    public fun get_pool_manager_info(manager: &SuiPoolManager): (u64, u64, bool, u64) {
        // verify the bag is not empty at first
        let principal_in_sui: &Balance<SUI> = bag::borrow(&manager.temp_sui_balance, SuiKey {});
        assert!(balance::value(principal_in_sui) == 0, 0);
        (manager.original_sui_amount, balance::value(&manager.vsui_balance), manager.enabled_manage, manager.target_sui_amount)
    }

    #[test_only]
    public fun enable_manage_for_testing(manager: &mut SuiPoolManager) {
        enable_manage(manager);
    }

    #[test_only]
    public fun disable_manage_for_testing(manager: &mut SuiPoolManager, pool_sui_amount: u64) {
        disable_manage(manager, pool_sui_amount);
    }

    #[test_only]
    public fun update_deposit_for_testing(manager: &mut SuiPoolManager, new_deposit_amount: u64) {
        update_deposit(manager, new_deposit_amount);
    }

    #[test_only]
    public fun update_withdraw_for_testing(manager: &mut SuiPoolManager, new_withdraw_amount: u64) {
        update_withdraw(manager, new_withdraw_amount);
    }

    #[test_only]
    public fun refresh_stake_for_testing(manager: &mut SuiPoolManager, pool_balance: &mut Balance<SUI>, system_state: &mut SuiSystemState, ctx: &mut TxContext) {
        refresh_stake(manager, pool_balance, system_state, ctx);
    }

    #[test_only]
    public fun prepare_before_withdraw_for_testing<CoinType>(manager: &mut SuiPoolManager, withdraw_amount: u64, pool_sui_amount: u64, system_state: &mut SuiSystemState, ctx: &mut TxContext): Balance<CoinType> {
        prepare_before_withdraw<CoinType>(manager, withdraw_amount, pool_sui_amount, system_state, ctx)
    }

    #[test_only]
    public fun set_target_sui_amount_for_testing(manager: &mut SuiPoolManager, target_sui_amount: u64) {
        set_target_sui_amount(manager, target_sui_amount);
    }

    #[test_only]
    public fun take_vsui_from_treasury_for_testing(manager: &mut SuiPoolManager, pool_sui_amount: u64, system_state: &mut SuiSystemState, ctx: &mut TxContext): Balance<CERT> {
        take_vsui_from_treasury(manager, pool_sui_amount, system_state, ctx)
    }

    #[test_only]
    public fun unstake_vsui_for_testing(manager: &mut SuiPoolManager, system_state: &mut SuiSystemState, vsui_coin: Coin<CERT>, ctx: &mut TxContext): Coin<SUI> {
        unstake_vsui(manager, system_state, vsui_coin, ctx)
    }

    #[test_only]
    public fun get_treasury_sui_amount_for_testing(manager: &SuiPoolManager, pool_sui_amount: u64): u64 {
        get_treasury_sui_amount(manager, pool_sui_amount)
    }
}