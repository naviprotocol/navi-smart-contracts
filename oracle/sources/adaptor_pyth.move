module oracle::adaptor_pyth {
    use sui::clock::{Clock};

    use pyth::i64::{Self};
    use pyth::pyth::{Self};
    use pyth::price::{Self};
    use pyth::state::{Self, State};
    use pyth::price_info::{Self, PriceInfoObject};
    use pyth::price_identifier::{Self};

    use oracle::oracle_utils::{Self as utils};
    
    // get_price_native: Just return the price/decimal(expo)/timestamp from pyth oracle
    public fun get_price_native(clock: &Clock, pyth_state: &State, pyth_price_info: &PriceInfoObject): (u64, u64, u64){
        let pyth_price_info = pyth::get_price(pyth_state, pyth_price_info, clock);

        let i64_price = price::get_price(&pyth_price_info);
        let i64_expo = price::get_expo(&pyth_price_info);
        let timestamp = price::get_timestamp(&pyth_price_info) * 1000; // timestamp from pyth in seconds, should be multiplied by 1000
        let price = i64::get_magnitude_if_positive(&i64_price);
        let expo = i64::get_magnitude_if_negative(&i64_expo);

        (price, expo, timestamp)
    }

    // get_price_unsafe_native: return the price(uncheck timestamp)/decimal(expo)/timestamp from pyth oracle
    public fun get_price_unsafe_native(pyth_price_info: &PriceInfoObject): (u64, u64, u64) {
        let pyth_price_info_unsafe = pyth::get_price_unsafe(pyth_price_info);

        let i64_price = price::get_price(&pyth_price_info_unsafe);
        let i64_expo = price::get_expo(&pyth_price_info_unsafe);
        let timestamp = price::get_timestamp(&pyth_price_info_unsafe) * 1000; // timestamp from pyth in seconds, should be multiplied by 1000
        let price = i64::get_magnitude_if_positive(&i64_price);
        let expo = i64::get_magnitude_if_negative(&i64_expo);

        (price, expo, timestamp)
    }

    // get_price_to_target_decimal: return the target decimal price and timestamp
    public fun get_price_to_target_decimal(clock: &Clock, pyth_state: &State, pyth_price_info: &PriceInfoObject, target_decimal: u8): (u256, u64) {
        let (price, decimal, timestamp) = get_price_native(clock, pyth_state, pyth_price_info);
        let decimal_price = utils::to_target_decimal_value_safe((price as u256), decimal, (target_decimal as u64));

        (decimal_price, timestamp)
    }

    // get_price_unsafe_to_target_decimal: return the target decimal price(uncheck timestamp) and timestamp
    public fun get_price_unsafe_to_target_decimal(pyth_price_info: &PriceInfoObject, target_decimal: u8): (u256, u64) {
        let (price, decimal, timestamp) = get_price_unsafe_native(pyth_price_info);
        let decimal_price = utils::to_target_decimal_value_safe((price as u256), decimal, (target_decimal as u64));

        (decimal_price, timestamp)
    }

    public fun get_identifier_to_vector(price_info_object: &PriceInfoObject): vector<u8> {
        let info = price_info::get_price_info_from_price_info_object(price_info_object);
        let identifier = price_info::get_price_identifier(&info);
        price_identifier::get_bytes(&identifier)
    }

    public fun get_price_info_object_id(pyth_state: &State, price_feed_id: address): address {
        let object_id = state::get_price_info_object_id(pyth_state, sui::address::to_bytes(price_feed_id));
        sui::object::id_to_address(&object_id)
    }
}