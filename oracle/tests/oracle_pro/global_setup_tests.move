#[test_only]
module oracle::oracle_global {
    use sui::clock::{Self, Clock};
    use std::vector::{Self};
    use sui::test_scenario::{Self, Scenario};
    use oracle::config::{Self, OracleConfig};

    use oracle::oracle_manage;
    use oracle::oracle_provider::{supra_provider, pyth_provider, test_provider};

    use oracle::oracle::{Self, OracleAdminCap, PriceOracle};

    use oracle::oracle_sui_test::{ORACLE_SUI_TEST};
    use oracle::test_coin1::{TEST_COIN1};
    use oracle::test_coin2::{TEST_COIN2};
    use oracle::test_coin3::{TEST_COIN3};
    use oracle::test_coin4::{TEST_COIN4};
    use oracle::test_coin5::{TEST_COIN5};
    use oracle::test_coin6::{TEST_COIN6};
    use oracle::test_coin7::{TEST_COIN7};
    use oracle::test_coin8::{TEST_COIN8};

    use oracle::oracle_lib;

    const OWNER: address = @0xA;

    #[test_only]
    public fun init_protocol(scenario_mut: &mut Scenario) {
        let owner = test_scenario::sender(scenario_mut);
        let clock = {
            let ctx = test_scenario::ctx(scenario_mut);
            clock::create_for_testing(ctx)
        };

        // Protocol init
        test_scenario::next_tx(scenario_mut, owner);
        {
            // Price Oracle init
            oracle::init_for_testing(test_scenario::ctx(scenario_mut));
        };

        test_scenario::next_tx(scenario_mut, owner);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario_mut);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario_mut);
            let ctx = test_scenario::ctx(scenario_mut);

            // OracleConfig create
            oracle_manage::create_config(&oracle_admin_cap, ctx);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_to_sender(scenario_mut, oracle_admin_cap);

        };

        create_price_feed_and_provider<ORACLE_SUI_TEST>(scenario_mut, &mut clock, 0, 6);

        // set provider
        test_scenario::next_tx(scenario_mut, owner);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario_mut);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario_mut);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario_mut);

            let address_vec = config::get_vec_feeds(&oracle_config);
            let feed_id = *vector::borrow(&address_vec, 0);

            oracle_manage::set_primary_oracle_provider(&oracle_admin_cap, &mut oracle_config, feed_id, pyth_provider());
            oracle_manage::set_secondary_oracle_provider(&oracle_admin_cap, &mut oracle_config, feed_id, supra_provider());

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
            test_scenario::return_to_sender(scenario_mut, oracle_admin_cap);

        };

        clock::destroy_for_testing(clock);
    }

    public fun regiter_test_coins(scenario: &mut Scenario, clock: &mut Clock) {

        create_price_feed_and_provider<TEST_COIN1>(scenario, clock, 1, 6);
        create_price_feed_and_provider<TEST_COIN2>(scenario, clock, 2, 6);
        create_price_feed_and_provider<TEST_COIN3>(scenario, clock, 3, 6);
        create_price_feed_and_provider<TEST_COIN4>(scenario, clock, 4, 4);
        create_price_feed_and_provider<TEST_COIN5>(scenario, clock, 5, 5);
        create_price_feed_and_provider<TEST_COIN6>(scenario, clock, 6, 6);
        create_price_feed_and_provider<TEST_COIN7>(scenario, clock, 7, 7);
        // specail case for no provider 
        create_price_feed<TEST_COIN8>(scenario, clock, 8, 8);

        test_scenario::next_tx(scenario, OWNER);
        {
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);

            let address_vec = config::get_vec_feeds(&oracle_config);

            let i = 1;
            while (i <= 7) {
                let feed_id = *vector::borrow(&address_vec, i);
                oracle_manage::set_primary_oracle_provider(&oracle_admin_cap, &mut oracle_config, feed_id, pyth_provider());
                oracle_manage::set_secondary_oracle_provider(&oracle_admin_cap, &mut oracle_config, feed_id, supra_provider());
                i = i + 1;
            };

            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(oracle_config);
        }
    }

    #[test_only]
    public fun init_protocol_without_provider(scenario_mut: &mut Scenario) {
        let owner = test_scenario::sender(scenario_mut);
        let clock = {
            let ctx = test_scenario::ctx(scenario_mut);
            clock::create_for_testing(ctx)
        };

        // Protocol init
        test_scenario::next_tx(scenario_mut, owner);
        {
            // Price Oracle init
            oracle::init_for_testing(test_scenario::ctx(scenario_mut));
        };

        test_scenario::next_tx(scenario_mut, owner);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario_mut);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario_mut);
            let ctx = test_scenario::ctx(scenario_mut);

            // OracleConfig create
            oracle_manage::create_config(&oracle_admin_cap, ctx);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_to_sender(scenario_mut, oracle_admin_cap);

        };

        create_price_feed_and_provider<ORACLE_SUI_TEST>(scenario_mut, &mut clock, 0, 6);

        clock::destroy_for_testing(clock);
    }

    #[test_only]
    public fun create_price_feed_and_provider<CoinType>(scenario_mut: &mut Scenario, clock: &mut Clock, oracle_id: u8, decimal: u8) {
        let owner = test_scenario::sender(scenario_mut);

        create_price_feed<CoinType>(scenario_mut, clock, oracle_id, decimal);

        // create provider
        test_scenario::next_tx(scenario_mut, owner);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario_mut);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario_mut);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario_mut);
            // let ctx = test_scenario::ctx(scenario_mut);

            let address_vec = config::get_vec_feeds(&oracle_config);
            let feed_id = *vector::borrow(&address_vec, (oracle_id as u64));
            let pair_id = b"00";
            oracle_manage::create_pyth_oracle_provider_config(
                &oracle_admin_cap,
                &mut oracle_config,
                feed_id,
                pair_id, 
                true);

            oracle_manage::create_supra_oracle_provider_config(
                &oracle_admin_cap,
                &mut oracle_config,
                feed_id,
                0, 
                true);

            config::new_oracle_provider_config_for_testing(&mut oracle_config, feed_id, test_provider(), b"0", true);

            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
            test_scenario::return_to_sender(scenario_mut, oracle_admin_cap);
        };
    }

    #[test_only]
    public fun create_price_feed<CoinType>(scenario_mut: &mut Scenario, clock: &mut Clock, oracle_id: u8, decimal: u8) {
        let owner = test_scenario::sender(scenario_mut);

        test_scenario::next_tx(scenario_mut, owner);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario_mut);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario_mut);

            // PriceFeed init
            oracle::register_token_price(
                &oracle_admin_cap,
                clock,
                &mut price_oracle,
                oracle_id,
                (oracle_lib::pow(10, (decimal as u64)) as u256),
                decimal,
            );
            test_scenario::return_shared(price_oracle);
            test_scenario::return_to_sender(scenario_mut, oracle_admin_cap);

        };

        test_scenario::next_tx(scenario_mut, owner);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario_mut);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario_mut);
            let oracle_config = test_scenario::take_shared<OracleConfig>(scenario_mut);
            let ctx = test_scenario::ctx(scenario_mut);

            oracle_manage::create_price_feed<CoinType>(
                &oracle_admin_cap,
                &mut oracle_config,
                oracle_id,
                60 * 1000, // max_timestamp_diff
                1000, // price_diff_ratio1
                2000, // price_diff_ratio2
                10 * 1000, // maximum_allowed_ratio2_ttl
                2000 , // maximum_allowed_span_percentage histroy
                (oracle_lib::pow(10, (decimal as u64)) as u256) * 10, // max price 
                (oracle_lib::pow(10, (decimal as u64)) as u256) / 10, // min price
                60 * 1000, // historical_price_ttl
                ctx
            );
            test_scenario::return_shared(price_oracle);
            test_scenario::return_shared(oracle_config);
            test_scenario::return_to_sender(scenario_mut, oracle_admin_cap);
        };
    }

}

#[test_only]
module oracle::oracle_lib {
    // use sui::math;
    use std::vector::{Self};

    #[test_only]
    public fun printf(str: vector<u8>) {
        std::debug::print(&std::ascii::string(str))
    }

    #[test_only]
    public fun print<T>(x: &T) {
        std::debug::print(x)
    }

    #[test_only]
    public fun print_u256(str: vector<u8>, value: u256) {
        std::vector::append(&mut str, b": ");
        let c = sui::hex::encode(sui::address::to_bytes(sui::address::from_u256(value)));
        std::vector::append(&mut str, c);
        std::debug::print(&std::ascii::string(str));
    }

    #[test_only]
    #[allow(unused_assignment)]
    public fun close_to(v1: u64, v2:u64, diff_digit: u64) {
        if (diff_digit == 0) {
            diff_digit = pow(10, 9);
        } else {
            diff_digit = pow(10, diff_digit);
        };

        let n_diff = 0;
        if (v1 > v2) {
            n_diff = v1 - v2
        } else {
            n_diff = v2 - v1;
        };
        assert!(n_diff <= diff_digit, 0);
    }

    #[test_only]
    public fun pow(n: u64, p: u64): u64 {
        if (p == 0) {
            return 1
        };
        let res = 1;
        while (p > 0) {
            res = res * n;
            p = p - 1;
        };
        res
    }
    #[test_only]
    public fun push_price_params(
        in_primary_price: u256, 
        in_primary_updated_time: u64, 
        in_secondary_price: u256, 
        in_secondary_updated_time: u64,
        in_primary_prices: &mut vector<u256>, 
        in_primary_updated_times: &mut vector<u64>, 
        in_secondary_prices: &mut vector<u256>, 
        in_secondary_updated_times: &mut vector<u64>,
    ) {
        vector::push_back(in_primary_prices, in_primary_price);
        vector::push_back(in_primary_updated_times, in_primary_updated_time);
        vector::push_back(in_secondary_prices, in_secondary_price);
        vector::push_back(in_secondary_updated_times, in_secondary_updated_time);
    }
}