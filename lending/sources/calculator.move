module lending_core::calculator {
    use sui::clock::{Clock};

    use math::ray_math;
    use lending_core::error::{Self};
    use lending_core::constants::{Self};
    use oracle::oracle::{Self, PriceOracle};
    use lending_core::storage::{Self, Storage};

    public fun caculate_utilization(storage: &mut Storage, asset: u8): u256 {
        let (total_supply, total_borrows) = storage::get_total_supply(storage, asset);
        let (current_supply_index, current_borrow_index) = storage::get_index(storage, asset);
        let scale_borrow_amount = ray_math::ray_mul(total_borrows, current_borrow_index);
        let scale_supply_amount = ray_math::ray_mul(total_supply, current_supply_index);

        if (scale_borrow_amount == 0) {
            0
        } else {
            // Equation: utilization = total_borrows / (total_cash + total_borrows)
            ray_math::ray_div(scale_borrow_amount, scale_supply_amount)
        }
    }

    public fun calculate_borrow_rate(storage: &mut Storage, asset: u8): u256 {
        let (base_rate, multiplier, jump_rate_multiplier, _, optimal_utilization) = storage::get_borrow_rate_factors(storage, asset);

        let utilization = caculate_utilization(storage, asset);

        if (utilization < optimal_utilization) {
            // Equation: borrow_rate = base_rate + (utilization * multiplier)
            base_rate + ray_math::ray_mul(utilization, multiplier)
        } else {
            // Equation: borrow_rate = base_rate + (optimal_utilization * multiplier) + ((utilization - optimal_utilization) * jump_rate_multiplier)
            base_rate + ray_math::ray_mul(optimal_utilization, multiplier) + ray_math::ray_mul((utilization - optimal_utilization), jump_rate_multiplier)
        }
    }

    public fun calculate_supply_rate(storage: &mut Storage, asset: u8, borrow_rate: u256): u256 {
        let (_, _, _, reserve_factor, _) = storage::get_borrow_rate_factors(storage, asset);
        let utilization = caculate_utilization(storage, asset);

        ray_math::ray_mul(
            ray_math::ray_mul(borrow_rate, utilization),
            ray_math::ray() - reserve_factor
        )
        // borrow_rate * utilization * (ray_math::ray() - reserve_factor)
    }
    
    /**
     * Title: Calculating compound interest
     * Input(current_timestamp): 1685029315718
     * Input(last_update_timestamp): 1685029255718
     * Input(rate): 6.3 * 1e27
     */
    public fun calculate_compounded_interest(
        timestamp_difference: u256,
        rate: u256
    ): u256 {
        // // e.g. get the time difference of the last update --> (1685029315718 - 1685029255718) / 1000 == 60s
        if (timestamp_difference == 0) {
            return ray_math::ray()
        };

        // time difference minus 1 --> 60 - 1 = 59
        let exp_minus_one = timestamp_difference - 1;

        // time difference minus 2 --> 60 - 2 = 58
        let exp_minus_two = 0;
        if (timestamp_difference > 2) {
            exp_minus_two = timestamp_difference - 2;
        };

        // e.g. get the rate per second --> (6.3 * 1e27) / (60 * 60 * 24 * 365) --> 1.9977168949771689 * 1e20 = 199771689497716894977
        let rate_per_second = rate / constants::seconds_per_year();
        
        let base_power_two = ray_math::ray_mul(rate_per_second, rate_per_second);
        let base_power_three = ray_math::ray_mul(base_power_two, rate_per_second);

        let second_term = timestamp_difference * exp_minus_one * base_power_two / 2;
        let third_term = timestamp_difference * exp_minus_one * exp_minus_two * base_power_three / 6;
        ray_math::ray() + rate_per_second * timestamp_difference + second_term + third_term
    }

    /**
     * Title: Calculating liner interest
     * Input(current_timestamp): 1685029315718
     * Input(last_update_timestamp): 1685029255718
     * Input(rate): 6.3 * 1e27
     */
    public fun calculate_linear_interest(
        timestamp_difference: u256,
        rate: u256
    ): u256 {
        ray_math::ray() + rate * timestamp_difference / constants::seconds_per_year()
    }

    public fun calculate_value(clock: &Clock, oracle: &PriceOracle, amount: u256, oracle_id: u8): u256 {
        let (is_valid, price, decimal) = oracle::get_token_price(clock, oracle, oracle_id);
        assert!(is_valid, error::invalid_price());
        amount * price / (sui::math::pow(10, decimal) as u256)
    }

    public fun calculate_amount(clock: &Clock, oracle: &PriceOracle, value: u256, oracle_id: u8): u256 {
        let (is_valid, price, decimal) = oracle::get_token_price(clock, oracle, oracle_id);
        assert!(is_valid, error::invalid_price());
        value * (sui::math::pow(10, decimal) as u256) / price
    }
}
