module lending_ui::calculator {
    use std::vector;
    use sui::address;
    use sui::clock::{Self, Clock};

    use math::ray_math;
    use oracle::oracle::{PriceOracle};
    use lending_core::calculator::{Self as c};
    use lending_core::pool::{Self, Pool};
    use lending_core::storage::{Self, Storage};
    use lending_core::error::{Self};

    public fun dynamic_health_factor<CoinType>(
        clock: &Clock,
        storage: &mut Storage,
        oracle: &PriceOracle,
        pool: &mut Pool<CoinType>,
        user: address,
        asset: u8,
        estimate_supply_value: u64, 
        estimate_borrow_value: u64, 
        is_increase: bool
    ): u256 {
        assert!(!(estimate_supply_value > 0 && estimate_borrow_value > 0), error::non_single_value());
        let normal_estimate_supply_value: u64 = 0;
        if (estimate_supply_value > 0) {
            normal_estimate_supply_value = pool::normal_amount(pool, estimate_supply_value);
        };

        let normal_estimate_borrow_value: u64 = 0;
        if (estimate_borrow_value > 0) {
            normal_estimate_borrow_value = pool::normal_amount(pool, estimate_borrow_value);
        };

        let dynamic_health_collateral_value = dynamic_user_health_collateral_value(
            clock, 
            oracle, 
            storage, 
            user,
            asset,
            (normal_estimate_supply_value as u256),
            is_increase
        );

        let dynamic_health_loan_value = dynamic_user_health_loan_value(
            clock,
            oracle,
            storage,
            user,
            asset,
            (normal_estimate_borrow_value as u256),
            is_increase
        );

        let dynamic_liquidation_threshold = dynamic_liquidation_threshold(
            clock, 
            storage, 
            oracle, 
            user,
            asset,
            (normal_estimate_supply_value as u256),
            is_increase
            ); 

        if (dynamic_health_loan_value > 0) {
            let ratio = ray_math::ray_div(dynamic_health_collateral_value, dynamic_health_loan_value);
            ray_math::ray_mul(ratio, dynamic_liquidation_threshold)
        } else {
            address::max()
        }
    }

    public fun dynamic_user_health_collateral_value(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage, 
        user: address,
        asset: u8, 
        estimate_value: u256, 
        is_increase: bool
    ): u256 {
        let (collaterals, _) = storage::get_user_assets(storage, user);
        let len = vector::length(&collaterals);
        let value = 0;
        let i = 0;

        let c = collaterals;
        if (!vector::contains(&collaterals, &asset)) {
            if (is_increase) {
                vector::push_back(&mut c, asset);
                len = len + 1;
            }
        };

        while (i < len) {
            let asset_t = vector::borrow(&c, i);
            let estimate_value_t = 0;
            if (asset == *asset_t) {
                estimate_value_t = estimate_value;
            };

            let collateral_value = dynamic_user_collateral_value(clock, oracle, storage, *asset_t, user, estimate_value_t, is_increase); // total collateral in usd
            value = value + collateral_value;
            i = i + 1;
        };
        value
    }

    public fun dynamic_user_health_loan_value(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        user: address, 
        asset: u8, 
        estimate_value: u256, 
        is_increase: bool
    ): u256 {
        let (_, loans) = storage::get_user_assets(storage, user);
        let len = vector::length(&loans);
        let value = 0;
        let i = 0;

        let l = loans;
        if (!vector::contains(&loans, &asset)) {
            if (is_increase) {
                vector::push_back(&mut l, asset);
                len = len + 1;
            }
        };


        while (i < len) {
            let asset_t = vector::borrow(&l, i);

            let estimate_value_t = 0;
            if (asset == *asset_t) {
                estimate_value_t = estimate_value;
            };

            let loan_value = dynamic_user_loan_value(clock, oracle, storage, *asset_t, user, estimate_value_t, is_increase);
            value = value + loan_value;
            i = i + 1;
        };
        value
    }

    public fun dynamic_user_collateral_value(
        clock: &Clock, 
        oracle: &PriceOracle, 
        storage: &mut Storage, 
        asset: u8, 
        user: address,
        estimate_value: u256, 
        is_increase: bool
    ): u256 {
        let balance = dynamic_user_collateral_balance(clock, storage, asset, user, estimate_value, is_increase);
        let oracle_id = storage::get_oracle_id(storage, asset);

        c::calculate_value(clock, oracle, balance, oracle_id)
    }

    public fun dynamic_user_loan_value(
        clock: &Clock, 
        oracle: &PriceOracle, 
        storage: &mut Storage, 
        asset: u8, 
        user: address,
        estimate_value: u256, 
        is_increase: bool
    ): u256 {
        let balance = dynamic_user_loan_balance(clock, storage, asset, user, estimate_value, is_increase);
        let oracle_id = storage::get_oracle_id(storage, asset);

        c::calculate_value(clock, oracle, balance, oracle_id)
    }

    public fun dynamic_user_collateral_balance(
        clock: &Clock,
        storage: &mut Storage,
        asset: u8,
        user: address,
        estimate_value: u256, 
        is_increase: bool
    ): u256 {
        let (supply_balance, _) = storage::get_user_balance(storage, asset, user);

        if (is_increase) {
            supply_balance = supply_balance + estimate_value;
        } else {
            supply_balance = supply_balance - estimate_value;
        };

        let (current_supply_index, _) = calculate_current_index(clock, storage, asset); 
        ray_math::ray_mul(supply_balance, current_supply_index) // scaled_amount
    }

    public fun dynamic_user_loan_balance(
        clock: &Clock, 
        storage: &mut Storage, 
        asset: u8, 
        user: address, 
        estimate_value: u256, 
        is_increase: bool
    ): u256 {
        let (_, borrow_balance) = storage::get_user_balance(storage, asset, user);

        if (is_increase) {
            borrow_balance = borrow_balance + estimate_value;
        } else {
            borrow_balance = borrow_balance - estimate_value;
        };

        let (_, current_borrow_index) = calculate_current_index(clock, storage, asset); 
        ray_math::ray_mul(borrow_balance, current_borrow_index) // scaled_amount
    }

    public fun dynamic_liquidation_threshold(
        clock: &Clock, 
        storage: &mut Storage, 
        oracle: &PriceOracle, 
        user: address,
        asset: u8, 
        estimate_value: u256, 
        is_increase: bool
    ): u256 {
        let (collaterals, _) = storage::get_user_assets(storage, user);
        let len = vector::length(&collaterals);
        let i = 0;

        let c = collaterals;
        if (!vector::contains(&collaterals, &asset)) {
            vector::push_back(&mut c, asset);
            len = len + 1;
        };

        let collateral_value = 0;
        let collateral_health_value = 0;

        while (i < len) {
            let asset_t = vector::borrow(&c, i);
            let (_, _, threshold) = storage::get_liquidation_factors(storage, *asset_t); // liquidation threshold for coin

            let estimate_value_t = 0;
            if (asset == *asset_t) {
                estimate_value_t = estimate_value;
            };

            let user_collateral_value = dynamic_user_collateral_value(clock, oracle, storage, *asset_t, user, estimate_value_t, is_increase); // total collateral in usd

            collateral_health_value = collateral_health_value + ray_math::ray_mul(user_collateral_value, threshold);
            collateral_value = collateral_value + user_collateral_value;
            i = i + 1;
        };

        if (collateral_value > 0) {
            ray_math::ray_div(collateral_health_value, collateral_value)
        } else {
            0
        }
    }

    public fun calculate_current_index(clock: &Clock, storage: &mut Storage, asset: u8): (u256, u256) {
        let current_timestamp = clock::timestamp_ms(clock);
        let last_update_timestamp = storage::get_last_update_timestamp(storage, asset);

        let (current_supply_index, current_borrow_index) = storage::get_index(storage, asset);
        let (current_supply_rate, current_borrow_rate) = storage::get_current_rate(storage, asset);

        let timestamp_difference = (current_timestamp - last_update_timestamp as u256) / 1000;

        // get new borrow index
        let compounded_interest = c::calculate_compounded_interest(
            timestamp_difference,
            current_borrow_rate
        );
        let new_borrow_index = ray_math::ray_mul(compounded_interest, current_borrow_index);

        // get new supply index
        let linear_interest = c::calculate_linear_interest(
            timestamp_difference,
            current_supply_rate
        );
        let new_supply_index = ray_math::ray_mul(linear_interest, current_supply_index);

        (new_supply_index, new_borrow_index)
    }

    public fun dynamic_calculate_apy<CoinType>(
        clock: &Clock, 
        storage: &mut Storage, 
        pool: &mut Pool<CoinType>, 
        asset: u8, 
        estimate_supply_value: u64, 
        estimate_borrow_value: u64, 
        is_increase: bool
    ): (u256, u256){
        assert!(!(estimate_supply_value > 0 && estimate_borrow_value > 0), error::non_single_value());
        // supply: estimate_supply_value > 0 && is_increase = true
        // withdraw: estimate_supply_value > 0 && is_increase = false
        // borrow: estimate_borrow_value > 0 && is_increase = true
        // repay: estimate_borrow_value > 0 && is_increase = false

        let normal_estimate_supply_value: u64 = 0;
        if (estimate_supply_value > 0) {
            normal_estimate_supply_value = pool::normal_amount(pool, estimate_supply_value);
        };

        let normal_estimate_borrow_value: u64 = 0;
        if (estimate_borrow_value > 0) {
            normal_estimate_borrow_value = pool::normal_amount(pool, estimate_borrow_value);
        };

        let borrow_rate = dynamic_calculate_borrow_rate(
            clock, 
            storage, 
            asset, 
            (normal_estimate_supply_value as u256), 
            (normal_estimate_borrow_value as u256), 
            is_increase
        );

        let supply_rate = dynamic_calculate_supply_rate(
            clock, 
            storage, 
            asset, 
            borrow_rate, 
            (normal_estimate_supply_value as u256), 
            (normal_estimate_borrow_value as u256), 
            is_increase
        );

        (borrow_rate, supply_rate)
    }

    public fun dynamic_calculate_borrow_rate(
        clock: &Clock,
        storage: &mut Storage, 
        asset: u8, 
        estimate_supply_value: u256, 
        estimate_borrow_value: u256, 
        is_increase: bool
    ): u256 {
        let (base_rate, multiplier, jump_rate_multiplier, _, optimal_utilization) = storage::get_borrow_rate_factors(storage, asset);

        let utilization = dynamic_caculate_utilization(clock, storage, asset, estimate_supply_value, estimate_borrow_value, is_increase);

        if (utilization < optimal_utilization) {
            base_rate + ray_math::ray_mul(utilization, multiplier)
        } else {
            base_rate + ray_math::ray_mul(utilization, multiplier) + ray_math::ray_mul((utilization - optimal_utilization), jump_rate_multiplier)
        }
    }
    
    public fun dynamic_calculate_supply_rate(
        clock: &Clock, 
        storage: &mut Storage, 
        asset: u8, 
        borrow_rate: u256, 
        estimate_supply_value: u256, 
        estimate_borrow_value: u256, 
        is_increase: bool
    ): u256 {
        let (_, _, _, reserve_factor, _) = storage::get_borrow_rate_factors(storage, asset);
        let utilization = dynamic_caculate_utilization(clock, storage, asset, estimate_supply_value, estimate_borrow_value, is_increase);

        ray_math::ray_mul(
            ray_math::ray_mul(borrow_rate, utilization),
            ray_math::ray() - reserve_factor
        )
    }

    public fun dynamic_caculate_utilization(
        clock: &Clock, 
        storage: &mut Storage, 
        asset: u8, 
        estimate_supply_value: u256, 
        estimate_borrow_value: u256, 
        is_increase: bool
    ): u256 {
        let (total_supply, total_borrows) = storage::get_total_supply(storage, asset);
        if (estimate_supply_value > 0) {
            if (is_increase) {
                total_supply = total_supply + estimate_supply_value
            } else {
                total_supply = total_supply - estimate_supply_value
            }
        };

        if (estimate_borrow_value > 0) {
            if (is_increase) {
                total_borrows = total_borrows + estimate_borrow_value
            } else {
                total_borrows = total_borrows - estimate_borrow_value
            }
        };

        let (current_supply_index, current_borrow_index) = calculate_current_index(clock, storage, asset);
        let scale_supply_amount = ray_math::ray_mul(total_supply, current_supply_index);
        let scale_borrow_amount = ray_math::ray_mul(total_borrows, current_borrow_index);

        if (scale_borrow_amount == 0) {
            0
        } else {
            ray_math::ray_div(scale_borrow_amount, scale_supply_amount)
        }
    }
}