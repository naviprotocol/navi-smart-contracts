#[test_only]
module lending_core::incentive_v2_test {
    use std::vector::{Self};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::transfer::{Self};
    use sui::clock::{Self, Clock};
    use sui::test_scenario::{Self, Scenario};

    use math::ray_math;
    use math::safe_math;
    use oracle::oracle::{PriceOracle};
    use lending_core::base::{Self};
    use lending_core::pool::{Self, Pool};
    use lending_core::sui_test::{SUI_TEST};
    use lending_core::usdt_test::{USDT_TEST};
    use lending_core::usdc_test::{USDC_TEST};
    use lending_core::storage::{Self, Storage, OwnerCap as StorageOwnerCap};
    use lending_core::incentive_v2::{Self, OwnerCap, Incentive, IncentiveFundsPool};
    use lending_core::base_lending_tests::{Self};
    use lending_core::account::{Self, AccountCap};
    use lending_core::incentive_v3::{Self, Incentive as IncentiveV3};

    const OWNER: address = @0xA;
    const UserB: address = @0xB;

    #[test_only]
    public fun initial_incentive_v2_v3(scenario: &mut Scenario) {
        incentive_v3::init_for_testing(test_scenario::ctx(scenario));
        // create incentive owner cap
        test_scenario::next_tx(scenario, OWNER);
        {
            let storage_owner_cap = test_scenario::take_from_sender<StorageOwnerCap>(scenario);
            incentive_v2::create_and_transfer_owner(&storage_owner_cap, test_scenario::ctx(scenario));
            test_scenario::return_to_sender(scenario, storage_owner_cap);
        };
        
        // create incentive
        test_scenario::next_tx(scenario, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(scenario);
            incentive_v2::create_incentive(&owner_cap, test_scenario::ctx(scenario));
            test_scenario::return_to_sender(scenario, owner_cap);
        };

        // create funds pool
        test_scenario::next_tx(scenario, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(scenario);
            let incentive = test_scenario::take_shared<Incentive>(scenario);
            incentive_v2::create_funds_pool<USDC_TEST>(&owner_cap, &mut incentive, 1, false, test_scenario::ctx(scenario));
            incentive_v2::create_funds_pool<USDT_TEST>(&owner_cap, &mut incentive, 2, false, test_scenario::ctx(scenario));

            test_scenario::return_shared(incentive);
            test_scenario::return_to_sender(scenario, owner_cap);
        };

        // increase USDC pool funds
        // increase USDT pool funds
        test_scenario::next_tx(scenario, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(scenario);

            let usdt_funds = test_scenario::take_shared<IncentiveFundsPool<USDT_TEST>>(scenario);
            let coin = coin::mint_for_testing<USDT_TEST>(100000_000000, test_scenario::ctx(scenario));
            incentive_v2::add_funds(&owner_cap, &mut usdt_funds, coin, 100000_000000, test_scenario::ctx(scenario));
            let usdt_before = incentive_v2::get_funds_value(&usdt_funds);
            assert!(usdt_before == 100000_000000, 0);

            let usdc_funds = test_scenario::take_shared<IncentiveFundsPool<USDC_TEST>>(scenario);
            let usdc_coin = coin::mint_for_testing<USDC_TEST>(100000_000000, test_scenario::ctx(scenario));
            incentive_v2::add_funds(&owner_cap, &mut usdc_funds, usdc_coin, 100000_000000, test_scenario::ctx(scenario));
            let usdc_before = incentive_v2::get_funds_value(&usdc_funds);
            assert!(usdc_before == 100000_000000, 0);

            test_scenario::return_shared(usdt_funds);
            test_scenario::return_shared(usdc_funds);
            test_scenario::return_to_sender(scenario, owner_cap);
        };
    }

    #[test_only]
    public fun create_incentive_pool_for_testing<T>(
        scenario: &mut Scenario,
        funds_pool: &IncentiveFundsPool<T>,
        phase: u64,
        start_at: u64,
        end_at: u64,
        closed_at: u64,
        total_supply: u64,
        option: u8,
        asset_id: u8,
        factor: u256,
    ) {
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(scenario);
            let incentive = test_scenario::take_shared<Incentive>(scenario);

            // start_at < end_at
            incentive_v2::create_incentive_pool<T>(
                &owner_cap,
                &mut incentive,
                funds_pool,
                phase, // phase
                start_at, // start_at
                end_at, // end_at
                closed_at, // closed_at
                total_supply, // total_supply
                option, // option
                asset_id, // asset_id
                factor, // factor
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(incentive);
            test_scenario::return_to_sender(scenario, owner_cap);
    }

    #[test_only]
    public fun entry_deposit_for_testing<T>(scenario: &mut Scenario, clock: &Clock, pool: &mut Pool<T>, deposit_coin: Coin<T>, asset: u8, amount: u64) {
        let storage = test_scenario::take_shared<Storage>(scenario);
        let incentive = test_scenario::take_shared<Incentive>(scenario);
        let incentive_v3 = test_scenario::take_shared<IncentiveV3>(scenario);
        
        incentive_v3::entry_deposit(clock, &mut storage, pool, asset, deposit_coin, amount, &mut incentive, &mut incentive_v3, test_scenario::ctx(scenario));

        test_scenario::return_shared(storage);
        test_scenario::return_shared(incentive);
        test_scenario::return_shared(incentive_v3);
    }

    #[test_only]
    public fun entry_deposit_on_behalf_of_user_for_testing<T>(scenario: &mut Scenario, clock: &Clock, pool: &mut Pool<T>, deposit_coin: Coin<T>, asset: u8, amount: u64, user: address) {
        let storage = test_scenario::take_shared<Storage>(scenario);
        let incentive = test_scenario::take_shared<Incentive>(scenario);
        let incentive_v3 = test_scenario::take_shared<IncentiveV3>(scenario);
        
        incentive_v3::entry_deposit_on_behalf_of_user(clock, &mut storage, pool, asset, deposit_coin, amount, user, &mut incentive, &mut incentive_v3, test_scenario::ctx(scenario));

        test_scenario::return_shared(storage);
        test_scenario::return_shared(incentive);
        test_scenario::return_shared(incentive_v3);
    }

    #[test_only]
    public fun entry_deposit_with_account_cap_for_testing<T>(scenario: &mut Scenario, clock: &Clock, pool: &mut Pool<T>, deposit_coin: Coin<T>, asset: u8, account_cap: &AccountCap) {
        let storage = test_scenario::take_shared<Storage>(scenario);
        let incentive = test_scenario::take_shared<Incentive>(scenario);
        let incentive_v3 = test_scenario::take_shared<IncentiveV3>(scenario);
        
        incentive_v3::deposit_with_account_cap(clock, &mut storage, pool, asset, deposit_coin, &mut incentive, &mut incentive_v3, account_cap);

        test_scenario::return_shared(storage);
        test_scenario::return_shared(incentive);
        test_scenario::return_shared(incentive_v3);
    }

    #[test_only]
    public fun entry_repay_on_behalf_of_user_for_testing<T>(scenario: &mut Scenario, clock: &Clock, pool: &mut Pool<T>, deposit_coin: Coin<T>, asset: u8, amount: u64, user: address) {
        let storage = test_scenario::take_shared<Storage>(scenario);
        let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
        let incentive = test_scenario::take_shared<Incentive>(scenario);
        let incentive_v3 = test_scenario::take_shared<IncentiveV3>(scenario);
        
        incentive_v3::entry_repay_on_behalf_of_user(clock, &price_oracle, &mut storage, pool, asset, deposit_coin, amount, user, &mut incentive, &mut incentive_v3, test_scenario::ctx(scenario));

        test_scenario::return_shared(storage);
        test_scenario::return_shared(incentive);
        test_scenario::return_shared(incentive_v3);
        test_scenario::return_shared(price_oracle);
    }

    // #[test_only]
    // public fun non_entry_deposit_for_testing<T>(scenario: &mut Scenario, clock: &Clock, pool: &mut Pool<T>, deposit_coin: Coin<T>, asset: u8) {
    //     let storage = test_scenario::take_shared<Storage>(scenario);
    //     let incentive = test_scenario::take_shared<Incentive>(scenario);
    //     let incentive_v3 = test_scenario::take_shared<IncentiveV1>(scenario);
        
    //     incentive_v2::claim_reward_non_entry(clock, &mut storage, pool, asset, deposit_coin, &mut incentive_v3, &mut incentive, test_scenario::ctx(scenario));

    //     test_scenario::return_shared(storage);
    //     test_scenario::return_shared(incentive);
    //     test_scenario::return_shared(incentive_v3);
    // }

    #[test_only]
    public fun entry_borrow_for_testing<T>(scenario: &mut Scenario, clock: &Clock, pool: &mut Pool<T>, asset: u8, amount: u64) {
        let storage = test_scenario::take_shared<Storage>(scenario);
        let incentive = test_scenario::take_shared<Incentive>(scenario);
        let incentive_v3 = test_scenario::take_shared<IncentiveV3>(scenario);
        let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
        
        incentive_v3::entry_borrow(clock, &price_oracle, &mut storage, pool, asset, amount, &mut incentive, &mut incentive_v3, test_scenario::ctx(scenario));

        test_scenario::return_shared(storage);
        test_scenario::return_shared(incentive);
        test_scenario::return_shared(price_oracle);
        test_scenario::return_shared(incentive_v3);
    }
    #[test_only]
    public fun entry_borrow_with_account_cap_for_testing<T>(scenario: &mut Scenario, clock: &Clock, pool: &mut Pool<T>, asset: u8, amount: u64, account_cap: &AccountCap): Balance<T> {
        let storage = test_scenario::take_shared<Storage>(scenario);
        let incentive = test_scenario::take_shared<Incentive>(scenario);
        let incentive_v3 = test_scenario::take_shared<IncentiveV3>(scenario);
        let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
        
        let _balance = incentive_v3::borrow_with_account_cap(clock, &price_oracle, &mut storage, pool, asset, amount, &mut incentive, &mut incentive_v3, account_cap);

        test_scenario::return_shared(storage);
        test_scenario::return_shared(incentive);
        test_scenario::return_shared(price_oracle);
        test_scenario::return_shared(incentive_v3);
        _balance
    }

    #[test_only]
    public fun claim_reward_for_testing<T>(scenario: &mut Scenario, clock: &Clock, funds_pool: &mut IncentiveFundsPool<T>, asset: u8, option: u8) {
        let storage = test_scenario::take_shared<Storage>(scenario);
        let incentive = test_scenario::take_shared<Incentive>(scenario);
        let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
        
        incentive_v2::claim_reward(clock, &mut incentive, funds_pool, &mut storage, asset, option, test_scenario::ctx(scenario));

        test_scenario::return_shared(storage);
        test_scenario::return_shared(incentive);
        test_scenario::return_shared(price_oracle);
    }

    #[test]
    #[expected_failure(abort_code = 1506, location = lending_core::incentive_v2)]
    public fun test_add_and_withdraw_funds() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
            initial_incentive_v2_v3(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(&scenario);
            let usdt_funds = test_scenario::take_shared<IncentiveFundsPool<USDT_TEST>>(&scenario);

            incentive_v2::withdraw_funds(&owner_cap, &mut usdt_funds, 100000_000000, test_scenario::ctx(&mut scenario));
            let after = incentive_v2::get_funds_value(&usdt_funds);
            assert!(after == 100000_000000 - 100000_000000, 0); // No.2 can withdraw funds

            test_scenario::return_shared(usdt_funds);
            test_scenario::return_to_sender(&scenario, owner_cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(&scenario);
            let usdt_funds = test_scenario::take_shared<IncentiveFundsPool<USDT_TEST>>(&scenario);

            incentive_v2::withdraw_funds(&owner_cap, &mut usdt_funds, 1, test_scenario::ctx(&mut scenario));

            test_scenario::return_shared(usdt_funds);
            test_scenario::return_to_sender(&scenario, owner_cap);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_created_multiple_incentive_pools() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
            initial_incentive_v2_v3(&mut scenario);
        };

        // Incentive1: phase 0, start 1000, end 2000, closed 0, total_supply 100u, option 1, asset 0, factor 1
        // Incentive2: phase 0, start 1000, end 2000, closed 0, total_supply 100u, option 1, asset 1, factor 1
        // Incentive3: phase 1, start 2000, end 3000, closed 0, total_supply 100u, option 1, asset 0, factor 1
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let usdt_funds = test_scenario::take_shared<IncentiveFundsPool<USDT_TEST>>(&scenario);

            create_incentive_pool_for_testing(
                &mut scenario,
                &usdt_funds,
                0, // phase
                1000, // start
                2000, // end
                0, // closed
                100_000000, // total_supply
                1, // option
                0, // asset
                1000000000000000000 // factor
            );

            test_scenario::return_shared(usdt_funds);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let usdt_funds = test_scenario::take_shared<IncentiveFundsPool<USDT_TEST>>(&scenario);

            create_incentive_pool_for_testing(
                &mut scenario,
                &usdt_funds,
                0, // phase
                1000, // start
                2000, // end
                0, // closed
                100_000000, // total_supply
                1, // option
                1, // asset
                1000000000000000000 // factor
            );

            test_scenario::return_shared(usdt_funds);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let usdt_funds = test_scenario::take_shared<IncentiveFundsPool<USDT_TEST>>(&scenario);

            create_incentive_pool_for_testing(
                &mut scenario,
                &usdt_funds,
                1, // phase
                2000, // start
                3000, // end
                0, // closed
                100_000000, // total_supply
                1, // option
                0, // asset
                1000000000000000000 // factor
            );

            test_scenario::return_shared(usdt_funds);
        };

        // check length
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive>(&scenario);

            let length = incentive_v2::get_pool_length(&incentive);
            assert!(length == 3, 0);

            test_scenario::return_shared(incentive);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1802, location = lending_core::incentive_v2)]
    public fun test_created_pool_with_available_time() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
            initial_incentive_v2_v3(&mut scenario);
        };

        // Incentive1: phase 0, start 2000, end 1000, closed 0, total_supply 100u, option 1, asset 0, factor 1
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(&scenario);
            let usdt_funds = test_scenario::take_shared<IncentiveFundsPool<USDT_TEST>>(&scenario);
            let usdc_funds = test_scenario::take_shared<IncentiveFundsPool<USDC_TEST>>(&scenario);
            let incentive = test_scenario::take_shared<Incentive>(&scenario);

            // start_at < end_at
            incentive_v2::create_incentive_pool<USDT_TEST>(
                &owner_cap,
                &mut incentive,
                &usdt_funds,
                0, // phase
                2000, // start_at
                1000, // end_at
                0, // closed_at
                100_000000, // total_supply
                1, // option
                0, // asset_id
                1000000000000000000, // factor
                test_scenario::ctx(&mut scenario)
            );

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(usdt_funds);
            test_scenario::return_shared(usdc_funds);
            test_scenario::return_to_sender(&scenario, owner_cap);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1802, location = lending_core::incentive_v2)]
    public fun test_created_pool_with_available_closed_at() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
            initial_incentive_v2_v3(&mut scenario);
        };

        // Incentive1: phase 0, start 1000, end 2000, closed 1000, total_supply 100u, option 1, asset 0, factor 1
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let usdt_funds = test_scenario::take_shared<IncentiveFundsPool<USDT_TEST>>(&scenario);

            create_incentive_pool_for_testing(
                &mut scenario,
                &usdt_funds,
                0, // phase
                1000, // start
                2000, // end
                1000, // closed
                100_000000, // total_supply
                1, // option
                0, // asset
                1000000000000000000 // factor
            );

            test_scenario::return_shared(usdt_funds);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_deposit() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        let current_timestamp = 1700006400000;
        clock::set_for_testing(&mut _clock, current_timestamp);
        {
            base::initial_protocol(&mut scenario, &_clock);
            initial_incentive_v2_v3(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let usdt_funds = test_scenario::take_shared<IncentiveFundsPool<USDT_TEST>>(&scenario);

            create_incentive_pool_for_testing(
                &mut scenario,
                &usdt_funds,
                0, // phase
                current_timestamp, // start, 2023-11-15 08:00:00
                current_timestamp + 1000 * 60 * 60, // end, 2023-11-15 09:00:00
                0, // closed
                100_000000, // total_supply
                1, // option 
                0, // asset
                1000000000000000000000000000 // factor
            );

            test_scenario::return_shared(usdt_funds);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            clock::increment_for_testing(&mut _clock, 1000 * 10); // 10 seconds after the reward starts
            let pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);

            let coin = coin::mint_for_testing<USDC_TEST>(100_000000000, test_scenario::ctx(&mut scenario));

            entry_deposit_for_testing(&mut scenario, &_clock, &mut pool, coin, 1, 100_000000000);
            let (total_supply, _, _) = pool::get_pool_info(&pool);
            assert!(total_supply == 100_000000000, 0);

            test_scenario::return_shared(pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive>(&scenario);
            let pool_objs = incentive_v2::get_active_pools(&incentive, 0, 1, clock::timestamp_ms(&_clock));
            let length = vector::length(&pool_objs);
            assert!(length == 1, 0);

            let (_,_,_,_,_,_,_,_,_,factor,last_update_at,distributed,index_reward) = incentive_v2::get_pool_info(&incentive, *vector::borrow(&pool_objs, 0));
            assert!(last_update_at == current_timestamp, 0);
            assert!(distributed == 0, 0);
            assert!(index_reward == 0, 0);

            let storage = test_scenario::take_shared<Storage>(&scenario);
            let (total_supply_balance, total_borrow_balance) = storage::get_total_supply(&mut storage, 0);
            assert!(total_supply_balance == 0, 0);
            assert!(total_borrow_balance == 0, 0);

            let (user_supply_balance, user_borrow_balance) = storage::get_user_balance(&mut storage, 0, OWNER);
            assert!(user_supply_balance == 0, 0);
            assert!(user_borrow_balance == 0, 0);

            let user_effective_amount = incentive_v2::calculate_user_effective_amount(1, user_supply_balance, user_borrow_balance, factor);
            assert!(user_effective_amount == 0, 0);

            let (index_reward, total_rewards_of_user) = incentive_v2::calculate_one_from_pool(
                &incentive,
                *vector::borrow(&pool_objs, 0),
                clock::timestamp_ms(&_clock),
                total_supply_balance,
                OWNER,
                user_effective_amount
            );
            assert!(total_rewards_of_user == 0, 0);
            assert!(index_reward == 0, 0);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            clock::increment_for_testing(&mut _clock, 1000 * 10); // 20 seconds after the reward starts
            let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            let coin = coin::mint_for_testing<SUI_TEST>(10000_000000000, test_scenario::ctx(&mut scenario));

            entry_deposit_for_testing(&mut scenario, &_clock, &mut pool, coin, 0, 10000_000000000);

            let (total_supply, _, _) = pool::get_pool_info(&pool);
            assert!(total_supply == 10000_000000000, 0);

            test_scenario::return_shared(pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive>(&scenario);
            let pool_objs = incentive_v2::get_active_pools(&incentive, 0, 1, clock::timestamp_ms(&_clock));
            let length = vector::length(&pool_objs);
            assert!(length == 1, 0);

            let (_,_,_,_,_,_,_,_,_,factor,last_update_at,_,_) = incentive_v2::get_pool_info(&incentive, *vector::borrow(&pool_objs, 0));
            assert!(last_update_at == clock::timestamp_ms(&_clock), 0);

            let storage = test_scenario::take_shared<Storage>(&scenario);
            let (total_supply_balance, total_borrow_balance) = storage::get_total_supply(&mut storage, 0);
            assert!(total_supply_balance == 10000_000000000, 0);
            assert!(total_borrow_balance == 0, 0);

            let (user_supply_balance, user_borrow_balance) = storage::get_user_balance(&mut storage, 0, OWNER);
            assert!(user_supply_balance == 10000_000000000, 0);
            assert!(user_borrow_balance == 0, 0);

            let user_effective_amount = incentive_v2::calculate_user_effective_amount(1, user_supply_balance, user_borrow_balance, factor);
            assert!(user_effective_amount == 10000_000000000, 0);

            let (index_reward, total_rewards_of_user) = incentive_v2::calculate_one_from_pool(
                &incentive,
                *vector::borrow(&pool_objs, 0),
                clock::timestamp_ms(&_clock),
                total_supply_balance,
                OWNER,
                user_effective_amount
            );
            assert!(total_rewards_of_user == 0, 0);
            assert!(index_reward == 0, 0);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            clock::increment_for_testing(&mut _clock, 1000 * 10); // 30 seconds after the reward starts
            let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            let coin = coin::mint_for_testing<SUI_TEST>(10000_000000000, test_scenario::ctx(&mut scenario));

            entry_deposit_for_testing(&mut scenario, &_clock, &mut pool, coin, 0, 10000_000000000);

            let (total_supply, _, _) = pool::get_pool_info(&pool);
            assert!(total_supply == 20000_000000000, 0);

            test_scenario::return_shared(pool);
        };

        let _before_index_reward = 0;
        let _before_total_rewards_of_user = 0;
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive>(&scenario);
            let pool_objs = incentive_v2::get_active_pools(&incentive, 0, 1, clock::timestamp_ms(&_clock));
            let length = vector::length(&pool_objs);
            assert!(length == 1, 0);

            let (_,_,_,_,_,_,_,_,_,factor,last_update_at,_,_) = incentive_v2::get_pool_info(&incentive, *vector::borrow(&pool_objs, 0));
            assert!(last_update_at == clock::timestamp_ms(&_clock), 0);

            let storage = test_scenario::take_shared<Storage>(&scenario);
            let (total_supply_balance, total_borrow_balance) = storage::get_total_supply(&mut storage, 0);
            assert!(total_supply_balance == 20000_000000000, 0);
            assert!(total_borrow_balance == 0, 0);

            let (user_supply_balance, user_borrow_balance) = storage::get_user_balance(&mut storage, 0, OWNER);
            assert!(user_supply_balance == 20000_000000000, 0);
            assert!(user_borrow_balance == 0, 0);

            let user_effective_amount = incentive_v2::calculate_user_effective_amount(1, user_supply_balance, user_borrow_balance, factor);
            assert!(user_effective_amount == 20000_000000000, 0);

            let (index_reward, total_rewards_of_user) = incentive_v2::calculate_one_from_pool(
                &incentive,
                *vector::borrow(&pool_objs, 0),
                clock::timestamp_ms(&_clock),
                total_supply_balance,
                OWNER,
                user_effective_amount
            );

            let time_diff = 10 * 1000;
            let rate_ms = ray_math::ray_div(100_000000, 1000 * 60 * 60);
            _before_index_reward = safe_math::mul(rate_ms, (time_diff as u256)) / 10000_000000000;
            _before_total_rewards_of_user = _before_index_reward * 10000_000000000;
            assert!(index_reward == _before_index_reward, 0);
            assert!(total_rewards_of_user == _before_total_rewards_of_user, 0);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            clock::increment_for_testing(&mut _clock, 1000 * 10); // 40 seconds after the reward starts
            let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

            entry_borrow_for_testing(&mut scenario, &_clock, &mut pool, 0, 10000_000000000);

            let (total_supply, _, _) = pool::get_pool_info(&pool);
            assert!(total_supply == 10000_000000000, 0);

            test_scenario::return_shared(pool);
        };
        
        let _before_index_reward2 = 0;
        let _before_total_rewards_of_user2 = 0;
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive>(&scenario);
            let pool_objs = incentive_v2::get_active_pools(&incentive, 0, 1, clock::timestamp_ms(&_clock));
            let length = vector::length(&pool_objs);
            assert!(length == 1, 0);

            let (_,_,_,_,_,_,_,_,_,factor,last_update_at,_,_) = incentive_v2::get_pool_info(&incentive, *vector::borrow(&pool_objs, 0));
            assert!(last_update_at == clock::timestamp_ms(&_clock), 0);

            let storage = test_scenario::take_shared<Storage>(&scenario);
            let (total_supply_balance, total_borrow_balance) = storage::get_total_supply(&mut storage, 0);
            assert!(total_supply_balance == 20000_000000000, 0);
            assert!(total_borrow_balance == 10000_000000000, 0);

            let (user_supply_balance, user_borrow_balance) = storage::get_user_balance(&mut storage, 0, OWNER);
            assert!(user_supply_balance == 20000_000000000, 0);
            assert!(user_borrow_balance == 10000_000000000, 0);

            let user_effective_amount = incentive_v2::calculate_user_effective_amount(1, user_supply_balance, user_borrow_balance, factor);
            // assert!(user_effective_amount == 10000_000000000, 0);

            let (index_reward, total_rewards_of_user) = incentive_v2::calculate_one_from_pool(
                &incentive,
                *vector::borrow(&pool_objs, 0),
                clock::timestamp_ms(&_clock),
                total_supply_balance,
                OWNER,
                user_effective_amount
            );

            let time_diff = 10 * 1000;
            let rate_ms = ray_math::ray_div(100_000000, 1000 * 60 * 60);
            _before_index_reward2 = safe_math::mul(rate_ms, (time_diff as u256)) / 20000000000000;
            _before_total_rewards_of_user2 = _before_index_reward2 * 20000_000000000;

            assert!(index_reward == _before_index_reward + _before_index_reward2, 0);
            assert!(total_rewards_of_user == _before_total_rewards_of_user + _before_total_rewards_of_user2, 0);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            clock::increment_for_testing(&mut _clock, 1000 * 10); // 50 seconds after the reward starts
            let usdt_funds = test_scenario::take_shared<IncentiveFundsPool<USDT_TEST>>(&scenario);

            claim_reward_for_testing(&mut scenario, &_clock, &mut usdt_funds, 0, 1);

            test_scenario::return_shared(usdt_funds);
        };

        let _funds_value = 0;
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive>(&scenario);
            let pool_objs = incentive_v2::get_active_pools(&incentive, 0, 1, clock::timestamp_ms(&_clock));
            let length = vector::length(&pool_objs);
            assert!(length == 1, 0);

            let (_,_,_,_,_,_,_,_,_,factor,last_update_at,_,_) = incentive_v2::get_pool_info(&incentive, *vector::borrow(&pool_objs, 0));
            assert!(last_update_at == clock::timestamp_ms(&_clock), 0);

            let storage = test_scenario::take_shared<Storage>(&scenario);
            let (total_supply_balance, total_borrow_balance) = storage::get_total_supply(&mut storage, 0);
            assert!(total_supply_balance == 20000_000000000, 0);
            assert!(total_borrow_balance == 10000_000000000, 0);

            let (user_supply_balance, user_borrow_balance) = storage::get_user_balance(&mut storage, 0, OWNER);
            assert!(user_supply_balance == 20000_000000000, 0);
            assert!(user_borrow_balance == 10000_000000000, 0);

            let user_effective_amount = incentive_v2::calculate_user_effective_amount(1, user_supply_balance, user_borrow_balance, factor);
            // assert!(user_effective_amount == 10000_000000000, 0);

            let (index_reward, _) = incentive_v2::calculate_one_from_pool(
                &incentive,
                *vector::borrow(&pool_objs, 0),
                clock::timestamp_ms(&_clock),
                total_supply_balance,
                OWNER,
                user_effective_amount
            );

            let time_diff = 10 * 1000;
            let rate_ms = ray_math::ray_div(100_000000, 1000 * 60 * 60);
            let expected_index_reward = safe_math::mul(rate_ms, (time_diff as u256)) / 20000000000000;
            // let expected_total_rewards_of_user = expected_index_reward * 10000_000000000;

            assert!(index_reward == _before_index_reward + _before_index_reward2 + expected_index_reward, 0);
            // assert!(total_rewards_of_user == _before_total_rewards_of_user + _before_total_rewards_of_user2 + expected_total_rewards_of_user, 0);

            let usdt_funds = test_scenario::take_shared<IncentiveFundsPool<USDT_TEST>>(&scenario);
            _funds_value = incentive_v2::get_funds_value(&usdt_funds);
            assert!(_funds_value > 0, 0);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(usdt_funds);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let usdt_funds = test_scenario::take_shared<IncentiveFundsPool<USDT_TEST>>(&scenario);

            claim_reward_for_testing(&mut scenario, &_clock, &mut usdt_funds, 0, 1);

            test_scenario::return_shared(usdt_funds);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive>(&scenario);

            let pool_objs = incentive_v2::get_active_pools(&incentive, 0, 1, clock::timestamp_ms(&_clock));
            let length = vector::length(&pool_objs);
            assert!(length == 1, 0);

            let (_,_,_,_,_,_,_,_,_,factor,last_update_at,_,_) = incentive_v2::get_pool_info(&incentive, *vector::borrow(&pool_objs, 0));
            assert!(last_update_at == clock::timestamp_ms(&_clock), 0);

            let storage = test_scenario::take_shared<Storage>(&scenario);
            let (total_supply_balance, total_borrow_balance) = storage::get_total_supply(&mut storage, 0);
            assert!(total_supply_balance == 20000_000000000, 0);
            assert!(total_borrow_balance == 10000_000000000, 0);

            let (user_supply_balance, user_borrow_balance) = storage::get_user_balance(&mut storage, 0, OWNER);
            assert!(user_supply_balance == 20000_000000000, 0);
            assert!(user_borrow_balance == 10000_000000000, 0);

            let user_effective_amount = incentive_v2::calculate_user_effective_amount(1, user_supply_balance, user_borrow_balance, factor);
            // assert!(user_effective_amount == 10000_000000000, 0);

            let (index_reward, _) = incentive_v2::calculate_one_from_pool(
                &incentive,
                *vector::borrow(&pool_objs, 0),
                clock::timestamp_ms(&_clock),
                total_supply_balance,
                OWNER,
                user_effective_amount
            );

            let time_diff = 10 * 1000;
            let rate_ms = ray_math::ray_div(100_000000, 1000 * 60 * 60);
            let expected_index_reward = safe_math::mul(rate_ms, (time_diff as u256)) / 20000000000000;
            // let expected_total_rewards_of_user = expected_index_reward * 10000_000000000;

            assert!(index_reward == _before_index_reward + _before_index_reward2 + expected_index_reward, 0);
            // assert!(total_rewards_of_user == _before_total_rewards_of_user + _before_total_rewards_of_user2 + expected_total_rewards_of_user, 0);

            let usdt_funds = test_scenario::take_shared<IncentiveFundsPool<USDT_TEST>>(&scenario);
            let this_value = incentive_v2::get_funds_value(&usdt_funds);
            assert!(_funds_value > 0, 0);
            assert!(this_value == _funds_value, 0);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(usdt_funds);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive>(&scenario);

            // asset: sui, option: supply
            let objs1 = incentive_v2::get_active_pools(&incentive, 0, 1, clock::timestamp_ms(&_clock));
            let length1 = vector::length(&objs1);
            assert!(length1 == 1, 0);

            // asset: sui, option: borrow
            let objs2 = incentive_v2::get_active_pools(&incentive, 1, 1, clock::timestamp_ms(&_clock));
            let length2 = vector::length(&objs2);
            assert!(length2 == 0, 0);

            // asset: sui, option: borrow
            let objs3 = incentive_v2::get_active_pools(&incentive, 0, 3, clock::timestamp_ms(&_clock));
            let length3 = vector::length(&objs3);
            assert!(length3 == 0, 0);

            // now > end_at
            clock::increment_for_testing(&mut _clock, 1000 * 60 * 60 * 2);
            let objs4 = incentive_v2::get_active_pools(&incentive, 0, 1, clock::timestamp_ms(&_clock));
            let length4 = vector::length(&objs4);
            assert!(length4 == 0, 0);

            test_scenario::return_shared(incentive);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_claim_reward_non_entry() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        let current_timestamp = 1700006400000;
        clock::set_for_testing(&mut _clock, current_timestamp);
        {
            base::initial_protocol(&mut scenario, &_clock);
            initial_incentive_v2_v3(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let usdt_funds = test_scenario::take_shared<IncentiveFundsPool<USDT_TEST>>(&scenario);

            create_incentive_pool_for_testing(
                &mut scenario,
                &usdt_funds,
                0, // phase
                current_timestamp, // start, 2023-11-15 08:00:00
                current_timestamp + 1000 * 60 * 60, // end, 2023-11-15 09:00:00
                0, // closed
                100_000000, // total_supply
                1, // option 
                0, // asset
                1000000000000000000000000000 // factor
            );

            test_scenario::return_shared(usdt_funds);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            clock::increment_for_testing(&mut _clock, 1000 * 10); // 10 seconds after the reward starts
            let pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);
            let coin = coin::mint_for_testing<USDC_TEST>(100_000000, test_scenario::ctx(&mut scenario));

            entry_deposit_for_testing(&mut scenario, &_clock, &mut pool, coin, 1, 100_000000);
            let (total_supply, _, _) = pool::get_pool_info(&pool);
            assert!(total_supply == 100_000000, 0);

            test_scenario::return_shared(pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);

            let (account_supply_balance, account_borrow_balance) = storage::get_user_balance(&mut storage, 1, OWNER);
            assert!(account_supply_balance == 100_000000000, 0);
            assert!(account_borrow_balance == 0, 0);

            test_scenario::return_shared(storage);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive>(&scenario);
            let pool_objs = incentive_v2::get_active_pools(&incentive, 0, 1, clock::timestamp_ms(&_clock));
            let length = vector::length(&pool_objs);
            assert!(length == 1, 0);

            let (_,_,_,_,_,_,_,_,_,factor,last_update_at,distributed,index_reward) = incentive_v2::get_pool_info(&incentive, *vector::borrow(&pool_objs, 0));
            assert!(last_update_at == current_timestamp, 0);
            assert!(distributed == 0, 0);
            assert!(index_reward == 0, 0);

            let storage = test_scenario::take_shared<Storage>(&scenario);
            let (total_supply_balance, total_borrow_balance) = storage::get_total_supply(&mut storage, 0);
            assert!(total_supply_balance == 0, 0);
            assert!(total_borrow_balance == 0, 0);

            let (user_supply_balance, user_borrow_balance) = storage::get_user_balance(&mut storage, 0, OWNER);
            assert!(user_supply_balance == 0, 0);
            assert!(user_borrow_balance == 0, 0);

            let user_effective_amount = incentive_v2::calculate_user_effective_amount(1, user_supply_balance, user_borrow_balance, factor);
            assert!(user_effective_amount == 0, 0);

            let (index_reward, total_rewards_of_user) = incentive_v2::calculate_one_from_pool(
                &incentive,
                *vector::borrow(&pool_objs, 0),
                clock::timestamp_ms(&_clock),
                total_supply_balance,
                OWNER,
                user_effective_amount
            );
            assert!(total_rewards_of_user == 0, 0);
            assert!(index_reward == 0, 0);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            clock::increment_for_testing(&mut _clock, 1000 * 10); // 20 seconds after the reward starts
            let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            let coin = coin::mint_for_testing<SUI_TEST>(10000_000000000, test_scenario::ctx(&mut scenario));

            entry_deposit_for_testing(&mut scenario, &_clock, &mut pool, coin, 0, 10000_000000000);

            let (total_supply, _, _) = pool::get_pool_info(&pool);
            assert!(total_supply == 10000_000000000, 0);

            test_scenario::return_shared(pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive>(&scenario);
            let pool_objs = incentive_v2::get_active_pools(&incentive, 0, 1, clock::timestamp_ms(&_clock));
            let length = vector::length(&pool_objs);
            assert!(length == 1, 0);

            let (_,_,_,_,_,_,_,_,_,factor,last_update_at,_,_) = incentive_v2::get_pool_info(&incentive, *vector::borrow(&pool_objs, 0));
            assert!(last_update_at == clock::timestamp_ms(&_clock), 0);

            let storage = test_scenario::take_shared<Storage>(&scenario);
            let (total_supply_balance, total_borrow_balance) = storage::get_total_supply(&mut storage, 0);
            assert!(total_supply_balance == 10000_000000000, 0);
            assert!(total_borrow_balance == 0, 0);

            let (user_supply_balance, user_borrow_balance) = storage::get_user_balance(&mut storage, 0, OWNER);
            assert!(user_supply_balance == 10000_000000000, 0);
            assert!(user_borrow_balance == 0, 0);

            let user_effective_amount = incentive_v2::calculate_user_effective_amount(1, user_supply_balance, user_borrow_balance, factor);
            assert!(user_effective_amount == 10000_000000000, 0);

            let (index_reward, total_rewards_of_user) = incentive_v2::calculate_one_from_pool(
                &incentive,
                *vector::borrow(&pool_objs, 0),
                clock::timestamp_ms(&_clock),
                total_supply_balance,
                OWNER,
                user_effective_amount
            );
            assert!(total_rewards_of_user == 0, 0);
            assert!(index_reward == 0, 0);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            clock::increment_for_testing(&mut _clock, 1000 * 10); // 30 seconds after the reward starts
            let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            let coin = coin::mint_for_testing<SUI_TEST>(10000_000000000, test_scenario::ctx(&mut scenario));

            entry_deposit_for_testing(&mut scenario, &_clock, &mut pool, coin, 0, 10000_000000000);

            let (total_supply, _, _) = pool::get_pool_info(&pool);
            assert!(total_supply == 20000_000000000, 0);

            test_scenario::return_shared(pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            clock::increment_for_testing(&mut _clock, 1000 * 10); // 40 seconds after the reward starts
            let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

            entry_borrow_for_testing(&mut scenario, &_clock, &mut pool, 0, 10000_000000000);

            let (total_supply, _, _) = pool::get_pool_info(&pool);
            assert!(total_supply == 10000_000000000, 0);

            test_scenario::return_shared(pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            clock::increment_for_testing(&mut _clock, 1000 * 10); // 50 seconds after the reward starts
            let usdt_funds = test_scenario::take_shared<IncentiveFundsPool<USDT_TEST>>(&scenario);
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let incentive = test_scenario::take_shared<Incentive>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            
            let _balance = incentive_v2::claim_reward_non_entry(&_clock, &mut incentive, &mut usdt_funds, &mut storage, 0, 1, test_scenario::ctx(&mut scenario));
            assert!(balance::value(&_balance) > 0, 0);

            transfer::public_transfer(coin::from_balance(_balance, test_scenario::ctx(&mut scenario)), OWNER);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(incentive);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(usdt_funds);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_claim_reward_with_account_cap() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        let current_timestamp = 1700006400000;
        clock::set_for_testing(&mut _clock, current_timestamp);
        {
            base::initial_protocol(&mut scenario, &_clock);
            initial_incentive_v2_v3(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            base_lending_tests::create_account_cap_for_testing(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let usdt_funds = test_scenario::take_shared<IncentiveFundsPool<USDT_TEST>>(&scenario);

            create_incentive_pool_for_testing(
                &mut scenario,
                &usdt_funds,
                0, // phase
                current_timestamp, // start, 2023-11-15 08:00:00
                current_timestamp + 1000 * 60 * 60, // end, 2023-11-15 09:00:00
                0, // closed
                100_000000, // total_supply
                1, // option 
                0, // asset
                1000000000000000000000000000 // factor
            );

            test_scenario::return_shared(usdt_funds);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let account_cap = test_scenario::take_from_sender<AccountCap>(&scenario);
            let account_owner = account::account_owner(&account_cap);
            assert!(account_owner != OWNER, 0);

            {
                clock::increment_for_testing(&mut _clock, 1000 * 10); // 10 seconds after the reward starts
                let pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);
                let coin = coin::mint_for_testing<USDC_TEST>(100_000000, test_scenario::ctx(&mut scenario));

                entry_deposit_with_account_cap_for_testing(&mut scenario, &_clock, &mut pool, coin, 1, &account_cap);
                
                let (total_supply, _, _) = pool::get_pool_info(&pool);
                assert!(total_supply == 100_000000, 0);

                test_scenario::return_shared(pool);
            };

            test_scenario::return_to_sender(&scenario, account_cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let account_cap = test_scenario::take_from_sender<AccountCap>(&scenario);
            let account_owner = account::account_owner(&account_cap);
            let storage = test_scenario::take_shared<Storage>(&scenario);

            let (owner_supply_balance, owner_borrow_balance) = storage::get_user_balance(&mut storage, 1, OWNER);
            assert!(owner_supply_balance == 0, 0);
            assert!(owner_borrow_balance == 0, 0);

            let (account_supply_balance, account_borrow_balance) = storage::get_user_balance(&mut storage, 1, account_owner);
            assert!(account_supply_balance == 100_000000000, 0);
            assert!(account_borrow_balance == 0, 0);

            test_scenario::return_shared(storage);
            test_scenario::return_to_sender(&scenario, account_cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive>(&scenario);
            let pool_objs = incentive_v2::get_active_pools(&incentive, 0, 1, clock::timestamp_ms(&_clock));
            let length = vector::length(&pool_objs);
            assert!(length == 1, 0);

            let (_,_,_,_,_,_,_,_,_,factor,last_update_at,distributed,index_reward) = incentive_v2::get_pool_info(&incentive, *vector::borrow(&pool_objs, 0));
            assert!(last_update_at == current_timestamp, 0);
            assert!(distributed == 0, 0);
            assert!(index_reward == 0, 0);

            let storage = test_scenario::take_shared<Storage>(&scenario);
            let (total_supply_balance, total_borrow_balance) = storage::get_total_supply(&mut storage, 0);
            assert!(total_supply_balance == 0, 0);
            assert!(total_borrow_balance == 0, 0);

            let (user_supply_balance, user_borrow_balance) = storage::get_user_balance(&mut storage, 0, OWNER);
            assert!(user_supply_balance == 0, 0);
            assert!(user_borrow_balance == 0, 0);

            let user_effective_amount = incentive_v2::calculate_user_effective_amount(1, user_supply_balance, user_borrow_balance, factor);
            assert!(user_effective_amount == 0, 0);

            let (index_reward, total_rewards_of_user) = incentive_v2::calculate_one_from_pool(
                &incentive,
                *vector::borrow(&pool_objs, 0),
                clock::timestamp_ms(&_clock),
                total_supply_balance,
                OWNER,
                user_effective_amount
            );
            assert!(total_rewards_of_user == 0, 0);
            assert!(index_reward == 0, 0);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let account_cap = test_scenario::take_from_sender<AccountCap>(&scenario);
            let account_owner = account::account_owner(&account_cap);
            assert!(account_owner != OWNER, 0);

            {
                clock::increment_for_testing(&mut _clock, 1000 * 10); // 20 seconds after the reward starts
                let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
                let coin = coin::mint_for_testing<SUI_TEST>(10000_000000000, test_scenario::ctx(&mut scenario));

                entry_deposit_with_account_cap_for_testing(&mut scenario, &_clock, &mut pool, coin, 0, &account_cap);

                let (total_supply, _, _) = pool::get_pool_info(&pool);
                assert!(total_supply == 10000_000000000, 0);

                test_scenario::return_shared(pool);
            };
            test_scenario::return_to_sender(&scenario, account_cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let account_cap = test_scenario::take_from_sender<AccountCap>(&scenario);
            let account_owner = account::account_owner(&account_cap);

            let incentive = test_scenario::take_shared<Incentive>(&scenario);
            let pool_objs = incentive_v2::get_active_pools(&incentive, 0, 1, clock::timestamp_ms(&_clock));
            let length = vector::length(&pool_objs);
            assert!(length == 1, 0);

            let (_,_,_,_,_,_,_,_,_,factor,last_update_at,_,_) = incentive_v2::get_pool_info(&incentive, *vector::borrow(&pool_objs, 0));
            assert!(last_update_at == clock::timestamp_ms(&_clock), 0);

            let storage = test_scenario::take_shared<Storage>(&scenario);
            let (total_supply_balance, total_borrow_balance) = storage::get_total_supply(&mut storage, 0);
            assert!(total_supply_balance == 10000_000000000, 0);
            assert!(total_borrow_balance == 0, 0);

            let (user_supply_balance, user_borrow_balance) = storage::get_user_balance(&mut storage, 0, account_owner);
            assert!(user_supply_balance == 10000_000000000, 0);
            assert!(user_borrow_balance == 0, 0);

            let user_effective_amount = incentive_v2::calculate_user_effective_amount(1, user_supply_balance, user_borrow_balance, factor);
            assert!(user_effective_amount == 10000_000000000, 0);

            let (index_reward, total_rewards_of_user) = incentive_v2::calculate_one_from_pool(
                &incentive,
                *vector::borrow(&pool_objs, 0),
                clock::timestamp_ms(&_clock),
                total_supply_balance,
                OWNER,
                user_effective_amount
            );
            assert!(total_rewards_of_user == 0, 0);
            assert!(index_reward == 0, 0);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
            test_scenario::return_to_sender(&scenario, account_cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let account_cap = test_scenario::take_from_sender<AccountCap>(&scenario);
            let account_owner = account::account_owner(&account_cap);
            assert!(account_owner != OWNER, 0);

            {
                clock::increment_for_testing(&mut _clock, 1000 * 10); // 30 seconds after the reward starts
                let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
                let coin = coin::mint_for_testing<SUI_TEST>(10000_000000000, test_scenario::ctx(&mut scenario));

                entry_deposit_with_account_cap_for_testing(&mut scenario, &_clock, &mut pool, coin, 0, &account_cap);

                let (total_supply, _, _) = pool::get_pool_info(&pool);
                assert!(total_supply == 20000_000000000, 0);

                test_scenario::return_shared(pool);
            };

            test_scenario::return_to_sender(&scenario, account_cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let account_cap = test_scenario::take_from_sender<AccountCap>(&scenario);
            let account_owner = account::account_owner(&account_cap);
            assert!(account_owner != OWNER, 0);
            
            {
                clock::increment_for_testing(&mut _clock, 1000 * 10); // 40 seconds after the reward starts
                let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

                let balance = entry_borrow_with_account_cap_for_testing(&mut scenario, &_clock, &mut pool, 0, 10000_000000000, &account_cap);
                transfer::public_transfer(coin::from_balance(balance, test_scenario::ctx(&mut scenario)), account_owner);

                let (total_supply, _, _) = pool::get_pool_info(&pool);
                assert!(total_supply == 10000_000000000, 0);

                test_scenario::return_shared(pool);
            };

            test_scenario::return_to_sender(&scenario, account_cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let account_cap = test_scenario::take_from_sender<AccountCap>(&scenario);
            let account_owner = account::account_owner(&account_cap);
            assert!(account_owner != OWNER, 0);
            
            clock::increment_for_testing(&mut _clock, 1000 * 10); // 50 seconds after the reward starts
            let usdt_funds = test_scenario::take_shared<IncentiveFundsPool<USDT_TEST>>(&scenario);
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let incentive = test_scenario::take_shared<Incentive>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            
            let _balance = incentive_v2::claim_reward_with_account_cap(&_clock, &mut incentive, &mut usdt_funds, &mut storage, 0, 1, &account_cap);
            assert!(balance::value(&_balance) > 0, 0);

            transfer::public_transfer(coin::from_balance(_balance, test_scenario::ctx(&mut scenario)), account_owner);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(incentive);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(usdt_funds);

            test_scenario::return_to_sender(&scenario, account_cap);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_freeze_incentive_pool() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

        let current_timestamp = 1700006400000;
        clock::set_for_testing(&mut _clock, current_timestamp);

        let _target_pool: address = @0x0;
        let _target_pool_update_time: u64 = 0;
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            base::initial_protocol(&mut scenario, &_clock);
            initial_incentive_v2_v3(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive>(&scenario);

            let active_pools = incentive_v2::get_pool_objects(&incentive);
            let inactive_pools = incentive_v2::get_inactive_pool_objects(&incentive);
            
            assert!(vector::length(&active_pools) == 0, 0);
            assert!(vector::length(&inactive_pools) == 0, 0);
            test_scenario::return_shared(incentive);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let usdt_funds = test_scenario::take_shared<IncentiveFundsPool<USDT_TEST>>(&scenario);
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(&scenario);
            let incentive = test_scenario::take_shared<Incentive>(&scenario);

            {
                incentive_v2::create_incentive_pool<USDT_TEST>(
                    &owner_cap,
                    &mut incentive,
                    &usdt_funds,
                    0, // phase
                    current_timestamp, // start_at
                    current_timestamp + 1000 * 60 * 60, // end_at
                    0, // closed_at
                    100_000000, // total_supply
                    1, // option
                    1, // asset_id
                    1000000000000000000000000000, // factor
                    test_scenario::ctx(&mut scenario)
                );
            };

            {
                incentive_v2::create_incentive_pool<USDT_TEST>(
                    &owner_cap,
                    &mut incentive,
                    &usdt_funds,
                    0, // phase
                    current_timestamp, // start_at
                    current_timestamp + 1000 * 60 * 60, // end_at
                    0, // closed_at
                    100_000000, // total_supply
                    3, // option
                    1, // asset_id
                    1000000000000000000000000000, // factor
                    test_scenario::ctx(&mut scenario)
                );
            };

            {
                incentive_v2::create_incentive_pool<USDT_TEST>(
                    &owner_cap,
                    &mut incentive,
                    &usdt_funds,
                    1, // phase
                    current_timestamp, // start_at
                    current_timestamp + 1000 * 60 * 60 * 2, // end_at
                    0, // closed_at
                    100_000000, // total_supply
                    3, // option
                    1, // asset_id
                    1000000000000000000000000000, // factor
                    test_scenario::ctx(&mut scenario)
                );
            };

            {
                incentive_v2::create_incentive_pool<USDT_TEST>(
                    &owner_cap,
                    &mut incentive,
                    &usdt_funds,
                    1, // phase
                    current_timestamp, // start_at
                    current_timestamp + 1000 * 60 * 60 * 2, // end_at
                    0, // closed_at
                    100_000000, // total_supply
                    1, // option
                    1, // asset_id
                    1000000000000000000000000000, // factor
                    test_scenario::ctx(&mut scenario)
                );
            };

            test_scenario::return_shared(usdt_funds);
            test_scenario::return_shared(incentive);
            test_scenario::return_to_sender(&scenario, owner_cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive>(&scenario);

            let active_pools = incentive_v2::get_pool_objects(&incentive);
            let inactive_pools = incentive_v2::get_inactive_pool_objects(&incentive);

            assert!(vector::length(&active_pools) == 4, 0);
            assert!(vector::length(&inactive_pools) == 0, 0);

            _target_pool = *vector::borrow(&active_pools, 0);

            let (_,_,_,_,_,_,_,_,_,_,last_update_at,_,_) = incentive_v2::get_pool_info(&incentive, _target_pool);
            _target_pool_update_time = last_update_at;
            test_scenario::return_shared(incentive);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            clock::increment_for_testing(&mut _clock, 1000 * 10); // 10 seconds after the reward starts
            let pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);

            let coin = coin::mint_for_testing<USDC_TEST>(100_000000000, test_scenario::ctx(&mut scenario));

            entry_deposit_for_testing(&mut scenario, &_clock, &mut pool, coin, 1, 100_000000000);
            let (total_supply, _, _) = pool::get_pool_info(&pool);
            assert!(total_supply == 100_000000000, 0);

            test_scenario::return_shared(pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            clock::increment_for_testing(&mut _clock, 1000 * 60 * 20); // 50 seconds after the reward starts
            let usdt_funds = test_scenario::take_shared<IncentiveFundsPool<USDT_TEST>>(&scenario);
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let incentive = test_scenario::take_shared<Incentive>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            
            let _balance = incentive_v2::claim_reward_non_entry(&_clock, &mut incentive, &mut usdt_funds, &mut storage, 1, 1, test_scenario::ctx(&mut scenario));
            assert!(balance::value(&_balance) > 0, 0);

            transfer::public_transfer(coin::from_balance(_balance, test_scenario::ctx(&mut scenario)), OWNER);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(incentive);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(usdt_funds);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            clock::increment_for_testing(&mut _clock, 1000 * 1); // 50 seconds after the reward starts
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(&scenario);
            let incentive = test_scenario::take_shared<Incentive>(&scenario);

            incentive_v2::freeze_incentive_pool(&owner_cap, &mut incentive, 1);
            test_scenario::return_shared(incentive);
            test_scenario::return_to_sender(&scenario, owner_cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            clock::increment_for_testing(&mut _clock, 1000 * 60 * 20); // 50 seconds after the reward starts
            let usdt_funds = test_scenario::take_shared<IncentiveFundsPool<USDT_TEST>>(&scenario);
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let incentive = test_scenario::take_shared<Incentive>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            
            let _balance = incentive_v2::claim_reward_non_entry(&_clock, &mut incentive, &mut usdt_funds, &mut storage, 1, 1, test_scenario::ctx(&mut scenario));
            assert!(balance::value(&_balance) > 0, 0);

            let active_pools = incentive_v2::get_pool_objects(&incentive);
            let inactive_pools = incentive_v2::get_inactive_pool_objects(&incentive);
            
            assert!(vector::length(&active_pools) == 2, 0);
            assert!(vector::length(&inactive_pools) == 2, 0);

            transfer::public_transfer(coin::from_balance(_balance, test_scenario::ctx(&mut scenario)), OWNER);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(incentive);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(usdt_funds);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            clock::increment_for_testing(&mut _clock, 1000 * 2); // 50 seconds after the reward starts
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(&scenario);
            let incentive = test_scenario::take_shared<Incentive>(&scenario);

            incentive_v2::freeze_incentive_pool(&owner_cap, &mut incentive, 2);
            test_scenario::return_shared(incentive);
            test_scenario::return_to_sender(&scenario, owner_cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            clock::increment_for_testing(&mut _clock, 1000 * 60 * 5); // 50 seconds after the reward starts
            let usdt_funds = test_scenario::take_shared<IncentiveFundsPool<USDT_TEST>>(&scenario);
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let incentive = test_scenario::take_shared<Incentive>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            
            let _balance = incentive_v2::claim_reward_non_entry(&_clock, &mut incentive, &mut usdt_funds, &mut storage, 1, 1, test_scenario::ctx(&mut scenario));
            assert!(balance::value(&_balance) == 0, 0);

            let active_pools = incentive_v2::get_pool_objects(&incentive);
            let inactive_pools = incentive_v2::get_inactive_pool_objects(&incentive);
            
            assert!(vector::length(&active_pools) == 0, 0);
            assert!(vector::length(&inactive_pools) == 4, 0);

            transfer::public_transfer(coin::from_balance(_balance, test_scenario::ctx(&mut scenario)), OWNER);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(incentive);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(usdt_funds);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive>(&scenario);

            let (_,_,_,_,_,_,_,_,_,_,last_update_at,_,_) = incentive_v2::get_pool_info(&incentive, _target_pool);
            assert!(last_update_at > _target_pool_update_time, 0);
            _target_pool_update_time = last_update_at;
            
            test_scenario::return_shared(incentive);
        };

        let next_timestamp = 1700006400000 + 1000 * 60 * 60 * 2;
        clock::set_for_testing(&mut _clock, next_timestamp);
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let usdt_funds = test_scenario::take_shared<IncentiveFundsPool<USDT_TEST>>(&scenario);
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(&scenario);
            let incentive = test_scenario::take_shared<Incentive>(&scenario);

            {
                incentive_v2::create_incentive_pool<USDT_TEST>(
                    &owner_cap,
                    &mut incentive,
                    &usdt_funds,
                    2, // phase
                    next_timestamp, // start_at
                    next_timestamp + 1000 * 60 * 30, // end_at
                    0, // closed_at
                    100_000000, // total_supply
                    1, // option
                    1, // asset_id
                    1000000000000000000000000000, // factor
                    test_scenario::ctx(&mut scenario)
                );
            };

            {
                incentive_v2::create_incentive_pool<USDT_TEST>(
                    &owner_cap,
                    &mut incentive,
                    &usdt_funds,
                    3, // phase
                    next_timestamp + 1000 * 60 * 30, // start_at
                    next_timestamp + 1000 * 60 * 30 * 2, // end_at
                    0, // closed_at
                    100_000000, // total_supply
                    3, // option
                    1, // asset_id
                    1000000000000000000000000000, // factor
                    test_scenario::ctx(&mut scenario)
                );
            };

            test_scenario::return_shared(usdt_funds);
            test_scenario::return_shared(incentive);
            test_scenario::return_to_sender(&scenario, owner_cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive>(&scenario);

            let active_pools = incentive_v2::get_pool_objects(&incentive);
            let inactive_pools = incentive_v2::get_inactive_pool_objects(&incentive);
            
            assert!(vector::length(&active_pools) == 2, 0);
            assert!(vector::length(&inactive_pools) == 4, 0);
            test_scenario::return_shared(incentive);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            clock::increment_for_testing(&mut _clock, 1000 * 60 * 40);
            let usdt_funds = test_scenario::take_shared<IncentiveFundsPool<USDT_TEST>>(&scenario);
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let incentive = test_scenario::take_shared<Incentive>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            
            let _balance = incentive_v2::claim_reward_non_entry(&_clock, &mut incentive, &mut usdt_funds, &mut storage, 1, 1, test_scenario::ctx(&mut scenario));
            assert!(balance::value(&_balance) > 0, 0);

            let active_pools = incentive_v2::get_pool_objects(&incentive);
            let inactive_pools = incentive_v2::get_inactive_pool_objects(&incentive);
            
            assert!(vector::length(&active_pools) == 2, 0);
            assert!(vector::length(&inactive_pools) == 4, 0);

            transfer::public_transfer(coin::from_balance(_balance, test_scenario::ctx(&mut scenario)), OWNER);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(incentive);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(usdt_funds);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive>(&scenario);

            let (_,_,_,_,_,_,_,_,_,_,last_update_at,_,_) = incentive_v2::get_pool_info(&incentive, _target_pool);
            assert!(last_update_at == _target_pool_update_time, 0);
            _target_pool_update_time = last_update_at;
            std::debug::print(&_target_pool_update_time);
            
            test_scenario::return_shared(incentive);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_entry_deposit_on_behalf_of_user_should_update_incentive_index() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        let current_timestamp = 1700006400000;
        clock::set_for_testing(&mut _clock, current_timestamp);
        {
            base::initial_protocol(&mut scenario, &_clock);
            initial_incentive_v2_v3(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let usdt_funds = test_scenario::take_shared<IncentiveFundsPool<USDT_TEST>>(&scenario);

            create_incentive_pool_for_testing(
                &mut scenario,
                &usdt_funds,
                0, // phase
                current_timestamp, // start, 2023-11-15 08:00:00
                current_timestamp + 1000 * 60 * 60, // end, 2023-11-15 09:00:00
                0, // closed
                100_000000, // total_supply
                1, // option 
                0, // asset
                1000000000000000000000000000 // factor
            );

            test_scenario::return_shared(usdt_funds);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            clock::increment_for_testing(&mut _clock, 1000 * 10); // 10 seconds after the reward starts
            let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            let coin = coin::mint_for_testing<SUI_TEST>(10000_000000000, test_scenario::ctx(&mut scenario));

            entry_deposit_on_behalf_of_user_for_testing(&mut scenario, &_clock, &mut pool, coin, 0, 10000_000000000, UserB);

            let (total_supply, _, _) = pool::get_pool_info(&pool);
            assert!(total_supply == 10000_000000000, 0);

            test_scenario::return_shared(pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive>(&scenario);
            let pool_objs = incentive_v2::get_active_pools(&incentive, 0, 1, clock::timestamp_ms(&_clock));
            let length = vector::length(&pool_objs);
            assert!(length == 1, 0);

            let (_,_,_,_,_,_,_,_,_,factor,last_update_at,_,_) = incentive_v2::get_pool_info(&incentive, *vector::borrow(&pool_objs, 0));
            assert!(last_update_at == clock::timestamp_ms(&_clock), 0);

            let storage = test_scenario::take_shared<Storage>(&scenario);
            let (total_supply_balance, total_borrow_balance) = storage::get_total_supply(&mut storage, 0);
            assert!(total_supply_balance == 10000_000000000, 0);
            assert!(total_borrow_balance == 0, 0);

            let (user_supply_balance, user_borrow_balance) = storage::get_user_balance(&mut storage, 0, UserB);
            assert!(user_supply_balance == 10000_000000000, 0);
            assert!(user_borrow_balance == 0, 0);

            let user_effective_amount = incentive_v2::calculate_user_effective_amount(1, user_supply_balance, user_borrow_balance, factor);
            assert!(user_effective_amount == 10000_000000000, 0);

            let (index_reward, total_rewards_of_user) = incentive_v2::calculate_one_from_pool(
                &incentive,
                *vector::borrow(&pool_objs, 0),
                clock::timestamp_ms(&_clock),
                total_supply_balance,
                UserB,
                user_effective_amount
            );
            assert!(total_rewards_of_user == 0, 0);
            assert!(index_reward == 0, 0);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            clock::increment_for_testing(&mut _clock, 1000 * 60 * 2); // 2min after the reward starts
            let incentive = test_scenario::take_shared<Incentive>(&scenario);
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let pool_objs = incentive_v2::get_active_pools(&incentive, 0, 1, clock::timestamp_ms(&_clock));

            let (_,_,_,_,_,_,_,_,_,factor,_,_,_) = incentive_v2::get_pool_info(&incentive, *vector::borrow(&pool_objs, 0));

            let (total_supply_balance, _) = storage::get_total_supply(&mut storage, 0);
            let (user_supply_balance, user_borrow_balance) = storage::get_user_balance(&mut storage, 0, UserB);
            let user_effective_amount = incentive_v2::calculate_user_effective_amount(1, user_supply_balance, user_borrow_balance, factor);

            let (owner_supply_balance, owner_borrow_balance) = storage::get_user_balance(&mut storage, 0, OWNER);
            let owner_effective_amount = incentive_v2::calculate_user_effective_amount(1, owner_supply_balance, owner_borrow_balance, factor);

            let (index_reward, total_rewards_of_user) = incentive_v2::calculate_one_from_pool(
                &incentive,
                *vector::borrow(&pool_objs, 0),
                clock::timestamp_ms(&_clock),
                total_supply_balance,
                UserB,
                user_effective_amount
            );
            assert!(index_reward > 0, 0);
            assert!(total_rewards_of_user > 0, 0);

            let (_, owner_total_rewards_of_user) = incentive_v2::calculate_one_from_pool(
                &incentive,
                *vector::borrow(&pool_objs, 0),
                clock::timestamp_ms(&_clock),
                total_supply_balance,
                OWNER,
                owner_effective_amount
            );
            assert!(owner_total_rewards_of_user == 0, 0);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_entry_repay_on_behalf_of_user_should_update_incentive_index() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        let current_timestamp = 1700006400000;
        clock::set_for_testing(&mut _clock, current_timestamp);
        {
            base::initial_protocol(&mut scenario, &_clock);
            initial_incentive_v2_v3(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let usdt_funds = test_scenario::take_shared<IncentiveFundsPool<USDT_TEST>>(&scenario);

            create_incentive_pool_for_testing(
                &mut scenario,
                &usdt_funds,
                0, // phase
                current_timestamp, // start, 2023-11-15 08:00:00
                current_timestamp + 1000 * 60 * 60, // end, 2023-11-15 09:00:00
                0, // closed
                100_000000, // total_supply
                3, // option 
                0, // asset
                1000000000000000000000000000 // factor
            );

            test_scenario::return_shared(usdt_funds);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            clock::increment_for_testing(&mut _clock, 1000 * 10); // 10 seconds after the reward starts
            let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            let coin = coin::mint_for_testing<SUI_TEST>(10000_000000000, test_scenario::ctx(&mut scenario));

            entry_deposit_on_behalf_of_user_for_testing(&mut scenario, &_clock, &mut pool, coin, 0, 10000_000000000, OWNER);

            test_scenario::return_shared(pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            clock::increment_for_testing(&mut _clock, 1000 * 10); // 10 seconds after the reward starts
            let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

            entry_borrow_for_testing(&mut scenario, &_clock, &mut pool, 0, 500_000000000);

            test_scenario::return_shared(pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        let _last_index = 0;
        {
            let incentive = test_scenario::take_shared<Incentive>(&scenario);
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let pool_objs = incentive_v2::get_active_pools(&incentive, 0, 3, clock::timestamp_ms(&_clock));

            let (_,_,_,_,_,_,_,_,_,_,_,_,index) = incentive_v2::get_pool_info(&incentive, *vector::borrow(&pool_objs, 0));
            _last_index = index;

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            clock::increment_for_testing(&mut _clock, 1000 * 60 * 2); // 2min after the reward starts
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            let sui_coin = coin::mint_for_testing<SUI_TEST>(30000_000000000, test_scenario::ctx(&mut scenario));
            let sui_value = coin::value(&sui_coin);
            entry_repay_on_behalf_of_user_for_testing<SUI_TEST>(&mut scenario, &_clock, &mut sui_pool, sui_coin, 0, sui_value, OWNER);

            test_scenario::return_shared(sui_pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive>(&scenario);
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let pool_objs = incentive_v2::get_active_pools(&incentive, 0, 3, clock::timestamp_ms(&_clock));

            let (_,_,_,_,_,_,_,_,_,_,_,_,index) = incentive_v2::get_pool_info(&incentive, *vector::borrow(&pool_objs, 0));

            let (_, user_borrow_balance) = storage::get_user_balance(&mut storage, 0, OWNER);
            assert!(user_borrow_balance == 0, 0);
            assert!((_last_index == 0) && (index > _last_index), 0);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }
}