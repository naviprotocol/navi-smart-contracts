module oracle::strategy {
    use oracle::oracle_utils::{Self as utils};
    use oracle::oracle_constants::{Self as constants};

    // |------------------------------------------|------------------------------------------------------|-------------------------------------------------------------------|
    // 0                                          x1                                                     x2                                                                  n
    // |is_within_diff1=true, is_within_diff2=true|      is_within_diff1=false,is_within_diff2=true      |            is_within_diff1=false,is_within_diff2=false            |
    // returns return severity, critical/major/warning/normal etc.
    public fun validate_price_difference(primary_price: u256, secondary_price: u256, threshold1: u64, threshold2: u64, current_timestamp: u64, max_duration_within_thresholds: u64, ratio2_usage_start_time: u64): u8 {
        let diff = utils::calculate_amplitude(primary_price, secondary_price);

        if (diff < threshold1) { return constants::level_normal() };
        if (diff > threshold2) { return constants::level_critical() };

        if (ratio2_usage_start_time > 0 && current_timestamp > max_duration_within_thresholds + ratio2_usage_start_time) {
            return constants::level_major()
        } else {
            return constants::level_warning()
        }
    }

    // return bool: is_normal
    public fun validate_price_range_and_history(
        price: u256,
        maximum_effective_price: u256,
        minimum_effective_price: u256,
        maximum_allowed_span_percentage: u64,
        current_timestamp: u64,
        historical_price_ttl: u64,
        historical_price: u256,
        historical_updated_time: u64,
    ): bool {
        // check if the price is greater than the maximum configuration value
        if (maximum_effective_price > 0 && price > maximum_effective_price) {
            return false
        };

        // check if the price is less than the minimum configuration value
        if (price < minimum_effective_price) {
            return false
        };

        // check the final price and the history price range is smaller than the acceptable range
        if (current_timestamp - historical_updated_time < historical_price_ttl) {
            let amplitude = utils::calculate_amplitude(historical_price, price);

            if (amplitude > maximum_allowed_span_percentage) {
                return false
            };
        };

        return true
    }

    public fun is_oracle_price_fresh(current_timestamp: u64, oracle_timestamp: u64, max_timestamp_diff: u64): bool {
        if (current_timestamp < oracle_timestamp) {
            return false
        };

        return (current_timestamp - oracle_timestamp) < max_timestamp_diff
    }
}