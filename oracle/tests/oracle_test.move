#[test_only]
module oracle::oracle_test {
    use sui::test_scenario;
    use sui::clock::{Self};
    use oracle::oracle::{Self, OracleAdminCap, OracleFeederCap, PriceOracle};

    const OWNER: address = @0xA;

    #[test]
    public fun test_register_and_get_price() {
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

        // test get price and decimals
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let (valid, value, decimal) = oracle::get_token_price(&clock, &price_oracle, oracle_id);

            assert!(valid, 0);
            assert!(value == initial_token_price, 0);
            assert!(decimal == decimal, 0);
            test_scenario::return_shared(price_oracle); 
        };
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_update_price() {
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

        // test update token price
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let oracle_id = 0;
            let token_decimal = 6;
            let new_token_price = 10000000;

            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let oracle_feeder_cap = test_scenario::take_from_sender<OracleFeederCap>(&scenario);

            oracle::update_token_price(
                &oracle_feeder_cap,
                &clock,
                &mut price_oracle,
                oracle_id,
                new_token_price,
            );

            let (valid, value, decimal) = oracle::get_token_price(&clock, &price_oracle, oracle_id);
            assert!(valid, 0);
            assert!(value == new_token_price, 0);
            assert!(decimal == token_decimal, 0);

            test_scenario::return_shared(price_oracle); 
            test_scenario::return_to_sender(&scenario, oracle_feeder_cap);
        };
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_decimal() {
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

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);

            let decimal = oracle::decimal(&mut price_oracle, 0);
            assert!(decimal == 6, 0);

            let decimal = oracle::safe_decimal(&price_oracle, 0);
            assert!(decimal == 6, 0);

            test_scenario::return_shared(price_oracle); 
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }


    #[test]
    public fun test_invalid_update_price() {
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
            test_scenario::return_shared(price_oracle); 
            test_scenario::return_to_sender(&scenario, oracle_admin_cap); 
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

        // test update token price
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let oracle_id = 0;
            let token_decimal = 6;
            let new_token_price = 10000000;

            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let oracle_feeder_cap = test_scenario::take_from_sender<OracleFeederCap>(&scenario);

            oracle::update_token_price(
                &oracle_feeder_cap,
                &clock,
                &mut price_oracle,
                oracle_id,
                new_token_price,
            );

            let (valid, value, decimal) = oracle::get_token_price(&clock, &price_oracle, oracle_id);
            assert!(valid, 0);
            assert!(value == new_token_price, 0);
            assert!(decimal == token_decimal, 0);

            clock::increment_for_testing(&mut clock, 5000);

            test_scenario::return_shared(price_oracle); 
            test_scenario::return_to_sender(&scenario, oracle_feeder_cap);
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
    #[expected_failure(abort_code = 6014, location = oracle::oracle)]
    public fun test_invalid_interval() {
        let scenario = test_scenario::begin(OWNER);

        // package init
        {
            oracle::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        let clock = {
            let ctx = test_scenario::ctx(&mut scenario);
            clock::create_for_testing(ctx)
        };

        // set update interval
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(&scenario);
            oracle::set_update_interval(
                &oracle_admin_cap,
                &mut price_oracle,
                0,
            );
            test_scenario::return_shared(price_oracle); 
            test_scenario::return_to_sender(&scenario, oracle_admin_cap); 
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }
}