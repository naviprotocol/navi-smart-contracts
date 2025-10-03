// Source Interface: https://gb-docs.supraoracles.com/docs/data-feeds/pull-model
module oracle::adaptor_supra {
    use oracle::oracle_utils::{Self as utils};
    use SupraOracle::SupraSValueFeed::{Self as supra, OracleHolder};

    // get_price_native: Just return the price/decimal/timestamp from supra oracle
    public fun get_price_native(supra_oracle_holder: &OracleHolder, pair: u32): (u128, u16, u128){
        let (price, decimal, timestamp, _) = supra::get_price(supra_oracle_holder, pair);
        (price, decimal, timestamp)
    }

    // get_price: return the target decimal price and timestamp
    public fun get_price_to_target_decimal(supra_oracle_holder: &OracleHolder, pair: u32, target_decimal: u8): (u256, u64) {
        let (price, decimal, timestamp) = get_price_native(supra_oracle_holder, pair);
        let decimal_price = utils::to_target_decimal_value_safe((price as u256), (decimal as u64), (target_decimal as u64));

        return (decimal_price, (timestamp as u64))
    }

    public fun pair_id_to_vector(v: u32): vector<u8> {
        let v_address = sui::address::from_u256((v as u256));
        sui::address::to_bytes(v_address)
    }

    public fun vector_to_pair_id(v: vector<u8>): u32 {
        let v_bytes = sui::address::from_bytes(v);
        let v_u256 = sui::address::to_u256(v_bytes);
        (v_u256 as u32)
    }
}