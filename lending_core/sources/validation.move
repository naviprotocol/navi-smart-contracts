module lending_core::validation {
    use std::type_name;
    use lending_core::ray_math::{Self};
    use lending_core::storage::{Self, Storage};
    use lending_core::error::{Self};

    /** 
     * Title: Validates a deposit action
     * storage: -
     * asset: -
     * amount: 
     *   - The decimals of ETH is 9
     *   - Total collateral is 1.2ETH --> amount = 1.2 * 1e9 = 1200000000
     */
    public fun validate_deposit<CoinType>(storage: &mut Storage, asset: u8, amount: u256) {
        assert!(type_name::into_string(type_name::get<CoinType>()) == storage::get_coin_type(storage, asset), error::invalid_coin_type());
        assert!(amount != 0, error::invalid_amount());

        // e.g. Pool total collateral of 100ETH
        let (supply_balance, _) = storage::get_total_supply(storage, asset);
        let (current_supply_index, _) = storage::get_index(storage, asset);

        let scale_supply_balance = ray_math::ray_mul(supply_balance, current_supply_index);

        // e.g. The pool has a maximum collateral capacity of 10000 ETH
        let supply_cap_ceiling = storage::get_supply_cap_ceiling(storage, asset);

        // e.g. estimate_supply
        let estimate_supply = (scale_supply_balance + amount) * ray_math::ray();

        // e.g. supply_cap_ceiling >= estimate_supply?
        assert!(supply_cap_ceiling >= estimate_supply, error::exceeded_maximum_deposit_cap());
    }

    public fun validate_withdraw<CoinType>(storage: &mut Storage, asset: u8, amount: u256) {
        assert!(type_name::into_string(type_name::get<CoinType>()) == storage::get_coin_type(storage, asset), error::invalid_coin_type());
        assert!(amount != 0, error::invalid_amount());

        let (supply_balance, borrow_balance) = storage::get_total_supply(storage, asset);
        let (current_supply_index, current_borrow_index) = storage::get_index(storage, asset);

        let scale_supply_balance = ray_math::ray_mul(supply_balance, current_supply_index);
        let scale_borrow_balance = ray_math::ray_mul(borrow_balance, current_borrow_index);

        assert!(scale_supply_balance >= scale_borrow_balance + amount, error::insufficient_balance())
    }

    /** 
     * Title: Validates borrow action
     * storage: -
     * asset: -
     * amount: 
     *   - The decimals of ETH is 9
     *   - borrow amount is 1.2ETH --> amount = 1.2 * 1e9 = 1200000000
     */
    public fun validate_borrow<CoinType>(storage: &mut Storage, asset: u8, amount: u256) {
        assert!(type_name::into_string(type_name::get<CoinType>()) == storage::get_coin_type(storage, asset), error::invalid_coin_type());
        assert!(amount != 0, error::invalid_amount());

        // e.g. get the total lending and total collateral for this pool
        let (supply_balance, borrow_balance) = storage::get_total_supply(storage, asset);
        let (current_supply_index, current_borrow_index) = storage::get_index(storage, asset);

        let scale_supply_balance = ray_math::ray_mul(supply_balance, current_supply_index);
        let scale_borrow_balance = ray_math::ray_mul(borrow_balance, current_borrow_index);

        assert!(scale_borrow_balance + amount < scale_supply_balance, error::insufficient_balance());

        // get current borrowing ratio current_borrow_ratio
        let current_borrow_ratio = ray_math::ray_div(scale_borrow_balance + amount, scale_supply_balance);
        // e.g. borrow_ratio
        let borrow_ratio = storage::get_borrow_cap_ceiling_ratio(storage, asset);
        assert!(borrow_ratio >= current_borrow_ratio, error::exceeded_maximum_borrow_cap())
    }

    public fun validate_repay<CoinType>(storage: &mut Storage, asset: u8, amount: u256) {
        assert!(type_name::into_string(type_name::get<CoinType>()) == storage::get_coin_type(storage, asset), error::invalid_coin_type());
        assert!(amount != 0, error::invalid_amount());
    }

    public fun validate_liquidate<LoanCointype, CollateralCoinType>(storage: &mut Storage, debt_asset: u8, collateral_asset: u8, amount: u256) {
        assert!(type_name::into_string(type_name::get<LoanCointype>()) == storage::get_coin_type(storage, debt_asset), error::invalid_coin_type());
        assert!(type_name::into_string(type_name::get<CollateralCoinType>()) == storage::get_coin_type(storage, collateral_asset), error::invalid_coin_type());
        assert!(amount != 0, error::invalid_amount())
    }
}