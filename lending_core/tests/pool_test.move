#[test_only]
#[allow(unused_mut_ref)]
module lending_core::pool_test {
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::test_scenario::{Self};
    
    use lending_core::pool::{Self, Pool, PoolAdminCap};

    const OWNER: address = @0xA;

    #[test]
    public fun test_create_pool() {
        let scenario = test_scenario::begin(OWNER);
        {
            pool::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool_admin_cap = test_scenario::take_from_sender<PoolAdminCap>(&scenario);
            pool::create_pool_for_testing<SUI>(&pool_admin_cap, 9, test_scenario::ctx(&mut scenario));

            test_scenario::return_to_sender(&scenario, pool_admin_cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI>>(&scenario);
            let (balance_value, treasury_balance_value, decimal) = pool::get_pool_info(&pool);

            assert!(balance_value == 0, 0);
            assert!(treasury_balance_value == 0, 0);
            assert!(decimal == 9, 0);

            test_scenario::return_shared(pool);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_deposit() {
        let scenario = test_scenario::begin(OWNER);
        {
            pool::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool_admin_cap = test_scenario::take_from_sender<PoolAdminCap>(&scenario);
            pool::create_pool_for_testing<SUI>(&pool_admin_cap, 9, test_scenario::ctx(&mut scenario));

            test_scenario::return_to_sender(&scenario, pool_admin_cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI>>(&scenario);
            let (balance_value, treasury_balance_value, _) = pool::get_pool_info(&pool);
            assert!(balance_value == 0, 0);
            assert!(treasury_balance_value == 0, 0);

            let ctx = test_scenario::ctx(&mut scenario);
            let coin = coin::mint_for_testing<SUI>(100, ctx);
            pool::deposit_for_testing(&mut pool, coin, ctx);

            let (balance_value, _, _) = pool::get_pool_info(&pool);
            assert!(balance_value == 100, 0);
            test_scenario::return_shared(pool);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_withdraw() {
        let scenario = test_scenario::begin(OWNER);
        {
            pool::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool_admin_cap = test_scenario::take_from_sender<PoolAdminCap>(&scenario);
            pool::create_pool_for_testing<SUI>(&pool_admin_cap, 9, test_scenario::ctx(&mut scenario));

            test_scenario::return_to_sender(&scenario, pool_admin_cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI>>(&scenario);
            
            let ctx = test_scenario::ctx(&mut scenario);
            let coin = coin::mint_for_testing<SUI>(100, ctx);
            pool::deposit_for_testing(&mut pool, coin, ctx);

            let (balance_value, _, _) = pool::get_pool_info(&pool);
            assert!(balance_value == 100, 0);
            test_scenario::return_shared(pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI>>(&scenario);

            let ctx = test_scenario::ctx(&mut scenario);
            pool::withdraw_for_testing(&mut pool, 100, OWNER, ctx);

            let (balance_value, _, _) = pool::get_pool_info(&pool);
            assert!(balance_value == 0, 0);
            test_scenario::return_shared(pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            // check the owner's balance
            let c = test_scenario::take_from_sender<Coin<SUI>>(&scenario);
            assert!(coin::value(&c) == 100, 0);
            test_scenario::return_to_sender(&scenario, c);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_deposit_treasury() {
        let scenario = test_scenario::begin(OWNER);
        {
            pool::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool_admin_cap = test_scenario::take_from_sender<PoolAdminCap>(&scenario);
            pool::create_pool_for_testing<SUI>(&pool_admin_cap, 9, test_scenario::ctx(&mut scenario));

            test_scenario::return_to_sender(&scenario, pool_admin_cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI>>(&scenario);
            
            let ctx = test_scenario::ctx(&mut scenario);
            let coin = coin::mint_for_testing<SUI>(100, ctx);
            pool::deposit_for_testing(&mut pool, coin, ctx);
            let (balance_value, _, _) = pool::get_pool_info(&pool);
            assert!(balance_value == 100, 0);

            pool::deposit_treasury_for_testing(&mut pool, 100);
            let (balance_value, treasury_balance_value, _) = pool::get_pool_info(&pool);
            assert!(balance_value == 0, 0);
            assert!(treasury_balance_value == 100, 0);

            test_scenario::return_shared(pool);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_withdraw_treasury() {
        let scenario = test_scenario::begin(OWNER);
        {
            pool::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool_admin_cap = test_scenario::take_from_sender<PoolAdminCap>(&scenario);
            pool::create_pool_for_testing<SUI>(&pool_admin_cap, 9, test_scenario::ctx(&mut scenario));

            test_scenario::return_to_sender(&scenario, pool_admin_cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI>>(&scenario);
            
            let ctx = test_scenario::ctx(&mut scenario);
            let coin = coin::mint_for_testing<SUI>(100, ctx);
            pool::deposit_for_testing(&mut pool, coin, ctx);
            let (balance_value, _, _) = pool::get_pool_info(&pool);
            assert!(balance_value == 100, 0);

            pool::deposit_treasury_for_testing(&mut pool, 100);
            let (balance_value, treasury_balance_value, _) = pool::get_pool_info(&pool);
            assert!(balance_value == 0, 0);
            assert!(treasury_balance_value == 100, 0);

            test_scenario::return_shared(pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI>>(&scenario);
            let cap = test_scenario::take_from_sender<PoolAdminCap>(&scenario);

            pool::withdraw_treasury<SUI>(&mut cap, &mut pool, 100, OWNER, test_scenario::ctx(&mut scenario));
            let (_, treasury_balance_value, _) = pool::get_pool_info(&pool);
            assert!(treasury_balance_value == 0, 0);

            test_scenario::return_shared(pool);
            test_scenario::return_to_sender(&scenario, cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            // check the owner's balance
            let c = test_scenario::take_from_sender<Coin<SUI>>(&scenario);
            assert!(coin::value(&c) == 100, 0);
            test_scenario::return_to_sender(&scenario, c);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1506, location = lending_core::pool)]
    public fun test_withdraw_treasury_over_balance() {
        let scenario = test_scenario::begin(OWNER);
        {
            pool::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool_admin_cap = test_scenario::take_from_sender<PoolAdminCap>(&scenario);
            pool::create_pool_for_testing<SUI>(&pool_admin_cap, 9, test_scenario::ctx(&mut scenario));

            test_scenario::return_to_sender(&scenario, pool_admin_cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI>>(&scenario);
            let cap = test_scenario::take_from_sender<PoolAdminCap>(&scenario);

            pool::withdraw_treasury<SUI>(&mut cap, &mut pool, 100, OWNER, test_scenario::ctx(&mut scenario));

            test_scenario::return_shared(pool);
            test_scenario::return_to_sender(&scenario, cap);
        };

        test_scenario::end(scenario);
    }


    #[test]
    public fun test_get_coin_decimal() {
        let scenario = test_scenario::begin(OWNER);
        {
            pool::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool_admin_cap = test_scenario::take_from_sender<PoolAdminCap>(&scenario);
            pool::create_pool_for_testing<SUI>(&pool_admin_cap, 9, test_scenario::ctx(&mut scenario));

            test_scenario::return_to_sender(&scenario, pool_admin_cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI>>(&scenario);
            assert!(pool::get_coin_decimal(&pool) == 9, 0);
            test_scenario::return_shared(pool);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_convert_amount() {
        assert!(pool::convert_amount(1000, 1, 2) == 10000, 0);
        assert!(pool::convert_amount(1000, 2, 1) == 100, 0);
    }

    #[test]
    public fun test_normal_amount() {
        let scenario = test_scenario::begin(OWNER);
        {
            pool::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool_admin_cap = test_scenario::take_from_sender<PoolAdminCap>(&scenario);
            pool::create_pool_for_testing<SUI>(&pool_admin_cap, 9, test_scenario::ctx(&mut scenario));

            test_scenario::return_to_sender(&scenario, pool_admin_cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI>>(&scenario);
            assert!(pool::normal_amount(&pool, 1000000000) == 1000000000, 0);
            test_scenario::return_shared(pool);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_unnormal_amount() {
        let scenario = test_scenario::begin(OWNER);
        {
            pool::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool_admin_cap = test_scenario::take_from_sender<PoolAdminCap>(&scenario);
            pool::create_pool_for_testing<SUI>(&pool_admin_cap, 9, test_scenario::ctx(&mut scenario));

            test_scenario::return_to_sender(&scenario, pool_admin_cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI>>(&scenario);
            assert!(pool::unnormal_amount(&pool, 1000000000) == 1000000000, 0);
            test_scenario::return_shared(pool);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_deposit_balance_and_withdraw_balance() {
        use sui::balance;
        use sui::test_utils;

        let scenario = test_scenario::begin(OWNER);
        {
            pool::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool_admin_cap = test_scenario::take_from_sender<PoolAdminCap>(&scenario);
            pool::create_pool_for_testing<SUI>(&pool_admin_cap, 9, test_scenario::ctx(&mut scenario));
            test_scenario::return_to_sender(&scenario, pool_admin_cap);
        };

        // Test deposit_balance
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI>>(&scenario);

            let deposit_balance = balance::create_for_testing<SUI>(5_000_000_000);
            pool::deposit_balance_for_testing(&mut pool, deposit_balance, OWNER);

            let (balance_value, _, _) = pool::get_pool_info(&pool);
            assert!(balance_value == 5_000_000_000, 0);

            test_scenario::return_shared(pool);
        };

        // Test withdraw_balance
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI>>(&scenario);

            let withdrawn = pool::withdraw_balance_for_testing(&mut pool, 2_000_000_000, OWNER);
            assert!(balance::value(&withdrawn) == 2_000_000_000, 0);

            let (balance_value, _, _) = pool::get_pool_info(&pool);
            assert!(balance_value == 3_000_000_000, 0);

            test_utils::destroy(withdrawn);
            test_scenario::return_shared(pool);
        };

        // Test withdraw zero amount
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI>>(&scenario);

            let zero_balance = pool::withdraw_balance_for_testing(&mut pool, 0, OWNER);
            assert!(balance::value(&zero_balance) == 0, 0);

            test_utils::destroy(zero_balance);
            test_scenario::return_shared(pool);
        };

        test_scenario::end(scenario);
    }

    // Note: withdraw_reserve_balance is public(friend) and cannot be tested directly
    // It's tested through integration with the lending module

    // Test coin type for multi-pool testing
    struct USDT has drop {}

    #[test]
    public fun test_multi_coin_pools() {
        let scenario = test_scenario::begin(OWNER);
        {
            pool::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let cap = test_scenario::take_from_sender<PoolAdminCap>(&scenario);

            // Create SUI pool (9 decimals)
            pool::create_pool_for_testing<SUI>(&cap, 9, test_scenario::ctx(&mut scenario));

            // Create USDT pool (6 decimals)
            pool::create_pool_for_testing<USDT>(&cap, 6, test_scenario::ctx(&mut scenario));

            test_scenario::return_to_sender(&scenario, cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let sui_pool = test_scenario::take_shared<Pool<SUI>>(&scenario);
            let usdt_pool = test_scenario::take_shared<Pool<USDT>>(&scenario);

            // Verify decimals
            assert!(pool::get_coin_decimal(&sui_pool) == 9, 0);
            assert!(pool::get_coin_decimal(&usdt_pool) == 6, 0);

            // Test decimal conversion
            let usdt_amount = 1_000_000; // 1 USDT (6 decimals)
            let normalized = pool::normal_amount(&usdt_pool, usdt_amount);
            assert!(normalized == 1_000_000_000, 0); // Converted to 9 decimals

            let unnormalized = pool::unnormal_amount(&usdt_pool, normalized);
            assert!(unnormalized == 1_000_000, 0); // Back to 6 decimals

            test_scenario::return_shared(sui_pool);
            test_scenario::return_shared(usdt_pool);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_decimal_conversion_edge_cases() {
        // Test same decimal
        assert!(pool::convert_amount(1000, 5, 5) == 1000, 0);

        // Test increase by 1
        assert!(pool::convert_amount(100, 2, 3) == 1000, 0);

        // Test decrease by 1
        assert!(pool::convert_amount(1000, 3, 2) == 100, 0);

        // Test large increase
        assert!(pool::convert_amount(1, 0, 9) == 1_000_000_000, 0);

        // Test large decrease
        assert!(pool::convert_amount(1_000_000_000, 9, 0) == 1, 0);
    }

}
