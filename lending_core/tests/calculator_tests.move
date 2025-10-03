#[test_only]
module lending_core::calculator_tests {
    use sui::clock;
    use sui::test_scenario::{Self};

    use math::ray_math;
    use oracle::oracle::{PriceOracle};
    use lending_core::global;
    use lending_core::calculator;

    const OWNER: address = @0xA;

    #[test]
    public fun test_calculate_compounded_interest() {
        let current_timestamp = 1685000060000;
        let last_update_timestamp = 1685000000000;
        let rate = 6300000000000000000000000000u256;

        let timestamp_diff = (current_timestamp - last_update_timestamp as u256) / 1000;
        let exp_minus_one = timestamp_diff - 1;
        let exp_minus_two = timestamp_diff - 2;
        let rate_per_sec = rate / (60 * 60 * 24 * 365);
        let base_power_two = ray_math::ray_mul(rate_per_sec, rate_per_sec);
        let base_power_three = ray_math::ray_mul(base_power_two, rate_per_sec);

        let second_term = timestamp_diff * exp_minus_one * base_power_two / 2;
        let third_term = timestamp_diff * exp_minus_one * exp_minus_two * base_power_three / 6;
        let expect_result = ray_math::ray() + rate_per_sec * timestamp_diff + second_term + third_term;


        let result = calculator::calculate_compounded_interest(
            (current_timestamp - last_update_timestamp as u256) / 1000,
            rate
        );
        assert!(result == expect_result, 0);
    }

    #[test]
    public fun test_calculate_linear_interest() {
        let current_timestamp = 1685000060000;
        let last_update_timestamp = 1685000000000;
        let rate = 6300000000000000000000000000u256;

        let timestamp_diff = (current_timestamp - last_update_timestamp as u256) / 1000;
        let expect_result = ray_math::ray() + rate * timestamp_diff / (60 * 60 * 24 * 365);

        let result = calculator::calculate_linear_interest(
            (current_timestamp - last_update_timestamp as u256) / 1000,
            rate
        );
        assert!(result == expect_result, 0);
    }

    #[test]
    public fun test_calculate_value() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };

        // calculate token value
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

            // 10 * 1800_000000000 / 10**9
            let value = calculator::calculate_value(
                &clock,
                &price_oracle,
                10,
                1
            );
            assert!(value == 18000, 0);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(price_oracle);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_calculate_amount() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };

        // calculate token amount
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

            // 18000 * 10**9 / 1800_000000000
            let value = calculator::calculate_amount(
                &clock,
                &price_oracle,
                18000,
                1
            );
            assert!(value == 10, 0);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(price_oracle);
        };

        test_scenario::end(scenario);
    }
}
