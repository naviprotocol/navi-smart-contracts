#[lint_allow(self_transfer)]
#[allow(unused_use)]
module lending_core::incentive_v2 {
    use std::vector::{Self};
    use std::type_name::{Self, TypeName};

    use sui::transfer;
    use sui::event::emit;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID};
    use sui::table::{Self, Table};
    use sui::clock::{Self, Clock};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};

    use lending_core::utils;
    use lending_core::ray_math;
    use lending_core::safe_math;
    use oracle::oracle::{PriceOracle};

    use lending_core::lending;
    use lending_core::pool::{Pool};
    use lending_core::version::{Self};
    use lending_core::error::{Self};
    use lending_core::constants::{Self};
    use lending_core::account::{Self, AccountCap};
    use lending_core::incentive::{Self as incentive_v1, Incentive as IncentiveV1};
    use lending_core::storage::{Self, Storage, OwnerCap as StorageOwnerCap};

    friend lending_core::incentive_v3;

    struct OwnerCap has key, store {
        id: UID,
    }

    struct Incentive has key, store {
        id: UID,
        version: u64,
        pool_objs: vector<address>,
        inactive_objs: vector<address>,
        pools: Table<address, IncentivePool>,
        funds: Table<address, IncentiveFundsPoolInfo>,
    }

    struct IncentivePool has key, store {
        id: UID,
        phase: u64,
        funds: address, // IncentiveFundsPool.id -> pre_check: object::id_to_address(IncentiveFundsPool.id) equals IncentivePool.funds
        start_at: u64, // Distribution start time
        end_at: u64, // Distribution end time
        closed_at: u64, // Distribution closed time, that means you cannot claim after this time. But the administrator can set this value to 0, which means it can always be claimed.
        total_supply: u64, // sui::balance::supply_value max is 18446744073709551615u64, see https://github.com/MystenLabs/sui/blob/main/crates/sui-framework/packages/sui-framework/sources/balance.move#L53
        option: u8, // supply, withdraw, borrow, repay or liquidation
        asset_id: u8, // the asset id on protocol pool
        factor: u256, // the ratio, type in 1e18
        last_update_at: u64,
        distributed: u64,
        index_reward: u256,
        index_rewards_paids: Table<address, u256>,
        total_rewards_of_users: Table<address, u256>,
        total_claimed_of_users: Table<address, u256>,
    }

    struct IncentiveFundsPool<phantom CoinType> has key, store {
        id: UID,
        oracle_id: u8,
        balance: Balance<CoinType>,
        coin_type: TypeName,
    }

    struct IncentiveFundsPoolInfo has key, store {
        id: UID,
        oracle_id: u8,
        coin_type: TypeName
    }

    // Events
    struct CreateFundsPool has copy, drop {
        sender: address,
        coin_type: TypeName,
        oracle_id: u8,
        force: bool,
    }

    struct IncreasedFunds has copy, drop {
        sender: address,
        balance_before: u64,
        balance_after: u64,
    }

    struct WithdrawFunds has copy, drop {
        sender: address,
        value: u64,
    }

    struct CreateIncentive has copy, drop {
        sender: address,
        incentive_pool_pro: address,
    }

    struct CreateIncentivePool has copy, drop {
        sender: address,
        pool: address,
    }

    struct RewardsClaimed has copy, drop {
        sender: address,
        pool: address,
        amount: u64,
    }

    public fun create_and_transfer_owner(_: &StorageOwnerCap, ctx: &mut TxContext) {
        transfer::public_transfer(OwnerCap {id: object::new(ctx)}, tx_context::sender(ctx));
    }

    public fun version_verification(incentive: &Incentive) {
        version::pre_check_version(incentive.version)
    }
    
    public fun version_migrate(_: &OwnerCap, incentive: &mut Incentive) {
        assert!(incentive.version < version::this_version(), error::incorrect_version());
        incentive.version = version::this_version();
    }

    // +++++++++++++++Split: For Funds Pool+++++++++++++++
    public fun create_funds_pool<T>(_: &OwnerCap, incentive: &mut Incentive, oracle_id: u8, force: bool, ctx: &mut TxContext) {
        version_verification(incentive);

        // TODO: force create, if funds already exists
        let new_id = object::new(ctx);
        let new_obj_address = object::uid_to_address(&new_id);

        transfer::share_object(IncentiveFundsPool<T> {
            id: new_id,
            oracle_id: oracle_id,
            balance: balance::zero<T>(),
            coin_type: type_name::get<T>(),
        });

        table::add(&mut incentive.funds, new_obj_address, IncentiveFundsPoolInfo {
            id: object::new(ctx),
            oracle_id: oracle_id,
            coin_type: type_name::get<T>(),
        });

        emit(CreateFundsPool {
            sender: tx_context::sender(ctx),
            coin_type: type_name::get<T>(),
            force: force,
            oracle_id: oracle_id,
        })
    }

    // TODO: to be entry?
    public fun add_funds<T>(_: &OwnerCap, funds: &mut IncentiveFundsPool<T>, funds_coin: Coin<T>, value: u64, ctx: &mut TxContext) {
        let before = balance::value(&funds.balance);
        let funds_balance = utils::split_coin_to_balance(funds_coin, value, ctx);
        let after = balance::join(&mut funds.balance, funds_balance);

        emit(IncreasedFunds {
            sender: tx_context::sender(ctx),
            balance_before: before,
            balance_after: after,
        })
    }

    public fun withdraw_funds<T>(_: &OwnerCap, funds: &mut IncentiveFundsPool<T>, value: u64, ctx: &mut TxContext) {
        assert!(balance::value(&funds.balance) >= value, error::insufficient_balance());

        let _coin = coin::from_balance(
            balance::split(&mut funds.balance, value),
            ctx
        );
        transfer::public_transfer(_coin, tx_context::sender(ctx));

        emit(WithdrawFunds {
            sender: tx_context::sender(ctx),
            value: value,
        })
    }

    // +++++++++++++++Split: For Incentive Pool+++++++++++++++
    public fun create_incentive(_: &OwnerCap, ctx: &mut TxContext) {
        let new_id = object::new(ctx);
        let new_obj_address = object::uid_to_address(&new_id);

        let pool = Incentive {
            id: new_id,
            version: version::this_version(),
            pool_objs: vector::empty<address>(),
            inactive_objs: vector::empty<address>(),
            pools: table::new<address, IncentivePool>(ctx),
            funds: table::new<address, IncentiveFundsPoolInfo>(ctx),
        };
        transfer::share_object(pool);

        emit(CreateIncentive {
            sender: tx_context::sender(ctx),
            incentive_pool_pro: new_obj_address,
        })
    }

    public fun create_incentive_pool<T>(
        _: &OwnerCap,
        incentive: &mut Incentive,
        funds: &IncentiveFundsPool<T>,
        phase: u64,
        start_at: u64,
        end_at: u64,
        closed_at: u64,
        total_supply: u64,
        option: u8,
        asset_id: u8,
        factor: u256,
        ctx: &mut TxContext
    ) {
        assert!(start_at < end_at, error::invalid_duration_time());
        assert!(closed_at == 0 || closed_at > end_at, error::invalid_duration_time());

        let new_id = object::new(ctx);
        let new_obj_address = object::uid_to_address(&new_id);

        let pool = IncentivePool {
            id: new_id,
            funds: object::uid_to_address(&funds.id),
            phase: phase,
            start_at: start_at,
            end_at: end_at,
            closed_at: closed_at,
            total_supply: total_supply,
            asset_id: asset_id,
            option: option,
            factor: factor,
            index_reward: 0,
            distributed: 0,
            last_update_at: start_at,
            index_rewards_paids: table::new<address, u256>(ctx),
            total_rewards_of_users: table::new<address, u256>(ctx),
            total_claimed_of_users: table::new<address, u256>(ctx),
        };

        table::add(&mut incentive.pools, new_obj_address, pool);
        vector::push_back(&mut incentive.pool_objs, new_obj_address);

        emit(CreateIncentivePool {
            sender: tx_context::sender(ctx),
            pool: new_obj_address,
        })
    }

    public fun freeze_incentive_pool(_: &OwnerCap, incentive_v2: &mut Incentive, deadline: u64) {
        let new_active_pools = vector::empty<address>();
        let new_inactive_pools = vector::empty<address>();

        let pool_length = vector::length(&incentive_v2.pool_objs);
        while (pool_length > 0) {
            let pool_obj = *vector::borrow(&incentive_v2.pool_objs, pool_length-1);
            let pool_info = table::borrow(&incentive_v2.pools, pool_obj);
            if (pool_info.phase < deadline) {
                vector::push_back(&mut new_inactive_pools, pool_obj);
            } else {
                vector::push_back(&mut new_active_pools, pool_obj);
            };

            pool_length = pool_length - 1;
        };

        incentive_v2.pool_objs = new_active_pools;
        vector::append(&mut incentive_v2.inactive_objs, new_inactive_pools);
    }

    public entry fun claim_reward<T>(clock: &Clock, incentive: &mut Incentive, funds_pool: &mut IncentiveFundsPool<T>, storage: &mut Storage, asset_id: u8, option: u8, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let reward_balance = base_claim_reward(clock, incentive, funds_pool, storage, asset_id, option, sender);

        if (balance::value(&reward_balance) > 0) {
            transfer::public_transfer(coin::from_balance(reward_balance, ctx), sender)
        } else {
            balance::destroy_zero(reward_balance)
        }
    }

    public fun claim_reward_non_entry<T>(clock: &Clock, incentive: &mut Incentive, funds_pool: &mut IncentiveFundsPool<T>, storage: &mut Storage, asset_id: u8, option: u8, ctx: &TxContext): Balance<T> {
        let sender = tx_context::sender(ctx);
        base_claim_reward(clock, incentive, funds_pool, storage, asset_id, option, sender)
    }

    public fun claim_reward_with_account_cap<T>(clock: &Clock, incentive: &mut Incentive, funds_pool: &mut IncentiveFundsPool<T>, storage: &mut Storage, asset_id: u8, option: u8, account_cap: &AccountCap): Balance<T> {
        let sender = account::account_owner(account_cap);
        base_claim_reward(clock, incentive, funds_pool, storage, asset_id, option, sender)
    }

    fun base_claim_reward<T>(clock: &Clock, incentive: &mut Incentive, funds_pool: &mut IncentiveFundsPool<T>, storage: &mut Storage, asset_id: u8, option: u8, user: address): Balance<T> {
        version_verification(incentive);

        // let sender = tx_context::sender(ctx);
        let now = clock::timestamp_ms(clock);
        update_reward(clock, incentive, storage, asset_id, option, user);

        let hits = get_pool_from_funds_pool(incentive, funds_pool, asset_id, option);
        let hit_length = vector::length(&hits);
        let amount_to_pay = 0;
        while (hit_length > 0) {
            let pool_obj = *vector::borrow(&hits, hit_length-1);
            let pool = table::borrow_mut(&mut incentive.pools, pool_obj);
            if (pool.closed_at > 0 && now > pool.closed_at) {
                hit_length = hit_length -1;
                continue
            };

            let total_rewards_of_user = 0;
            if (table::contains(&pool.total_rewards_of_users, user)) {
                total_rewards_of_user = *table::borrow(&pool.total_rewards_of_users, user);
            };

            let total_claimed_of_user = 0;
            if (table::contains(&pool.total_claimed_of_users, user)) {
                total_claimed_of_user = table::remove(&mut pool.total_claimed_of_users, user);
            };
            table::add(&mut pool.total_claimed_of_users, user, total_rewards_of_user);

            let reward = ((total_rewards_of_user - total_claimed_of_user) / ray_math::ray() as u64);
            if ((pool.distributed + reward) > pool.total_supply) {
                reward = pool.total_supply - pool.distributed
            };

            if (reward > 0) {
                amount_to_pay = amount_to_pay + reward;
                pool.distributed = pool.distributed + reward;

                emit(RewardsClaimed {
                    sender: user,
                    pool: pool_obj,
                    amount: reward,
                })
            };
            hit_length = hit_length -1;
        };

        if (amount_to_pay > 0) {
            let _balance = decrease_balance(funds_pool, amount_to_pay);
            return _balance
        };
        return balance::zero<T>()
    }

    public fun get_pool_from_funds_pool<T>(incentive: &Incentive, funds_pool: &IncentiveFundsPool<T>, asset_id: u8, option: u8): vector<address> {
        let funds_pool_obj = object::uid_to_address(&funds_pool.id);
        let ret = vector::empty<address>();

        let pool_objs = incentive.pool_objs;
        let pool_length = vector::length(&pool_objs);

        while (pool_length > 0) {
            let obj = *vector::borrow(&pool_objs, pool_length-1);
            let info = table::borrow(&incentive.pools, obj);

            if (
                (info.asset_id == asset_id) &&
                (info.option == option) &&
                (info.funds == funds_pool_obj)
            ) {
                vector::push_back(&mut ret, obj)
            };

            pool_length = pool_length - 1;
        };

        ret
    }

    public(friend) fun update_reward_all(clock: &Clock, incentive: &mut Incentive, storage: &mut Storage, asset_id: u8, user: address) {
        update_reward(clock, incentive, storage, asset_id, constants::option_type_supply(), user);
        update_reward(clock, incentive, storage, asset_id, constants::option_type_withdraw(), user);
        update_reward(clock, incentive, storage, asset_id, constants::option_type_repay(), user);
        update_reward(clock, incentive, storage, asset_id, constants::option_type_borrow(), user);
    }

    fun update_reward(clock: &Clock, incentive: &mut Incentive, storage: &mut Storage, asset_id: u8, option: u8, user: address) {
        version_verification(incentive);

        let now = clock::timestamp_ms(clock);
        let (_, _, pool_objs) = get_pool_from_asset_and_option(incentive, asset_id, option);
        let pool_length = vector::length(&pool_objs);
        let (user_supply_balance, user_borrow_balance) = storage::get_user_balance(storage, asset_id, user);
        let (total_supply_balance, total_borrow_balance) = storage::get_total_supply(storage, asset_id);
        if (option == constants::option_type_borrow()) {
            total_supply_balance = total_borrow_balance
        };

        
        while(pool_length > 0) {
            let pool = table::borrow_mut(
                &mut incentive.pools,
                *vector::borrow(&pool_objs, pool_length-1)
            );

            let user_effective_amount = calculate_user_effective_amount(option, user_supply_balance, user_borrow_balance, pool.factor);
            let (index_reward, total_rewards_of_user) = calculate_one(pool, now, total_supply_balance, user, user_effective_amount);

            pool.index_reward = index_reward;
            pool.last_update_at = now;
            
            if (table::contains(&pool.index_rewards_paids, user)) {
                table::remove(&mut pool.index_rewards_paids, user);
            };
            table::add(&mut pool.index_rewards_paids, user, index_reward);

            if (table::contains(&pool.total_rewards_of_users, user)) {
                table::remove(&mut pool.total_rewards_of_users, user);
            };
            table::add(&mut pool.total_rewards_of_users, user, total_rewards_of_user);

            pool_length = pool_length - 1;
        }
    }

    fun calculate_one(pool: &IncentivePool, current_timestamp: u64, supply: u256, user: address, user_balance: u256): (u256, u256) {
        let start_at = pool.start_at;
        if (start_at < pool.last_update_at) {
            start_at = pool.last_update_at
        };

        let end_at = pool.end_at;
        if (current_timestamp < end_at) {
            end_at = current_timestamp;
        };

        let index_reward = pool.index_reward;
        if (start_at < end_at) {
            let time_diff = end_at - start_at;
            let rate_ms = calculate_release_rate(pool);

            let index_increase = 0;
            if (supply > 0) {
                index_increase = safe_math::mul(rate_ms, (time_diff as u256)) / supply;
            };

            index_reward = index_reward + index_increase;
        };

        let total_rewards_of_user = 0;
        if (table::contains(&pool.total_rewards_of_users, user)) {
            total_rewards_of_user = *table::borrow(&pool.total_rewards_of_users, user);
        };

        let index_rewards_paid = 0;
        if (table::contains(&pool.index_rewards_paids, user)) {
            index_rewards_paid = *table::borrow(&pool.index_rewards_paids, user);
        };
        
        let reward_increase = (index_reward - index_rewards_paid) * user_balance;
        total_rewards_of_user = total_rewards_of_user + reward_increase;

        return (index_reward, total_rewards_of_user)
    }

    public fun calculate_release_rate(pool: &IncentivePool): u256 {
        ray_math::ray_div(
            (pool.total_supply as u256),
            ((pool.end_at - pool.start_at) as u256)
        )
    }

    public fun calculate_user_effective_amount(option: u8, supply_balance: u256, borrow_balance: u256, factor: u256): u256 {
        let tmp_balance = supply_balance;
        if (option == constants::option_type_borrow()) {
            supply_balance = borrow_balance;
            borrow_balance = tmp_balance;
        };

        // supply- Scoefficient*borrow
        // **After many verifications, the calculation method is ray_mul
        // factor is set to 1e27, and borrow_balance decimal is 9
        // the correct one is: ray_math::ray_mul(1000000000000000000000000000, 2_000000000) = 2_000000000
        // ray_math::ray_mul(800000000000000000000000000, 2_000000000) = 1_600000000
        let effective_borrow_balance = ray_math::ray_mul(factor, borrow_balance);
        if (supply_balance > effective_borrow_balance) {
            return supply_balance - effective_borrow_balance
        };

        0
    }

    public fun get_pool_from_asset_and_option(incentive: &Incentive, asset_id: u8, option: u8): (vector<address>, vector<address>, vector<address>) {
        let pool_objs = incentive.pool_objs;
        let pool_length = vector::length(&pool_objs);

        let pools_by_asset = vector::empty<address>();
        let pools_by_option = vector::empty<address>();
        let pools_by_asset_and_option = vector::empty<address>();
        while (pool_length > 0) {
            let obj = *vector::borrow(&pool_objs, pool_length-1);
            let info = table::borrow(&incentive.pools, obj);
            if (info.asset_id == asset_id && info.option == option) {
                vector::push_back(&mut pools_by_asset, obj);
                vector::push_back(&mut pools_by_option, obj);
                vector::push_back(&mut pools_by_asset_and_option, obj);
                pool_length = pool_length - 1;
                continue
            };

            if (info.asset_id == asset_id) {
                vector::push_back(&mut pools_by_asset, obj)
            };

            if (info.option == option) {
                vector::push_back(&mut pools_by_option, obj)
            };

            pool_length = pool_length - 1;
        };

        return (pools_by_asset, pools_by_option, pools_by_asset_and_option)
    }

    public fun get_active_pools(incentive: &Incentive, asset_id: u8, option: u8, now: u64): vector<address> {
        let pool_objs = incentive.pool_objs;
        let pool_length = vector::length(&pool_objs);

        let pools = vector::empty<address>();
        while (pool_length > 0) {
            let obj = *vector::borrow(&pool_objs, pool_length-1);
            let info = table::borrow(&incentive.pools, obj);

            if (
                (info.asset_id == asset_id) &&
                (info.option == option) &&
                (info.start_at <= now) &&
                (info.end_at >= now)
            ) {
                vector::push_back(&mut pools, obj);
            };
            pool_length = pool_length - 1;
        };
        pools
    }

    public fun get_pool_objects(incentive: &Incentive): vector<address> {
        incentive.pool_objs
    }

    public fun get_inactive_pool_objects(incentive: &Incentive): vector<address> {
        incentive.inactive_objs
    }

    // public getter
    public fun option_supply(): u8 {
        constants::option_type_supply()
    }

    public fun option_withdraw(): u8 {
        constants::option_type_withdraw()
    }

    public fun option_borrow(): u8 {
        constants::option_type_borrow()
    }

    public fun option_repay(): u8 {
        constants::option_type_repay()
    }

    public fun get_pool_info(incentive: &Incentive, obj: address): (
        address, // id
        u64, // phase
        address, // funds
        u64, // start_at
        u64, // end_at
        u64, // closed_at
        u64, // total_supply
        u8, // option
        u8, // asset_id
        u256, // factor
        u64, // last_update_at
        u64, // distributed
        u256 // index_reward
    ) {
        let pool = table::borrow(&incentive.pools, obj);

        (
            object::uid_to_address(&pool.id),
            pool.phase,
            pool.funds,
            pool.start_at,
            pool.end_at,
            pool.closed_at,
            pool.total_supply,
            pool.option,
            pool.asset_id,
            pool.factor,
            pool.last_update_at,
            pool.distributed,
            pool.index_reward
        )
    }

    public fun get_pool_length(incentive: &Incentive): u64 {
        vector::length(&incentive.pool_objs)
    }

    public fun get_funds_value<T>(funds: &IncentiveFundsPool<T>): u64 {
        balance::value(&funds.balance)
    }

    public fun calculate_one_from_pool(incentive: &Incentive, obj: address, current_timestamp: u64, supply: u256, user: address, user_balance: u256): (u256, u256) {
        let pool = table::borrow(&incentive.pools, obj);
        calculate_one(pool, current_timestamp, supply, user, user_balance)
    }

    public fun get_total_claimed_from_user(incentive: &Incentive, obj: address, user: address): u256 {
        let pool = table::borrow(&incentive.pools, obj);
        let total_claimed_of_user = 0;
        if (table::contains(&pool.total_claimed_of_users, user)) {
            total_claimed_of_user = *table::borrow(&pool.total_claimed_of_users, user)
        };
        total_claimed_of_user
    }

    public fun get_funds_info(incentive: &Incentive, obj: address): (
        address, // id
        u8, // oracle_id
        TypeName,
    ) {
        let info = table::borrow(&incentive.funds, obj);
        (
            object::uid_to_address(&info.id),
            info.oracle_id,
            info.coin_type
        )
    }

    // private function
    fun decrease_balance<T>(funds_pool: &mut IncentiveFundsPool<T>, amount: u64): Balance<T> {
        let _balance = balance::split(&mut funds_pool.balance, amount);
        return _balance
    }

    // lending protocol entry function
    #[allow(unused_variable)] 
    public entry fun entry_deposit<CoinType>(
        clock: &Clock,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        deposit_coin: Coin<CoinType>,
        amount: u64,
        incentive_v1: &mut IncentiveV1,
        incentive_v2: &mut Incentive,
        ctx: &mut TxContext
    ) {
        abort 0
    }


    #[allow(unused_variable)] 
    public fun deposit_with_account_cap<CoinType>(
        clock: &Clock,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        deposit_coin: Coin<CoinType>,
        incentive_v1: &mut IncentiveV1,
        incentive_v2: &mut Incentive,
        account_cap: &AccountCap
    ) {
        abort 0
    }

    #[allow(unused_variable)] 
    public entry fun entry_deposit_on_behalf_of_user<CoinType>(
        clock: &Clock,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        deposit_coin: Coin<CoinType>,
        amount: u64,
        user: address,
        incentive_v1: &mut IncentiveV1,
        incentive_v2: &mut Incentive,
        ctx: &mut TxContext
    ) {
        abort 0
    }

    #[allow(unused_variable)] 
    public entry fun entry_withdraw<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        amount: u64,
        incentive_v1: &mut IncentiveV1,
        incentive_v2: &mut Incentive,
        ctx: &mut TxContext
    ) {
        abort 0
    }

    #[allow(unused_variable)] 
    public fun withdraw_with_account_cap<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        amount: u64,
        incentive_v1: &mut IncentiveV1,
        incentive_v2: &mut Incentive,
        account_cap: &AccountCap
    ): Balance<CoinType> {
        abort 0
    }

    #[allow(unused_variable)] 
    public fun withdraw<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        amount: u64,
        incentive_v1: &mut IncentiveV1,
        incentive_v2: &mut Incentive,
        ctx: &mut TxContext
    ): Balance<CoinType> {
        abort 0
    }

    #[allow(unused_variable)] 
    public entry fun entry_borrow<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        amount: u64,
        incentive: &mut Incentive,
        ctx: &mut TxContext
    ) {
        abort 0
    }

    #[allow(unused_variable)] 
    public fun borrow_with_account_cap<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        amount: u64,
        incentive: &mut Incentive,
        account_cap: &AccountCap
    ): Balance<CoinType> {
        abort 0
    }

    #[allow(unused_variable)] 
    public fun borrow<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        amount: u64,
        incentive: &mut Incentive,
        ctx: &mut TxContext
    ): Balance<CoinType> {
        abort 0
    }

    #[allow(unused_variable)] 
    public entry fun entry_repay<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        repay_coin: Coin<CoinType>,
        amount: u64,
        incentive: &mut Incentive,
        ctx: &mut TxContext
    ) {
        abort 0
    }

    #[allow(unused_variable)] 
    public fun repay_with_account_cap<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        repay_coin: Coin<CoinType>,
        incentive: &mut Incentive,
        account_cap: &AccountCap
    ): Balance<CoinType> {
        abort 0
    }

    #[allow(unused_variable)] 
    public fun entry_repay_on_behalf_of_user<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        repay_coin: Coin<CoinType>,
        amount: u64,
        user: address,
        incentive: &mut Incentive,
        ctx: &mut TxContext
    ) {
        abort 0
    }

    #[allow(unused_variable)] 
    public fun repay<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        repay_coin: Coin<CoinType>,
        amount: u64,
        incentive: &mut Incentive,
        ctx: &mut TxContext
    ): Balance<CoinType> {
        abort 0
    }

    #[allow(unused_variable)] 
    public entry fun entry_liquidation<DebtCoinType, CollateralCoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        debt_asset: u8,
        debt_pool: &mut Pool<DebtCoinType>,
        debt_coin: Coin<DebtCoinType>,
        collateral_asset: u8,
        collateral_pool: &mut Pool<CollateralCoinType>,
        liquidate_user: address,
        liquidate_amount: u64,
        incentive_v1: &mut IncentiveV1,
        incentive_v2: &mut Incentive,
        ctx: &mut TxContext
    ) {
        abort 0
    }

    #[allow(unused_variable)] 
    public fun liquidation<DebtCoinType, CollateralCoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        debt_asset: u8,
        debt_pool: &mut Pool<DebtCoinType>,
        debt_balance: Balance<DebtCoinType>,
        collateral_asset: u8,
        collateral_pool: &mut Pool<CollateralCoinType>,
        liquidate_user: address,
        incentive_v1: &mut IncentiveV1,
        incentive_v2: &mut Incentive,
        ctx: &mut TxContext
    ): (Balance<CollateralCoinType>, Balance<DebtCoinType>) {
        abort 0
    }

    #[test_only]
    public fun create_next_version_incentive_for_testing(_: &OwnerCap, ctx: &mut TxContext) {
        let new_id = object::new(ctx);
        let new_obj_address = object::uid_to_address(&new_id);

        let pool = Incentive {
            id: new_id,
            version: 0,
            pool_objs: vector::empty<address>(),
            inactive_objs: vector::empty<address>(),
            pools: table::new<address, IncentivePool>(ctx),
            funds: table::new<address, IncentiveFundsPoolInfo>(ctx),
        };
        transfer::share_object(pool);

        emit(CreateIncentive {
            sender: tx_context::sender(ctx),
            incentive_pool_pro: new_obj_address,
        })
    }

    #[test_only]
    public entry fun entry_deposit_for_testing<CoinType>(
        clock: &Clock,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        deposit_coin: Coin<CoinType>,
        amount: u64,
        incentive_v1: &mut IncentiveV1,
        incentive_v2: &mut Incentive,
        ctx: &mut TxContext
    ) {
        incentive_v1::update_reward(incentive_v1, clock, storage, asset, tx_context::sender(ctx));
        update_reward_all(clock, incentive_v2, storage, asset, tx_context::sender(ctx));
        lending::deposit_coin<CoinType>(clock, storage, pool, asset, deposit_coin, amount, ctx);
    }

    #[test_only]
    public entry fun entry_borrow_for_testing<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        amount: u64,
        incentive: &mut Incentive,
        ctx: &mut TxContext
    ) {
        update_reward_all(clock, incentive, storage, asset, tx_context::sender(ctx));
        let _balance =  lending::borrow_coin<CoinType>(clock, oracle, storage, pool, asset, amount, ctx);

        let _coin = coin::from_balance(_balance, ctx);
        transfer::public_transfer(_coin, tx_context::sender(ctx));
    }
}
