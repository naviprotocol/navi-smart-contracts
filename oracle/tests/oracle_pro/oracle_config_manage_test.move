#[test_only]
module oracle::oracle_config_manage_test {
    use sui::test_scenario;
    use std::vector::{Self};
    use sui::clock::{Self};
    use oracle::oracle::{Self, OracleAdminCap, PriceOracle};
    use oracle::config::{Self, OracleConfig};
    use std::ascii::{Self, String};
    use sui::table::{Self};

    use oracle::oracle_sui_test::{ORACLE_SUI_TEST};
    use oracle::oracle_version;
    use oracle::adaptor_pyth;
    use oracle::oracle_global::{Self as global};
    use oracle::oracle_manage;
    use oracle::oracle_provider;
    use oracle::oracle_lib::{Self as lib};
    use oracle::oracle_constants::{Self as constants};
    use oracle::oracle_provider::{supra_provider, pyth_provider, new_empty_provider};

    const OWNER: address = @0xA;

    // Should set and get parameters
    #[test]
    public fun test_getter_setter() {
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
            let feed = config::get_price_feed(&oracle_config, *vector::borrow(&address_vec, 0));

            let feed_id = config::get_price_feed_id(&oracle_config, *vector::borrow(&address_vec, 0));
            assert!(feed_id == *vector::borrow(&address_vec, 0), 0);

            let feed_id2 =  config::get_price_feed_id_from_feed(feed);
            assert!(feed_id2 == feed_id, 0);

            let is_enabled = config::is_price_feed_enable(feed);
            assert!(is_enabled, 0);

            let max_timestamp_diff = config::get_max_timestamp_diff(&oracle_config ,feed_id);
            assert!(max_timestamp_diff == 60 * 1000, 0);

            let max_timestamp_diff2 = config::get_max_timestamp_diff_from_feed(feed);
            assert!(max_timestamp_diff == max_timestamp_diff2, 0);

            let get_price_diff_threshold1 = config::get_price_diff_threshold1(&oracle_config ,feed_id);
            assert!(get_price_diff_threshold1 == 1000, 0);

            let get_price_diff_threshold1_1 = config::get_price_diff_threshold1_from_feed(feed);
            assert!(get_price_diff_threshold1 == get_price_diff_threshold1_1, 0);

            let get_price_diff_threshold2 = config::get_price_diff_threshold2(&oracle_config ,feed_id);
            assert!(get_price_diff_threshold2 == 2000, 0);

            let get_price_diff_threshold2_2 = config::get_price_diff_threshold2_from_feed(feed);
            assert!(get_price_diff_threshold2 == get_price_diff_threshold2_2, 0);

            let max_duration_within_thresholds = config::get_max_duration_within_thresholds(&oracle_config ,feed_id);
            assert!(max_duration_within_thresholds == 10000, 0);

            let max_duration_within_thresholds_2 = config::get_max_duration_within_thresholds_from_feed(feed);
            assert!(max_duration_within_thresholds == max_duration_within_thresholds_2, 0);

            let diff_threshold2_timer = config::get_diff_threshold2_timer(&oracle_config ,feed_id);
            assert!(diff_threshold2_timer == 0, 0);

            let diff_threshold2_timer_2 = config::get_diff_threshold2_timer_from_feed(feed);
            assert!(diff_threshold2_timer == diff_threshold2_timer_2, 0);

            let maximum_allowed_span_percentage = config::get_maximum_allowed_span_percentage(&oracle_config ,feed_id);
            assert!(maximum_allowed_span_percentage == 2000, 0);

            let maximum_allowed_span_percentage_2 = config::get_maximum_allowed_span_percentage_from_feed(feed);
            assert!(maximum_allowed_span_percentage == maximum_allowed_span_percentage_2, 0);

            let get_maximum_effective_price = config::get_maximum_effective_price(&oracle_config ,feed_id);
            assert!(get_maximum_effective_price == 10_000000, 0);

            let get_maximum_effective_price_2 = config::get_maximum_effective_price_from_feed(feed);
            assert!(get_maximum_effective_price == get_maximum_effective_price_2, 0);

            let get_minimum_effective_price = config::get_minimum_effective_price(&oracle_config ,feed_id);
            assert!(get_minimum_effective_price == 0_100000, 0);

            let get_minimum_effective_price_2 = config::get_minimum_effective_price_from_feed(feed);
            assert!(get_minimum_effective_price == get_minimum_effective_price_2, 0);

            let get_oracle_id = config::get_oracle_id(&oracle_config ,feed_id);
            assert!(get_oracle_id == 0, 0);

            let get_oracle_id_2 = config::get_oracle_id_from_feed(feed);
            assert!(get_oracle_id == get_oracle_id_2, 0);

            let get_coin_type = config::get_coin_type(&oracle_config ,feed_id);
            assert!(get_coin_type == ascii::string(b"0000000000000000000000000000000000000000000000000000000000000000::oracle_sui_test::ORACLE_SUI_TEST"), 0);

            let get_coin_type_2 = config::get_coin_type_from_feed(feed);
            assert!(get_coin_type == get_coin_type_2, 0);

            let get_historical_price_ttl = config::get_historical_price_ttl(feed);
            assert!(get_historical_price_ttl == 60000, 0);

            // let history = config::get_history_price_from_feed(feed);
            
            let (h_price, h_updated_time) = config::get_history_price_data_from_feed(feed);
            assert!(h_price == 0, 0);
            assert!(h_updated_time == 0, 0);

            let get_oracle_provider_config = config::get_oracle_provider_config(&oracle_config ,feed_id, supra_provider());

            let get_oracle_provider_config_2 = config::get_oracle_provider_config_from_feed(feed, supra_provider());
            assert!(get_oracle_provider_config == get_oracle_provider_config_2, 0);
            
            let get_pair_id = config::get_pair_id(&oracle_config ,feed_id, pyth_provider());
            assert!(get_pair_id == b"00", 0);

            let get_pair_id_2 = config::get_pair_id_from_feed(feed, pyth_provider());
            assert!(get_pair_id == get_pair_id_2, 0);

            let get_feeds = config::get_feeds(&oracle_config);
            let feed_0 = table::borrow(get_feeds, feed_id);
            let feed_0_id =  config::get_price_feed_id_from_feed(feed_0);
            assert!(feed_id == feed_0_id, 0);

            let addr = config::get_config_id_to_address(&oracle_config);
            lib::print(&addr);
            
            assert!(!config::is_paused(&oracle_config), 0);
            assert!(config::is_price_feed_exists<ORACLE_SUI_TEST>(&oracle_config, 0), 0);
            assert!(!config::is_price_feed_exists<PriceOracle>(&oracle_config, 1), 0);

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
            let feed_id = config::get_price_feed_id(&oracle_config, *vector::borrow(&address_vec, 0));

            // setter 
            oracle_manage::set_enable_to_price_feed(&oracle_admin_cap, &mut oracle_config, feed_id, false);

            let feed = config::get_price_feed(&oracle_config, *vector::borrow(&address_vec, 0));
            let is_enabled = config::is_price_feed_enable(feed);
            assert!(!is_enabled, 0);

            oracle_manage::set_max_timestamp_diff_to_price_feed(&oracle_admin_cap, &mut oracle_config, feed_id, 1);
            let max_timestamp_diff = config::get_max_timestamp_diff(&oracle_config ,feed_id);
            assert!(max_timestamp_diff == 1, 0);

            oracle_manage::set_price_diff_threshold1_to_price_feed(&oracle_admin_cap, &mut oracle_config, feed_id, 2);
            let get_price_diff_threshold1 = config::get_price_diff_threshold1(&oracle_config ,feed_id);
            assert!(get_price_diff_threshold1 == 2, 0);

            oracle_manage::set_price_diff_threshold2_to_price_feed(&oracle_admin_cap, &mut oracle_config, feed_id, 3);
            let v = config::get_price_diff_threshold2(&oracle_config ,feed_id);
            assert!(v == 3, 0);

            oracle_manage::set_max_duration_within_thresholds_to_price_feed(&oracle_admin_cap, &mut oracle_config, feed_id, 4);
            let v = config::get_max_duration_within_thresholds(&oracle_config ,feed_id);
            assert!(v == 4, 0);

            oracle_manage::set_maximum_allowed_span_percentage_to_price_feed(&oracle_admin_cap, &mut oracle_config, feed_id, 5);
            let v = config::get_maximum_allowed_span_percentage(&oracle_config ,feed_id);
            assert!(v == 5, 0);


            oracle_manage::set_minimum_effective_price_to_price_feed(&oracle_admin_cap, &mut oracle_config, feed_id, 6);
            let v = config::get_minimum_effective_price(&oracle_config ,feed_id);
            assert!(v == 6, 0);

            oracle_manage::set_maximum_effective_price_to_price_feed(&oracle_admin_cap, &mut oracle_config, feed_id, 7);
            let v = config::get_maximum_effective_price(&oracle_config ,feed_id);
            assert!(v == 7, 0);

            oracle_manage::set_historical_price_ttl_to_price_feed(&oracle_admin_cap, &mut oracle_config, feed_id, 8);
            let feed = config::get_price_feed(&oracle_config, *vector::borrow(&address_vec, 0));
            let v = config::get_historical_price_ttl(feed);
            assert!(v == 8, 0);

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };          
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // Should revert if is_price_feed_exists (CoinType)
    #[test]
    #[expected_failure(abort_code = 6001, location = oracle::config)]
    public fun test_duplicated_feed() {
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));
        {
            global::init_protocol(scenario);
        };

        test_scenario::next_tx(scenario, OWNER);
        {
            global::create_price_feed_and_provider<ORACLE_SUI_TEST>(scenario, &mut _clock, 1, 6);
        };          
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // Should return false for empty and same as primary
    // Should return true if secondary available
    #[test]
    public fun test_is_secondary_oracle_available() {
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

            let address_vec = &config::get_vec_feeds(&oracle_config);
            let feed_id = *vector::borrow(address_vec, 0);
            let feed = config::get_price_feed(&oracle_config, feed_id);

            // true if normal 
            let is_available = config::is_secondary_oracle_available(feed);
            assert!(is_available, 0);

            // false if same as primary
            oracle_manage::set_primary_oracle_provider(&oracle_admin_cap, &mut oracle_config, feed_id, supra_provider());
            let feed = config::get_price_feed(&oracle_config, feed_id);
            let is_available = config::is_secondary_oracle_available(feed);
            assert!(!is_available, 0);

            // true if normal 
            oracle_manage::set_primary_oracle_provider(&oracle_admin_cap, &mut oracle_config, feed_id, pyth_provider());
            let feed = config::get_price_feed(&oracle_config, feed_id);
            let is_available = config::is_secondary_oracle_available(feed);
            assert!(is_available, 0);

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };        

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // Should return false for empty and same as primary
    #[test]
    public fun test_is_secondary_oracle_available_empty() {
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
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);

            let address_vec = &config::get_vec_feeds(&oracle_config);
            let feed_id = *vector::borrow(address_vec, 0);
            let feed = config::get_price_feed(&oracle_config, feed_id);

            // false if empty 
            let is_available = config::is_secondary_oracle_available(feed);
            assert!(!is_available, 0);

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };        

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // Should update 1/2/3/n history and keep latest price
    // Should update price twice
    #[test]
    public fun test_keep_history_update() {
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;

        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));
        {
            global::init_protocol_without_provider(scenario);
        };  

        test_scenario::next_tx(scenario, OWNER);
        {
            // register 7 coins
            global::regiter_test_coins(scenario, &mut _clock);
        };

        test_scenario::next_tx(scenario, OWNER);
        {        
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);
            let address_vec = config::get_vec_feeds(&oracle_config);

            let i = 0;
            while (i < 8) {
                let feed = config::get_price_feed_mut_for_testing(&mut oracle_config, *vector::borrow(&address_vec, i));
                config::keep_history_update_for_testing(feed, (i as u256) * 1_000000, ((17_000000000 + i) as u64));
                i = i + 1;
            };

            i = 0;
            while (i < 8) {
                let feed = config::get_price_feed_mut_for_testing(&mut oracle_config, *vector::borrow(&address_vec, i));
                let (h_price, h_updated_time) = config::get_history_price_data_from_feed(feed);
                assert!(h_price == ((1_000000 * i) as u256), 0);
                assert!(h_updated_time == ((17_000000000 + i) as u64), 0);
                i = i + 1;
            };

            i = 0;
            while (i < 2) {
                let feed = config::get_price_feed_mut_for_testing(&mut oracle_config, *vector::borrow(&address_vec, i));
                config::keep_history_update_for_testing(feed, (i as u256) * 2_000000, ((18_000000000 + i) as u64));
                i = i + 1;
            };

            i = 0;
            while (i < 2) {
                let feed = config::get_price_feed_mut_for_testing(&mut oracle_config, *vector::borrow(&address_vec, i));
                let (h_price, h_updated_time) = config::get_history_price_data_from_feed(feed);
                assert!(h_price == ((2_000000 * i) as u256), 0);
                assert!(h_updated_time == ((18_000000000 + i) as u64), 0);
                i = i + 1;
            };

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };        

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    // Should update correct timestamp for 0 and non-zero
    public fun test_start_or_continue_diff_threshold2_timer() {
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
            let feed = config::get_price_feed_mut_for_testing(&mut oracle_config, *vector::borrow(&address_vec, 0));

            config::start_or_continue_diff_threshold2_timer_for_testing(feed, 1000);

            let diff_threshold2_timer = config::get_diff_threshold2_timer_from_feed(feed);
            assert!(diff_threshold2_timer == 1000, 0);

            config::start_or_continue_diff_threshold2_timer_for_testing(feed, 2000);

            let diff_threshold2_timer = config::get_diff_threshold2_timer_from_feed(feed);
            assert!(diff_threshold2_timer == 1000, 0);

            // config::reset_diff_threshold2_timer_for_testing(feed);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };        

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    // Should reset timestamp
    public fun test_reset_timestamp() {
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
            let feed = config::get_price_feed_mut_for_testing(&mut oracle_config, *vector::borrow(&address_vec, 0));

            config::start_or_continue_diff_threshold2_timer_for_testing(feed, 1000);

            let diff_threshold2_timer = config::get_diff_threshold2_timer_from_feed(feed);
            assert!(diff_threshold2_timer == 1000, 0);

            config::start_or_continue_diff_threshold2_timer_for_testing(feed, 2000);

            let diff_threshold2_timer = config::get_diff_threshold2_timer_from_feed(feed);
            assert!(diff_threshold2_timer == 1000, 0);

            config::reset_diff_threshold2_timer_for_testing(feed);
            let diff_threshold2_timer = config::get_diff_threshold2_timer_from_feed(feed);
            assert!(diff_threshold2_timer == 0, 0);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };        

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // Should only set enabled oracle as primary
    #[test]
    #[expected_failure(abort_code = 6013, location = oracle::config)]
    public fun test_fail_set_diabled_primary() {
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

            let address_vec = &config::get_vec_feeds(&oracle_config);
            let feed_id = *vector::borrow(address_vec, 0);
            let feed = config::get_price_feed(&oracle_config, feed_id);

            oracle_manage::disable_supra_oracle_provider(&oracle_admin_cap, &mut oracle_config, feed_id); // move to here, primary oracle can not be disable

            // false if same as primary
            oracle_manage::set_primary_oracle_provider(&oracle_admin_cap, &mut oracle_config, feed_id, supra_provider());

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };        

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    //-------------------------- validation  test------------------------------- //
    #[test]
    #[expected_failure(abort_code = 6005, location = oracle::config)]
    public fun test_fail_config_not_found() {
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));
        {
            global::init_protocol(scenario);
        };

        test_scenario::next_tx(scenario, OWNER);
        {
            global::regiter_test_coins(scenario, &mut _clock);
        };

        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);

            let address_vec = config::get_vec_feeds(&oracle_config);
            // let feed = config::get_price_feed(&oracle_config, *vector::borrow(&address_vec, 0));

            let feed_id = config::get_price_feed_id(&oracle_config, *vector::borrow(&address_vec, 8));

            let get_oracle_provider_config = config::get_oracle_provider_config(&oracle_config ,feed_id, supra_provider());
            // let get_oracle_provider_config_2 = config::get_oracle_provider_config_from_feed(feed, supra_provider());

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    #[expected_failure(abort_code = 6005, location = oracle::config)]
    public fun test_fail_config_from_feed_not_found() {
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));
        {
            global::init_protocol(scenario);
        };

        test_scenario::next_tx(scenario, OWNER);
        {
            global::regiter_test_coins(scenario, &mut _clock);
        };

        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);

            let address_vec = config::get_vec_feeds(&oracle_config);
            let feed = config::get_price_feed(&oracle_config, *vector::borrow(&address_vec, 8));

            let _get_oracle_provider_config_2 = config::get_oracle_provider_config_from_feed(feed, supra_provider());

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    #[expected_failure(abort_code = 6000, location = oracle::config)]
    public fun test_fail_get_feed() {
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
            let _feed = config::get_price_feed(&oracle_config, @0xa);

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    #[expected_failure(abort_code = 6000, location = oracle::config)]
    public fun test_fail_get_feed_mut() {
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
            let _feed = config::get_price_feed_mut_for_testing(&mut oracle_config, @0xa);

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    #[expected_failure(abort_code = 6000, location = oracle::config)]
    public fun test_fail_get_history() {
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

            oracle_manage::set_historical_price_ttl_to_price_feed(&oracle_admin_cap, &mut oracle_config, @0xa, 8);

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    #[expected_failure(abort_code = 6000, location = oracle::config)]
    public fun test_fail_set_oracle_provider_config_enable() {
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

            // let address_vec = config::get_vec_feeds(&oracle_config);
            // let feed = config::get_price_feed(&oracle_config, *vector::borrow(&address_vec, 8));
            config::set_oracle_provider_config_enable_for_testing(&mut oracle_config, @0xa, supra_provider(), true);

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    #[expected_failure(abort_code = 6005, location = oracle::config)]
    public fun test_fail_set_oracle_provider_config_enable2() {
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));
        {
            global::init_protocol(scenario);
        };
        
        test_scenario::next_tx(scenario, OWNER);
        {
            global::regiter_test_coins(scenario, &mut _clock);
        };

        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);

            let address_vec = config::get_vec_feeds(&oracle_config);
            config::set_oracle_provider_config_enable_for_testing(&mut oracle_config, *vector::borrow(&address_vec, 8), supra_provider(), true);

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    #[expected_failure(abort_code = 6000, location = oracle::config)]
    public fun test_fail_set_oracle_provider_config_pair() {
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

            // let address_vec = config::get_vec_feeds(&oracle_config);
            // let feed = config::get_price_feed(&oracle_config, *vector::borrow(&address_vec, 8));
            oracle_manage::set_pyth_price_oracle_provider_pair_id(&oracle_admin_cap, &mut oracle_config, @0xa, b"");

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    #[expected_failure(abort_code = 6005, location = oracle::config)]
    public fun test_fail_set_oracle_provider_config_pair2() {
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));
        {
            global::init_protocol(scenario);
        };
        
        test_scenario::next_tx(scenario, OWNER);
        {
            global::regiter_test_coins(scenario, &mut _clock);
        };

        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);

            let address_vec = config::get_vec_feeds(&oracle_config);
            oracle_manage::set_pyth_price_oracle_provider_pair_id(&oracle_admin_cap, &mut oracle_config, *vector::borrow(&address_vec, 8), b"");

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    #[expected_failure(abort_code = 6000, location = oracle::config)]
    public fun test_fail_new_oracle_provider() {
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

            // let address_vec = config::get_vec_feeds(&oracle_config);
            // let feed = config::get_price_feed(&oracle_config, *vector::borrow(&address_vec, 8));
            oracle_manage::create_pyth_oracle_provider_config(&oracle_admin_cap, &mut oracle_config, @0xa, b"", true );

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    #[expected_failure(abort_code = 6000, location = oracle::config)]
    public fun test_fail_set_second_provider() {
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

            // let address_vec = config::get_vec_feeds(&oracle_config);
            // let feed = config::get_price_feed(&oracle_config, *vector::borrow(&address_vec, 8));
            oracle_manage::set_secondary_oracle_provider(&oracle_admin_cap, &mut oracle_config, @0xa, pyth_provider());

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    #[expected_failure(abort_code = 6002, location = oracle::config)]
    public fun test_fail_set_second_provider2() {
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));
        {
            global::init_protocol(scenario);
        };
        
        test_scenario::next_tx(scenario, OWNER);
        {
            global::regiter_test_coins(scenario, &mut _clock);
        };

        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);

            let address_vec = config::get_vec_feeds(&oracle_config);
            oracle_manage::set_secondary_oracle_provider(&oracle_admin_cap, &mut oracle_config, *vector::borrow(&address_vec, 8), pyth_provider());

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    public fun test_same_second_provider() {
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));
        {
            global::init_protocol(scenario);
        };
        
        test_scenario::next_tx(scenario, OWNER);
        {
            global::regiter_test_coins(scenario, &mut _clock);
        };

        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);

            let address_vec = config::get_vec_feeds(&oracle_config);
            oracle_manage::set_secondary_oracle_provider(&oracle_admin_cap, &mut oracle_config, *vector::borrow(&address_vec, 0), supra_provider());

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    public fun test_empty_second_provider() {
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));
        {
            global::init_protocol(scenario);
        };
        
        test_scenario::next_tx(scenario, OWNER);
        {
            global::regiter_test_coins(scenario, &mut _clock);
        };

        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);

            let address_vec = config::get_vec_feeds(&oracle_config);
            oracle_manage::set_secondary_oracle_provider(&oracle_admin_cap, &mut oracle_config, *vector::borrow(&address_vec, 0), new_empty_provider());

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    #[expected_failure(abort_code = 6000, location = oracle::config)]
    public fun test_fail_set_primary_provider() {
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

            // let address_vec = config::get_vec_feeds(&oracle_config);
            // let feed = config::get_price_feed(&oracle_config, *vector::borrow(&address_vec, 8));
            oracle_manage::set_primary_oracle_provider(&oracle_admin_cap, &mut oracle_config, @0xa, pyth_provider());

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    #[expected_failure(abort_code = 6002, location = oracle::config)]
    public fun test_fail_set_primary_provider2() {
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));
        {
            global::init_protocol(scenario);
        };
        
        test_scenario::next_tx(scenario, OWNER);
        {
            global::regiter_test_coins(scenario, &mut _clock);
        };

        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);

            let address_vec = config::get_vec_feeds(&oracle_config);
            oracle_manage::set_primary_oracle_provider(&oracle_admin_cap, &mut oracle_config, *vector::borrow(&address_vec, 8), pyth_provider());

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    public fun test_same_primary_provider() {
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));
        {
            global::init_protocol(scenario);
        };
        
        test_scenario::next_tx(scenario, OWNER);
        {
            global::regiter_test_coins(scenario, &mut _clock);
        };

        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);

            let address_vec = config::get_vec_feeds(&oracle_config);
            oracle_manage::set_primary_oracle_provider(&oracle_admin_cap, &mut oracle_config, *vector::borrow(&address_vec, 0), pyth_provider());

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    #[expected_failure(abort_code = 6000, location = oracle::config)]
    public fun test_fail_set_min() {
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

            // let address_vec = config::get_vec_feeds(&oracle_config);
            // let feed = config::get_price_feed(&oracle_config, *vector::borrow(&address_vec, 8));
            oracle_manage::set_minimum_effective_price_to_price_feed(&oracle_admin_cap, &mut oracle_config, @0xa, 0);

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    #[expected_failure(abort_code = 6014, location = oracle::config)]
    public fun test_fail_set_min2() {
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
            oracle_manage::set_minimum_effective_price_to_price_feed(&oracle_admin_cap, &mut oracle_config, *vector::borrow(&address_vec, 0), 10000000000000000);

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    #[expected_failure(abort_code = 6000, location = oracle::config)]
    public fun test_fail_set_max() {
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

            // let address_vec = config::get_vec_feeds(&oracle_config);
            // let feed = config::get_price_feed(&oracle_config, *vector::borrow(&address_vec, 8));
            oracle_manage::set_maximum_effective_price_to_price_feed(&oracle_admin_cap, &mut oracle_config, @0xa, 0);

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    #[expected_failure(abort_code = 6014, location = oracle::config)]
    public fun test_fail_set_diff2() {
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
            oracle_manage::set_price_diff_threshold2_to_price_feed(&oracle_admin_cap, &mut oracle_config, *vector::borrow(&address_vec, 0), 0);

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    #[expected_failure(abort_code = 6014, location = oracle::config)]
    public fun test_fail_set_diff1() {
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
            oracle_manage::set_price_diff_threshold1_to_price_feed(&oracle_admin_cap, &mut oracle_config, *vector::borrow(&address_vec, 0), 1000000000);

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    public fun test_is_price_feed_exists() {
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
            assert!(config::is_price_feed_exists<PriceOracle>(&oracle_config, 0), 0);

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    #[expected_failure(abort_code = 6200, location = oracle::oracle_version)]
    public fun test_fail_version_check() {
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));
        {
            global::init_protocol(scenario);
        };

        test_scenario::next_tx(scenario, OWNER);
        {
            oracle_version::pre_check_version(constants::version() - 1);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    public fun test_version_migrate_current() {
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

            oracle_manage::version_migrate(&oracle_admin_cap, &mut oracle_config, &mut price_oracle);
            config::version_verification(&oracle_config);
            oracle::version_verification_for_testing(&price_oracle);

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }
    
}
