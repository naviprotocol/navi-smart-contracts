#[test_only]
module oracle::oracle_pro_test {
    use sui::test_scenario;
    use std::vector::{Self};
    use sui::clock::{Self};
    use oracle::oracle::{Self, OracleAdminCap, PriceOracle};
    use oracle::config::{Self, OracleConfig};
    use sui::address;
    use oracle::oracle_manage;
    use oracle::oracle_global::{Self as global};
    use oracle::oracle_pro;
    use oracle::oracle_lib::{Self as lib};
    use oracle::oracle_provider::{pyth_provider, supra_provider, new_empty_provider};

    use oracle::oracle_sui_test::{ORACLE_SUI_TEST};


    const OWNER: address = @0xA;


    // update_prices

    // Should update 0/1/8 prices
    // Should update other prices when with 1 failed price feed
    #[test]
    public fun test_update_prices_many() {
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));

        let in_primary_prices = vector::empty<u256>();
        let in_primary_updated_times = vector::empty<u64>();
        let in_secondary_prices = vector::empty<u256>();
        let in_secondary_updated_times = vector::empty<u64>();
        {
            global::init_protocol(scenario);
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
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);

            let time = 86400 * 1000;
            let expired_time =  time - 1000 * 60;
            clock::set_for_testing(&mut _clock, time);

            // check 0 prices
            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);
            assert!(!valid, 0);
            assert!(price == 1_000000, 0);
            assert!(decimal == 6, 0);

            // update 0-7 prices
            lib::push_price_params(1_000001, time, 1_000001, time, &mut in_primary_prices, &mut in_primary_updated_times, &mut in_secondary_prices, &mut in_secondary_updated_times);
            lib::push_price_params(1_000001, time, 1_000001, time, &mut in_primary_prices, &mut in_primary_updated_times, &mut in_secondary_prices, &mut in_secondary_updated_times);
            lib::push_price_params(1_000001, time, 1_000001, time, &mut in_primary_prices, &mut in_primary_updated_times, &mut in_secondary_prices, &mut in_secondary_updated_times);
            lib::push_price_params(1_000001, time, 1_000001, time, &mut in_primary_prices, &mut in_primary_updated_times, &mut in_secondary_prices, &mut in_secondary_updated_times);
            lib::push_price_params(1_0001, time, 1_0001, time, &mut in_primary_prices, &mut in_primary_updated_times, &mut in_secondary_prices, &mut in_secondary_updated_times);
            lib::push_price_params(1_00001, time, 1_00001, time, &mut in_primary_prices, &mut in_primary_updated_times, &mut in_secondary_prices, &mut in_secondary_updated_times);
            lib::push_price_params(1_000001, time, 1_000001, time, &mut in_primary_prices, &mut in_primary_updated_times, &mut in_secondary_prices, &mut in_secondary_updated_times);
            lib::push_price_params(1_0000001, time, 1_0000001, time, &mut in_primary_prices, &mut in_primary_updated_times, &mut in_secondary_prices, &mut in_secondary_updated_times);
            lib::push_price_params(0, time, 0, time, &mut in_primary_prices, &mut in_primary_updated_times, &mut in_secondary_prices, &mut in_secondary_updated_times);

            oracle_pro::update_prices_for_testing(&_clock, &mut oracle_config, &mut price_oracle, &in_primary_prices, &in_primary_updated_times, &in_secondary_prices, &in_secondary_updated_times);

            // verify price
            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);
            assert!(valid, 0);
            assert!(price == 1_000001, 0);
            assert!(decimal == 6, 0);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 1);
            assert!(valid, 0);
            assert!(price == 1_000001, 0);
            assert!(decimal == 6, 0);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 2);
            assert!(valid, 0);
            assert!(price == 1_000001, 0);
            assert!(decimal == 6, 0);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 3);
            assert!(valid, 0);
            assert!(price == 1_000001, 0);
            assert!(decimal == 6, 0);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 4);
            assert!(valid, 0);
            assert!(price == 1_0001, 0);
            assert!(decimal == 4, 0);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 5);
            assert!(valid, 0);
            assert!(price == 1_00001, 0);
            assert!(decimal == 5, 0);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 6);
            assert!(valid, 0);
            assert!(price == 1_000001, 0);
            assert!(decimal == 6, 0);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 7);
            assert!(valid, 0);
            assert!(price == 1_0000001, 0);
            assert!(decimal == 7, 0);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
            test_scenario::return_to_sender(scenario, oracle_admin_cap);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // Should update other prices when with 2 failed price feed
    #[test]
    public fun test_update_prices_many_2_failed() {
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));

        let in_primary_prices = vector::empty<u256>();
        let in_primary_updated_times = vector::empty<u64>();
        let in_secondary_prices = vector::empty<u256>();
        let in_secondary_updated_times = vector::empty<u64>();
        {
            global::init_protocol(scenario);
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
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);

            let time = 86400 * 1000;
            let expired_time =  time - 1000 * 60;
            clock::set_for_testing(&mut _clock, time);

            // check 0 prices
            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);
            assert!(!valid, 0);
            assert!(price == 1_000000, 0);
            assert!(decimal == 6, 0);

            // update 0-7 prices
            // id:1 fails by expired
            // id:7 fails by price diff
            lib::push_price_params(1_000001, time, 1_000001, time, &mut in_primary_prices, &mut in_primary_updated_times, &mut in_secondary_prices, &mut in_secondary_updated_times);
            lib::push_price_params(1_000001, expired_time, 1_000001, expired_time, &mut in_primary_prices, &mut in_primary_updated_times, &mut in_secondary_prices, &mut in_secondary_updated_times);
            lib::push_price_params(1_000001, time, 1_000001, time, &mut in_primary_prices, &mut in_primary_updated_times, &mut in_secondary_prices, &mut in_secondary_updated_times);
            lib::push_price_params(1_000001, time, 1_000001, time, &mut in_primary_prices, &mut in_primary_updated_times, &mut in_secondary_prices, &mut in_secondary_updated_times);
            lib::push_price_params(1_0001, time, 1_0001, time, &mut in_primary_prices, &mut in_primary_updated_times, &mut in_secondary_prices, &mut in_secondary_updated_times);
            lib::push_price_params(1_00001, time, 1_00001, time, &mut in_primary_prices, &mut in_primary_updated_times, &mut in_secondary_prices, &mut in_secondary_updated_times);
            lib::push_price_params(1_000001, time, 1_000001, time, &mut in_primary_prices, &mut in_primary_updated_times, &mut in_secondary_prices, &mut in_secondary_updated_times);
            lib::push_price_params(10_0000001, time, 1_0000001, time, &mut in_primary_prices, &mut in_primary_updated_times, &mut in_secondary_prices, &mut in_secondary_updated_times);
            lib::push_price_params(0, time, 0, time, &mut in_primary_prices, &mut in_primary_updated_times, &mut in_secondary_prices, &mut in_secondary_updated_times);

            oracle_pro::update_prices_for_testing(&_clock, &mut oracle_config, &mut price_oracle, &in_primary_prices, &in_primary_updated_times, &in_secondary_prices, &in_secondary_updated_times);

            // verify price
            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);
            assert!(valid, 0);
            assert!(price == 1_000001, 0);
            assert!(decimal == 6, 0);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 1);
            assert!(!valid, 0);
            assert!(price == 1_000000, 0);
            assert!(decimal == 6, 0);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 2);
            assert!(valid, 0);
            assert!(price == 1_000001, 0);
            assert!(decimal == 6, 0);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 3);
            assert!(valid, 0);
            assert!(price == 1_000001, 0);
            assert!(decimal == 6, 0);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 4);
            assert!(valid, 0);
            assert!(price == 1_0001, 0);
            assert!(decimal == 4, 0);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 5);
            assert!(valid, 0);
            assert!(price == 1_00001, 0);
            assert!(decimal == 5, 0);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 6);
            assert!(valid, 0);
            assert!(price == 1_000001, 0);
            assert!(decimal == 6, 0);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 7);
            assert!(!valid, 0);
            assert!(price == 1_0000000, 0);
            assert!(decimal == 7, 0);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
            test_scenario::return_to_sender(scenario, oracle_admin_cap);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    #[expected_failure(abort_code = 6006, location = oracle::oracle_pro)]
    public fun test_pause_failed() {
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

            oracle_manage::set_pause(&oracle_admin_cap, &mut oracle_config, true);
            let address_vec = config::get_vec_feeds(&oracle_config);
            let feed_id = *vector::borrow(&address_vec, 0);

            let time = 86400 * 1000;
            clock::increment_for_testing(&mut _clock, time);
            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, 1_000001, time, 1_000001, time, feed_id);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);

            lib::print(&valid);
            lib::print(&price);
            lib::print(&decimal);

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // primary_valid = [0, 1]
    // primary_fresh = [0, 1]
    // second_valid = [0, 1]
    // second_fresh = [0, 1]
    // range_diff = [0, 1, 2]  # 0 not in range, 1 in diff1, 2 in diff2
    // in_range = [0, 1]
    // history = [0, 1]

    // (0, 0, 0, 0, 0, 0, 0)
    #[test]
    #[expected_failure(abort_code = 1, location = oracle::oracle_pro)]
    public fun base_test_1() {
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
            let feed_id = *vector::borrow(&address_vec, 0);

            let time = 86400 * 1000;
            clock::increment_for_testing(&mut _clock, time);
            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, 1_000001, time, 1_000001, time, feed_id);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);

            lib::print(&valid);
            lib::print(&price);
            lib::print(&decimal);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // (1, 0, 0, 0, 0, 0, 0)
    #[test]
    #[expected_failure(abort_code = 3, location = oracle::oracle_pro)]
    public fun base_test_2() {
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));
        {
            global::init_protocol_without_provider(scenario);
        };

        // set provider
        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);

            let address_vec = config::get_vec_feeds(&oracle_config);
            let feed_id = *vector::borrow(&address_vec, 0);
            
            oracle_manage::set_primary_oracle_provider(&oracle_admin_cap, &mut oracle_config, feed_id, pyth_provider());

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
            test_scenario::return_to_sender(scenario, oracle_admin_cap);
        };

        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);

            let address_vec = config::get_vec_feeds(&oracle_config);
            let feed_id = *vector::borrow(&address_vec, 0);

            let time = 86400 * 1000;
            let expired_time =  time - 1000 * 60;

            clock::increment_for_testing(&mut _clock, time);
            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, 1_000001, expired_time, 1_000001, time, feed_id);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);

            lib::print(&valid);
            lib::print(&price);
            lib::print(&decimal);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // (1, 0, 1, 0, 0, 0, 0)
    #[test]
    #[expected_failure(abort_code = 3, location = oracle::oracle_pro)]
    public fun base_test_3() {
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
            let feed_id = *vector::borrow(&address_vec, 0);

            let time = 86400 * 1000;
            let expired_time =  time - 1000 * 60;

            clock::increment_for_testing(&mut _clock, time);
            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, 1_000001, expired_time, 1_000001, expired_time, feed_id);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);

            lib::print(&valid);
            lib::print(&price);
            lib::print(&decimal);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // (1, 0, 1, 1, 1, 0, 0)
    #[test]
    #[expected_failure(abort_code = 4, location = oracle::oracle_pro)]
    public fun base_test_4() {
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
            let feed_id = *vector::borrow(&address_vec, 0);

            let time = 86400 * 1000;
            let expired_time =  time - 1000 * 60;

            clock::increment_for_testing(&mut _clock, time);
            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, 10_000001, expired_time, 10_000001, time, feed_id);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);

            lib::print(&valid);
            lib::print(&price);
            lib::print(&decimal);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // (1, 0, 1, 1, 1, 1, 0)
    #[test]
    #[expected_failure(abort_code = 4, location = oracle::oracle_pro)]
    public fun base_test_5() {
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
            let feed_id = *vector::borrow(&address_vec, 0);

            let time = 1000 * 50;
            let expired_time =  time - 1000 * 40;

            clock::increment_for_testing(&mut _clock, time);
            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, 9_000001, expired_time, 9_000001, time, feed_id);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);

            lib::print(&valid);
            lib::print(&price);
            lib::print(&decimal);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // (1, 0, 1, 1, 1, 1, 1)
    #[test]
    public fun base_test_6() {
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
            let feed_id = *vector::borrow(&address_vec, 0);

            let time = 86400 * 1000;
            let expired_time =  time - 1000 * 60;

            clock::increment_for_testing(&mut _clock, time);
            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, 9_000001, expired_time, 9_000001, time, feed_id);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);

            std::debug::print(&decimal);
            assert!(valid, 0);
            assert!(price == 9_000001, 0);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // (1, 1, 0, 0, 1, 0, 0)
    #[test]
    #[expected_failure(abort_code = 4, location = oracle::oracle_pro)]
    public fun base_test_7() {
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));
        {
            global::init_protocol_without_provider(scenario);
        };
    
        // set provider
        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);

            let address_vec = config::get_vec_feeds(&oracle_config);
            let feed_id = *vector::borrow(&address_vec, 0);
            
            oracle_manage::set_primary_oracle_provider(&oracle_admin_cap, &mut oracle_config, feed_id, pyth_provider());

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
            test_scenario::return_to_sender(scenario, oracle_admin_cap);
        };

        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);

            let address_vec = config::get_vec_feeds(&oracle_config);
            let feed_id = *vector::borrow(&address_vec, 0);

            let time = 86400 * 1000;
            let expired_time =  time - 1000 * 60;

            clock::increment_for_testing(&mut _clock, time);
            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, 10_000001, time, 10_000001, expired_time, feed_id);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);

            std::debug::print(&decimal);
            assert!(valid, 0);
            assert!(price == 9_000001, 0);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // (1, 1, 0, 0, 1, 1, 0)
    #[test]
    #[expected_failure(abort_code = 4, location = oracle::oracle_pro)]
    public fun base_test_8() {
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));
        {
            global::init_protocol_without_provider(scenario);
        };
    
        // set provider
        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);

            let address_vec = config::get_vec_feeds(&oracle_config);
            let feed_id = *vector::borrow(&address_vec, 0);
            
            oracle_manage::set_primary_oracle_provider(&oracle_admin_cap, &mut oracle_config, feed_id, pyth_provider());

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
            test_scenario::return_to_sender(scenario, oracle_admin_cap);
        };

        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);

            let address_vec = config::get_vec_feeds(&oracle_config);
            let feed_id = *vector::borrow(&address_vec, 0);

            let time = 1000 * 50;
            let expired_time =  time - 1000 * 40;

            clock::increment_for_testing(&mut _clock, time);
            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, 9_000001, time, 9_000001, expired_time, feed_id);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);

            std::debug::print(&valid);
            std::debug::print(&price);
            std::debug::print(&decimal);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // (1, 1, 0, 0, 1, 1, 1)
    #[test]
    public fun base_test_9() {
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));
        {
            global::init_protocol_without_provider(scenario);
        };
    
        // set provider
        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);

            let address_vec = config::get_vec_feeds(&oracle_config);
            let feed_id = *vector::borrow(&address_vec, 0);
            
            oracle_manage::set_primary_oracle_provider(&oracle_admin_cap, &mut oracle_config, feed_id, pyth_provider());

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
            test_scenario::return_to_sender(scenario, oracle_admin_cap);
        };

        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);

            let address_vec = config::get_vec_feeds(&oracle_config);
            let feed_id = *vector::borrow(&address_vec, 0);

            let time = 86400 * 1000;
            let expired_time =  time - 1000 * 60;

            clock::increment_for_testing(&mut _clock, time);
            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, 9_000001, time, 9_000001, expired_time, feed_id);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);

            std::debug::print(&decimal);
            assert!(valid, 0);
            assert!(price == 9_000001, 0);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // (1, 1, 1, 0, 1, 0, 0)
    #[test]
    #[expected_failure(abort_code = 4, location = oracle::oracle_pro)]
    public fun base_test_10() {
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
            let feed_id = *vector::borrow(&address_vec, 0);

            let time = 86400 * 1000;
            let expired_time =  time - 1000 * 60;

            clock::increment_for_testing(&mut _clock, time);
            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, 10_000001, time, 10_000001, expired_time, feed_id);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);

            std::debug::print(&decimal);
            assert!(valid, 0);
            assert!(price == 9_000001, 0);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // (1, 1, 1, 0, 1, 1, 0)
    #[test]
    #[expected_failure(abort_code = 4, location = oracle::oracle_pro)]
    public fun base_test_11() {
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
            let feed_id = *vector::borrow(&address_vec, 0);

            let time = 50 * 1000;
            let expired_time =  time - 1000 * 40;

            clock::increment_for_testing(&mut _clock, time);
            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, 9_000001, time, 9_000001, expired_time, feed_id);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);

            std::debug::print(&decimal);
            assert!(valid, 0);
            assert!(price == 9_000001, 0);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // (1, 1, 1, 0, 1, 1, 1)
    #[test]
    public fun base_test_12() {
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
            let feed_id = *vector::borrow(&address_vec, 0);

            let time = 86400 * 1000;
            let expired_time =  time - 1000 * 40;

            clock::increment_for_testing(&mut _clock, time);
            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, 9_000001, time, 9_000001, expired_time, feed_id);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);

            std::debug::print(&decimal);
            assert!(valid, 0);
            assert!(price == 9_000001, 0);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // (1, 1, 1, 1, 0, 0, 0)
    #[test]
    #[expected_failure(abort_code = 2, location = oracle::oracle_pro)]
    public fun base_test_13() {
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
            let feed_id = *vector::borrow(&address_vec, 0);

            let time = 86400 * 1000;
            let expired_time =  time - 1000 * 40;
            std::debug::print(&expired_time);

            clock::increment_for_testing(&mut _clock, time);
            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, 9_000001, time, 11_000001, time, feed_id);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);

            std::debug::print(&decimal);
            assert!(valid, 0);
            assert!(price == 9_000001, 0);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // (1, 1, 1, 1, 1, 0, 0)
    #[test]
    #[expected_failure(abort_code = 4, location = oracle::oracle_pro)]
    public fun base_test_14() {
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
            let feed_id = *vector::borrow(&address_vec, 0);

            let time = 86400 * 1000;
            let expired_time =  time - 1000 * 40;
            std::debug::print(&expired_time);

            clock::increment_for_testing(&mut _clock, time);
            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, 10_000001, time, 10_000001, time, feed_id);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);

            std::debug::print(&decimal);
            assert!(valid, 0);
            assert!(price == 9_000001, 0);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // (1, 1, 1, 1, 1, 1, 0)
    #[test]
    #[expected_failure(abort_code = 4, location = oracle::oracle_pro)]
    public fun base_test_15() {
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
            let feed_id = *vector::borrow(&address_vec, 0);

            let time = 50 * 1000;
            let expired_time =  time - 1000 * 40;
            std::debug::print(&expired_time);

            clock::increment_for_testing(&mut _clock, time);
            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, 9_000001, time, 9_000001, time, feed_id);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);

            std::debug::print(&decimal);
            assert!(valid, 0);
            assert!(price == 9_000001, 0);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // (1, 1, 1, 1, 1, 1, 1)
    #[test]
    public fun base_test_16() {
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
            let feed_id = *vector::borrow(&address_vec, 0);

            let time = 86400 * 1000;
            let expired_time =  time - 1000 * 40;
            std::debug::print(&expired_time);

            clock::increment_for_testing(&mut _clock, time);
            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, 9_000001, time, 9_000001, time, feed_id);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);

            std::debug::print(&decimal);
            assert!(valid, 0);
            assert!(price == 9_000001, 0);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // (1, 1, 1, 1, 1, 1, 1) - 2
    // set secondary provider back to empty 
    #[test]
    public fun base_test_16_2() {
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
            let feed_id = *vector::borrow(&address_vec, 0);

            let time = 86400 * 1000;
            let expired_time =  time - 1000 * 40;
            std::debug::print(&expired_time);

            clock::increment_for_testing(&mut _clock, time);


            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, 9_000001, time, 9_000001, time, feed_id);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);

            std::debug::print(&decimal);
            assert!(valid, 0);
            assert!(price == 9_000001, 0);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };

        test_scenario::next_tx(scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);

            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);
            let address_vec = config::get_vec_feeds(&oracle_config);
            let feed_id = *vector::borrow(&address_vec, 0);

            let time = 86400 * 1000 * 2;
            let expired_time =  time - 1000 * 40;
            std::debug::print(&expired_time);


            clock::increment_for_testing(&mut _clock, time / 2);
            oracle_manage::set_secondary_oracle_provider(&oracle_admin_cap, &mut oracle_config, feed_id, new_empty_provider());

            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, 9_000002, time, 9_000002, time, feed_id);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);

            std::debug::print(&decimal);
            assert!(valid, 0);
            assert!(price == 9_000002, 0);

            test_scenario::return_to_sender(scenario, oracle_admin_cap);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // (1, 1, 1, 1, 2, 0, 0)
    #[test]
    #[expected_failure(abort_code = 4, location = oracle::oracle_pro)]
    public fun base_test_17() {
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
            let feed_id = *vector::borrow(&address_vec, 0);

            let time = 86400 * 1000;
            let expired_time =  time - 1000 * 40;
            std::debug::print(&expired_time);

            clock::increment_for_testing(&mut _clock, time);
            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, 0_90000, time, 0_80000, time, feed_id);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);

            std::debug::print(&decimal);
            assert!(valid, 0);
            assert!(price == 10_000000, 0);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // (1, 1, 1, 1, 2, 1, 0)
    #[test]
    #[expected_failure(abort_code = 4, location = oracle::oracle_pro)]
    public fun base_test_18() {
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
            let feed_id = *vector::borrow(&address_vec, 0);

            let time = 50 * 1000;
            let expired_time =  time - 1000 * 40;
            std::debug::print(&expired_time);

            clock::increment_for_testing(&mut _clock, time);
            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, 10_000000, time, 11_500000, time, feed_id);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);

            std::debug::print(&decimal);
            assert!(valid, 0);
            assert!(price == 10_000000, 0);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // (1, 1, 1, 1, 2, 1, 1)
    #[test]
    public fun base_test_19() {
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
            let feed_id = *vector::borrow(&address_vec, 0);

            let time = 86400 * 1000;
            let expired_time =  time - 1000 * 40;
            std::debug::print(&expired_time);

            clock::increment_for_testing(&mut _clock, time);
            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, 10_000000, time, 11_500000, time, feed_id);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);

            std::debug::print(&decimal);
            assert!(valid, 0);
            assert!(price == 10_000000, 0);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    #[expected_failure(abort_code = 4, location = oracle::oracle_pro)]
    public fun base_test_max() {
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
            let feed_id = *vector::borrow(&address_vec, 0);

            let time = 86400 * 1000;
            let expired_time =  time - 1000 * 40;
            std::debug::print(&expired_time);

            clock::increment_for_testing(&mut _clock, time);
            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, address::max(), time, address::max(), time, feed_id);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);

            std::debug::print(&decimal);
            assert!(valid, 0);
            assert!(price == 9_000001, 0);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    #[expected_failure(abort_code = 4, location = oracle::oracle_pro)]
    public fun base_test_price1() {
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
            let feed_id = *vector::borrow(&address_vec, 0);

            let time = 86400 * 1000;
            let expired_time =  time - 1000 * 40;
            std::debug::print(&expired_time);

            clock::increment_for_testing(&mut _clock, time);
            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, 1, time, 1, time, feed_id);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);

            std::debug::print(&decimal);
            assert!(valid, 0);
            assert!(price == 9_000001, 0);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    #[expected_failure(abort_code = 2, location = oracle::oracle_pro)]
    public fun base_test_price0() {
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
            let feed_id = *vector::borrow(&address_vec, 0);

            let time = 86400 * 1000;
            let expired_time =  time - 1000 * 40;
            std::debug::print(&expired_time);

            clock::increment_for_testing(&mut _clock, time);
            oracle_pro::update_single_price_for_testing(&_clock, &mut oracle_config, &mut price_oracle, 0, time, 0, time, feed_id);

            let (valid, price, decimal) = oracle::get_token_price(&_clock, &price_oracle, 0);

            std::debug::print(&decimal);
            assert!(valid, 0);
            assert!(price == 9_000001, 0);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }
}