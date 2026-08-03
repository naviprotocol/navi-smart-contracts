module oracle::adaptor_switchboard {

    use switchboard::aggregator::{Self, Aggregator};
    use switchboard::decimal::{Self};

    use oracle::oracle_utils::{Self as utils};
    
    public fun get_price_native(aggregator: &Aggregator): (u128, u8, u64){
        let current_result = aggregator::current_result(aggregator);
        let timestamp = aggregator::timestamp_ms(current_result);

        let result = aggregator::result(aggregator::current_result(aggregator));
        let price = decimal::value(result);
        let expo =  decimal::dec(result);
        (price, expo, timestamp)
    }

    // get_price_to_target_decimal: return the target decimal price and timestamp
    public fun get_price_to_target_decimal(aggregator: &Aggregator, target_decimal: u8): (u256, u64) {
        let (price, decimal, timestamp) = get_price_native(aggregator);
        let decimal_price = utils::to_target_decimal_value_safe((price as u256), (decimal as u64), (target_decimal as u64));

        (decimal_price, timestamp)
    }

    public fun get_identifier_to_vector(aggregator: &Aggregator): vector<u8> {
        sui::object::id_to_bytes(&aggregator::id(aggregator))
    }

    public fun get_aggregator_id(aggregator: &Aggregator): address {
        sui::object::id_to_address(&aggregator::id(aggregator))
    }
}