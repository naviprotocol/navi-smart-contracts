#[allow(unused_field, unused_mut_parameter)]
module lending_core::pool {
    use std::type_name;
    use std::ascii::{String};

    use sui::transfer;
    use sui::event::emit;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
    use sui::dynamic_field::{Self};
    use sui::vec_map::{VecMap};

    use lending_core::error::{Self};
    use lending_core::pool_manager::{Self, SuiPoolManager};
    use lending_core::event;

    use sui_system::sui_system::{SuiSystemState};
    use sui::sui::{SUI};
    use liquid_staking::stake_pool::{StakePool, OperatorCap};
    use liquid_staking::cert::{Metadata, CERT};

    friend lending_core::lending;
    friend lending_core::storage;
    friend lending_core::flash_loan;

    // The treasury pool, which is used to hold all the funds
    struct Pool<phantom CoinType> has key, store {
        id: UID,
        balance: Balance<CoinType>, // BTC. ETH
        treasury_balance: Balance<CoinType>,
        decimal: u8,
    }

    struct PoolAdminCap has key, store {
        id: UID,
        creator: address,
    }

    // Event
    struct PoolCreate has copy, drop {
        creator: address,
    }

    struct PoolBalanceRegister has copy, drop {
        sender: address,
        amount: u64,
        new_amount: u64,
        pool: String,
    }

    struct PoolDeposit has copy, drop {
        sender: address,
        amount: u64,
        pool: String,
    }

    struct PoolWithdraw has copy, drop {
        sender: address,
        recipient: address,
        amount: u64,
        pool: String,
    }

    struct PoolWithdrawReserve has copy, drop {
        sender: address,
        recipient: address,
        amount: u64,
        before: u64,
        after: u64,
        pool: String,
        poolId: address,
    }

    // === dynamic field keys ===
    struct PoolManagerKey has copy, drop, store {}
    struct MarketIdKey has copy, drop, store {}

    // Entry
    fun init(ctx: &mut TxContext) {
        transfer::public_transfer(PoolAdminCap {
            id: object::new(ctx),
            creator: tx_context::sender(ctx),
        }, tx_context::sender(ctx))
    }

    // DEPRECATED: use create_pool_with_market_id instead
    #[allow(unused)]
    public(friend) fun create_pool<CoinType>(_: &PoolAdminCap, decimal: u8, ctx: &mut TxContext) {
        abort error::invalid_function_call()
    }

    // only current main market needs to be initialized
    // other markets will be initialized when creating reserves
    public fun init_pool_for_main_market<CoinType>(_: &PoolAdminCap, pool: &mut Pool<CoinType>) {
        dynamic_field::add(&mut pool.id, MarketIdKey {}, 0u64);
    }

    public(friend) fun create_pool_with_market_id<CoinType>(_: &PoolAdminCap, decimal: u8, market_id: u64, ctx: &mut TxContext) {
        let pool_id = object::new(ctx);
        let pool_address = object::uid_to_address(&pool_id);
        let coin_type = type_name::into_string(type_name::get<CoinType>());
        let pool = Pool<CoinType> {
            id: pool_id,
            balance: balance::zero<CoinType>(),
            treasury_balance: balance::zero<CoinType>(),
            decimal: decimal,
        };
        dynamic_field::add(&mut pool.id, MarketIdKey {}, market_id);
        transfer::share_object(pool);

        event::emit_pool_create(tx_context::sender(ctx), coin_type, pool_address, market_id)
    }

    // It's used for direct deposit without updating pool manager
    public(friend) fun deposit<CoinType>(pool: &mut Pool<CoinType>, mint_coin: Coin<CoinType>, ctx: &mut TxContext) {
        let mint_value = coin::value(&mint_coin);
        let mint_balance = coin::into_balance(mint_coin);
        balance::join(&mut pool.balance, mint_balance);

        let market_id = get_market_id(pool);
        event::emit_pool_deposit(
            tx_context::sender(ctx),
            mint_value,
            type_name::into_string(type_name::get<CoinType>()),
            market_id
        )
    }

    public(friend) fun deposit_balance<CoinType>(pool: &mut Pool<CoinType>, deposit_balance: Balance<CoinType>, user: address) {
        let balance_value = balance::value(&deposit_balance);
        balance::join(&mut pool.balance, deposit_balance);

        if (dynamic_field::exists_(&pool.id, PoolManagerKey {})) {
            let manage = dynamic_field::borrow_mut(&mut pool.id, PoolManagerKey {});
            pool_manager::update_deposit(manage, balance_value);
        };

        let market_id = get_market_id(pool);
        event::emit_pool_deposit(
            user,
            balance_value,
            type_name::into_string(type_name::get<CoinType>()),
            market_id
        )
    }

    // unused
    // warning: this function doesn't track pool balance for fund manager
    public(friend) fun withdraw<CoinType>(pool: &mut Pool<CoinType>, amount: u64, recipient: address, ctx: &mut TxContext) {
        let withdraw_balance = balance::split(&mut pool.balance, amount);
        let withdraw_coin = coin::from_balance(withdraw_balance, ctx);
        let market_id = get_market_id(pool);
        event::emit_pool_withdraw(
            tx_context::sender(ctx),
            recipient,
            amount,
            type_name::into_string(type_name::get<CoinType>()),
            market_id
        );

        transfer::public_transfer(withdraw_coin, recipient)
    }

    public(friend) fun withdraw_balance<CoinType>(pool: &mut Pool<CoinType>, amount: u64, user: address): Balance<CoinType> {
        if (amount == 0) {
            let _zero = balance::zero<CoinType>();
            return _zero
        };

        if (dynamic_field::exists_(&pool.id, PoolManagerKey {})) {
            abort error::invalid_function_call()
        };

        let _balance = balance::split(&mut pool.balance, amount);
        let market_id = get_market_id(pool);
        event::emit_pool_withdraw(
            user,
            user,
            amount,
            type_name::into_string(type_name::get<CoinType>()),
            market_id
        );

        return _balance
    }

    // for repay only, no need to prepare fund because it's for excess amount
    // directly withdraw balance without preparing fund
    public(friend) fun direct_withdraw_balance_v2<CoinType>(pool: &mut Pool<CoinType>, amount: u64, user: address): Balance<CoinType> {
        if (amount == 0) {
            let _zero = balance::zero<CoinType>();
            return _zero
        };

        if (dynamic_field::exists_(&pool.id, PoolManagerKey {})) {
            let manage = dynamic_field::borrow_mut(&mut pool.id, PoolManagerKey {});
            pool_manager::update_withdraw(manage, amount);
        };

        let _balance = balance::split(&mut pool.balance, amount);
        let market_id = get_market_id(pool);
        event::emit_pool_withdraw(
            user,
            user,
            amount,
            type_name::into_string(type_name::get<CoinType>()),
            market_id
        );

        return _balance
    }


    public(friend) fun withdraw_balance_v2<CoinType>(pool: &mut Pool<CoinType>, amount: u64, user: address, system_state: &mut SuiSystemState, ctx: &mut TxContext): Balance<CoinType> {
        if (amount == 0) {
            let _zero = balance::zero<CoinType>();
            return _zero
        };

        let _balance = if (dynamic_field::exists_(&pool.id, PoolManagerKey {})) {
            let manage = dynamic_field::borrow_mut(&mut pool.id, PoolManagerKey {});
            let _prepare_balance = pool_manager::prepare_before_withdraw<CoinType>(manage, amount, balance::value(&pool.balance), system_state, ctx);
            balance::join(&mut pool.balance, _prepare_balance);
            let _withdraw_balance = balance::split(&mut pool.balance, amount);
            pool_manager::update_withdraw(manage, amount);
            _withdraw_balance
        } else {
            let _withdraw_balance = balance::split(&mut pool.balance, amount);
            _withdraw_balance
        };
        
        let market_id = get_market_id(pool);
        event::emit_pool_withdraw(
            user,
            user,
            amount,
            type_name::into_string(type_name::get<CoinType>()),
            market_id
        );

        return _balance
    }

    public(friend) fun deposit_treasury<CoinType>(pool: &mut Pool<CoinType>, deposit_amount: u64) {
        let total_supply = balance::value(&pool.balance);
        assert!(total_supply >= deposit_amount, error::insufficient_balance());

        let decrease_balance = balance::split(&mut pool.balance, deposit_amount);
        if (dynamic_field::exists_(&pool.id, PoolManagerKey {})) {
            let manage = dynamic_field::borrow_mut(&mut pool.id, PoolManagerKey {});
            pool_manager::update_withdraw(manage, deposit_amount);
        };
        balance::join(&mut pool.treasury_balance, decrease_balance);
    }

    public fun withdraw_treasury<CoinType>(_cap: &mut PoolAdminCap, pool: &mut Pool<CoinType>, amount: u64, recipient: address, ctx: &mut TxContext) {
        let total_supply = balance::value(&pool.treasury_balance);
        assert!(total_supply >= amount, error::insufficient_balance());

        let withdraw_balance = balance::split(&mut pool.treasury_balance, amount);
        let withdraw_coin = coin::from_balance(withdraw_balance, ctx);
        transfer::public_transfer(withdraw_coin, recipient)
    }

    public(friend) fun withdraw_reserve_balance<CoinType>(
        _: &PoolAdminCap,
        pool: &mut Pool<CoinType>,
        amount: u64,
        recipient: address,
        system_state: &mut SuiSystemState,
        ctx: &mut TxContext
    ) {
        abort error::invalid_function_call()
    }

    public(friend) fun withdraw_reserve_balance_v2<CoinType>(
        _: &PoolAdminCap,
        pool: &mut Pool<CoinType>,
        amount: u64,
        recipient: address,
        system_state: &mut SuiSystemState,
        ctx: &mut TxContext
    ) {
        if (dynamic_field::exists_(&pool.id, PoolManagerKey {})) {
            let manage = dynamic_field::borrow_mut(&mut pool.id, PoolManagerKey {});
            let _prepare_balance = pool_manager::prepare_before_withdraw<CoinType>(manage, amount, balance::value(&pool.balance), system_state, ctx);
            balance::join(&mut pool.balance, _prepare_balance);
            pool_manager::update_withdraw(manage, amount);
        };

        let total_supply = balance::value(&pool.balance);
        assert!(total_supply >= amount, error::insufficient_balance());

        let withdraw_balance = balance::split(&mut pool.balance, amount);
        let withdraw_coin = coin::from_balance(withdraw_balance, ctx);

        let total_supply_after_withdraw = balance::value(&pool.balance);
        let market_id = get_market_id(pool);
        event::emit_pool_withdraw_reserve(
            tx_context::sender(ctx),
            recipient,
            amount,
            total_supply,
            total_supply_after_withdraw,
            type_name::into_string(type_name::get<CoinType>()),
            object::uid_to_address(&pool.id),
            market_id
        );

        transfer::public_transfer(withdraw_coin, recipient)
    }

    /// Get coin decimal
    public fun get_coin_decimal<CoinType>(pool: &Pool<CoinType>): u8 {
        pool.decimal
    }

    /// Convert amount from current decimal to target decimal
    public fun convert_amount(amount: u64, cur_decimal: u8, target_decimal: u8): u64 {
        while (cur_decimal != target_decimal) {
            if (cur_decimal < target_decimal) {
                amount = amount * 10;
                cur_decimal = cur_decimal + 1;
            }else {
                amount = amount / 10;
                cur_decimal = cur_decimal - 1;
            };
        };
        amount
    }

    /// Normal coin amount in dola protocol
    public fun normal_amount<CoinType>(pool: &Pool<CoinType>, amount: u64): u64 {
        let cur_decimal = get_coin_decimal<CoinType>(pool);
        let target_decimal = 9;
        convert_amount(amount, cur_decimal, target_decimal)
    }

    /// Unnormal coin amount in dola protocol
    public fun unnormal_amount<CoinType>(pool: &Pool<CoinType>, amount: u64): u64 {
        let cur_decimal = 9;
        let target_decimal = get_coin_decimal<CoinType>(pool);
        convert_amount(amount, cur_decimal, target_decimal)
    }

    public fun uid<T>(pool: &Pool<T>): &UID {
        &pool.id
    }

    // ------Pool Manager------
    public fun init_sui_pool_manager(_: &PoolAdminCap, pool: &mut Pool<SUI>, stake_pool: StakePool, metadata: Metadata<CERT>, target_sui_amount: u64, ctx: &mut TxContext) {
        assert!(!dynamic_field::exists_(&pool.id, PoolManagerKey {}), 0);
        let pool_manager = pool_manager::new(stake_pool, metadata, balance::value(&pool.balance), target_sui_amount, ctx);
        dynamic_field::add(&mut pool.id, PoolManagerKey {}, pool_manager);
    }

    public fun enable_manage(_: &PoolAdminCap, pool: &mut Pool<SUI>) {
        let pool_manager = dynamic_field::borrow_mut(&mut pool.id, PoolManagerKey {});
        pool_manager::enable_manage(pool_manager);
    }

    public fun disable_manage(_: &PoolAdminCap, pool: &mut Pool<SUI>) {
        let pool_manager = dynamic_field::borrow_mut(&mut pool.id, PoolManagerKey {});
        pool_manager::disable_manage(pool_manager, balance::value(&pool.balance));
    }

    public fun refresh_stake(pool: &mut Pool<SUI>, system_state: &mut SuiSystemState, ctx: &mut TxContext) {
        let pool_manager = dynamic_field::borrow_mut(&mut pool.id, PoolManagerKey {});
        pool_manager::refresh_stake(pool_manager, &mut pool.balance, system_state, ctx);
    }

    public fun withdraw_vsui_from_treasury(_: &PoolAdminCap, pool: &mut Pool<SUI>, recipient: address, system_state: &mut SuiSystemState, ctx: &mut TxContext) {
        let pool_manager = dynamic_field::borrow_mut(&mut pool.id, PoolManagerKey {});
        let vsui_balance = pool_manager::take_vsui_from_treasury(pool_manager, balance::value(&pool.balance), system_state, ctx);
        let vsui_coin = coin::from_balance(vsui_balance, ctx);
        transfer::public_transfer(vsui_coin, recipient);
    }

    public fun set_target_sui_amount(_: &PoolAdminCap, pool: &mut Pool<SUI>, target_sui_amount: u64, system_state: &mut SuiSystemState, ctx: &mut TxContext) {
        let pool_manager = dynamic_field::borrow_mut(&mut pool.id, PoolManagerKey {});
        pool_manager::set_target_sui_amount(pool_manager, target_sui_amount);
        pool_manager::refresh_stake(pool_manager, &mut pool.balance, system_state, ctx);
    }

    public fun unstake_vsui(pool: &mut Pool<SUI>, system_state: &mut SuiSystemState, vsui_coin: Coin<CERT>, ctx: &mut TxContext): Coin<SUI> {
        let pool_manager = dynamic_field::borrow_mut(&mut pool.id, PoolManagerKey {});
        pool_manager::unstake_vsui(pool_manager, system_state, vsui_coin, ctx)
    }

    public fun set_validator_weights_vsui(pool: &mut Pool<SUI>, system_state: &mut SuiSystemState,  vsui_operator_cap: &OperatorCap, validator_weights: VecMap<address, u64>, ctx: &mut TxContext) {
        let pool_manager = dynamic_field::borrow_mut(&mut pool.id, PoolManagerKey {});
        pool_manager::set_validator_weights_vsui(pool_manager, system_state, vsui_operator_cap, validator_weights, ctx)
    }

    public fun direct_deposit_sui(_: &PoolAdminCap, pool: &mut Pool<SUI>, sui_coin: Coin<SUI>, ctx: &mut TxContext) {
        deposit(pool, sui_coin, ctx)
    }

    public fun get_treasury_sui_amount(pool: &Pool<SUI>): u64 {
        let pool_manager = dynamic_field::borrow(&pool.id, PoolManagerKey {});
        pool_manager::get_treasury_sui_amount(pool_manager, balance::value(&pool.balance))
    }

    public fun get_market_id<CoinType>(pool: &Pool<CoinType>): u64 {
        *dynamic_field::borrow(&pool.id, MarketIdKey {})
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx)
    }

    #[test_only]
    public fun create_pool_for_testing<T>(cap: &PoolAdminCap, decimal: u8, ctx: &mut TxContext) {
        create_pool_with_market_id<T>(cap, decimal, 0, ctx);
    }

    #[test_only]
    public fun create_pool_with_market_id_for_testing<T>(cap: &PoolAdminCap, decimal: u8, market_id: u64, ctx: &mut TxContext) {
        create_pool_with_market_id<T>(cap, decimal, market_id, ctx);
    }

    #[test_only]
    public fun get_pool_info<T>(pool: &Pool<T>): (u64, u64, u8) {
        (
            balance::value(&pool.balance),
            balance::value(&pool.treasury_balance),
            pool.decimal,
        )
    }

    #[test_only]
    public fun deposit_for_testing<T>(pool: &mut Pool<T>, mint_coin: Coin<T>, ctx: &mut TxContext) {
        deposit(pool, mint_coin, ctx);
    }

    #[test_only]
    public fun withdraw_for_testing<T>(pool: &mut Pool<T>, amount: u64, recipient: address, ctx: &mut TxContext) {
        withdraw(pool, amount, recipient, ctx)
    }

    #[test_only]
    public fun deposit_treasury_for_testing<T>(pool: &mut Pool<T>, deposit_amount: u64) {
        deposit_treasury(pool, deposit_amount)
    }

    #[test_only]
    public fun deposit_balance_for_testing<T>(pool: &mut Pool<T>, deposit_balance: Balance<T>, user: address) {
        deposit_balance(pool, deposit_balance, user)
    }

    #[test_only]
    public fun withdraw_balance_for_testing<T>(pool: &mut Pool<T>, amount: u64, user: address): Balance<T> {
        withdraw_balance(pool, amount, user)
    }

    #[test_only]
    public fun withdraw_balance_v2_for_testing<T>(pool: &mut Pool<T>, amount: u64, user: address, system_state: &mut SuiSystemState, ctx: &mut TxContext): Balance<T> {
        withdraw_balance_v2(pool, amount, user, system_state, ctx)
    }

    #[test_only]
    public fun get_pool_manager<CoinType>(pool: &mut Pool<CoinType>): &mut SuiPoolManager {
        dynamic_field::borrow_mut(&mut pool.id, PoolManagerKey {})
    }
}