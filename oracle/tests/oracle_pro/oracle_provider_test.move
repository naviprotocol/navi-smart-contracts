#[test_only]
module oracle::oracle_provider_test {
    use sui::test_scenario;
    use std::vector::{Self};
    use sui::clock::{Self};
    use oracle::oracle::{Self, OracleAdminCap, PriceOracle};
    use oracle::config::{Self, OracleConfig};
    use std::ascii::{Self, String};
    use sui::table::{Self};

    use oracle::oracle_utils;
    use oracle::adaptor_supra;
    use oracle::oracle_global::{Self as global};
    use oracle::oracle_manage;
    use oracle::oracle_provider;
    use oracle::oracle_lib::{Self as lib};
    use oracle::oracle_constants::{Self as constants};
    use oracle::oracle_provider::{supra_provider, pyth_provider, new_empty_provider};

    const OWNER: address = @0xA;

    // Should create config for supra and pyth
    // Should set and get parameters
    // Should get to_string for pyth/supra/empty
    #[test]
    // #[expected_failure(abort_code = 6013, location = oracle::config)]
    public fun test_create_set_config() {
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

            let address_vec = config::get_vec_feeds(&oracle_config);
            let feed = config::get_price_feed(&oracle_config, *vector::borrow(&address_vec, 0));

            let primary = config::get_primary_oracle_provider(feed);
            let secondary = config::get_secondary_oracle_provider(feed);

            assert!(oracle_provider::to_string(primary) == ascii::string(b"PythOracleProvider"), 0);
            assert!(oracle_provider::to_string(secondary) == ascii::string(b"SupraOracleProvider"), 0);

            let configs = config::get_oracle_provider_configs_from_feed(feed);

            let configs_2 = config::get_oracle_provider_configs(&oracle_config, *vector::borrow(&address_vec, 0));
            assert!(configs == configs_2, 0);

            let primary_config = table::borrow(configs, *primary);
            let secondary_config = table::borrow(configs, *secondary);

            let primary_config_2 = config::get_primary_oracle_provider_config(feed);
            let secondary_config_2 = config::get_secondary_source_config(feed);
            assert!(primary_config == primary_config_2, 0);
            assert!(secondary_config == secondary_config_2, 0);
    
            let pair = config::get_pair_id_from_oracle_provider_config(primary_config);
            let name =  config::get_oracle_provider_from_oracle_provider_config(primary_config);
            let enable = config::is_oracle_provider_config_enable(primary_config);
            assert!(pair == b"00", 0);
            assert!(oracle_provider::to_string(&name) == ascii::string(b"PythOracleProvider"), 0);
            assert!(enable, 0);

            let pair = config::get_pair_id_from_oracle_provider_config(secondary_config);
            let name =  config::get_oracle_provider_from_oracle_provider_config(secondary_config);
            let enable = config::is_oracle_provider_config_enable(secondary_config);
            lib::print(&pair);
            assert!(adaptor_supra::vector_to_pair_id(pair) == 0, 0);
            assert!(oracle_provider::to_string(&name) == ascii::string(b"SupraOracleProvider"), 0);
            assert!(enable, 0);

            lib::print(primary_config);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };

        // set
        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);

            let address_vec = config::get_vec_feeds(&oracle_config);
            let feed_id = *vector::borrow(&address_vec, 0);

            oracle_manage::set_supra_price_source_pair_id(&oracle_admin_cap, &mut oracle_config, feed_id, b"001");
            oracle_manage::enable_supra_oracle_provider(&oracle_admin_cap, &mut oracle_config, feed_id);

            oracle_manage::set_primary_oracle_provider(&oracle_admin_cap, &mut oracle_config, feed_id, supra_provider());

            oracle_manage::set_pyth_price_oracle_provider_pair_id(&oracle_admin_cap, &mut oracle_config, feed_id, b"000");
            oracle_manage::disable_pyth_oracle_provider(&oracle_admin_cap, &mut oracle_config, feed_id);
            oracle_manage::enable_pyth_oracle_provider(&oracle_admin_cap, &mut oracle_config, feed_id);

            oracle_manage::set_primary_oracle_provider(&oracle_admin_cap, &mut oracle_config, feed_id, pyth_provider());
            oracle_manage::disable_supra_oracle_provider(&oracle_admin_cap, &mut oracle_config, feed_id); // move to here, primary oracle can not be disable

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
            let enable = config::is_oracle_provider_config_enable(primary_config);
            assert!(pair == b"000", 0);
            assert!(enable, 0);

            let pair = config::get_pair_id_from_oracle_provider_config(secondary_config);
            let enable = config::is_oracle_provider_config_enable(secondary_config);
            assert!(pair == b"001", 0);
            assert!(!enable, 0);

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // Should fail if set primary value
    #[test]
    #[expected_failure(abort_code = 6003, location = oracle::config)]
    public fun test_set_primary_failed() {
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

    #[test]
   // Should be empty if no config
    public fun test_create_config_empty() {
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));
        {
            global::init_protocol_without_provider(scenario);
        };

        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);

            let address_vec = config::get_vec_feeds(&oracle_config);
            let feed_id = config::get_price_feed(&oracle_config, *vector::borrow(&address_vec, 0));

            let primary = config::get_primary_oracle_provider(feed_id);
            let secondary = config::get_secondary_oracle_provider(feed_id);

            assert!(oracle_provider::to_string(primary) == ascii::string(b""), 0);
            assert!(oracle_provider::to_string(secondary) == ascii::string(b""), 0);

            assert!(oracle_provider::is_empty(primary), 0);
            assert!(oracle_provider::is_empty(secondary), 0);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // Should not create existed provider
    #[test]
    #[expected_failure(abort_code = 6004, location = oracle::config)]
    public fun test_create_repeated_config() {
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

            oracle_manage::create_pyth_oracle_provider_config(
                &oracle_admin_cap,
                &mut oracle_config,
                feed_id,
                b"0", 
                true);

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }
}