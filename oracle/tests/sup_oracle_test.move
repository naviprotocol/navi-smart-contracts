#[test_only]
module oracle::oracle_test_sup {
    use sui::test_scenario;
    use std::vector;
    use sui::clock::{Self};
    use oracle::oracle::{Self, OracleAdminCap, OracleFeederCap, PriceOracle};

    const OWNER: address = @0xA;

    //Should update and get the correct token price
    #[test]
    public fun test_register_and_get_price() {
        
        let scenario = test_scenario::begin(OWNER);

        // paramt
        let oracle_id = 0;
        let decimal = 6;
        let initial_token_price = 9900000;
        let updated_token_price = 10000000;

        // package init
        {
            oracle::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        let clock = {
            let ctx = test_scenario::ctx(&mut scenario);
            clock::create_for_testing(ctx)
        };

        // test register token
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(&scenario);

            oracle::register_token_price(
                &oracle_admin_cap,
                &clock,
                &mut price_oracle,
                oracle_id,
                initial_token_price,
                decimal,
            );

            test_scenario::return_shared(price_oracle); 
            test_scenario::return_to_sender(&scenario, oracle_admin_cap);
        };


        // test get price before update
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let (valid, value, decimal) = oracle::get_token_price(&clock, &price_oracle, oracle_id);

            assert!(valid, 0);
            assert!(value == initial_token_price, 0);
            assert!(decimal == decimal, 0);
            test_scenario::return_shared(price_oracle); 
        };

        //test Update the code
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let oracle_feeder_cap = test_scenario::take_from_sender<OracleFeederCap>(&scenario);

            oracle::update_token_price(
                &oracle_feeder_cap,
                &clock,
                &mut price_oracle,
                oracle_id,
                updated_token_price,
            );

            test_scenario::return_shared(price_oracle); 
            test_scenario::return_to_sender(&scenario, oracle_feeder_cap);
        };

         // test get updated
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let (valid, value, decimal) = oracle::get_token_price(&clock, &price_oracle, oracle_id);

            assert!(valid, 0);
            assert!(value == updated_token_price, 0);
            assert!(decimal == decimal, 0);
            test_scenario::return_shared(price_oracle); 
        };
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    //Should fail if update unregistered token 
    #[test]
    #[expected_failure(abort_code = 6011, location=oracle::oracle)]
    public fun test_fail_update_unregistered_token() {
        
        let scenario = test_scenario::begin(OWNER);

        // paramt
        let oracle_id = 0;
        let unregistered_oracle_id = 1;
        let decimal = 6;
        let initial_token_price = 9900000;
        let updated_token_price = 10000000;

        // package init
        {
            oracle::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        let clock = {
            let ctx = test_scenario::ctx(&mut scenario);
            clock::create_for_testing(ctx)
        };

        // test register token
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(&scenario);
            oracle::register_token_price(
                &oracle_admin_cap,
                &clock,
                &mut price_oracle,
                oracle_id,
                initial_token_price,
                decimal,
            );

            test_scenario::return_shared(price_oracle); 
            test_scenario::return_to_sender(&scenario, oracle_admin_cap);
        };

        // test get price before update
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let (valid, value, decimal) = oracle::get_token_price(&clock, &price_oracle, oracle_id);

            assert!(valid, 0);
            assert!(value == initial_token_price, 0);
            assert!(decimal == decimal, 0);
            test_scenario::return_shared(price_oracle); 
        };


        //test Update the ungistered code
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let oracle_feeder_cap = test_scenario::take_from_sender<OracleFeederCap>(&scenario);

            oracle::update_token_price(
                &oracle_feeder_cap,
                &clock,
                &mut price_oracle,
                unregistered_oracle_id,
                updated_token_price,
            );

            test_scenario::return_shared(price_oracle); 
            test_scenario::return_to_sender(&scenario, oracle_feeder_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    //Should fail if read unregistered token 
    #[test]
    #[expected_failure(abort_code = 6011, location=oracle::oracle)]
    public fun test_fail_read_unregistered_token() {
        
        let scenario = test_scenario::begin(OWNER);

        // paramt
        let oracle_id = 0;
        let unregistered_oracle_id = 1;
        let decimal = 6;
        let initial_token_price = 9900000;

        // package init
        {
            oracle::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        let clock = {
            let ctx = test_scenario::ctx(&mut scenario);
            clock::create_for_testing(ctx)
        };

        // test register token
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(&scenario);

            oracle::register_token_price(
                &oracle_admin_cap,
                &clock,
                &mut price_oracle,
                oracle_id,
                initial_token_price,
                decimal,
            );

            test_scenario::return_shared(price_oracle); 
            test_scenario::return_to_sender(&scenario, oracle_admin_cap);
        };

        // test get price before update
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let (valid, value, decimal) = oracle::get_token_price(&clock, &price_oracle, unregistered_oracle_id);

            assert!(valid, 0);
            assert!(value == initial_token_price, 0);
            assert!(decimal == decimal, 0);
            test_scenario::return_shared(price_oracle); 
        };
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    //Should fail if read a token price that is expired
    #[test]
    public fun test_fail_if_token_expire() {
        
        let scenario = test_scenario::begin(OWNER);

        // paramt
        let oracle_id = 0;
        let decimal = 6;
        let initial_token_price = 9900000;

        // package init
        {
            oracle::init_for_testing(test_scenario::ctx(&mut scenario));
        };
        let clock = {
            let ctx = test_scenario::ctx(&mut scenario);
            clock::create_for_testing(ctx)
        };

        // test register token
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(&scenario);

            oracle::register_token_price(
                &oracle_admin_cap,
                &clock,
                &mut price_oracle,
                oracle_id,
                initial_token_price,
                decimal,
            );

            test_scenario::return_shared(price_oracle); 
            test_scenario::return_to_sender(&scenario, oracle_admin_cap);
        };


        // test get price before update
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let (valid, value, decimal) = oracle::get_token_price(&clock, &price_oracle, oracle_id);

            assert!(valid, 0);
            assert!(value == initial_token_price, 0);
            assert!(decimal == decimal, 0);
            test_scenario::return_shared(price_oracle); 
        };

        // set update interval
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(&scenario);
            oracle::set_update_interval(
                &oracle_admin_cap,
                &mut price_oracle,
                1000,
            );

            clock::increment_for_testing(&mut clock, 5000);
            test_scenario::return_shared(price_oracle); 
            test_scenario::return_to_sender(&scenario, oracle_admin_cap); 
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool_id = 0;
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);

            let (valid, _, _) = oracle::get_token_price(&clock, &price_oracle, pool_id);
            assert!(!valid, 0);

            test_scenario::return_shared(price_oracle);
        };


        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    // Should expire a token price after setting a shorter interval 
    public fun test_invalid_interval() {
        let scenario = test_scenario::begin(OWNER);
        // paramt
        let oracle_id = 0;
        let decimal = 6;
        let initial_token_price = 9900000;

        // package init
        {
            oracle::init_for_testing(test_scenario::ctx(&mut scenario));
        };
        let clock = {
            let ctx = test_scenario::ctx(&mut scenario);
            clock::create_for_testing(ctx)
        };

        // test shorter interval
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(&scenario);

            oracle::register_token_price(
                &oracle_admin_cap,
                &clock,
                &mut price_oracle,
                oracle_id,
                initial_token_price,
                decimal,
            );

            clock::increment_for_testing(&mut clock, 10000);
            let (valid, value, _) = oracle::get_token_price(&clock, &price_oracle, oracle_id);

            assert!(value == initial_token_price, 0);
            assert!(valid, 0);

            oracle::set_update_interval(
                &oracle_admin_cap,
                &mut price_oracle,
                1000,
            );

            let (valid, _, _) = oracle::get_token_price(&clock, &price_oracle, oracle_id);

            assert!(!valid, 0);

            test_scenario::return_shared(price_oracle); 
            test_scenario::return_to_sender(&scenario, oracle_admin_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    // Should update batch and get the correct token prices
    public fun test_update_token_price_batch() {
        let scenario = test_scenario::begin(OWNER);
        // paramt
        let decimal = 6;
        let initial_token_price = 9900000;
        let new_token_price = 10000000;

        // package init
        {
            oracle::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        let clock = {
            let ctx = test_scenario::ctx(&mut scenario);
            clock::create_for_testing(ctx)
        };

        // test update token price
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let token_decimal = 6;

            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let oracle_feeder_cap = test_scenario::take_from_sender<OracleFeederCap>(&scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(&scenario);
            let i = 0;
            let token_num = 5;
            let oracle_ids = vector::empty<u8>();
            let new_prices = vector::empty<u256>();

            while (i < token_num) {
                oracle::register_token_price(
                    &oracle_admin_cap,
                    &clock,
                    &mut price_oracle,
                    i,
                    initial_token_price * (i as u256),
                    decimal,
                );
                vector::push_back(&mut oracle_ids, i);
                vector::push_back(&mut new_prices, new_token_price);
                i = i + 1;
            };
            // remove the last one
            vector::pop_back(&mut oracle_ids);
            vector::pop_back(&mut new_prices);

            oracle::update_token_price_batch(
                &oracle_feeder_cap,
                &clock,
                &mut price_oracle,
                oracle_ids,
                new_prices
            );
            i = 0;
            while (i < token_num - 1) {
                let (valid, value, decimal) = oracle::get_token_price(&clock, &price_oracle, i);
                assert!(valid, 0);
                assert!(value == new_token_price, 0);
                assert!(decimal == token_decimal, 0);
                i = i + 1;
            };

            //ensure the last price is not updated
            let (valid, value, _) = oracle::get_token_price(&clock, &price_oracle, i);
            assert!(valid, 0);
            assert!(value == initial_token_price * ((token_num - 1) as u256), 0);

            test_scenario::return_shared(price_oracle); 
            test_scenario::return_to_sender(&scenario, oracle_feeder_cap);
            test_scenario::return_to_sender(&scenario, oracle_admin_cap);
        };
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }
}