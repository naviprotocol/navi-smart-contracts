#[test_only]
module oracle::random_test {
    use oracle::oracle_utils::{Self};
    use oracle::oracle_provider::{Self};

    fun assert_price_conf_within_range(arg0: u64, arg1: u64) {
        let v0 = 10000;
        let a = ((((arg1 * v0 * 100) as u128) / (arg0 as u128)) as u64);
        std::debug::print(&a);
        assert!( a <= 2 * v0, 70297);
    }

    #[test]
    public fun test_price_conf() {
        assert_price_conf_within_range(100032499, 62517)
    }

    #[test]
    public fun test_calculate_amplitude() {
        let a = 12;
        let b = 10;

        let c1 = oracle_utils::calculate_amplitude(a, b);
        let c2 = oracle_utils::calculate_amplitude(b, a);
        std::debug::print(&c1);
        std::debug::print(&c2);
    }

    #[test]
    public fun test_provider() {
        let supra = oracle_provider::supra_provider();
        let pyth = oracle_provider::pyth_provider();

        std::debug::print(&supra);
        std::debug::print(&pyth);
    }
}