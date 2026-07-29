module oracle::adaptor_pyth {
    use sui::clock::{Clock};

    use pyth::state::{State};
    use pyth::price_info::{PriceInfoObject};

    use pyth_pro_compatible::i64::{Self as pro_i64};
    use pyth_pro_compatible::pyth::{Self as pro_pyth};
    use pyth_pro_compatible::price::{Self as pro_price};
    use pyth_pro_compatible::state::{Self as pro_state, State as ProState};
    use pyth_pro_compatible::price_info::{Self as pro_price_info, PriceInfoObject as ProPriceInfoObject};
    use pyth_pro_compatible::price_identifier::{Self as pro_price_identifier};

    use oracle::oracle_utils::{Self as utils};

    // Legacy Pyth (0x8d97..) is retired after the Pyth Core upgrade (2026-07-31).
    // Each legacy function below is kept as an abort stub for upgrade compatibility,
    // with its pro-compatible replacement (_v2) directly underneath.

    #[allow(unused_variable)]
    public fun get_price_native(clock: &Clock, pyth_state: &State, pyth_price_info: &PriceInfoObject): (u64, u64, u64){
        abort 0
    }

    // get_price_native_v2: Just return the price/decimal(expo)/timestamp from pyth oracle
    public fun get_price_native_v2(clock: &Clock, pyth_state: &ProState, pyth_price_info: &ProPriceInfoObject): (u64, u64, u64){
        let pyth_price_info = pro_pyth::get_price(pyth_state, pyth_price_info, clock);

        let i64_price = pro_price::get_price(&pyth_price_info);
        let i64_expo = pro_price::get_expo(&pyth_price_info);
        let timestamp = pro_price::get_timestamp(&pyth_price_info) * 1000; // timestamp from pyth in seconds, should be multiplied by 1000
        let price = pro_i64::get_magnitude_if_positive(&i64_price);
        let expo = pro_i64::get_magnitude_if_negative(&i64_expo);

        (price, expo, timestamp)
    }

    #[allow(unused_variable)]
    public fun get_price_unsafe_native(pyth_price_info: &PriceInfoObject): (u64, u64, u64) {
        abort 0
    }

    // get_price_unsafe_native_v2: return the price(uncheck timestamp)/decimal(expo)/timestamp from pyth oracle
    public fun get_price_unsafe_native_v2(pyth_price_info: &ProPriceInfoObject): (u64, u64, u64) {
        let pyth_price_info_unsafe = pro_pyth::get_price_unsafe(pyth_price_info);

        let i64_price = pro_price::get_price(&pyth_price_info_unsafe);
        let i64_expo = pro_price::get_expo(&pyth_price_info_unsafe);
        let timestamp = pro_price::get_timestamp(&pyth_price_info_unsafe) * 1000; // timestamp from pyth in seconds, should be multiplied by 1000
        let price = pro_i64::get_magnitude_if_positive(&i64_price);
        let expo = pro_i64::get_magnitude_if_negative(&i64_expo);

        (price, expo, timestamp)
    }

    #[allow(unused_variable)]
    public fun get_price_to_target_decimal(clock: &Clock, pyth_state: &State, pyth_price_info: &PriceInfoObject, target_decimal: u8): (u256, u64) {
        abort 0
    }

    // get_price_to_target_decimal_v2: return the target decimal price and timestamp
    public fun get_price_to_target_decimal_v2(clock: &Clock, pyth_state: &ProState, pyth_price_info: &ProPriceInfoObject, target_decimal: u8): (u256, u64) {
        let (price, decimal, timestamp) = get_price_native_v2(clock, pyth_state, pyth_price_info);
        let decimal_price = utils::to_target_decimal_value_safe((price as u256), decimal, (target_decimal as u64));

        (decimal_price, timestamp)
    }

    #[allow(unused_variable)]
    public fun get_price_unsafe_to_target_decimal(pyth_price_info: &PriceInfoObject, target_decimal: u8): (u256, u64) {
        abort 0
    }

    // get_price_unsafe_to_target_decimal_v2: return the target decimal price(uncheck timestamp) and timestamp
    public fun get_price_unsafe_to_target_decimal_v2(pyth_price_info: &ProPriceInfoObject, target_decimal: u8): (u256, u64) {
        let (price, decimal, timestamp) = get_price_unsafe_native_v2(pyth_price_info);
        let decimal_price = utils::to_target_decimal_value_safe((price as u256), decimal, (target_decimal as u64));

        (decimal_price, timestamp)
    }

    #[allow(unused_variable)]
    public fun get_identifier_to_vector(price_info_object: &PriceInfoObject): vector<u8> {
        abort 0
    }

    public fun get_identifier_to_vector_v2(price_info_object: &ProPriceInfoObject): vector<u8> {
        let info = pro_price_info::get_price_info_from_price_info_object(price_info_object);
        let identifier = pro_price_info::get_price_identifier(&info);
        pro_price_identifier::get_bytes(&identifier)
    }

    #[allow(unused_variable)]
    public fun get_price_info_object_id(pyth_state: &State, price_feed_id: address): address {
        abort 0
    }

    public fun get_price_info_object_id_v2(pyth_state: &ProState, price_feed_id: address): address {
        let object_id = pro_state::get_price_info_object_id(pyth_state, sui::address::to_bytes(price_feed_id));
        sui::object::id_to_address(&object_id)
    }
}
