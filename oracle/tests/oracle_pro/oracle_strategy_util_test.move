#[test_only]
module oracle::oracle_strategy_util_test {
    use sui::test_scenario;
    use std::vector::{Self};
    use sui::clock::{Self};
    use oracle::oracle::{Self, OracleAdminCap, PriceOracle};
    use oracle::config::{Self, OracleConfig};

    use oracle::oracle_utils;
    use oracle::oracle_global::{Self as global};
    use oracle::oracle_pro;
    use oracle::strategy;
    use oracle::oracle_lib::{Self as lib};
    use oracle::oracle_constants::{Self as constants};
    use oracle::oracle_provider::{supra_provider, pyth_provider, new_empty_provider};

    const OWNER: address = @0xA;

    // strategy
    #[test]
    public fun test_validate_price_difference() {
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, OWNER);
        {
            // Should validate price difference when a > b but in diff1
            let res = strategy::validate_price_difference(1_099999, 1_000000,1000, 2000, 1000, 1000, 1);
            assert!(res == constants::level_normal(), 0);
            
            // Should validate price difference when a <= b but in diff1
            let res = strategy::validate_price_difference(1_000000, 1_099999,1000, 2000, 1000, 1000, 1);
            assert!(res == constants::level_normal(), 0);

            // Should validate price difference when a > b but in diff2
            let res = strategy::validate_price_difference(1_000000,1_200000,1000, 2000, 1000, 1000, 1);
            assert!(res == constants::level_warning(), 0);

            // Should validate price difference when a <= b but in diff2
            let res = strategy::validate_price_difference(1_000000, 1_200000,1000, 2000, 1000, 1000, 1);
            assert!(res == constants::level_warning(), 0);

            // Should fail if price diff > diff2
            let res = strategy::validate_price_difference( 1_000000, 1_201000, 1000, 2000, 1000, 1000, 1);
            assert!(res == constants::level_critical(), 0);

            // Should fail when timer exceeds limit 
            let res = strategy::validate_price_difference(1_000000, 1_200000, 1000, 2000, 1002, 1000, 1);
            assert!(res == constants::level_major(), 0);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    public fun test_validate_price_range_and_history() {
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));
        {

            // Should validate price in range and history
            let time_past_in_sec = 10;
            let res = strategy::validate_price_range_and_history(1_000000, 10_000000, 0_100000, 1000, 1_700000000, 60, 1_000000, 1_700000000 - time_past_in_sec);
            assert!(res, 0);

            // Should validate price in range and no history
            let time_past_in_sec = 1_700000000;
            let res = strategy::validate_price_range_and_history(1_000000, 10_000000, 0_100000, 1000, 1_700000000, 60, 1_000000, 1_700000000 - time_past_in_sec);
            assert!(res, 0);

            // Should validate price in range and expired history
            let time_past_in_sec = 61;
            let res = strategy::validate_price_range_and_history(1_000000, 10_000000, 0_100000, 1000, 1_700000000, 60, 1_000000, 1_700000000 - time_past_in_sec);
            assert!(res, 0);

            // Should fail when price < min
            let time_past_in_sec = 61;
            let res = strategy::validate_price_range_and_history(0_099999, 10_000000, 0_100000, 1000, 1_700000000, 60, 1_000000, 1_700000000 - time_past_in_sec);
            assert!(!res, 0);

            // Should fail when price > max
            let time_past_in_sec = 61;
            let res = strategy::validate_price_range_and_history(10_000001, 10_000000, 0_100000, 1000, 1_700000000, 60, 1_000000, 1_700000000 - time_past_in_sec);
            assert!(!res, 0);

            // Should fail when price changes over span
            let time_past_in_sec = 10;
            let res = strategy::validate_price_range_and_history(1_100100, 10_000000, 0_100000, 1000, 1_700000000, 60, 1_000000, 1_700000000 - time_past_in_sec);
            assert!(!res, 0);

            // Should fail when max = 0
            let time_past_in_sec = 10;
            let res = strategy::validate_price_range_and_history(1, 10, 0, 1000, 1_700000000, 60, 1_000000, 1_700000000 - time_past_in_sec);
            assert!(!res, 0);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }


    #[test]
    public fun test_abnormal_update_time() {
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));
        {

            // Should validate price in range and history
            let time_past_in_sec = 10;
            let res = strategy::is_oracle_price_fresh(0, 1, 1);
            assert!(!res, 0);
        };
            clock::destroy_for_testing(_clock);
            test_scenario::end(_scenario);
    }

    // util
    #[test]
    public fun test_to_target_decimal_value() {
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, OWNER);
        {
            // Should convert to 1/2/6/9/10 decimal from 1/5 decimal
            let res = oracle_utils::to_target_decimal_value(1_2, 1, 1);
            assert!(res == 1_2, 0);

            let res = oracle_utils::to_target_decimal_value(1_2, 1, 2);
            assert!(res == 1_20, 0);

            let res = oracle_utils::to_target_decimal_value(1_2, 1, 6);
            assert!(res == 1_200000, 0);

            let res = oracle_utils::to_target_decimal_value(1_2, 1, 9);
            assert!(res == 1_200000000, 0);

            let res = oracle_utils::to_target_decimal_value(1_2, 1, 10);
            assert!(res == 1_2000000000, 0);

            let res = oracle_utils::to_target_decimal_value(1_23456, 5, 1);
            assert!(res == 1_2, 0);

            let res = oracle_utils::to_target_decimal_value(1_23456, 5, 2);
            assert!(res == 1_23, 0);

            let res = oracle_utils::to_target_decimal_value(1_23456, 5, 6);
            assert!(res == 1_234560, 0);

            let res = oracle_utils::to_target_decimal_value(1_23456, 5, 9);
            assert!(res == 1_234560000, 0);

            let res = oracle_utils::to_target_decimal_value(1_23456, 5, 10);
            assert!(res == 1_2345600000, 0);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1, location = oracle::oracle_utils)]
    public fun test_to_target_decimal_value_fail() {
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, OWNER);
        {
            let res = oracle_utils::to_target_decimal_value(1_2, 0, 1);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }


    #[test]
    public fun test_to_target_decimal_value_safe() {
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, OWNER);
        {
            // Should convert to 1/5/16 decimal from 0/1/5/1B decimal

            let res = oracle_utils::to_target_decimal_value_safe(1_2, 1, 1);
            assert!(res == 1_2, 0);

            let res = oracle_utils::to_target_decimal_value_safe(1_2, 1, 5);
            assert!(res == 1_20000, 0);

            let res = oracle_utils::to_target_decimal_value_safe(1_2, 1, 16);
            assert!(res == 1_2000000000000000, 0);

            let res = oracle_utils::to_target_decimal_value_safe(1_23456, 5, 1);
            assert!(res == 1_2, 0);

            let res = oracle_utils::to_target_decimal_value_safe(1_2, 5, 5);
            assert!(res == 1_2, 0);

            let res = oracle_utils::to_target_decimal_value_safe(1_2, 5, 16);
            assert!(res == 1_200000000000, 0);

            let res = oracle_utils::to_target_decimal_value_safe(1_2, 200, 1);
            assert!(res == 0, 0);

            let res = oracle_utils::to_target_decimal_value_safe(1_2, 200, 5);
            assert!(res == 0, 0);

            let res = oracle_utils::to_target_decimal_value_safe(1_2, 1_000_000_000, 1);
            assert!(res == 0, 0);

            let res = oracle_utils::to_target_decimal_value_safe(1_2, 1_000_000_000, 5);
            assert!(res == 0, 0);

            let res = oracle_utils::to_target_decimal_value_safe(1_2, 1_000_000_000, 16);
            assert!(res == 0, 0);


            let res = oracle_utils::to_target_decimal_value_safe(1_2, 0, 1);
            assert!(res == 1_20, 0);

            let res = oracle_utils::to_target_decimal_value_safe(1_2, 0, 5);
            assert!(res == 1_200000, 0);

            let res = oracle_utils::to_target_decimal_value_safe(1_2, 0, 16);
            assert!(res == 1_20000000000000000, 0);

        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    // Should fail for 0 decimal
    #[test]
    #[expected_failure(abort_code = 1, location = oracle::oracle_utils)]
    public fun test_fail_0_decimal() {
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, OWNER);
        {
            let res = oracle_utils::to_target_decimal_value(1_123456, 6, 0);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

    #[test]
    public fun test_calculate_amplitude() {
        let _scenario = test_scenario::begin(OWNER);
        let scenario = &mut _scenario;
        let _clock = clock::create_for_testing(test_scenario::ctx(scenario));
        let _u64max: u64 = 18446744073709551615;

        test_scenario::next_tx(scenario, OWNER);
        {
            // Should calculate amplitude when a >,=,< b
            let res = oracle_utils::calculate_amplitude(1_000000000, 2_000000000);
            assert!(res == 10000, 0);
            let res = oracle_utils::calculate_amplitude(2_000000000, 1_000000000);
            assert!(res == 5000, 0);
            let res = oracle_utils::calculate_amplitude(1_000000000, 1_000000000);
            assert!(res == 0, 0);

            // Should calculate amplitude for diff < 0.0001 
            let res = oracle_utils::calculate_amplitude(1_000000000, 1_000100000);
            assert!(res == 1, 0);
            let res = oracle_utils::calculate_amplitude(1_000000000, 1_000099999);
            assert!(res == 0, 0);

            // Should calculate amplitude for large number
            let res = oracle_utils::calculate_amplitude(1000000000_000000000, 11000000000_000000000);
            assert!(res == 100000, 0);

            let res = oracle_utils::calculate_amplitude(1000000000_000000000, 11000000000_000000000);
            assert!(res == 100000, 0);

            let res = oracle_utils::calculate_amplitude(sui::address::max(), 1);
            assert!(res == _u64max, 0);

            let res = oracle_utils::calculate_amplitude(1, sui::address::max() / 100000);
            assert!(res == _u64max, 0);

        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(_scenario);
    }

}