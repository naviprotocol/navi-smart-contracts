module oracle::oracle_constants {

    // Critical level: it is issued when the price difference exceeds x2
    public fun level_critical(): u8 { 0 }

    // Major level: it is issued when the price difference exceeds x1 and does not exceed x2, but it lasts too long
    public fun level_major(): u8 { 1 }

    // Warning level: it is issued when the price difference exceeds x1 and does not exceed x2 and the duration is within an acceptable range
    public fun level_warning(): u8 { 2 }

    public fun level_normal(): u8 { 3 }

    // After the price is filtered by the strategy, the available prices are empty. Highest level
    public fun no_available_prices(): u8 { 0 }

    // After the price is filtered by the strategy, the unavailable price list is not empty. Warning level
    public fun unavailable_prices(): u8 { 1 }

    public fun primary_type(): u8 { 0 }

    public fun secondary_type(): u8 { 1 }

    public fun both_type(): u8 { 2 }

    public fun multiple(): u64 { 10000 }

    public fun version(): u64 { 2 }

    public fun default_update_interval(): u64 {30000} // 30s

    public fun default_decimal_limit(): u8 {16}

    public fun success(): u64 {1} 

}