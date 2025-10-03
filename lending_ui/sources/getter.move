module lending_ui::getter {
    use std::vector;
    use sui::clock::{Clock};
    use std::ascii::{String};

    use oracle::oracle::{Self, PriceOracle};
    use lending_core::storage::{Self, Storage};

    struct OracleInfo has copy, drop {
        oracle_id: u8,
        price: u256,
        decimals: u8,
        valid: bool,
    }
    public fun get_oracle_info(clock: &Clock, price_oracle: &PriceOracle, ids: vector<u8>): (vector<OracleInfo>) {
        let info = vector::empty<OracleInfo>();
        let length = vector::length(&ids);

        while(length > 0) {
            let id = vector::borrow(&ids, length - 1);
            let (valid, price, decimals) = oracle::get_token_price(clock, price_oracle, *id);

            vector::push_back(&mut info, OracleInfo {
                oracle_id: *id,
                price: price,
                decimals: decimals,
                valid: valid,
            });

            length = length - 1;
        };

        info
    }

    struct UserStateInfo has copy, drop {
        asset_id: u8,
        borrow_balance: u256,
        supply_balance: u256,
    }

    public fun get_user_state(storage_: &mut Storage, user: address): (vector<UserStateInfo>) {
        let info = vector::empty<UserStateInfo>();
        let length = storage::get_reserves_count(storage_);

        while (length > 0) {
            let (supply, borrow) = storage::get_user_balance(storage_, length-1, user);

            vector::push_back(&mut info, UserStateInfo {
                asset_id: length-1,
                supply_balance: supply,
                borrow_balance: borrow,
            });

            length = length - 1;
        };

        info
    }

    struct ReserveDataInfo has copy, drop {
        id: u8,
        oracle_id: u8,
        coin_type: String,
        supply_cap: u256,
        borrow_cap: u256,
        supply_rate: u256,
        borrow_rate: u256,
        supply_index: u256,
        borrow_index: u256,
        total_supply: u256,
        total_borrow: u256,
        last_update_at: u64,
        ltv: u256,
        treasury_factor: u256,
        treasury_balance: u256,
        base_rate: u256,
        multiplier: u256,
        jump_rate_multiplier: u256,
        reserve_factor: u256,
        optimal_utilization: u256,
        liquidation_ratio: u256,
        liquidation_bonus: u256,
        liquidation_threshold: u256,
    }

    public fun get_reserve_data(storage_: &mut Storage): vector<ReserveDataInfo> {
        let info = vector::empty<ReserveDataInfo>();
        let length = storage::get_reserves_count(storage_);

        while (length > 0) {
            let reserve_id = length - 1;
            let oracle_id = storage::get_oracle_id(storage_, reserve_id);
            let coin_type = storage::get_coin_type(storage_, reserve_id);
            let supply_cap = storage::get_supply_cap_ceiling(storage_, reserve_id);
            let borrow_cap = storage::get_borrow_cap_ceiling_ratio(storage_, reserve_id);
            let (supply_rate, borrow_rate) = storage::get_current_rate(storage_, reserve_id);
            let (supply_index, borrow_index) = storage::get_index(storage_, reserve_id);
            let (total_supply, total_borrow) = storage::get_total_supply(storage_, reserve_id);
            let last_update_at = storage::get_last_update_timestamp(storage_, reserve_id);
            let ltv = storage::get_asset_ltv(storage_, reserve_id);
            let treasury_factor = storage::get_treasury_factor(storage_, reserve_id);
            let treasury_balance = storage::get_treasury_balance(storage_, reserve_id);
            let (base_rate, multiplier, jump_rate_multiplier, reserve_factor, optimal_utilization) = storage::get_borrow_rate_factors(storage_, reserve_id);
            let (liquidation_ratio, liquidation_bonus, liquidation_threshold) = storage::get_liquidation_factors(storage_, reserve_id);

            vector::push_back(&mut info, ReserveDataInfo {
                id: reserve_id,
                oracle_id: oracle_id,
                coin_type: coin_type,
                supply_cap: supply_cap,
                borrow_cap: borrow_cap,
                supply_rate: supply_rate,
                borrow_rate: borrow_rate,
                supply_index: supply_index,
                borrow_index: borrow_index,
                total_supply: total_supply,
                total_borrow: total_borrow,
                last_update_at: last_update_at,
                ltv: ltv,
                treasury_factor: treasury_factor,
                treasury_balance: treasury_balance,
                base_rate: base_rate,
                multiplier: multiplier,
                jump_rate_multiplier: jump_rate_multiplier,
                reserve_factor: reserve_factor,
                optimal_utilization: optimal_utilization,
                liquidation_ratio: liquidation_ratio,
                liquidation_bonus: liquidation_bonus,
                liquidation_threshold: liquidation_threshold,
            });

            length = length - 1;
        };

        info
    }
}