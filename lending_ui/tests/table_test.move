module lending_ui::table_test {
    use math::ray_math;
    // #[test]
    // public fun test_table() {
    //     let sender = @0x0;
    //     let scenario = ts::begin(sender);
    //     let table_ = table::new(ts::ctx(&mut scenario));
    //     table::add(&mut table_, b"hello", 0);
    //     std::debug::print(table::borrow(&table_, b"hello"));
    //     table::add(&mut table_, b"hello", 1);
    //     std::debug::print(table::borrow(&table_, b"hello"));
    //     abort 42
    // }

    #[test]
    public fun test_apy() {
        // // usdc 2000 -> 2000*1e6
        // // sui 2000 -> 2000*19e
        // // APY = [total_incentive_amount/(start-end )* Oracle price(reward token)]  * 1000*60*60*24*365 /  total_supply * oracle price(supply token) )*100%
        // let apy = total_incentive_amount / (end_at - start_at) * (reward_token_price as u64) * MsPerYear / (total_supply as u64) * (asset_price as u64);
        // total_apy = total_apy + apy;
        let total_incentive_amount = 2000 * 1000_000; // u
        let incentive_price = 1000000; // 1u

        let pool_total_supply = 1000000_000000000;
        let start_at = 1699372800000;
        let end_at = 1699545600000;
        let pool_price = 500000000;

        let total_amount: u256 = pool_total_supply * pool_price;
        std::debug::print(&total_amount);

        let apy = (total_incentive_amount / (end_at - start_at) * incentive_price * 1000*60*60*24*365) / total_amount;
        std::debug::print(&apy)
    }

    #[test]
    public fun test_mul() {
        // // 2000u, 60 * 60 * 24 * 2 * 1000
        // let a = ray_math::ray_div(
        //     (2000 * 1000_000 as u256),
        //     172800000
        // );
        // // let a = ray_math::ray_div(
        // //     (2000 * 1000_000 as u256),
        // //     ((1699545600000 - 1699372800000) as u256)
        // // );
        // std::debug::print(&a)

        let price_on_incentive_amount = 9999710000;
        let duration = 172800000;
        let ms_per_year = 1000*60*60*24*365;
        let price_on_total_supply = 7816229506279389;


        let apy_ = ray_math::ray_div(
            price_on_incentive_amount,
            (duration as u256),
        );
        let aa = ray_math::ray_mul(
            apy_,
            (ms_per_year as u256)
        );
        let apy = ray_math::ray_div(
            aa,
            price_on_total_supply
        );
        // let apy = price_on_incentive_amount / (duration as u256) * (ms_per_year as u256) / price_on_total_supply;
        std::debug::print(&apy);
    }


    //     public fun calculate_value(clock: &Clock, oracle: &PriceOracle, amount: u256, oracle_id: u8): u256 {
    //     let (is_valid, price, decimal) = oracle::get_token_price(clock, oracle, oracle_id);
    //     assert!(is_valid, CALCULATOR_PRICE_UNVALID);
    //     amount * price / (sui::math::pow(10, decimal) as u256)
    // }

    // public fun calculate_amount(clock: &Clock, oracle: &PriceOracle, value: u256, oracle_id: u8): u256 {
    //     let (is_valid, price, decimal) = oracle::get_token_price(clock, oracle, oracle_id);
    //     assert!(is_valid, CALCULATOR_PRICE_UNVALID);
    //     value * (sui::math::pow(10, decimal) as u256) / price
    // }

    #[test]
    public fun test_xor() {
        let supply_balance = 1;
        let borrow_balance = 10000000000;
        supply_balance = supply_balance ^ borrow_balance;
        borrow_balance = supply_balance ^ borrow_balance;
        supply_balance = supply_balance ^ borrow_balance;

        std::debug::print(&supply_balance);
        std::debug::print(&borrow_balance);
    }
}