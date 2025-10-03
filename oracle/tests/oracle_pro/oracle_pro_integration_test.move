#[test_only]
module oracle::oracle_pro_integration_test {
    use sui::test_scenario;
    use std::vector::{Self};
    use sui::clock::{Self};
    use oracle::oracle::{Self, OracleAdminCap, PriceOracle};
    use oracle::config::{Self, OracleConfig};
    use std::ascii::{Self, String};
    use sui::table::{Self};

    use oracle::oracle_pro;
    use oracle::oracle_sui_test::{ORACLE_SUI_TEST};
    use oracle::oracle_utils;
    use oracle::adaptor_pyth;
    use oracle::oracle_global::{Self as global};
    use oracle::oracle_manage;
    use oracle::oracle_provider;
    use oracle::oracle_lib::{Self as lib};
    use oracle::oracle_constants::{Self as constants};
    use oracle::oracle_provider::{supra_provider, pyth_provider, new_empty_provider, test_provider};

    const OWNER: address = @0xA;

    // Setup primary+secondary oracles. Under normal price update. Set primary oracle enable=0. check price update normally
    #[test]
    #[expected_failure(abort_code = 6003, location = oracle::config)]
    public fun test_primary_unable() {
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));
        {
            global::init_protocol(scenario);
        };
        

        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);
            let address_vec = config::get_vec_feeds(&oracle_config);
            let feed_id = *vector::borrow(&address_vec, 0);

            oracle_manage::disable_pyth_oracle_provider(&oracle_admin_cap, &mut oracle_config, feed_id);
            test_scenario::return_to_sender(scenario, oracle_admin_cap);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // Setup primary+secondary oracles. Under normal price update. Set secondary oracle enable=0. check price update normally
    #[test]
    public fun test_secondary_unable() { 
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));
        {
            global::init_protocol(scenario);
        };
        

        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);
            let address_vec = config::get_vec_feeds(&oracle_config);
            let feed_id = *vector::borrow(&address_vec, 0);

            let time = 86400 * 1000;
            let expired_time =  time - 1000 * 60;

            clock::increment_for_testing(&mut _clock, time);
            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, 9_000001, time, 9_000002, time, feed_id);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);
            assert!(valid, 0);
            assert!(price == 9_000001, 0);
            assert!(decimal == 6, 0);

            oracle_manage::disable_supra_oracle_provider(&oracle_admin_cap, &mut oracle_config, feed_id);

            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, 9_000002, time, 100_000002, time, feed_id);
            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);
            assert!(valid, 0);
            assert!(price == 9_000002, 0);
            assert!(decimal == 6, 0);

            test_scenario::return_to_sender(scenario, oracle_admin_cap);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // Setup primary oracle. Under normal price update. Set up a new secondary oracle. check price update normally
    #[test]
    public fun test_new_secondary() { 
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));
        {
            global::init_protocol(scenario);
        };
        

        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);
            let address_vec = config::get_vec_feeds(&oracle_config);
            let feed_id = *vector::borrow(&address_vec, 0);

            let time = 86400 * 1000;
            let expired_time =  time - 1000 * 60;

            clock::increment_for_testing(&mut _clock, time);
            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, 9_000001, time, 9_000002, time, feed_id);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);
            assert!(valid, 0);
            assert!(price == 9_000001, 0);
            assert!(decimal == 6, 0);

            oracle_manage::set_secondary_oracle_provider(&oracle_admin_cap, &mut oracle_config, feed_id, test_provider());

            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, 9_000002, time, 9_000003, time, feed_id);
            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);
            assert!(valid, 0);
            assert!(price == 9_000002, 0);
            assert!(decimal == 6, 0);

            test_scenario::return_to_sender(scenario, oracle_admin_cap);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // Setup primary oracle. Under normal price update. Set up a new secondary oracle with enable=false first. check price update normally. Then set enable=true. check price update normally
    #[test]
    public fun test_new_secondary_false() { 
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));
        {
            global::init_protocol(scenario);
        };
        

        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);
            let address_vec = config::get_vec_feeds(&oracle_config);
            let feed_id = *vector::borrow(&address_vec, 0);
            config::set_oracle_provider_config_enable_for_testing(&mut oracle_config, feed_id, supra_provider(), false);

            let time = 86400 * 1000;
            let expired_time =  time - 1000 * 60;

            clock::increment_for_testing(&mut _clock, time);
            // will not fail for secondary > 10 due to provider unabled
            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, 9_000000, time, 109_000002, time, feed_id);
            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);
            assert!(valid, 0);
            assert!(price == 9_000000, 0);

            config::set_oracle_provider_config_enable_for_testing(&mut oracle_config, feed_id, supra_provider(), true);

            // will fail if secondary price > 10 due to price check
            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, 9_000001, time, 9_000002, time, feed_id);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);
            assert!(valid, 0);
            assert!(price == 9_000001, 0);

            test_scenario::return_to_sender(scenario, oracle_admin_cap);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // Setup primary+secondary oracles. Triggered PriceRegulation Major. Set secondary oracle enable=0. check price update normally
    #[test]
    public fun test_primary_regulation() { 
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));
        {
            global::init_protocol(scenario);
        };
        

        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);
            let address_vec = config::get_vec_feeds(&oracle_config);
            let feed_id = *vector::borrow(&address_vec, 0);

            let time = 86400 * 1000;
            let expired_time =  time - 1000 * 60;

            clock::increment_for_testing(&mut _clock, time);
            oracle_pro::update_single_price_for_testing_non_abort(&_clock, &mut oracle_config, &mut price_oracle, 9_000001, time, 10_500000, time, feed_id);

            time = time + 30 * 1000;
            clock::set_for_testing(&mut _clock, time);

            let result = oracle_pro::update_single_price_for_testing_non_abort(&_clock, &mut oracle_config, &mut price_oracle, 9_000001, time, 10_500000, time, feed_id);
            // level_major major
            assert!(result == 11, 0);

            config::set_oracle_provider_config_enable_for_testing(&mut oracle_config, feed_id, supra_provider(), false);
            let result = oracle_pro::update_single_price_for_testing_non_abort(&_clock, &mut oracle_config, &mut price_oracle, 9_000001, time, 10_500000, time, feed_id);
            assert!(result == 0, 0);

            test_scenario::return_to_sender(scenario, oracle_admin_cap);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // Setup primary+secondary oracles. Triggered PriceRegulation Major. Update diff range to larger. check price update normally
    #[test]
    public fun test_primary_regulation_update_diff() { 
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));
        {
            global::init_protocol(scenario);
        };
        
        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);
            let address_vec = config::get_vec_feeds(&oracle_config);
            let feed_id = *vector::borrow(&address_vec, 0);

            let time = 86400 * 1000;
            let expired_time =  time - 1000 * 60;

            clock::increment_for_testing(&mut _clock, time);
            oracle_pro::update_single_price_for_testing_non_abort(&_clock, &mut oracle_config, &mut price_oracle, 9_000001, time, 10_500000, time, feed_id);

            time = time + 30 * 1000;
            clock::set_for_testing(&mut _clock, time);

            let result = oracle_pro::update_single_price_for_testing_non_abort(&_clock, &mut oracle_config, &mut price_oracle, 9_000001, time, 10_500000, time, feed_id);
            // level_major major
            assert!(result == 11, 0);

            // diff1 = 18%
            oracle_manage::set_price_diff_threshold1_to_price_feed(&oracle_admin_cap, &mut oracle_config, feed_id, 1800);
            let result = oracle_pro::update_single_price_for_testing_non_abort(&_clock, &mut oracle_config, &mut price_oracle, 9_000001, time, 10_500000, time, feed_id);
            assert!(result == 0, 0);

            test_scenario::return_to_sender(scenario, oracle_admin_cap);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // Setup primary+secondary oracles. Triggered oracle unavailable. Wait for recovery. check price update normally
   #[test]
    public fun test_provider_unavailable() { 
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));
        {
            global::init_protocol(scenario);
        };
        
        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);
            let address_vec = config::get_vec_feeds(&oracle_config);
            let feed_id = *vector::borrow(&address_vec, 0);

            let time = 86400 * 1000;
            let expired_time =  time - 1000 * 60;

            clock::increment_for_testing(&mut _clock, time);

            // expired
            let result = oracle_pro::update_single_price_for_testing_non_abort(&_clock, &mut oracle_config, &mut price_oracle, 9_000001, expired_time, 9_500000, expired_time, feed_id);
            assert!(result == 4, 0);

            // fresh
            let result = oracle_pro::update_single_price_for_testing_non_abort(&_clock, &mut oracle_config, &mut price_oracle, 9_000001, time, 9_500000, time, feed_id);
            assert!(result == 0, 0);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);
            assert!(valid, 0);
            assert!(price == 9_000001, 0);

            test_scenario::return_to_sender(scenario, oracle_admin_cap);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // Setup primary+secondary oracles. Update primary and secondary prices to a different prices. check price update normally (usdc to usdy. vSui to Sui. sui to eth)
    #[test]
    // #[expected_failure(abort_code = 6013, location = oracle::config)]
    public fun test_create_set_config() {
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));
        {
            global::init_protocol(scenario);
        };

        // first set 
        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);

            let address_vec = config::get_vec_feeds(&oracle_config);
            let feed_id = *vector::borrow(&address_vec, 0);

            oracle_manage::set_pyth_price_oracle_provider_pair_id(&oracle_admin_cap, &mut oracle_config, feed_id, b"001");
            oracle_manage::set_supra_price_source_pair_id(&oracle_admin_cap, &mut oracle_config, feed_id, b"101");

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };

        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);

            let address_vec = config::get_vec_feeds(&oracle_config);
            let feed = config::get_price_feed(&oracle_config, *vector::borrow(&address_vec, 0));
            let secondary_config = config::get_oracle_provider_config_from_feed(feed, supra_provider());
            let primary_config = config::get_oracle_provider_config_from_feed(feed, pyth_provider());

            let pair = config::get_pair_id_from_oracle_provider_config(primary_config);
            assert!(pair == b"001", 0);

            let pair = config::get_pair_id_from_oracle_provider_config(secondary_config);
            assert!(pair == b"101", 0);

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };

        // second set 
        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);

            let address_vec = config::get_vec_feeds(&oracle_config);
            let feed_id = *vector::borrow(&address_vec, 0);

            oracle_manage::set_pyth_price_oracle_provider_pair_id(&oracle_admin_cap, &mut oracle_config, feed_id, b"002");
            oracle_manage::set_supra_price_source_pair_id(&oracle_admin_cap, &mut oracle_config, feed_id, b"102");

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };

        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);

            let address_vec = config::get_vec_feeds(&oracle_config);
            let feed = config::get_price_feed(&oracle_config, *vector::borrow(&address_vec, 0));
            let secondary_config = config::get_oracle_provider_config_from_feed(feed, supra_provider());
            let primary_config = config::get_oracle_provider_config_from_feed(feed, pyth_provider());

            let pair = config::get_pair_id_from_oracle_provider_config(primary_config);
            assert!(pair == b"002", 0);

            let pair = config::get_pair_id_from_oracle_provider_config(secondary_config);
            assert!(pair == b"102", 0);

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }
}