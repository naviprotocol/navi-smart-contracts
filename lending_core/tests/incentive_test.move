#[test_only]
module lending_core::incentive_tests {
    use std::vector;
    use sui::clock;
    use sui::coin::{Self};
    use sui::balance::{Self};
    use sui::transfer::{Self};
    use sui::test_scenario::{Self};

    use math::ray_math;
    use lending_core::global;
    use lending_core::storage::{Storage};
    use lending_core::lending::{Self};
    use lending_core::incentive::{Self, Incentive, IncentiveBal};
    use lending_core::pool::{Pool};
    use lending_core::btc_test::{BTC_TEST};
    use lending_core::base_lending_tests::{Self};

    const OWNER: address = @0xA;

    #[test]
    #[expected_failure(abort_code = 1501, location = lending_core::incentive)]
    public fun test_add_pool_by_other() {
        let other = @0xB;

        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, other);
        {
            let i = test_scenario::take_shared<Incentive>(&scenario);

            let ctx = test_scenario::ctx(&mut scenario);
            let coin = coin::mint_for_testing<BTC_TEST>(100, ctx);
            let clock = clock::create_for_testing(ctx);

            incentive::add_pool<BTC_TEST>(&mut i, &clock, 0, 1, 1, coin, 100, 0, ctx);

            clock::destroy_for_testing(clock);

            test_scenario::return_shared(i);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1802, location = lending_core::incentive)]
    public fun test_add_pool_invalid_duration() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let i = test_scenario::take_shared<Incentive>(&scenario);
            let coin = coin::mint_for_testing<BTC_TEST>(100, test_scenario::ctx(&mut scenario));

            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

            incentive::add_pool<BTC_TEST>(&mut i, &clock, 0, 1, 0, coin, 100, 0, test_scenario::ctx(&mut scenario));

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(i);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_add_pool() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let i = test_scenario::take_shared<Incentive>(&scenario);

            let ctx = test_scenario::ctx(&mut scenario);
            let coin = coin::mint_for_testing<BTC_TEST>(100, ctx);
            let clock = clock::create_for_testing(ctx);

            incentive::add_pool<BTC_TEST>(&mut i, &clock, 0, 1, 2, coin, 100, 0, ctx);
            assert!(incentive::get_pool_count(&i, 0) == 1, 0);
            let (start_time, end_time, rate, oracle_id) = incentive::get_pool_info(&i, 0, 0);
            assert!(start_time == 1, 0);
            assert!(end_time == 2, 0);
            assert!(rate == 100*ray_math::ray(), 0);
            assert!(oracle_id == 0, 0);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(i);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 0, location = lending_core::lending)] // This function(lending::deposit) has been deprecated, update to lending::deposit_coin
    public fun test_update_reward() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let i = test_scenario::take_shared<Incentive>(&scenario);

            let ctx = test_scenario::ctx(&mut scenario);
            let coin = coin::mint_for_testing<BTC_TEST>(100, ctx);
            let clock = clock::create_for_testing(ctx);

            incentive::add_pool<BTC_TEST>(&mut i, &clock, 2, 100, 200, coin, 100, 0, ctx);

            clock::destroy_for_testing(clock);

            test_scenario::return_shared(i);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);
            let pool = test_scenario::take_shared<Pool<BTC_TEST>>(&scenario);
            let i = test_scenario::take_shared<Incentive>(&scenario);

            let ctx = test_scenario::ctx(&mut scenario);
            let clock = clock::create_for_testing(ctx);

            let coin = coin::mint_for_testing<BTC_TEST>(50, ctx);
            lending::deposit<BTC_TEST>(&clock, &mut stg, &mut pool, 2, coin, 50, &mut i, ctx);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(stg);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(i);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);
            let i = test_scenario::take_shared<Incentive>(&scenario);

            let ctx = test_scenario::ctx(&mut scenario);
            let clock = clock::create_for_testing(ctx);
            clock::increment_for_testing(&mut clock, 150);

            let (coin_types, user_earned_rewards, oracle_ids) = incentive::earned(&i, &mut stg, &clock, 2, OWNER);

            assert!(vector::length(&coin_types) == 1, 0);
            assert!(vector::length(&user_earned_rewards) == 1, 0);
            assert!(*vector::borrow(&user_earned_rewards, 0) == 50*ray_math::ray(), 0);
            assert!(vector::length(&oracle_ids) == 1, 0);
            assert!(*vector::borrow(&oracle_ids, 0) == 0, 0);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(i);
            test_scenario::return_shared(stg);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);
            let i = test_scenario::take_shared<Incentive>(&scenario);
            let b = test_scenario::take_shared<IncentiveBal<BTC_TEST>>(&scenario);
            let ctx = test_scenario::ctx(&mut scenario);
            let clock = clock::create_for_testing(ctx);
            clock::increment_for_testing(&mut clock, 50);

            incentive::claim_reward<BTC_TEST>(&mut i, &mut b, &clock, &mut stg, OWNER, ctx);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(stg);
            test_scenario::return_shared(i);
            test_scenario::return_shared(b);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_update_reward_non_entry() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let i = test_scenario::take_shared<Incentive>(&scenario);

            let ctx = test_scenario::ctx(&mut scenario);
            let coin = coin::mint_for_testing<BTC_TEST>(100_000000000, ctx);
            let clock = clock::create_for_testing(ctx);

            incentive::add_pool<BTC_TEST>(&mut i, &clock, 2, 100, 200, coin, 100_000000000, 0, ctx);

            clock::destroy_for_testing(clock);

            test_scenario::return_shared(i);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<BTC_TEST>>(&scenario);
            let i = test_scenario::take_shared<Incentive>(&scenario);

            let ctx = test_scenario::ctx(&mut scenario);
            let clock = clock::create_for_testing(ctx);

            let coin = coin::mint_for_testing<BTC_TEST>(50000_000000000, ctx);
            base_lending_tests::base_deposit_for_testing(&mut scenario, &clock, &mut pool, coin, 2, 50000_000000000);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(i);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);
            let i = test_scenario::take_shared<Incentive>(&scenario);

            let ctx = test_scenario::ctx(&mut scenario);
            let clock = clock::create_for_testing(ctx);
            clock::increment_for_testing(&mut clock, 150);

            let (coin_types, user_earned_rewards, oracle_ids) = incentive::earned(&i, &mut stg, &clock, 2, OWNER);
            std::debug::print(vector::borrow(&user_earned_rewards, 0));
            assert!(vector::length(&coin_types) == 1, 0);
            assert!(vector::length(&user_earned_rewards) == 1, 0);
            assert!(*vector::borrow(&user_earned_rewards, 0) == 50_000000000*ray_math::ray(), 0);
            assert!(vector::length(&oracle_ids) == 1, 0);
            assert!(*vector::borrow(&oracle_ids, 0) == 0, 0);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(i);
            test_scenario::return_shared(stg);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);
            let i = test_scenario::take_shared<Incentive>(&scenario);
            let b = test_scenario::take_shared<IncentiveBal<BTC_TEST>>(&scenario);
            let ctx = test_scenario::ctx(&mut scenario);
            let clock = clock::create_for_testing(ctx);
            clock::increment_for_testing(&mut clock, 50);

            let _balance = incentive::claim_reward_non_entry<BTC_TEST>(&mut i, &mut b, &clock, &mut stg, ctx);

            if (balance::value(&_balance) > 0) {
                transfer::public_transfer(coin::from_balance(_balance, ctx), test_scenario::sender(&scenario))
            } else {
                balance::destroy_zero(_balance)
            };

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(stg);
            test_scenario::return_shared(i);
            test_scenario::return_shared(b);
        };

        test_scenario::end(scenario);
    }
}