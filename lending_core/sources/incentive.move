#[allow(unused_field)]
module lending_core::incentive {
    use std::vector;
    use std::type_name;
    use std::ascii::{String};

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
    use lending_core::storage::{Self, Storage};
    use lending_core::error::{Self};
    use lending_core::account::{Self, AccountCap};

    friend lending_core::lending;
    friend lending_core::incentive_v2;

    struct IncentiveBal<phantom CoinType> has key, store {
        id: UID,
        asset: u8,
        current_idx: u64,
        distributed_amount: u256,
        balance: Balance<CoinType>
    }

    struct PoolInfo has store {
        id: u8,
        last_update_time: u64,
        coin_types: vector<String>,
        start_times: vector<u64>,
        end_times: vector<u64>,
        total_supplys: vector<u256>,
        rates: vector<u256>,
        index_rewards: vector<u256>,
        index_rewards_paids: vector<Table<address, u256>>,
        user_acc_rewards: vector<Table<address, u256>>,
        user_acc_rewards_paids: vector<Table<address, u256>>,
        oracle_ids: vector<u8>,
    }

    struct Incentive has key, store {
        id: UID,
        creator: address,
        owners: Table<u256, bool>,
        admins: Table<u256, bool>,

        pools: Table<u8, PoolInfo>,
        assets: vector<u8>,
    }

    struct PoolOwnerSetting has copy, drop {
        sender: address,
        owner: u256,
        value: bool,
    }

    struct PoolAdminSetting has copy, drop {
        sender: address,
        admin: u256,
        value: bool,
    }

    struct IncentiveOwnerCap has key, store {
        id: UID,
    }

    struct IncentiveAdminCap has key, store {
        id: UID,
    }

    fun init(ctx: &mut TxContext) {
        transfer::share_object(Incentive {
            id: object::new(ctx),
            creator: tx_context::sender(ctx),
            owners: table::new<u256, bool>(ctx),
            admins: table::new<u256, bool>(ctx),

            pools: table::new<u8, PoolInfo>(ctx),
            assets: vector::empty<u8>(),
        })
    }

    public fun create_and_transfer_ownership(_owner: address, _ctx: &mut TxContext) {
        abort 0
    }

    // Call by creator
    public fun set_owner(incentive: &mut Incentive, owner: u256, val: bool, ctx: &mut TxContext) {
        assert!(incentive.creator == tx_context::sender(ctx), error::not_owner());

        if (!table::contains(&incentive.owners, owner)) {
            table::add(&mut incentive.owners, owner, val)
        } else {
            let v = table::borrow_mut(&mut incentive.owners, owner);
            *v = val
        };

        emit(PoolOwnerSetting {
            sender: tx_context::sender(ctx),
            owner: owner, value: val
        })
    }

    public fun set_admin(incentive: &mut Incentive, admin: u256, val: bool, ctx: &mut TxContext) {
        assert!(incentive.creator == tx_context::sender(ctx), error::not_owner());

        if (!table::contains(&incentive.admins, admin)) {
            table::add(&mut incentive.admins, admin, val)
        } else {
            let v = table::borrow_mut(&mut incentive.admins, admin);
            *v = val
        };

        emit(PoolAdminSetting {
            sender: tx_context::sender(ctx),
            admin: admin, value: val
        })
    }

    public entry fun add_pool<CoinType>(
        incentive: &mut Incentive,
        clock: &Clock,
        asset: u8,
        start_time: u64,
        end_time: u64,
        reward_coin: Coin<CoinType>,
        amount: u64,
        oracle_id: u8,
        ctx: &mut TxContext
    ) {
        assert!(incentive.creator == tx_context::sender(ctx), error::not_owner());
        assert!(start_time > clock::timestamp_ms(clock) && end_time > start_time, error::invalid_duration_time());

        if (!table::contains(&incentive.pools, asset)) {
            table::add(&mut incentive.pools, asset, PoolInfo{
                id: asset,
                last_update_time: 0,
                coin_types: vector::empty<String>(),
                start_times: vector::empty<u64>(),
                end_times: vector::empty<u64>(),
                total_supplys: vector::empty<u256>(),
                rates: vector::empty<u256>(),
                index_rewards: vector::empty<u256>(),
                index_rewards_paids: vector::empty<Table<address, u256>>(),
                user_acc_rewards: vector::empty<Table<address, u256>>(),
                user_acc_rewards_paids: vector::empty<Table<address, u256>>(),
                oracle_ids: vector::empty<u8>(),
            });
            vector::push_back(&mut incentive.assets, asset)
        };

        let pool_info = table::borrow_mut(&mut incentive.pools, asset);
        let current_idx = vector::length(&pool_info.coin_types);

        vector::push_back(&mut pool_info.coin_types, type_name::into_string(type_name::get<CoinType>()));
        vector::push_back(&mut pool_info.start_times, start_time);
        vector::push_back(&mut pool_info.end_times, end_time);
        vector::push_back(&mut pool_info.total_supplys, (amount as u256));
        vector::push_back(&mut pool_info.rates, ray_math::ray_div((amount as u256), ((end_time - start_time) as u256)));
        vector::push_back(&mut pool_info.index_rewards, 0);
        vector::push_back(&mut pool_info.index_rewards_paids, table::new<address, u256>(ctx));
        vector::push_back(&mut pool_info.user_acc_rewards, table::new<address, u256>(ctx));
        vector::push_back(&mut pool_info.user_acc_rewards_paids, table::new<address, u256>(ctx));
        vector::push_back(&mut pool_info.oracle_ids, oracle_id);

        let bal = utils::split_coin_to_balance(reward_coin, amount, ctx);
        transfer::share_object(IncentiveBal<CoinType> {
            id: object::new(ctx),
            asset: asset,
            current_idx: current_idx,
            distributed_amount: 0,
            balance: bal
        })
    }

    public(friend) fun update_reward(
        incentive: &mut Incentive,
        clock: &Clock,
        storage: &mut Storage,
        asset: u8,
        account: address
    ) {
        if (table::contains(&incentive.pools, asset)) {
            let current_timestamp = clock::timestamp_ms(clock);
            let (index_rewards, user_acc_rewards) = calc_pool_update_rewards(incentive, storage, current_timestamp, asset, account);
            
            let pool_info = table::borrow_mut(&mut incentive.pools, asset);
            pool_info.last_update_time = current_timestamp;

            let length = vector::length(&pool_info.coin_types);
            let i = 0;
            while(i < length) {
                let index_reward_new = *vector::borrow(&index_rewards, i);
                let user_acc_reward_new = *vector::borrow(&user_acc_rewards, i);

                let index_reward = vector::borrow_mut(&mut pool_info.index_rewards, i);
                *index_reward = index_reward_new;

                let index_rewards_paids = vector::borrow_mut(&mut pool_info.index_rewards_paids, i);
                if (table::contains(index_rewards_paids, account)) {
                    table::remove(index_rewards_paids, account);
                };
                table::add(index_rewards_paids, account, index_reward_new);

                let user_acc_rewards = vector::borrow_mut(&mut pool_info.user_acc_rewards, i);
                if (table::contains(user_acc_rewards, account)) {
                    table::remove(user_acc_rewards, account);
                };
                table::add(user_acc_rewards, account, user_acc_reward_new);

                i = i + 1;
            }
        }
    }

    fun calc_pool_update_rewards(
        incentive: &Incentive,
        storage: &mut Storage,
        current_timestamp: u64,
        asset: u8,
        account: address
    ): (vector<u256>, vector<u256>) {
        let pool_info = table::borrow(&incentive.pools, asset);
        let length = vector::length(&pool_info.coin_types);
        let i = 0;

        let index_rewards = vector::empty<u256>();
        let user_acc_rewards = vector::empty<u256>();
        while(i < length) {
            let start_time = *vector::borrow(&pool_info.start_times, i);
            if (start_time < pool_info.last_update_time) {
                start_time = pool_info.last_update_time
            };
            let end_time = *vector::borrow(&pool_info.end_times, i);
            if (current_timestamp < end_time) {
                end_time = current_timestamp;
            };

            let rate = *vector::borrow(&pool_info.rates, i);
            let index_reward = *vector::borrow(&pool_info.index_rewards, i);
            if (start_time < end_time) {
                let time_diff = ((end_time - start_time) as u256);
                let (total_supply, _) = storage::get_total_supply(storage, asset);

                let index_increase = 0;
                if (total_supply > 0) {
                    index_increase = safe_math::mul(rate, time_diff) / total_supply;
                };
                index_reward = index_reward + index_increase;
            };
            vector::push_back(&mut index_rewards, index_reward);
            
            let user_acc_reward = 0;
            if (account != @0x0) {
                let _user_acc_rewards = vector::borrow(&pool_info.user_acc_rewards, i);
                if (table::contains(_user_acc_rewards, account)) {
                    user_acc_reward = *table::borrow(_user_acc_rewards, account);
                };

                let index_rewards_paid = 0;
                let index_rewards_paids = vector::borrow(&pool_info.index_rewards_paids, i);
                if (table::contains(index_rewards_paids, account)) {
                    index_rewards_paid = *table::borrow(index_rewards_paids, account);
                };
                let (supply_balance, _) = storage::get_user_balance(storage, asset, account);
                let reward_increase = (index_reward - index_rewards_paid) * supply_balance;
                user_acc_reward = user_acc_reward + reward_increase;
            };
            vector::push_back(&mut user_acc_rewards, user_acc_reward);

            i = i + 1;
        };

        (index_rewards, user_acc_rewards)
    }

    public entry fun claim_reward<CoinType>(
        incentive: &mut Incentive,
        bal: &mut IncentiveBal<CoinType>,
        clock: &Clock,
        storage: &mut Storage,
        account: address,
        ctx: &mut TxContext
    ) {
        let reward_balance = base_claim_reward(incentive, bal, clock, storage, account);

        if (balance::value(&reward_balance) > 0) {
            transfer::public_transfer(coin::from_balance(reward_balance, ctx), account)
        } else {
            balance::destroy_zero(reward_balance)
        }
    }

    public fun claim_reward_non_entry<CoinType>(incentive: &mut Incentive, bal: &mut IncentiveBal<CoinType>, clock: &Clock, storage: &mut Storage, ctx: &mut TxContext): Balance<CoinType> {
        base_claim_reward(incentive, bal, clock, storage, tx_context::sender(ctx))
    }

    public fun claim_reward_with_account_cap<CoinType>(incentive: &mut Incentive, bal: &mut IncentiveBal<CoinType>, clock: &Clock, storage: &mut Storage, account_cap: &AccountCap): Balance<CoinType> {
        base_claim_reward(incentive, bal, clock, storage, account::account_owner(account_cap))
    }

    fun base_claim_reward<CoinType>(incentive: &mut Incentive, bal: &mut IncentiveBal<CoinType>, clock: &Clock, storage: &mut Storage, account: address): Balance<CoinType> {
        update_reward(incentive, clock, storage, bal.asset, account);

        let pool_info = table::borrow_mut(&mut incentive.pools, bal.asset);
        let current_idx = bal.current_idx;

        let user_acc_reward = 0;
        let user_acc_rewards = vector::borrow(&pool_info.user_acc_rewards, current_idx);
        if (table::contains(user_acc_rewards, account)) {
            user_acc_reward = *table::borrow(user_acc_rewards, account);
        };

        let user_acc_rewards_paid = 0;
        let user_acc_rewards_paids = vector::borrow_mut(&mut pool_info.user_acc_rewards_paids, current_idx);
        if (table::contains(user_acc_rewards_paids, account)) {
            user_acc_rewards_paid = table::remove(user_acc_rewards_paids, account);
        };
        table::add(user_acc_rewards_paids, account, user_acc_reward);

        let amount_to_pay = (user_acc_reward - user_acc_rewards_paid) / ray_math::ray();

        let total_supply = *vector::borrow(&pool_info.total_supplys, current_idx);
        assert!(bal.distributed_amount + amount_to_pay <= total_supply, error::insufficient_balance());
        bal.distributed_amount = bal.distributed_amount + amount_to_pay;

        let claim_balance = balance::split(&mut bal.balance, (amount_to_pay as u64));
        claim_balance
    }

    public fun get_pool_count(incentive: &Incentive, asset: u8): u64 {
        let pool_count = 0;
        if (table::contains(&incentive.pools, asset)) {
            let pool_info = table::borrow(&incentive.pools, asset);
            pool_count = vector::length(&pool_info.coin_types);
        };
        (pool_count)
    }

    public fun get_pool_info(incentive: &Incentive, asset: u8, pool_idx: u64): (u64, u64, u256, u8) {
        assert!(table::contains(&incentive.pools, asset), error::invalid_pool());
        let pool_info = table::borrow(&incentive.pools, asset);
        assert!(vector::length(&pool_info.coin_types) > pool_idx, error::invalid_pool());
        (
            *vector::borrow(&pool_info.start_times, pool_idx), 
            *vector::borrow(&pool_info.end_times, pool_idx),
            *vector::borrow(&pool_info.rates, pool_idx),
            *vector::borrow(&pool_info.oracle_ids, pool_idx)
        )
    }

    public fun earned(
        incentive: &Incentive,
        storage: &mut Storage,
        clock: &Clock,
        asset: u8,
        account: address
    ): (vector<String>, vector<u256>, vector<u8>) {
        let coin_types = vector::empty<String>();
        let user_earned_rewards = vector::empty<u256>();
        let oracle_ids = vector::empty<u8>();

        if (table::contains(&incentive.pools, asset)) {
            let current_timestamp = clock::timestamp_ms(clock);
            let (_, user_acc_rewards) = calc_pool_update_rewards(incentive, storage, current_timestamp, asset, account);

            let pool_info = table::borrow(&incentive.pools, asset);
            let length = vector::length(&pool_info.coin_types);
            let i = 0;

            while(i < length) {
                let user_acc_rewards_paids = vector::borrow(&pool_info.user_acc_rewards_paids, i);
                let user_acc_rewards_paid = 0;
                if (table::contains(user_acc_rewards_paids, account)) {
                    user_acc_rewards_paid = *table::borrow(user_acc_rewards_paids, account);
                };

                vector::push_back(&mut coin_types, *vector::borrow(&pool_info.coin_types, i));
                vector::push_back(&mut user_earned_rewards, *vector::borrow(&user_acc_rewards, i) - user_acc_rewards_paid);
                vector::push_back(&mut oracle_ids, *vector::borrow(&pool_info.oracle_ids, i));

                i = i + 1;
            };
        };

        (coin_types, user_earned_rewards, oracle_ids)
    }

    #[test_only]
    friend lending_core::incentive_tests;

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx)
    }

}
