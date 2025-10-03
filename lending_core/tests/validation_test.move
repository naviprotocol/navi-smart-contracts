#[test_only]
module lending_core::validation_tests {
    use sui::clock;
    use sui::coin::{Self};
    use sui::test_scenario::{Self};

    use lending_core::base;
    use lending_core::validation::{Self};
    use lending_core::pool::{Self, Pool};
    use lending_core::sui_test::{SUI_TEST};
    use lending_core::usdt_test::{USDT_TEST};
    use lending_core::storage::{Self, Storage};
    use lending_core::base_lending_tests::{Self};

    const OWNER: address = @0xA;

    #[test]
    public fun test_validate_repay() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            let coin = coin::mint_for_testing<SUI_TEST>(100_000000000, test_scenario::ctx(&mut scenario));

            base_lending_tests::base_deposit_for_testing(&mut scenario, &clock, &mut pool, coin, 0, 100_000000000);

            let (total_supply, _, _) = pool::get_pool_info(&pool);
            assert!(total_supply == 100_000000000, 0);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            base_lending_tests::base_borrow_for_testing(&mut scenario, &clock, &mut pool, 0, 275_000000);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);
            validation::validate_repay<SUI_TEST>(&mut stg, 0, 1_000000000);

            test_scenario::return_shared(stg);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1503, location = lending_core::validation)]
    public fun test_validate_repay_zero() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);

            validation::validate_repay<SUI_TEST>(&mut stg, 0, 0);

            test_scenario::return_shared(stg);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_validate_liquidate() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);

            validation::validate_liquidate<SUI_TEST, USDT_TEST>(&mut stg, 0, 2, 1);

            test_scenario::return_shared(stg);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1503, location = lending_core::validation)]
    public fun test_validate_liquidate_zero() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);

            validation::validate_liquidate<SUI_TEST, USDT_TEST>(&mut stg, 0, 2, 0);

            test_scenario::return_shared(stg);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1506, location = lending_core::validation)]
    public fun test_validate_borrow_balance_not_enough() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);

            validation::validate_borrow<SUI_TEST>(&mut stg, 0, 1);

            test_scenario::return_shared(stg);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1605, location = lending_core::validation)]
    public fun test_validate_borrow_over_cap() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);

            storage::increase_supply_balance_for_testing(&mut stg, 0, OWNER, 20000000_000000000);
            validation::validate_borrow<SUI_TEST>(&mut stg, 0, 19000000_000000000);

            test_scenario::return_shared(stg);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_validate_borrow() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);

            storage::increase_supply_balance_for_testing(&mut stg, 0, OWNER, 2);
            validation::validate_borrow<SUI_TEST>(&mut stg, 0, 1);

            test_scenario::return_shared(stg);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1506, location = lending_core::validation)]
    public fun test_validate_withdraw_balance_not_enough() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            let coin = coin::mint_for_testing<SUI_TEST>(1000000_000000, test_scenario::ctx(&mut scenario));

            base_lending_tests::base_deposit_for_testing(&mut scenario, &clock, &mut pool, coin, 0, 100_000000000);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);

            validation::validate_withdraw<SUI_TEST>(&mut stg, 0, 101_000000000);

            test_scenario::return_shared(stg);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_validate_withdraw_balance() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);

            storage::increase_supply_balance_for_testing(&mut stg, 0, OWNER, 2);
            validation::validate_withdraw<SUI_TEST>(&mut stg, 0, 1);

            test_scenario::return_shared(stg);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1604, location = lending_core::validation)]
    public fun test_validate_deposit_over_cap() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);

            validation::validate_deposit<SUI_TEST>(&mut stg, 0, 30000000_000000000);

            test_scenario::return_shared(stg);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_validate_deposit() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);

            validation::validate_deposit<SUI_TEST>(&mut stg, 0, 1);

            test_scenario::return_shared(stg);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }
}