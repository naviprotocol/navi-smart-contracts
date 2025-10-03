module lending_core::constants {
    public fun seconds_per_year(): u256 {60 * 60 * 24 * 365}

    // incentive v2 & v3
    public fun option_type_supply(): u8 {1}
    public fun option_type_withdraw(): u8 {2}
    public fun option_type_borrow(): u8 {3}
    public fun option_type_repay(): u8 {4}

    // storage
    public fun max_number_of_reserves(): u8 {255}

    // version
    public fun version(): u64 {13}

    public fun FlashLoanMultiple(): u64 {10000}

    public fun percentage_benchmark(): u64 {10000}
}