#[test_only]
module lending_core::lending_tests {
    use sui::clock;
    use sui::address;
    use sui::coin::{Self};
    use sui::test_scenario::{Self};

    use lending_core::ray_math;
    use oracle::oracle::{Self, PriceOracle, OracleFeederCap};
    use lending_core::base;
    use lending_core::logic::{Self};
    use lending_core::pool::{Self, Pool};
    use lending_core::eth_test::{ETH_TEST};
    use lending_core::sui_test::{SUI_TEST};
    use lending_core::usdt_test::{USDT_TEST};
    use lending_core::usdc_test::{USDC_TEST};
    use lending_core::test_coin::{TEST_COIN};
    use lending_core::storage::{Self, Storage, OwnerCap as StorageOwnerCap};
    use lending_core::base_lending_tests::{Self};
    use lending_core::lib;

    const OWNER: address = @0xA;
    const UserA: address = @0xA;
    const UserB: address = @0xB;

    #[test]
    #[expected_failure(abort_code = 0, location = lending_core::lending)]
    public fun test_deprecated_deposit() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            let sui_coin = coin::mint_for_testing<SUI_TEST>(100_000000000, test_scenario::ctx(&mut scenario));

            base_lending_tests::base_deprecated_deposit_for_testing(&mut scenario, &mut pool, sui_coin);

            test_scenario::return_shared(pool);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 0, location = lending_core::lending)]
    public fun test_deprecated_withdraw() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            
            base_lending_tests::base_deprecated_withdraw_for_testing(&mut scenario, &mut pool);

            test_scenario::return_shared(pool);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 0, location = lending_core::lending)]
    public fun test_deprecated_borrow() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            base_lending_tests::base_deprecated_borrow_for_testing(&mut scenario, &mut pool);
            test_scenario::return_shared(pool);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 0, location = lending_core::lending)]
    public fun test_deprecated_repay() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            let repay_coin = coin::mint_for_testing<SUI_TEST>(1_000000000, test_scenario::ctx(&mut scenario));
            base_lending_tests::base_deprecated_repay_for_testing(&mut scenario, &mut pool, repay_coin);
            test_scenario::return_shared(pool);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }
    
    #[test] // deposit
    public fun test_deposit() {
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

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    #[test] // deposit -> borrow
    public fun test_borrow() {
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

            base_lending_tests::base_borrow_for_testing(&mut scenario, &clock, &mut pool, 0, 10_000000000);
            let (total_supply, _, _) = pool::get_pool_info(&pool);
            assert!(total_supply == 90_000000000, 0);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(pool);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    #[test] // deposit -> withdraw
    public fun test_withdraw() {
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
            base_lending_tests::base_withdraw_for_testing(&mut scenario, &clock, &mut pool, 0, 100_000000000);

            // validation
            let (total_supply, _, _) = pool::get_pool_info<SUI_TEST>(&pool);
            assert!(total_supply == 0, 0);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(pool);
        };
        
        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    #[test] // deposit -> borrow -> repay
    public fun test_repay() {
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

            base_lending_tests::base_borrow_for_testing(&mut scenario, &clock, &mut pool, 0, 10_000000000);
            let (total_supply, _, _) = pool::get_pool_info(&pool);
            assert!(total_supply == 90_000000000, 0);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            let coin = coin::mint_for_testing<SUI_TEST>(100_000000000, test_scenario::ctx(&mut scenario));

            base_lending_tests::base_repay_for_testing(&mut scenario, &clock, &mut pool, coin, 0, 1_000000000);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(pool);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_liquidation_call() {
        let userA = @0xA;
        let userB = @0xB;
        let liquidator = @0xC;
        let scenarioA = test_scenario::begin(userA);
        let scenarioB = test_scenario::begin(userB);
        let scenario_liquidator = test_scenario::begin(liquidator);

        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };

        // lending: userA deposit USDT 1000000
        test_scenario::next_tx(&mut scenarioA, userA);
        {
            let pool = test_scenario::take_shared<Pool<USDT_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            let coin = coin::mint_for_testing<USDT_TEST>(1000000_000000, test_scenario::ctx(&mut scenarioA));

            base_lending_tests::base_deposit_for_testing(&mut scenarioA, &clock, &mut pool, coin, 2, 1000000_000000);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(pool);
        };

        // lending: userB deposit SUI 1000
        test_scenario::next_tx(&mut scenarioB, userB);
        {
            let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            let coin = coin::mint_for_testing<SUI_TEST>(1000_000000000, test_scenario::ctx(&mut scenarioB));

            base_lending_tests::base_deposit_for_testing(&mut scenarioB, &clock, &mut pool, coin, 0, 1000_000000000);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(pool);
        };

        // lending: userB borrow USDT
        test_scenario::next_tx(&mut scenarioB, userB);
        {
            let pool = test_scenario::take_shared<Pool<USDT_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

            base_lending_tests::base_borrow_for_testing(&mut scenarioB, &clock, &mut pool, 2, 275_000000);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(pool);
        };

        // oracle: update SUI price to 0.38
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let oracle_feeder_cap = test_scenario::take_from_sender<OracleFeederCap>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenarioB));

            oracle::update_token_price(
                &oracle_feeder_cap, // feeder cap
                &clock,
                &mut price_oracle, // PriceOracle
                0,                 // Oracle id
                380000000,    // price
            );

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_to_sender(&scenario, oracle_feeder_cap);
            test_scenario::return_shared(storage);
        };

        // liquidation call
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let usdt_pool = test_scenario::take_shared<Pool<USDT_TEST>>(&scenario);
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            let usdt_coin = coin::mint_for_testing<USDT_TEST>(10000000_000000000, test_scenario::ctx(&mut scenario_liquidator));
           
            base_lending_tests::base_liquidation_for_testing(
                &mut scenario,
                2,
                &mut usdt_pool,
                usdt_coin,
                0,
                &mut sui_pool,
                userB,
                10000_000000000
            );
            test_scenario::return_shared(sui_pool);
            test_scenario::return_shared(usdt_pool);
        };
        
        test_scenario::next_tx(&mut scenarioB, userB);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenarioB));
            let avg_ltv = logic::calculate_avg_ltv(&clock, &price_oracle, &mut storage, userB);
            let avg_threshold = logic::calculate_avg_threshold(&clock, &price_oracle, &mut storage, userB);
            let health_factor_in_borrow = ray_math::ray_div(avg_threshold, avg_ltv);
            std::debug::print(&health_factor_in_borrow);

            std::debug::print(&logic::user_collateral_value(&clock, &price_oracle, &mut storage, 0, userB));
            std::debug::print(&logic::user_loan_value(&clock, &price_oracle, &mut storage, 2, userB));
            std::debug::print(&logic::user_health_factor(&clock, &mut storage, &price_oracle, userB));
            
            clock::destroy_for_testing(clock);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(price_oracle);
        };

        test_scenario::end(scenario);
        test_scenario::end(scenarioA);
        test_scenario::end(scenarioB);
        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario_liquidator);
    }

    #[test]
    #[expected_failure(abort_code = 1600, location = lending_core::logic)]
    public fun test_add_ltv_to_borrow_health_factor() {
        let userA = @0xA;
        let userB = @0xB;
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };

        // userA deposit 1000k usdt
        test_scenario::next_tx(&mut scenario, userA);
        {
            let usdt_pool = test_scenario::take_shared<Pool<USDT_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            let coin = coin::mint_for_testing<USDT_TEST>(1000000_000000, test_scenario::ctx(&mut scenario));
            base_lending_tests::base_deposit_for_testing(&mut scenario, &clock, &mut usdt_pool, coin, 2, 1000000_000000);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(usdt_pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 1000);

            let avg_ltv = logic::calculate_avg_ltv(&clock, &price_oracle, &mut storage, userB);
            let avg_threshold = logic::calculate_avg_threshold(&clock, &price_oracle, &mut storage, userB);
            let user_health_factor = logic::user_health_factor(&clock, &mut storage, &price_oracle, userB);
            assert!(avg_ltv == 0, 0); // No. 0
            assert!(avg_threshold == 0, 0); // No. 1
            assert!(user_health_factor == address::max(), 0); // No. 2

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(price_oracle);
        };

        test_scenario::next_tx(&mut scenario, userB);
        {
            let eth_pool = test_scenario::take_shared<Pool<ETH_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            let eth_coin = coin::mint_for_testing<ETH_TEST>(1_000000000, test_scenario::ctx(&mut scenario));
            base_lending_tests::base_deposit_for_testing(&mut scenario, &clock, &mut eth_pool, eth_coin, 3, 1_000000000);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(eth_pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 2000);

            let reserve_ltv = storage::get_asset_ltv(&storage, 3);
            let (_, _, reserve_threshold) = storage::get_liquidation_factors(&mut storage, 3);

            let avg_ltv = logic::calculate_avg_ltv(&clock, &price_oracle, &mut storage, userB);
            let avg_threshold = logic::calculate_avg_threshold(&clock, &price_oracle, &mut storage, userB);
            let user_health_factor = logic::user_health_factor(&clock, &mut storage, &price_oracle, userB);

            assert!(avg_ltv == reserve_ltv, 0); // No. 4
            assert!(avg_threshold == reserve_threshold, 0); // No. 5
            assert!(user_health_factor == address::max(), 0); // No. 6

            test_scenario::return_shared(storage);
            test_scenario::return_shared(price_oracle);
            clock::destroy_for_testing(clock);
        };

        let _max_borrow = 0;
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let usdt_pool = test_scenario::take_shared<Pool<USDT_TEST>>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 3000);

            let avg_ltv = logic::calculate_avg_ltv(&clock, &price_oracle, &mut storage, userB);
            let avg_threshold = logic::calculate_avg_threshold(&clock, &price_oracle, &mut storage, userB);
            let health_factor_in_borrow = ray_math::ray_div(avg_threshold, avg_ltv);
            let health_collateral_value = logic::user_health_collateral_value(&clock, &price_oracle, &mut storage, userB);
            let dynamic_liquidation_threshold = logic::dynamic_liquidation_threshold(&clock, &mut storage, &price_oracle, userB);
            _max_borrow = ray_math::ray_div(health_collateral_value, ray_math::ray_div(health_factor_in_borrow, dynamic_liquidation_threshold));

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(usdt_pool);
            test_scenario::return_shared(price_oracle);
        };

        test_scenario::next_tx(&mut scenario, userB);
        {
            let usdt_pool = test_scenario::take_shared<Pool<USDT_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            base_lending_tests::base_borrow_for_testing<USDT_TEST>(
                &mut scenario,
                &clock,
                &mut usdt_pool,
                2,
                (_max_borrow as u64) / 1000,
            ); // No. 7

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(usdt_pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 3000);
            
            let avg_ltv = logic::calculate_avg_ltv(&clock, &price_oracle, &mut storage, userB);
            let avg_threshold = logic::calculate_avg_threshold(&clock, &price_oracle, &mut storage, userB);
            let health_factor_in_borrow = ray_math::ray_div(avg_threshold, avg_ltv);

            let user_health_factor = logic::user_health_factor(&clock, &mut storage, &price_oracle, userB);
            assert!(user_health_factor > health_factor_in_borrow, 0);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(price_oracle);
        };

        test_scenario::next_tx(&mut scenario, userB);
        {
            let usdt_pool = test_scenario::take_shared<Pool<USDT_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

            // expected error:
            // #[expected_failure(abort_code = logic::LOGIC_USER_UN_HEALTH)]
            base_lending_tests::base_borrow_for_testing<USDT_TEST>(
                &mut scenario,
                &clock,
                &mut usdt_pool,
                2,
                1000000,
            ); // No. 8

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(usdt_pool);
        };

        test_scenario::end(scenario);
        clock::destroy_for_testing(_clock);
    }

    #[test]
    #[expected_failure(abort_code = 1603, location = lending_core::logic)]
    public fun test_add_ltv_to_borrow_health_factor_zero_ltv() {
        let userA = @0xA;
        let userB = @0xB;
        let scenario = test_scenario::begin(OWNER);
        let scenarioA = test_scenario::begin(userA); // only deposit
        let scenarioB = test_scenario::begin(userB);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
            base::initial_test_coin(&mut scenario, &_clock);
        };

        // userA deposit 1000k usdt
        test_scenario::next_tx(&mut scenarioA, userA);
        {
            let usdt_pool = test_scenario::take_shared<Pool<USDT_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            let coin = coin::mint_for_testing<USDT_TEST>(1000000_000000, test_scenario::ctx(&mut scenarioA));

            base_lending_tests::base_deposit_for_testing(
                &mut scenarioA,
                &clock,
                &mut usdt_pool,
                coin,
                2,
                1000000_000000
            );

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(usdt_pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let test_pool = test_scenario::take_shared<Pool<TEST_COIN>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            let test_coin = coin::mint_for_testing<TEST_COIN>(1000_000000000, test_scenario::ctx(&mut scenarioB));

            base_lending_tests::base_deposit_for_testing(
                &mut scenarioB,
                &clock,
                &mut test_pool,
                test_coin,
                4,
                1000_000000000
            );

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(test_pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenarioB));
            clock::set_for_testing(&mut clock, 2000);

            let avg_ltv = logic::calculate_avg_ltv(&clock, &price_oracle, &mut storage, userB);
            let avg_threshold = logic::calculate_avg_threshold(&clock, &price_oracle, &mut storage, userB);
            assert!(avg_ltv == 0, 0); // No. 9
            assert!(avg_threshold == 0, 0); // No. 10

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(price_oracle);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenarioB));
            clock::set_for_testing(&mut clock, 2000);
            
            // expected error: expected_failure(abort_code = logic::LOGIC_LTV_NOT_SUFFICIENT)
            logic::execute_borrow_for_testing<USDT_TEST>(&clock, &price_oracle, &mut storage, 2, userB, 1_000000000); // No. 3

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(price_oracle);
        };

        test_scenario::end(scenario);
        test_scenario::end(scenarioA);
        test_scenario::end(scenarioB);
        clock::destroy_for_testing(_clock);
    }

    #[test]
    #[allow(unused_assignment)]
    #[expected_failure(abort_code = 1600, location = lending_core::logic)]
    public fun test_add_ltv_to_borrow_health_factor_multiple_assets() {
        let userA = @0xA;
        let userB = @0xB;
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
            base::initial_test_coin(&mut scenario, &_clock);
        };

        // userA deposit 1000k usdt
        test_scenario::next_tx(&mut scenario, userA);
        {
            let usdt_pool = test_scenario::take_shared<Pool<USDT_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

            let usdt_coin = coin::mint_for_testing<USDT_TEST>(1000000_000000, test_scenario::ctx(&mut scenario));
            base_lending_tests::base_deposit_for_testing(&mut scenario, &clock, &mut usdt_pool, usdt_coin, 2, 1000000_000000);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(usdt_pool);
        };

        test_scenario::next_tx(&mut scenario, userA);
        {
            let test_coin_pool = test_scenario::take_shared<Pool<TEST_COIN>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

            let test_coin = coin::mint_for_testing<TEST_COIN>(1000000_0000, test_scenario::ctx(&mut scenario));
            base_lending_tests::base_deposit_for_testing(
                &mut scenario,
                &clock,
                &mut test_coin_pool,
                test_coin,
                4,
                1000000_0000
            );

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(test_coin_pool);
        };

        test_scenario::next_tx(&mut scenario, userB);
        {
            let eth_pool = test_scenario::take_shared<Pool<ETH_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

            let eth_coin = coin::mint_for_testing<ETH_TEST>(1_000000000, test_scenario::ctx(&mut scenario));
            base_lending_tests::base_deposit_for_testing(
                &mut scenario,
                &clock,
                &mut eth_pool,
                eth_coin,
                3,
                1_000000000
            );

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(eth_pool);
        };

        test_scenario::next_tx(&mut scenario, userB);
        {
            let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

            let usdc_coin = coin::mint_for_testing<USDC_TEST>(1000_000000, test_scenario::ctx(&mut scenario));
            base_lending_tests::base_deposit_for_testing(
                &mut scenario,
                &clock,
                &mut usdc_pool,
                usdc_coin,
                1,
                1000_000000
            );

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(usdc_pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);

            let eth_ltv = storage::get_asset_ltv(&storage, 3);
            let (_, _, eth_threshold) = storage::get_liquidation_factors(&mut storage, 3);
            let eth_collateral_value = logic::user_collateral_value(&clock, &price_oracle, &mut storage, 3, userB);

            let usdc_ltv = storage::get_asset_ltv(&storage, 1);
            let (_, _, usdc_threshold) = storage::get_liquidation_factors(&mut storage, 1);
            let usdc_collateral_value = logic::user_collateral_value(&clock, &price_oracle, &mut storage, 1, userB);

            let expect_ltv = ray_math::ray_div(
                ray_math::ray_mul(eth_ltv, eth_collateral_value) + ray_math::ray_mul(usdc_ltv, usdc_collateral_value),
                eth_collateral_value + usdc_collateral_value
            );

            let expect_threshold = ray_math::ray_div(
                ray_math::ray_mul(eth_threshold, eth_collateral_value) + ray_math::ray_mul(usdc_threshold, usdc_collateral_value),
                eth_collateral_value + usdc_collateral_value
            );

            let avg_ltv = logic::calculate_avg_ltv(&clock, &price_oracle, &mut storage, userB);
            let avg_threshold = logic::calculate_avg_threshold(&clock, &price_oracle, &mut storage, userB);
            let health_factor_in_borrow = ray_math::ray_div(avg_threshold, avg_ltv);

            assert!(expect_ltv == avg_ltv, 0); // No. 11
            assert!(expect_threshold == avg_threshold, 0); // No. 12
            assert!(health_factor_in_borrow == ray_math::ray_div(expect_threshold, expect_ltv), 0); // No. 13

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(price_oracle);
        };

        test_scenario::next_tx(&mut scenario, userB);
        {
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            let sui_coin = coin::mint_for_testing<SUI_TEST>(10000_000000000, test_scenario::ctx(&mut scenario));
            base_lending_tests::base_deposit_for_testing(
                &mut scenario,
                &clock,
                &mut sui_pool,
                sui_coin,
                0,
                10000_000000000
            );

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(sui_pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

            let eth_ltv = storage::get_asset_ltv(&storage, 3);
            let (_, _, eth_threshold) = storage::get_liquidation_factors(&mut storage, 3);
            let eth_collateral_value = logic::user_collateral_value(&clock, &price_oracle, &mut storage, 3, userB);

            let sui_ltv = storage::get_asset_ltv(&storage, 0);
            let (_, _, sui_threshold) = storage::get_liquidation_factors(&mut storage, 0);
            let sui_collateral_value = logic::user_collateral_value(&clock, &price_oracle, &mut storage, 0, userB);

            let usdc_ltv = storage::get_asset_ltv(&storage, 1);
            let (_, _, usdc_threshold) = storage::get_liquidation_factors(&mut storage, 1);
            let usdc_collateral_value = logic::user_collateral_value(&clock, &price_oracle, &mut storage, 1, userB);

            let expect_ltv = ray_math::ray_div(
                ray_math::ray_mul(eth_ltv, eth_collateral_value) + ray_math::ray_mul(usdc_ltv, usdc_collateral_value) + ray_math::ray_mul(sui_ltv, sui_collateral_value),
                eth_collateral_value + usdc_collateral_value + sui_collateral_value
            );

            let expect_threshold = ray_math::ray_div(
                ray_math::ray_mul(eth_threshold, eth_collateral_value) + ray_math::ray_mul(usdc_threshold, usdc_collateral_value) + ray_math::ray_mul(sui_threshold, sui_collateral_value),
                eth_collateral_value + usdc_collateral_value + sui_collateral_value
            );

            let avg_ltv = logic::calculate_avg_ltv(&clock, &price_oracle, &mut storage, userB);
            let avg_threshold = logic::calculate_avg_threshold(&clock, &price_oracle, &mut storage, userB);

            assert!(expect_ltv == avg_ltv, 0); // No. 16
            assert!(expect_threshold == avg_threshold, 0); // No. 17
            clock::destroy_for_testing(clock);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(price_oracle);
        };

        let _max_borrow = 0;
        let _health_factor_in_borrow = 0;
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let storage = test_scenario::take_shared<Storage>(&scenario);

            let avg_ltv = logic::calculate_avg_ltv(&clock, &price_oracle, &mut storage, userB);
            let avg_threshold = logic::calculate_avg_threshold(&clock, &price_oracle, &mut storage, userB);
            _health_factor_in_borrow = ray_math::ray_div(avg_threshold, avg_ltv);

            let health_collateral_value = logic::user_health_collateral_value(&clock, &price_oracle, &mut storage, userB);
            let dynamic_liquidation_threshold = logic::dynamic_liquidation_threshold(&clock, &mut storage, &price_oracle, userB);
            _max_borrow = ray_math::ray_div(health_collateral_value, ray_math::ray_div(_health_factor_in_borrow, dynamic_liquidation_threshold));

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(price_oracle);
        };

        test_scenario::next_tx(&mut scenario, userB);
        {
            let usdt_pool = test_scenario::take_shared<Pool<USDT_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

            base_lending_tests::base_borrow_for_testing<USDT_TEST>(
                &mut scenario,
                &clock,
                &mut usdt_pool,
                2,
                (_max_borrow as u64) / 1000 - 1,
            ); // No. 14

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(usdt_pool);
        };

        test_scenario::next_tx(&mut scenario, userB);
        {
            let test_pool = test_scenario::take_shared<Pool<TEST_COIN>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

            base_lending_tests::base_borrow_for_testing<TEST_COIN>(
                &mut scenario,
                &clock,
                &mut test_pool,
                4,
                100_0000,
            ); // No. 18

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(test_pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);

            let user_health_factor = logic::user_health_factor(&clock, &mut storage, &price_oracle, userB);
            assert!(user_health_factor > _health_factor_in_borrow, 0);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(price_oracle);
        };

        test_scenario::next_tx(&mut scenario, userB);
        {
            let usdt_pool = test_scenario::take_shared<Pool<USDT_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            base_lending_tests::base_borrow_for_testing<USDT_TEST>(
                &mut scenario,
                &clock,
                &mut usdt_pool,
                2,
                1000000,
            ); // No. 15

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(usdt_pool);
        };

        test_scenario::end(scenario);
        clock::destroy_for_testing(_clock);
    }

    #[test]
    public fun test_add_ltv_to_borrow_health_factor_one_to_one() {
        let userA = @0xA;
        let userB = @0xB;
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };

        // userA deposit 1000k usdt
        test_scenario::next_tx(&mut scenario, userA);
        {
            let usdt_pool = test_scenario::take_shared<Pool<USDT_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            let coin = coin::mint_for_testing<USDT_TEST>(1000000_000000, test_scenario::ctx(&mut scenario));

            base_lending_tests::base_deposit_for_testing(
                &mut scenario,
                &clock,
                &mut usdt_pool,
                coin,
                2,
                1000000_000000
            );

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(usdt_pool);
        };

        test_scenario::next_tx(&mut scenario, userB);
        {
            let eth_pool = test_scenario::take_shared<Pool<ETH_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            let eth_coin = coin::mint_for_testing<ETH_TEST>(1_000000000, test_scenario::ctx(&mut scenario));

            base_lending_tests::base_deposit_for_testing(
                &mut scenario,
                &clock,
                &mut eth_pool,
                eth_coin,
                3,
                1_000000000
            );

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(eth_pool);
        };

        test_scenario::next_tx(&mut scenario, userB);
        {
            let usdt_pool = test_scenario::take_shared<Pool<USDT_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

            base_lending_tests::base_borrow_for_testing<USDT_TEST>(
                &mut scenario,
                &clock,
                &mut usdt_pool,
                2,
                10_000000,
            ); // No. 8

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(usdt_pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

            let user_collateral_value = logic::user_collateral_value(&clock, &price_oracle, &mut storage, 3, userB);
            let user_loan_value = logic::user_loan_value(&clock, &price_oracle, &mut storage, 2, userB);

            let (_, _, eth_threshold) = storage::get_liquidation_factors(&mut storage, 3);
            let expect_threshold = ray_math::ray_div(
                ray_math::ray_mul(eth_threshold, user_collateral_value),
                user_collateral_value
            );
            let expect_health_factor = ray_math::ray_mul(
                ray_math::ray_div(user_collateral_value, user_loan_value),
                expect_threshold
            );
            let user_health_factor = logic::user_health_factor(&clock, &mut storage, &price_oracle, userB);

            assert!(expect_health_factor == user_health_factor, 0); // No.19

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(price_oracle);
        };

        test_scenario::end(scenario);
        clock::destroy_for_testing(_clock);
    }

    #[test]
    public fun test_deposit_on_behalf_of_should_success() {
        let scenario = test_scenario::begin(OWNER);
        let user_a_scenario = test_scenario::begin(UserA);
        let user_b_scenario = test_scenario::begin(UserB);
        let test_clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        clock::set_for_testing(&mut test_clock, 1704038400000);
        test_scenario::ctx(&mut scenario);
        {
            base::initial_protocol(&mut scenario, &test_clock);
        };


        { // UserA and UserB Perform Supply And Borrow Operations
            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                // UserA Supply 1000000 USDC
                clock::increment_for_testing(&mut test_clock, 60 * 1000); // 1 minute, 1 minute After Initial Time
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);

                let coin = coin::mint_for_testing<USDC_TEST>(1000000_000000, test_scenario::ctx(&mut user_a_scenario));
                base_lending_tests::base_deposit_for_testing(&mut user_a_scenario, &test_clock, &mut usdc_pool, coin, 1, 1000000_000000);

                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut user_b_scenario, UserB);
            {
                // UserB Supply 10000 SUI
                clock::increment_for_testing(&mut test_clock, 60 * 1000); // 1 minute, 2 minute After Initial Time
                let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&user_b_scenario);

                let coin = coin::mint_for_testing<SUI_TEST>(10000_000000000, test_scenario::ctx(&mut user_b_scenario));
                base_lending_tests::base_deposit_for_testing(&mut user_b_scenario, &test_clock, &mut sui_pool, coin, 0, 10000_000000000);

                test_scenario::return_shared(sui_pool);
            };
        };

        {
            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                let storage = test_scenario::take_shared<Storage>(&user_a_scenario);
                let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);

                let (user_a_usdc_supply, user_a_usdc_borrow) = storage::get_user_balance(&mut storage, 1, UserA);
                assert!(user_a_usdc_supply == 1000000_000000000, 0);
                assert!(user_a_usdc_borrow == 0, 0);

                let (user_b_sui_supply, user_b_sui_borrow) = storage::get_user_balance(&mut storage, 0, UserB);
                assert!(user_b_sui_supply == 10000_000000000, 0);
                assert!(user_b_sui_borrow == 0, 0);


                let (usdc_balance, _, _) = pool::get_pool_info(&usdc_pool);
                let (sui_balance, _, _) = pool::get_pool_info(&sui_pool);
                assert!(usdc_balance == 1000000_000000, 0);
                assert!(sui_balance == 10000_000000000, 0);

                test_scenario::return_shared(storage);
                test_scenario::return_shared(sui_pool);
                test_scenario::return_shared(usdc_pool);
            };
        };

        {
            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);

                let usdc_coin = coin::mint_for_testing<USDC_TEST>(100_000000, test_scenario::ctx(&mut scenario));
                base_lending_tests::base_deposit_on_behalf_of_user_for_testing<USDC_TEST>(&mut scenario, &test_clock, &mut usdc_pool, usdc_coin, 1, UserA, 100_000000);

                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

                let sui_coin = coin::mint_for_testing<SUI_TEST>(100_000000000, test_scenario::ctx(&mut scenario));
                base_lending_tests::base_deposit_on_behalf_of_user_for_testing<SUI_TEST>(&mut scenario, &test_clock, &mut sui_pool, sui_coin, 0, UserB, 100_000000000);

                test_scenario::return_shared(sui_pool);
            };
        };

        {
            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                let storage = test_scenario::take_shared<Storage>(&user_a_scenario);
                let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);

                let (user_a_usdc_supply, user_a_usdc_borrow) = storage::get_user_balance(&mut storage, 1, UserA);
                assert!(user_a_usdc_supply == 1000100_000000000, 0);
                assert!(user_a_usdc_borrow == 0, 0);

                let (user_b_sui_supply, user_b_sui_borrow) = storage::get_user_balance(&mut storage, 0, UserB);
                assert!(user_b_sui_supply == 10100_000000000, 0);
                assert!(user_b_sui_borrow == 0, 0);

                let (usdc_balance, _, _) = pool::get_pool_info(&usdc_pool);
                let (sui_balance, _, _) = pool::get_pool_info(&sui_pool);
                assert!(usdc_balance == 1000100_000000, 0);
                assert!(sui_balance == 10100_000000000, 0);

                test_scenario::return_shared(storage);
                test_scenario::return_shared(sui_pool);
                test_scenario::return_shared(usdc_pool);
            };
        };

        test_scenario::end(scenario);
        test_scenario::end(user_a_scenario);
        test_scenario::end(user_b_scenario);
        clock::destroy_for_testing(test_clock);
    }

    #[test]
    public fun test_repay_on_behalf_of_should_success() {
        let scenario = test_scenario::begin(OWNER);
        let test_clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        clock::set_for_testing(&mut test_clock, 1704038400000);
        test_scenario::ctx(&mut scenario);
        {
            base::initial_protocol(&mut scenario, &test_clock);
        };


        { // UserA and UserB Perform Supply And Borrow Operations
            test_scenario::next_tx(&mut scenario, UserA);
            {
                // UserA Supply 1000000 USDC
                clock::increment_for_testing(&mut test_clock, 60 * 1000); // 1 minute, 1 minute After Initial Time
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);

                let coin = coin::mint_for_testing<USDC_TEST>(1000000_000000, test_scenario::ctx(&mut scenario));
                base_lending_tests::base_deposit_for_testing(&mut scenario, &test_clock, &mut usdc_pool, coin, 1, 1000000_000000);

                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut scenario, UserB);
            {
                // UserB Supply 10000 SUI
                clock::increment_for_testing(&mut test_clock, 60 * 1000); // 1 minute, 2 minute After Initial Time
                let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

                let coin = coin::mint_for_testing<SUI_TEST>(10000_000000000, test_scenario::ctx(&mut scenario));
                base_lending_tests::base_deposit_for_testing(&mut scenario, &test_clock, &mut sui_pool, coin, 0, 10000_000000000);

                test_scenario::return_shared(sui_pool);
            };

            test_scenario::next_tx(&mut scenario, UserB);
            {
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);
                base_lending_tests::base_borrow_for_testing(&mut scenario, &test_clock, &mut usdc_pool, 1, 1000_000000);
                test_scenario::return_shared(usdc_pool);
            };
        };

        {
            test_scenario::next_tx(&mut scenario, UserA);
            {
                let storage = test_scenario::take_shared<Storage>(&scenario);
                let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);

                let (user_a_usdc_supply, user_a_usdc_borrow) = storage::get_user_balance(&mut storage, 1, UserA);
                assert!(user_a_usdc_supply == 1000000_000000000, 0);
                assert!(user_a_usdc_borrow == 0, 0);

                let (user_b_sui_supply, user_b_sui_borrow) = storage::get_user_balance(&mut storage, 0, UserB);
                assert!(user_b_sui_supply == 10000_000000000, 0);
                assert!(user_b_sui_borrow == 0, 0);

                let (user_b_usdc_supply, user_b_usdc_borrow) = storage::get_user_balance(&mut storage, 1, UserB);
                assert!(user_b_usdc_supply == 0, 0);
                assert!(user_b_usdc_borrow == 1000_000000000, 0);


                let (usdc_balance, _, _) = pool::get_pool_info(&usdc_pool);
                let (sui_balance, _, _) = pool::get_pool_info(&sui_pool);
                assert!(usdc_balance == 1000000_000000 - 1000_000000, 0);
                assert!(sui_balance == 10000_000000000, 0);

                test_scenario::return_shared(storage);
                test_scenario::return_shared(sui_pool);
                test_scenario::return_shared(usdc_pool);
            };
        };

        {
            test_scenario::next_tx(&mut scenario, UserA);
            {
                let owner_cap = test_scenario::take_from_sender<StorageOwnerCap>(&scenario);
                let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

                let sui_coin = coin::mint_for_testing<SUI_TEST>(100_000000000, test_scenario::ctx(&mut scenario));
                base_lending_tests::base_deposit_on_behalf_of_user_for_testing<SUI_TEST>(&mut scenario, &test_clock, &mut sui_pool, sui_coin, 0, UserB, 100_000000000);

                test_scenario::return_to_sender(&scenario, owner_cap);
                test_scenario::return_shared(sui_pool);
            };

            test_scenario::next_tx(&mut scenario, UserB);
            {
                // let owner_cap = test_scenario::take_from_sender<StorageOwnerCap>(&scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);

                let usdc_coin = coin::mint_for_testing<USDC_TEST>(500_000000, test_scenario::ctx(&mut scenario));
                base_lending_tests::base_repay_on_behalf_of_user_for_testing<USDC_TEST>(&mut scenario, &test_clock, &mut usdc_pool, usdc_coin, 01, UserB, 500_000000);

                // test_scenario::return_to_sender(&scenario, owner_cap);
                test_scenario::return_shared(usdc_pool);
            };
        };

        {
            test_scenario::next_tx(&mut scenario, UserA);
            {
                let storage = test_scenario::take_shared<Storage>(&scenario);
                let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);

                let (user_a_usdc_supply, user_a_usdc_borrow) = storage::get_user_balance(&mut storage, 1, UserA);
                assert!(user_a_usdc_supply == 1000000_000000000, 0);
                assert!(user_a_usdc_borrow == 0, 0);

                let (user_b_sui_supply, user_b_sui_borrow) = storage::get_user_balance(&mut storage, 0, UserB);
                assert!(user_b_sui_supply == 10000_000000000 + 100_000000000, 0);
                assert!(user_b_sui_borrow == 0, 0);

                let (user_b_usdc_supply, user_b_usdc_borrow) = storage::get_user_balance(&mut storage, 1, UserB);
                assert!(user_b_usdc_supply == 0, 0);
                assert!(user_b_usdc_borrow == 1000_000000000 - 500_000000000, 0);


                let (usdc_balance, _, _) = pool::get_pool_info(&usdc_pool);
                let (sui_balance, _, _) = pool::get_pool_info(&sui_pool);
                assert!(usdc_balance == 1000000_000000 - 1000_000000 + 500_000000, 0);
                assert!(sui_balance == 10000_000000000 + 100_000000000, 0);

                test_scenario::return_shared(storage);
                test_scenario::return_shared(sui_pool);
                test_scenario::return_shared(usdc_pool);
            };
        };

        test_scenario::end(scenario);
        clock::destroy_for_testing(test_clock);
    }

    #[test]
    #[expected_failure(abort_code = 46000, location=lending_core::utils)]
    public fun test_deposit_on_behalf_of_user_should_successfully_deposit_more_than_zero() {
        let scenario = test_scenario::begin(OWNER);
        let user_a_scenario = test_scenario::begin(UserA);
        let test_clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        clock::set_for_testing(&mut test_clock, 1704038400000);
        test_scenario::ctx(&mut scenario);
        {
            base::initial_protocol(&mut scenario, &test_clock);
        };

        {
            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                // UserA Supply 100 USDC
                clock::increment_for_testing(&mut test_clock, 60 * 1000);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);

                let coin = coin::mint_for_testing<USDC_TEST>(100_000000, test_scenario::ctx(&mut user_a_scenario));
                base_lending_tests::base_deposit_for_testing(&mut user_a_scenario, &test_clock, &mut usdc_pool, coin, 1, 100_000000);

                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                let storage = test_scenario::take_shared<Storage>(&user_a_scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);
                
                let (supply_balance, borrow_balance) = storage::get_user_balance(&mut storage, 1, UserA);
                assert!(supply_balance == 100_000000_000, 0);
                assert!(borrow_balance == 0, 0);

                let (balance, _, _) = pool::get_pool_info(&usdc_pool);
                assert!(balance == 100_000000, 0);

                test_scenario::return_shared(storage);
                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut scenario, OWNER);
            {
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);
                let usdc_coin = coin::zero<USDC_TEST>(test_scenario::ctx(&mut scenario));
                let usdc_value = coin::value(&usdc_coin);
                base_lending_tests::base_deposit_on_behalf_of_user_for_testing<USDC_TEST>(&mut scenario, &test_clock, &mut usdc_pool, usdc_coin, 1, UserA, usdc_value);

                test_scenario::return_shared(usdc_pool);
            };
        };

        test_scenario::end(scenario);
        test_scenario::end(user_a_scenario);
        clock::destroy_for_testing(test_clock);
    }

    #[test]
    #[expected_failure(abort_code = 46000, location=lending_core::utils)]
    public fun test_repay_on_behalf_of_user_should_successfully_repay_more_than_zero() {
        let scenario = test_scenario::begin(OWNER);
        let user_a_scenario = test_scenario::begin(UserA);
        let test_clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        clock::set_for_testing(&mut test_clock, 1704038400000);
        test_scenario::ctx(&mut scenario);
        {
            base::initial_protocol(&mut scenario, &test_clock);
        };

        {
            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                // UserA Supply 100 USDC
                clock::increment_for_testing(&mut test_clock, 60 * 1000);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);

                let coin = coin::mint_for_testing<USDC_TEST>(100_000000, test_scenario::ctx(&mut user_a_scenario));
                base_lending_tests::base_deposit_for_testing(&mut user_a_scenario, &test_clock, &mut usdc_pool, coin, 1, 100_000000);

                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);
                base_lending_tests::base_borrow_for_testing(&mut user_a_scenario, &test_clock, &mut usdc_pool, 1, 1_000000);
                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                let storage = test_scenario::take_shared<Storage>(&user_a_scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);
                
                let (supply_balance, borrow_balance) = storage::get_user_balance(&mut storage, 1, UserA);
                assert!(supply_balance == 100_000000_000, 0);
                assert!(borrow_balance == 1_000000_000, 0);

                let (balance, _, _) = pool::get_pool_info(&usdc_pool);
                assert!(balance == 100_000000 - 1_000000, 0);

                test_scenario::return_shared(storage);
                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut scenario, OWNER);
            {
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);
                let usdc_coin = coin::zero<USDC_TEST>(test_scenario::ctx(&mut scenario));
                let usdc_value = coin::value(&usdc_coin);
                base_lending_tests::base_repay_on_behalf_of_user_for_testing<USDC_TEST>(&mut scenario, &test_clock, &mut usdc_pool, usdc_coin, 1, UserA, usdc_value);

                test_scenario::return_shared(usdc_pool);
            };
        };

        test_scenario::end(scenario);
        test_scenario::end(user_a_scenario);
        clock::destroy_for_testing(test_clock);
    }

    #[test]
    public fun test_deposit_on_behalf_of_user_should_successfully_withdraw_from_user() {
        let scenario = test_scenario::begin(OWNER);
        let user_a_scenario = test_scenario::begin(UserA);
        let test_clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        clock::set_for_testing(&mut test_clock, 1704038400000);
        test_scenario::ctx(&mut scenario);
        {
            base::initial_protocol(&mut scenario, &test_clock);
        };

        {
            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                // UserA Supply 100 USDC
                clock::increment_for_testing(&mut test_clock, 60 * 1000);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);

                let coin = coin::mint_for_testing<USDC_TEST>(100_000000, test_scenario::ctx(&mut user_a_scenario));
                base_lending_tests::base_deposit_for_testing(&mut user_a_scenario, &test_clock, &mut usdc_pool, coin, 1, 100_000000);

                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                let storage = test_scenario::take_shared<Storage>(&user_a_scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);
                
                let (supply_balance, borrow_balance) = storage::get_user_balance(&mut storage, 1, UserA);
                assert!(supply_balance == 100_000000_000, 0);
                assert!(borrow_balance == 0, 0);

                let (balance, _, _) = pool::get_pool_info(&usdc_pool);
                assert!(balance == 100_000000, 0);

                test_scenario::return_shared(storage);
                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut scenario, OWNER);
            {
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);
                let usdc_coin = coin::mint_for_testing<USDC_TEST>(100_000000, test_scenario::ctx(&mut scenario));
                let usdc_value = coin::value(&usdc_coin);
                base_lending_tests::base_deposit_on_behalf_of_user_for_testing<USDC_TEST>(&mut scenario, &test_clock, &mut usdc_pool, usdc_coin, 1, UserA, usdc_value);

                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                let storage = test_scenario::take_shared<Storage>(&user_a_scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);
                
                let (supply_balance, borrow_balance) = storage::get_user_balance(&mut storage, 1, UserA);
                assert!(supply_balance == 200_000000_000, 0);
                assert!(borrow_balance == 0, 0);

                let (balance, _, _) = pool::get_pool_info(&usdc_pool);
                assert!(balance == 200_000000, 0);

                test_scenario::return_shared(storage);
                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                let pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);
                base_lending_tests::base_withdraw_for_testing(&mut user_a_scenario, &test_clock, &mut pool, 1, 200_000000);

                test_scenario::return_shared(pool);
            };

            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                let storage = test_scenario::take_shared<Storage>(&user_a_scenario);
                let pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);
                let (total_supply, _, _) = pool::get_pool_info<USDC_TEST>(&pool);
                assert!(total_supply == 0, 0);

                let (supply_balance, borrow_balance) = storage::get_user_balance(&mut storage, 1, UserA);
                assert!(supply_balance == 0, 0);
                assert!(borrow_balance == 0, 0);

                test_scenario::return_shared(pool);
                test_scenario::return_shared(storage);
            };
        };

        test_scenario::end(scenario);
        test_scenario::end(user_a_scenario);
        clock::destroy_for_testing(test_clock);
    }

    #[test]
    public fun test_deposit_on_behalf_of_user_should_successfully_deposit_large_amount() {
        let scenario = test_scenario::begin(OWNER);
        let user_a_scenario = test_scenario::begin(UserA);
        let test_clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        clock::set_for_testing(&mut test_clock, 1704038400000);
        test_scenario::ctx(&mut scenario);
        {
            base::initial_protocol(&mut scenario, &test_clock);
        };

        {
            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                // UserA Supply 100 USDC
                clock::increment_for_testing(&mut test_clock, 60 * 1000);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);

                let coin = coin::mint_for_testing<USDC_TEST>(100_000000, test_scenario::ctx(&mut user_a_scenario));
                base_lending_tests::base_deposit_for_testing(&mut user_a_scenario, &test_clock, &mut usdc_pool, coin, 1, 100_000000);

                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                let storage = test_scenario::take_shared<Storage>(&user_a_scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);
                
                let (supply_balance, borrow_balance) = storage::get_user_balance(&mut storage, 1, UserA);
                assert!(supply_balance == 100_000000_000, 0);
                assert!(borrow_balance == 0, 0);

                let (balance, _, _) = pool::get_pool_info(&usdc_pool);
                assert!(balance == 100_000000, 0);

                test_scenario::return_shared(storage);
                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut scenario, OWNER);
            {
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);
                let usdc_coin = coin::mint_for_testing<USDC_TEST>(10000000_000000, test_scenario::ctx(&mut scenario));
                let usdc_value = coin::value(&usdc_coin);
                base_lending_tests::base_deposit_on_behalf_of_user_for_testing<USDC_TEST>(&mut scenario, &test_clock, &mut usdc_pool, usdc_coin, 1, UserA, usdc_value);

                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                let storage = test_scenario::take_shared<Storage>(&user_a_scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);
                
                let (supply_balance, borrow_balance) = storage::get_user_balance(&mut storage, 1, UserA);
                assert!(supply_balance == 100_000000_000 + 10000000_000000_000, 0);
                assert!(borrow_balance == 0, 0);

                let (balance, _, _) = pool::get_pool_info(&usdc_pool);
                assert!(balance == 100_000000 + 10000000_000000, 0);

                test_scenario::return_shared(storage);
                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                let pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);
                base_lending_tests::base_withdraw_for_testing(&mut user_a_scenario, &test_clock, &mut pool, 1, 100_000000 + 10000000_000000);

                test_scenario::return_shared(pool);
            };

            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                let storage = test_scenario::take_shared<Storage>(&user_a_scenario);
                let pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);
                let (total_supply, _, _) = pool::get_pool_info<USDC_TEST>(&pool);
                assert!(total_supply == 0, 0);

                let (supply_balance, borrow_balance) = storage::get_user_balance(&mut storage, 1, UserA);
                assert!(supply_balance == 0, 0);
                assert!(borrow_balance == 0, 0);

                test_scenario::return_shared(pool);
                test_scenario::return_shared(storage);
            };
        };

        test_scenario::end(scenario);
        test_scenario::end(user_a_scenario);
        clock::destroy_for_testing(test_clock);
    }

    #[test]
    public fun test_repay_on_behalf_of_user_should_successfully_repay_large_amount() {
        let scenario = test_scenario::begin(OWNER);
        let user_a_scenario = test_scenario::begin(UserA);
        let test_clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        clock::set_for_testing(&mut test_clock, 1704038400000);
        test_scenario::ctx(&mut scenario);
        {
            base::initial_protocol(&mut scenario, &test_clock);
        };

        {
            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                // UserA Supply 10000000 USDC
                clock::increment_for_testing(&mut test_clock, 60 * 1000);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);

                let coin = coin::mint_for_testing<USDC_TEST>(10000000_000000, test_scenario::ctx(&mut user_a_scenario));
                let coin_value = coin::value(&coin);
                base_lending_tests::base_deposit_for_testing(&mut user_a_scenario, &test_clock, &mut usdc_pool, coin, 1, coin_value);

                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);
                base_lending_tests::base_borrow_for_testing(&mut user_a_scenario, &test_clock, &mut usdc_pool, 1, 5000000_000000);
                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                let storage = test_scenario::take_shared<Storage>(&user_a_scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);
                
                let (supply_balance, borrow_balance) = storage::get_user_balance(&mut storage, 1, UserA);
                assert!(supply_balance == 10000000_000000_000, 0);
                assert!(borrow_balance == 5000000_000000_000, 0);

                let (balance, _, _) = pool::get_pool_info(&usdc_pool);
                assert!(balance == 5000000_000000, 0);

                test_scenario::return_shared(storage);
                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut scenario, OWNER);
            {
                let owner_cap = test_scenario::take_from_sender<StorageOwnerCap>(&scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);

                let usdc_coin = coin::mint_for_testing<USDC_TEST>(1000000_000000, test_scenario::ctx(&mut scenario));
                let usdc_value = coin::value(&usdc_coin);
                base_lending_tests::base_repay_on_behalf_of_user_for_testing<USDC_TEST>(&mut scenario, &test_clock, &mut usdc_pool, usdc_coin, 01, UserA, usdc_value);

                test_scenario::return_to_sender(&scenario, owner_cap);
                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                let storage = test_scenario::take_shared<Storage>(&user_a_scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);
                
                let (supply_balance, borrow_balance) = storage::get_user_balance(&mut storage, 1, UserA);
                assert!(supply_balance == 10000000_000000_000, 0);
                assert!(borrow_balance == 4000000_000000_000, 0);

                let (balance, _, _) = pool::get_pool_info(&usdc_pool);
                assert!(balance == 6000000_000000, 0);

                test_scenario::return_shared(storage);
                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut scenario, OWNER);
            {
                let owner_cap = test_scenario::take_from_sender<StorageOwnerCap>(&scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);

                let usdc_coin = coin::mint_for_testing<USDC_TEST>(3000000_000000, test_scenario::ctx(&mut scenario));
                let usdc_value = coin::value(&usdc_coin);
                base_lending_tests::base_repay_on_behalf_of_user_for_testing<USDC_TEST>(&mut scenario, &test_clock, &mut usdc_pool, usdc_coin, 01, UserA, usdc_value);

                test_scenario::return_to_sender(&scenario, owner_cap);
                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                let storage = test_scenario::take_shared<Storage>(&user_a_scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);
                
                let (supply_balance, borrow_balance) = storage::get_user_balance(&mut storage, 1, UserA);
                assert!(supply_balance == 10000000_000000_000, 0);
                assert!(borrow_balance == 1000000_000000_000, 0);

                let (balance, _, _) = pool::get_pool_info(&usdc_pool);
                assert!(balance == 9000000_000000, 0);

                test_scenario::return_shared(storage);
                test_scenario::return_shared(usdc_pool);
            };
        };

        test_scenario::end(scenario);
        test_scenario::end(user_a_scenario);
        clock::destroy_for_testing(test_clock);
    }

    #[test]
    #[expected_failure(abort_code = 1602, location=lending_core::logic)]
    public fun test_repay_on_behalf_of_user_should_failed_to_repay_if_no_loan() {
        let scenario = test_scenario::begin(OWNER);
        let user_a_scenario = test_scenario::begin(UserA);
        let test_clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        clock::set_for_testing(&mut test_clock, 1704038400000);
        test_scenario::ctx(&mut scenario);
        {
            base::initial_protocol(&mut scenario, &test_clock);
        };

        {
            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                // UserA Supply 10000000 USDC
                clock::increment_for_testing(&mut test_clock, 60 * 1000);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);

                let coin = coin::mint_for_testing<USDC_TEST>(10_000000, test_scenario::ctx(&mut user_a_scenario));
                let coin_value = coin::value(&coin);
                base_lending_tests::base_deposit_for_testing(&mut user_a_scenario, &test_clock, &mut usdc_pool, coin, 1, coin_value);

                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                let storage = test_scenario::take_shared<Storage>(&user_a_scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);
                
                let (supply_balance, borrow_balance) = storage::get_user_balance(&mut storage, 1, UserA);
                assert!(supply_balance == 10_000000_000, 0);
                assert!(borrow_balance == 0, 0);

                let (balance, _, _) = pool::get_pool_info(&usdc_pool);
                assert!(balance == 10_000000, 0);

                test_scenario::return_shared(storage);
                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut scenario, OWNER);
            {
                let owner_cap = test_scenario::take_from_sender<StorageOwnerCap>(&scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);

                let usdc_coin = coin::mint_for_testing<USDC_TEST>(1_000000, test_scenario::ctx(&mut scenario));
                let usdc_value = coin::value(&usdc_coin);
                base_lending_tests::base_repay_on_behalf_of_user_for_testing<USDC_TEST>(&mut scenario, &test_clock, &mut usdc_pool, usdc_coin, 01, UserA, usdc_value);

                test_scenario::return_to_sender(&scenario, owner_cap);
                test_scenario::return_shared(usdc_pool);
            };
        };

        test_scenario::end(scenario);
        test_scenario::end(user_a_scenario);
        clock::destroy_for_testing(test_clock);
    }

    #[test]
    public fun test_repay_on_behalf_of_user_should_successfully_repay_all_debt_if_a_large_amount() {
        let scenario = test_scenario::begin(OWNER);
        let user_a_scenario = test_scenario::begin(UserA);
        let test_clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        clock::set_for_testing(&mut test_clock, 1704038400000);
        test_scenario::ctx(&mut scenario);
        {
            base::initial_protocol(&mut scenario, &test_clock);
        };

        {
            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                // UserA Supply 10000000 USDC
                clock::increment_for_testing(&mut test_clock, 60 * 1000);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);

                let coin = coin::mint_for_testing<USDC_TEST>(10_000000, test_scenario::ctx(&mut user_a_scenario));
                let coin_value = coin::value(&coin);
                base_lending_tests::base_deposit_for_testing(&mut user_a_scenario, &test_clock, &mut usdc_pool, coin, 1, coin_value);

                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);
                base_lending_tests::base_borrow_for_testing(&mut user_a_scenario, &test_clock, &mut usdc_pool, 1, 5_000000);
                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                let storage = test_scenario::take_shared<Storage>(&user_a_scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);
                
                let (supply_balance, borrow_balance) = storage::get_user_balance(&mut storage, 1, UserA);
                assert!(supply_balance == 10_000000_000, 0);
                assert!(borrow_balance == 5_000000_000, 0);

                let (balance, _, _) = pool::get_pool_info(&usdc_pool);
                assert!(balance == 5_000000, 0);

                test_scenario::return_shared(storage);
                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut scenario, OWNER);
            {
                let owner_cap = test_scenario::take_from_sender<StorageOwnerCap>(&scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);

                let usdc_coin = coin::mint_for_testing<USDC_TEST>(10000_000000, test_scenario::ctx(&mut scenario));
                let usdc_value = coin::value(&usdc_coin);
                base_lending_tests::base_repay_on_behalf_of_user_for_testing<USDC_TEST>(&mut scenario, &test_clock, &mut usdc_pool, usdc_coin, 1, UserA, usdc_value);

                test_scenario::return_to_sender(&scenario, owner_cap);
                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                let storage = test_scenario::take_shared<Storage>(&user_a_scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);
                
                let (supply_balance, borrow_balance) = storage::get_user_balance(&mut storage, 1, UserA);
                assert!(supply_balance == 10_000000_000, 0);
                assert!(borrow_balance == 0, 0);

                let (balance, _, _) = pool::get_pool_info(&usdc_pool);
                assert!(balance == 10_000000, 0);

                test_scenario::return_shared(storage);
                test_scenario::return_shared(usdc_pool);
            };
        };

        test_scenario::end(scenario);
        test_scenario::end(user_a_scenario);
        clock::destroy_for_testing(test_clock);
    }

    #[test]
    public fun test_deposit_on_behalf_of_user_should_successfully_deposit_if_user_no_deposit() {
        let scenario = test_scenario::begin(OWNER);
        let user_a_scenario = test_scenario::begin(UserA);
        let test_clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        clock::set_for_testing(&mut test_clock, 1704038400000);
        test_scenario::ctx(&mut scenario);
        {
            base::initial_protocol(&mut scenario, &test_clock);
        };

        {
            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                // UserA Supply 10000000 USDC
                clock::increment_for_testing(&mut test_clock, 60 * 1000);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);

                let coin = coin::mint_for_testing<USDC_TEST>(10_000000, test_scenario::ctx(&mut user_a_scenario));
                let coin_value = coin::value(&coin);
                base_lending_tests::base_deposit_for_testing(&mut user_a_scenario, &test_clock, &mut usdc_pool, coin, 1, coin_value);

                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                let storage = test_scenario::take_shared<Storage>(&user_a_scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);
                
                let (supply_balance, borrow_balance) = storage::get_user_balance(&mut storage, 1, UserA);
                assert!(supply_balance == 10_000000_000, 0);
                assert!(borrow_balance == 0, 0);

                let (balance, _, _) = pool::get_pool_info(&usdc_pool);
                assert!(balance == 10_000000, 0);

                test_scenario::return_shared(storage);
                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut scenario, OWNER);
            {
                let owner_cap = test_scenario::take_from_sender<StorageOwnerCap>(&scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);

                let usdc_coin = coin::mint_for_testing<USDC_TEST>(10000_000000, test_scenario::ctx(&mut scenario));
                let usdc_value = coin::value(&usdc_coin);
                base_lending_tests::base_deposit_on_behalf_of_user_for_testing<USDC_TEST>(&mut scenario, &test_clock, &mut usdc_pool, usdc_coin, 1, UserB, usdc_value);

                test_scenario::return_to_sender(&scenario, owner_cap);
                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                let storage = test_scenario::take_shared<Storage>(&user_a_scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);
                
                let (supply_balance, borrow_balance) = storage::get_user_balance(&mut storage, 1, UserA);
                assert!(supply_balance == 10_000000_000, 0);
                assert!(borrow_balance == 0, 0);

                let (user_b_supply_balance, user_b_borrow_balance) = storage::get_user_balance(&mut storage, 1, UserB);
                assert!(user_b_supply_balance == 10000_000000_000, 0);
                assert!(user_b_borrow_balance == 0, 0);

                let (balance, _, _) = pool::get_pool_info(&usdc_pool);
                assert!(balance == 10_000000 + 10000_000000, 0);

                test_scenario::return_shared(storage);
                test_scenario::return_shared(usdc_pool);
            };
        };

        test_scenario::end(scenario);
        test_scenario::end(user_a_scenario);
        clock::destroy_for_testing(test_clock);
    }

    #[test]
    public fun test_repay_on_behalf_of_self_should_success() {
        let scenario = test_scenario::begin(OWNER);
        let test_clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        clock::set_for_testing(&mut test_clock, 1704038400000);
        test_scenario::ctx(&mut scenario);
        {
            base::initial_protocol(&mut scenario, &test_clock);
        };


        { // UserA and UserB Perform Supply And Borrow Operations
            test_scenario::next_tx(&mut scenario, UserA);
            {
                // UserA Supply 1000000 USDC
                clock::increment_for_testing(&mut test_clock, 60 * 1000); // 1 minute, 1 minute After Initial Time
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);

                let coin = coin::mint_for_testing<USDC_TEST>(1000000_000000, test_scenario::ctx(&mut scenario));
                base_lending_tests::base_deposit_for_testing(&mut scenario, &test_clock, &mut usdc_pool, coin, 1, 1000000_000000);

                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut scenario, UserB);
            {
                // UserB Supply 10000 SUI
                clock::increment_for_testing(&mut test_clock, 60 * 1000); // 1 minute, 2 minute After Initial Time
                let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

                let coin = coin::mint_for_testing<SUI_TEST>(10000_000000000, test_scenario::ctx(&mut scenario));
                base_lending_tests::base_deposit_for_testing(&mut scenario, &test_clock, &mut sui_pool, coin, 0, 10000_000000000);

                test_scenario::return_shared(sui_pool);
            };

            test_scenario::next_tx(&mut scenario, UserB);
            {
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);
                base_lending_tests::base_borrow_for_testing(&mut scenario, &test_clock, &mut usdc_pool, 1, 1000_000000);
                test_scenario::return_shared(usdc_pool);
            };
        };

        {
            test_scenario::next_tx(&mut scenario, UserA);
            {
                let storage = test_scenario::take_shared<Storage>(&scenario);
                let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);

                let (user_a_usdc_supply, user_a_usdc_borrow) = storage::get_user_balance(&mut storage, 1, UserA);
                assert!(user_a_usdc_supply == 1000000_000000000, 0);
                assert!(user_a_usdc_borrow == 0, 0);

                let (user_b_sui_supply, user_b_sui_borrow) = storage::get_user_balance(&mut storage, 0, UserB);
                assert!(user_b_sui_supply == 10000_000000000, 0);
                assert!(user_b_sui_borrow == 0, 0);

                let (user_b_usdc_supply, user_b_usdc_borrow) = storage::get_user_balance(&mut storage, 1, UserB);
                assert!(user_b_usdc_supply == 0, 0);
                assert!(user_b_usdc_borrow == 1000_000000000, 0);


                let (usdc_balance, _, _) = pool::get_pool_info(&usdc_pool);
                let (sui_balance, _, _) = pool::get_pool_info(&sui_pool);
                assert!(usdc_balance == 1000000_000000 - 1000_000000, 0);
                assert!(sui_balance == 10000_000000000, 0);

                test_scenario::return_shared(storage);
                test_scenario::return_shared(sui_pool);
                test_scenario::return_shared(usdc_pool);
            };
        };



        {
            test_scenario::next_tx(&mut scenario, UserA);
            {
                let owner_cap = test_scenario::take_from_sender<StorageOwnerCap>(&scenario);
                let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

                let sui_coin = coin::mint_for_testing<SUI_TEST>(100_000000000, test_scenario::ctx(&mut scenario));
                base_lending_tests::base_deposit_on_behalf_of_user_for_testing<SUI_TEST>(&mut scenario, &test_clock, &mut sui_pool, sui_coin, 0, UserB, 100_000000000);

                test_scenario::return_to_sender(&scenario, owner_cap);
                test_scenario::return_shared(sui_pool);
            };

            test_scenario::next_tx(&mut scenario, UserB);
            {
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);

                let usdc_coin = coin::mint_for_testing<USDC_TEST>(500_000000, test_scenario::ctx(&mut scenario));
                base_lending_tests::base_repay_on_behalf_of_user_for_testing<USDC_TEST>(&mut scenario, &test_clock, &mut usdc_pool, usdc_coin, 01, UserB, 500_000000);

                test_scenario::return_shared(usdc_pool);
            };
        };

        
        test_scenario::next_tx(&mut scenario, UserA);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);

            let (user_a_usdc_supply, user_a_usdc_borrow) = storage::get_user_balance(&mut storage, 1, UserA);
            assert!(user_a_usdc_supply == 1000000_000000000, 0);
            assert!(user_a_usdc_borrow == 0, 0);

            let (user_b_sui_supply, user_b_sui_borrow) = storage::get_user_balance(&mut storage, 0, UserB);
            assert!(user_b_sui_supply == 10000_000000000 + 100_000000000, 0);
            assert!(user_b_sui_borrow == 0, 0);

            let (user_b_usdc_supply, user_b_usdc_borrow) = storage::get_user_balance(&mut storage, 1, UserB);
            assert!(user_b_usdc_supply == 0, 0);
            assert!(user_b_usdc_borrow == 1000_000000000 - 500_000000000, 0);


            let (usdc_balance, _, _) = pool::get_pool_info(&usdc_pool);
            let (sui_balance, _, _) = pool::get_pool_info(&sui_pool);
            assert!(usdc_balance == 1000000_000000 - 1000_000000 + 500_000000, 0);
            assert!(sui_balance == 10000_000000000 + 100_000000000, 0);

            test_scenario::return_shared(storage);
            test_scenario::return_shared(sui_pool);
            test_scenario::return_shared(usdc_pool);
        };
        

        test_scenario::end(scenario);
        clock::destroy_for_testing(test_clock);
    }

    #[test]
    public fun test_on_behalf_of_10_years() {
        let scenario = test_scenario::begin(OWNER);
        let test_clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        clock::set_for_testing(&mut test_clock, 1704038400000);
        test_scenario::ctx(&mut scenario);
        {
            base::initial_protocol(&mut scenario, &test_clock);
        };

        // deposit 100
        test_scenario::next_tx(&mut scenario, UserA);
        {
            let owner_cap = test_scenario::take_from_sender<StorageOwnerCap>(&scenario);
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

            let sui_coin = coin::mint_for_testing<SUI_TEST>(100_000000000, test_scenario::ctx(&mut scenario));
            base_lending_tests::base_deposit_on_behalf_of_user_for_testing<SUI_TEST>(&mut scenario, &test_clock, &mut sui_pool, sui_coin, 0, UserB, 100_000000000);

            test_scenario::return_to_sender(&scenario, owner_cap);
            test_scenario::return_shared(sui_pool);
        };

        // 10 year past, same price updated
        test_scenario::next_tx(&mut scenario, UserA);
        {
            //init
            let stg = test_scenario::take_shared<Storage>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let oracle_feeder_cap = test_scenario::take_from_sender<OracleFeederCap>(&scenario);

            clock::increment_for_testing(&mut test_clock, 86400 * 1000 * 365 * 10);
            oracle::update_token_price(
                &oracle_feeder_cap,
                &test_clock,
                &mut price_oracle,
                0,
                500000000,
            );

            test_scenario::return_shared(stg);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_to_sender(&scenario, oracle_feeder_cap);

        };

        // borrow 30
        test_scenario::next_tx(&mut scenario, UserB);
        {
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

            base_lending_tests::base_borrow_for_testing(&mut scenario, &test_clock, &mut sui_pool, 0, 30_000000000);

            test_scenario::return_shared(sui_pool);
        };

        // 1 year past, same price updated
        test_scenario::next_tx(&mut scenario, UserA);
        {
            //init
            let stg = test_scenario::take_shared<Storage>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let oracle_feeder_cap = test_scenario::take_from_sender<OracleFeederCap>(&scenario);

            clock::increment_for_testing(&mut test_clock, 86400 * 1000 * 365 * 1);
            oracle::update_token_price(
                &oracle_feeder_cap,
                &test_clock,
                &mut price_oracle,
                0,
                500000000,
            );

            test_scenario::return_shared(stg);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_to_sender(&scenario, oracle_feeder_cap);
        };


        // repay 30
        test_scenario::next_tx(&mut scenario, UserA);
        {
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

            let sui_coin = coin::mint_for_testing<SUI_TEST>(30_000000000, test_scenario::ctx(&mut scenario));
            base_lending_tests::base_repay_on_behalf_of_user_for_testing<SUI_TEST>(&mut scenario, &test_clock, &mut sui_pool, sui_coin, 0, UserB, 30_000000000);

            test_scenario::return_shared(sui_pool);
        };

        {
            test_scenario::next_tx(&mut scenario, UserA);
            {
                let storage = test_scenario::take_shared<Storage>(&scenario);
                let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

                let (user_b_sui_supply, user_b_sui_borrow) = storage::get_user_balance(&mut storage, 0, UserB);

                lib::print(&user_b_sui_supply);
                lib::print(&user_b_sui_borrow);
                assert!(user_b_sui_supply == 100_000000000, 0);
                assert!(user_b_sui_borrow == 1029118470, 0);

                let (sui_balance, _, _) = pool::get_pool_info(&sui_pool);
                assert!(sui_balance == 100_000000000, 0);
                lib::print(&sui_balance);

                test_scenario::return_shared(storage);
                test_scenario::return_shared(sui_pool);
            };
        };

        test_scenario::end(scenario);
        clock::destroy_for_testing(test_clock);
    }

    #[test]
    public fun test_normal_10_years() {
        let scenario = test_scenario::begin(OWNER);
        let test_clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        clock::set_for_testing(&mut test_clock, 1704038400000);
        test_scenario::ctx(&mut scenario);
        {
            base::initial_protocol(&mut scenario, &test_clock);
        };

        // deposit 100
        test_scenario::next_tx(&mut scenario, UserA);
        {
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

            let sui_coin = coin::mint_for_testing<SUI_TEST>(100_000000000, test_scenario::ctx(&mut scenario));
            let sui_value = coin::value(&sui_coin);
            base_lending_tests::base_deposit_for_testing<SUI_TEST>(&mut scenario, &test_clock, &mut sui_pool, sui_coin, 0, sui_value);

            test_scenario::return_shared(sui_pool);
        };

        // 10 year past, same price updated
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            //init
            let stg = test_scenario::take_shared<Storage>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let oracle_feeder_cap = test_scenario::take_from_sender<OracleFeederCap>(&scenario);

            clock::increment_for_testing(&mut test_clock, 86400 * 1000 * 365 * 10);
            oracle::update_token_price(
                &oracle_feeder_cap,
                &test_clock,
                &mut price_oracle,
                0,
                500000000,
            );

            test_scenario::return_shared(stg);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_to_sender(&scenario, oracle_feeder_cap);

        };

        // borrow 30
        test_scenario::next_tx(&mut scenario, UserA);
        {
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

            base_lending_tests::base_borrow_for_testing(&mut scenario, &test_clock, &mut sui_pool, 0, 30_000000000);

            test_scenario::return_shared(sui_pool);
        };

        // 1 year past, same price updated
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            //init
            let stg = test_scenario::take_shared<Storage>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let oracle_feeder_cap = test_scenario::take_from_sender<OracleFeederCap>(&scenario);

            clock::increment_for_testing(&mut test_clock, 86400 * 1000 * 365 * 1);
            oracle::update_token_price(
                &oracle_feeder_cap,
                &test_clock,
                &mut price_oracle,
                0,
                500000000,
            );

            test_scenario::return_shared(stg);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_to_sender(&scenario, oracle_feeder_cap);
        };


        // repay 30
        test_scenario::next_tx(&mut scenario, UserA);
        {
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

            let sui_coin = coin::mint_for_testing<SUI_TEST>(30_000000000, test_scenario::ctx(&mut scenario));
            let sui_value = coin::value(&sui_coin);
            base_lending_tests::base_repay_for_testing<SUI_TEST>(&mut scenario, &test_clock, &mut sui_pool, sui_coin, 0, sui_value);

            test_scenario::return_shared(sui_pool);
        };

        {
            test_scenario::next_tx(&mut scenario, UserA);
            {
                let storage = test_scenario::take_shared<Storage>(&scenario);
                let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

                let (user_a_sui_supply, user_a_sui_borrow) = storage::get_user_balance(&mut storage, 0, UserA);

                lib::print(&user_a_sui_supply);
                lib::print(&user_a_sui_borrow);
                assert!(user_a_sui_supply == 100_000000000, 0);
                assert!(user_a_sui_borrow == 1029118470, 0);

                let (sui_balance, _, _) = pool::get_pool_info(&sui_pool);
                assert!(sui_balance == 100_000000000, 0);
                lib::print(&sui_balance);

                test_scenario::return_shared(storage);
                test_scenario::return_shared(sui_pool);
            };
        };

        test_scenario::end(scenario);
        clock::destroy_for_testing(test_clock);
    }
}