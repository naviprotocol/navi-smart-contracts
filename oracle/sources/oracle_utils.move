module oracle::oracle_utils {
    use oracle::oracle_constants::{Self as constants};

    const U64MAX: u64 = 18446744073709551615;

    // to_target_decimal_value: return value, using target decimal
    // value = 10000000000, decimal = 9, target_decimal: 6 -> value = 10000000
    // production env: max target_decimal = 16, max value = max u128 => max return < max u256
    public fun to_target_decimal_value_safe(value: u256, decimal: u64, target_decimal: u64): u256 {
        // zero check to prevent stack overflow
        while (decimal != target_decimal && value != 0) {
            if (decimal < target_decimal) {
                value = value * 10;
                decimal = decimal + 1;
            } else {
                value = value / 10;
                decimal = decimal - 1;
            };
        };

        value
    }

    public fun to_target_decimal_value(value: u256, decimal: u8, target_decimal: u8): u256 {
        assert!(decimal > 0 && target_decimal > 0, 1);

        while (decimal != target_decimal) {
            if (decimal < target_decimal) {
                value = value * 10;
                decimal = decimal + 1;
            } else {
                value = value / 10;
                decimal = decimal - 1;
            };
        };

        value
    }

    public fun calculate_amplitude(a: u256, b: u256): u64 {
        if (a == 0 || b == 0) {
            return U64MAX
        };
        let ab_diff = abs_sub(a, b);

        // prevent overflow 
        if (ab_diff > sui::address::max() / (constants::multiple() as u256)) {
            return U64MAX
        };

        let amplitude = (ab_diff * (constants::multiple() as u256) / a);
        if (amplitude > (U64MAX as u256)) {
            return U64MAX
        };

        (amplitude as u64)
    }

    public fun abs_sub(a: u256, b: u256): u256 {
        if (a > b) {
            return (a - b) 
        } else {
            return (b - a)
        }
    }
}