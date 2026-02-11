module lending_core::logic {
    use std::vector;
    use sui::address;
    use sui::clock::{Self, Clock};

    use lending_core::ray_math;
    use lending_core::safe_math;
    use oracle::oracle::{PriceOracle};
    use lending_core::validation;
    use lending_core::calculator::{Self};
    use lending_core::storage::{Self, Storage};
    use lending_core::error::{Self};
    use sui::event::emit;
    use lending_core::constants::{Self};
    use lending_core::event;

    friend lending_core::lending;
    friend lending_core::flash_loan;

    struct StateUpdated has copy, drop {
        user: address,
        asset: u8,
        user_supply_balance: u256,
        user_borrow_balance: u256,
        new_supply_index: u256,
        new_borrow_index: u256,
    }

    /** 
     * Title: Execute deposit
     * Runner1: Update borrow_index, supply_index, last_timestamp, treasury
     * Runner2: 
     *   - Conversion of the actual balance of the amount deposited by the user according to the exchange rate
     *   - Increase the number of collateral for this asset for the user
     *   - Increase the total number of collateral in the pool
     * Runner3: Add the asset to the user's list of collateral assets
     * Runner4: Update borrow_rate, supply_rate
     */
    public(friend) fun execute_deposit<CoinType>(
        clock: &Clock,
        storage: &mut Storage,
        asset: u8,
        user: address,
        amount: u256
    ) {
        //////////////////////////////////////////////////////////////////
        // Update borrow_index, supply_index, last_timestamp, treasury  //
        //////////////////////////////////////////////////////////////////
        update_state_of_all(clock, storage);

        validation::validate_deposit<CoinType>(storage, asset, amount);

        /////////////////////////////////////////////////////////////////////////
        // Convert balances to actual balances using the latest exchange rates //
        /////////////////////////////////////////////////////////////////////////
        increase_supply_balance(storage, asset, user, amount);

        if (!is_collateral(storage, asset, user)) {
            storage::update_user_collaterals(storage, asset, user)
        };

        update_interest_rate(storage, asset);
        emit_state_updated_event(storage, asset, user);
    }

    /** 
     * Title: Execute Withdraw
     * 
     */
    public(friend) fun execute_withdraw<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        asset: u8,
        user: address,
        amount: u256 // e.g. 100USDT -> 100000000000
    ): u64 {
        assert!(user_collateral_balance(storage, asset, user) > 0, error::user_have_no_collateral());

        /////////////////////////////////////////////////////////////////
        // Update borrow_index, supply_index, last_timestamp, treasury //
        /////////////////////////////////////////////////////////////////
        update_state_of_user(clock, storage, user);

        validation::validate_withdraw<CoinType>(storage, asset, amount);

        /////////////////////////////////////////////////////////////////
        // Update borrow_index, supply_index, last_timestamp, treasury //
        /////////////////////////////////////////////////////////////////
        let token_amount = user_collateral_balance(storage, asset, user);
        let actual_amount = safe_math::min(amount, token_amount);
        decrease_supply_balance(storage, asset, user, actual_amount);
        assert!(is_health(clock, oracle, storage, user), error::user_is_unhealthy());

        if (actual_amount == token_amount) {
            // If the asset is all withdrawn, the asset type of the user is removed.
            if (is_collateral(storage, asset, user)) {
                storage::remove_user_collaterals(storage, asset, user);
            }
        };

        if (token_amount > actual_amount) {
            if (token_amount - actual_amount <= 1000) {
                // Tiny balance cannot be raised in full, put it to treasury 
                storage::increase_treasury_balance(storage, asset, token_amount - actual_amount);
                if (is_collateral(storage, asset, user)) {
                    storage::remove_user_collaterals(storage, asset, user);
                }
            };
        };

        update_interest_rate(storage, asset);
        emit_state_updated_event(storage, asset, user);

        (actual_amount as u64)
    }

    /**
     * Title: Execute Borrow
     * Runner1: Update borrow_index, supply_index, last_timestamp, treasury
     * Runner2: 
     *   - Conversion of the actual balance of the amount borrow by the user according to the exchange rate
     *   - Increase the number of loan for this asset for the user
     *   - Increase the total number of loan in the pool
     * Runner3: Add the asset to the user's list of loan assets
     * Runner4: checking user health factors
     * Runner5: Update borrow_rate, supply_rate
     */
    public(friend) fun execute_borrow<CoinType>(clock: &Clock, oracle: &PriceOracle, storage: &mut Storage, asset: u8, user: address, amount: u256) {
        //////////////////////////////////////////////////////////////////
        // Update borrow_index, supply_index, last_timestamp, treasury  //
        //////////////////////////////////////////////////////////////////
        
        update_state(clock, storage, asset);
        update_state_of_user(clock, storage, user);

        validation::validate_borrow<CoinType>(storage, asset, amount);

        /////////////////////////////////////////////////////////////////////////
        // Convert balances to actual balances using the latest exchange rates //
        /////////////////////////////////////////////////////////////////////////
        increase_borrow_balance(storage, asset, user, amount);
        
        /////////////////////////////////////////////////////
        // Add the asset to the user's list of loan assets //
        /////////////////////////////////////////////////////
        if (!is_loan(storage, asset, user)) {
            storage::update_user_loans(storage, asset, user)
        };

        //////////////////////////////////
        // Checking user health factors //
        //////////////////////////////////
        let avg_ltv = calculate_avg_ltv(clock, oracle, storage, user);
        let avg_threshold = dynamic_liquidation_threshold(clock, storage, oracle,user);

        assert!(avg_ltv > 0 && avg_threshold > 0, error::ltv_is_not_enough());
        let health_factor_in_borrow = ray_math::ray_div(avg_threshold, avg_ltv);
        let health_factor = user_health_factor(clock, storage, oracle, user);
        assert!(health_factor >= health_factor_in_borrow, error::user_is_unhealthy());

        update_interest_rate(storage, asset);
        emit_state_updated_event(storage, asset, user);
    }

    /**
     * Title: Execute Repay
     * amount: 100USDT(100 * 1e6) -> 100 * 1e9
     */
    public(friend) fun execute_repay<CoinType>(clock: &Clock, _oracle: &PriceOracle, storage: &mut Storage, asset: u8, user: address, amount: u256): u256 {
        assert!(user_loan_balance(storage, asset, user) > 0, error::user_have_no_loan());

        update_state_of_user(clock, storage, user);

        validation::validate_repay<CoinType>(storage, asset, amount);

        // get the total debt of the user in this pool, borrow_balance * borrow_index --> 98 * 1e9
        let current_debt = user_loan_balance(storage, asset, user);
        
        let excess_amount = 0;
        let repay_debt = amount; // 100 * 1e9
        if (current_debt < amount) { // 98 * 1e9 < 100 * 1e9?
            repay_debt = current_debt; // repay_debt = 98 * 1e9
            excess_amount = amount - current_debt // excess_amount = 100 * 1e9 - 98 * 1e9 = 2 * 1e9
        };
        decrease_borrow_balance(storage, asset, user, repay_debt);

        if (repay_debt == current_debt) {
            storage::remove_user_loans(storage, asset, user)
        };

        update_interest_rate(storage, asset);
        emit_state_updated_event(storage, asset, user);

        excess_amount
    }

    public(friend) fun execute_liquidate<CoinType, CollateralCoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        user: address,
        collateral_asset: u8,
        debt_asset: u8,
        amount: u256
    ): (u256, u256, u256) {
        // check if the user has loan on this asset
        assert!(is_loan(storage, debt_asset, user), error::user_have_no_loan());
        // check if the user's liquidated assets are collateralized
        assert!(is_collateral(storage, collateral_asset, user), error::user_have_no_collateral());

        update_state(clock, storage, debt_asset);
        update_state(clock, storage, collateral_asset);
        update_state_of_user(clock, storage, user);

        validation::validate_liquidate<CoinType, CollateralCoinType>(storage, debt_asset, collateral_asset, amount);

        // Check the health factor of the user
        assert!(!is_health(clock, oracle, storage, user), error::user_is_healthy());

        let (
            liquidable_amount_in_collateral,
            liquidable_amount_in_debt,
            executor_bonus_amount,
            treasury_amount,
            executor_excess_amount,
            is_max_loan_value,
        ) = calculate_liquidation(clock, storage, oracle, user, collateral_asset, debt_asset, amount);

        // Reduce the liquidated user's loan assets
        decrease_borrow_balance(storage, debt_asset, user, liquidable_amount_in_debt);
        // Reduce the liquidated user's supply assets
        decrease_supply_balance(storage, collateral_asset, user, liquidable_amount_in_collateral + executor_bonus_amount + treasury_amount);

        if (is_max_loan_value) {
            storage::remove_user_loans(storage, debt_asset, user);
        };

        update_interest_rate(storage, collateral_asset);
        update_interest_rate(storage, debt_asset);

        emit_state_updated_event(storage, collateral_asset, user);
        emit_state_updated_event(storage, debt_asset, user);

        (liquidable_amount_in_collateral + executor_bonus_amount, executor_excess_amount, treasury_amount)
    }

    // May cause an increase in gas
    // TODO: If the upgrade fails, need to modify this method to private and add another function
    public(friend) fun update_state_of_all(clock: &Clock, storage: &mut Storage) {
        let count = storage::get_reserves_count(storage);

        let i = 0;
        while (i < count) {
            update_state(clock, storage, i);
            i = i + 1;
        }
    }

    // Update the state of the user's assets
    // Assume the user has both collateral and loan assets, otherwise the function will cost a bit more gas
    public(friend) fun update_state_of_user(clock: &Clock, storage: &mut Storage, user: address) {
        let (collaterals, loans) = storage::get_user_assets(storage, user);
        let len = vector::length(&collaterals);
        let i = 0;
        while (i < len) {
            let asset = vector::borrow(&collaterals, i);
            update_state(clock, storage, *asset);
            i = i + 1;
        };

        let len = vector::length(&loans);
        let i = 0;
        while (i < len) {
            let asset = vector::borrow(&loans, i);
            update_state(clock, storage, *asset);
            i = i + 1;
        };
    }

    /**
     * Title: Update borrow_index, supply_index, last_timestamp, treasury
     */
    fun update_state(clock: &Clock, storage: &mut Storage, asset: u8) {
        // e.g. get the current timestamp in milliseconds
        let current_timestamp = clock::timestamp_ms(clock);

        // Calculate the time difference between now and the last update
        let last_update_timestamp = storage::get_last_update_timestamp(storage, asset);
        let timestamp_difference = (current_timestamp - last_update_timestamp as u256) / 1000;

        // Get All required reserve configurations
        let (current_supply_index, current_borrow_index) = storage::get_index(storage, asset);
        let (current_supply_rate, current_borrow_rate) = storage::get_current_rate(storage, asset);
        let (_, _, _, reserve_factor, _) = storage::get_borrow_rate_factors(storage, asset);
        let (_, total_borrow) = storage::get_total_supply(storage, asset);

        // Calculate new supply index via linear interest
        let linear_interest = calculator::calculate_linear_interest(timestamp_difference, current_supply_rate);
        let new_supply_index = ray_math::ray_mul(linear_interest, current_supply_index);

        // Calculate new borrowing index via compound interest
        let compounded_interest = calculator::calculate_compounded_interest(timestamp_difference, current_borrow_rate);
        let new_borrow_index = ray_math::ray_mul(compounded_interest, current_borrow_index);

        // Calculate the treasury amount
        let treasury_amount = ray_math::ray_mul(
            ray_math::ray_mul(total_borrow, (new_borrow_index - current_borrow_index)),
            reserve_factor
        );
        let scaled_treasury_amount = ray_math::ray_div(treasury_amount, new_supply_index);

        storage::update_state(storage, asset, new_borrow_index, new_supply_index, current_timestamp, scaled_treasury_amount);
        storage::increase_total_supply_balance(storage, asset, scaled_treasury_amount);
        // storage::increase_balance_for_pool(storage, asset, scaled_supply_amount, scaled_borrow_amount + scaled_reserve_amount) // **No need to double calculate interest
    }


    // reserve mod
    // TODO: If the upgrade fails, need to modify this method to private and add another function
    public(friend) fun update_interest_rate(storage: &mut Storage, asset: u8) {
        let borrow_rate = calculator::calculate_borrow_rate(storage, asset);
        let supply_rate = calculator::calculate_supply_rate(storage, asset, borrow_rate);

        storage::update_interest_rate(storage, asset, borrow_rate, supply_rate)
    }

    public(friend) fun cumulate_to_supply_index(storage: &mut Storage, asset: u8, amount: u256) {
        //next liquidity index is calculated this way: `((amount / totalLiquidity) + 1) * liquidityIndex`
        //division `amount / totalLiquidity` done in ray for precision

        let (total_supply, _) = storage::get_total_supply(storage, asset);
        let (supply_index, borrow_index) = storage::get_index(storage, asset);
        let last_update_at = storage::get_last_update_timestamp(storage, asset);

        let result = ray_math::ray_mul(
            ray_math::ray_div(amount, total_supply) + ray_math::ray(), // (amount / totalSupply) + 1
            supply_index,
        );

        storage::update_state(storage, asset, borrow_index, result, last_update_at, 0);
        emit_state_updated_event(storage, asset, @0x0);
    }

    // Token mod Start
    // supply_index -> exchange rate
    // Example:
    // current: DAI(1000), cDAI(40000), exchangeRate(0.025), 1000 / 40000 = 0.025
    // after one year: exchangeRate(0.0275), 0.025 -> 0.0275
    // scaled_amount = cDAI(40000) * exchangeRate(0.0275) = DAI(1100)
    fun increase_supply_balance(storage: &mut Storage, asset: u8, user: address, amount: u256) {
        //////////////////////////////////////////////////////////////////////////////////////////////
        //                               get the current exchange rate                              //
        // the update_state function has been called before here, so it is the latest exchange rate //
        //////////////////////////////////////////////////////////////////////////////////////////////
        let (supply_index, _) = storage::get_index(storage, asset);
        let scaled_amount = ray_math::ray_div(amount, supply_index);

        storage::increase_supply_balance(storage, asset, user, scaled_amount)
    }

    fun decrease_supply_balance(storage: &mut Storage, asset: u8, user: address, amount: u256) {
        let (supply_index, _) = storage::get_index(storage, asset);
        let scaled_amount = ray_math::ray_div(amount, supply_index);

        storage::decrease_supply_balance(storage, asset, user, scaled_amount)
    }

    fun increase_borrow_balance(storage: &mut Storage, asset: u8, user: address, amount: u256) {
        let (_, borrow_index) = storage::get_index(storage, asset);
        let scaled_amount = ray_math::ray_div(amount, borrow_index);

        storage::increase_borrow_balance(storage, asset, user, scaled_amount)
    }

    fun decrease_borrow_balance(storage: &mut Storage, asset: u8, user: address, amount: u256) {
        let (_, borrow_index) = storage::get_index(storage, asset);
        let scaled_amount = ray_math::ray_div(amount, borrow_index);

        storage::decrease_borrow_balance(storage, asset, user, scaled_amount)
    }

    /**
     * Title: check the user's health status, is the health factors greater than 1.
     * Returns: true/false.
     */
    public fun is_health(clock: &Clock, oracle: &PriceOracle, storage: &mut Storage, user: address): bool {
        user_health_factor(clock, storage, oracle, user) >= ray_math::ray()
    }

    public fun user_health_factor_batch(clock: &Clock, oracle: &PriceOracle, storage: &mut Storage, users: vector<address>): vector<u256> {
        let len = vector::length(&users);
        let i = 0;
        let results = vector::empty<u256>();
        while (i < len) {
            let health_factor = user_health_factor(clock, storage, oracle, *vector::borrow(&users, i));
            vector::push_back(&mut results, health_factor);
            i = i + 1;
        };
        results
    }

    /**
     * Title: get the user's health factors.
     * Returns: RAY.
     */
    public fun user_health_factor(clock: &Clock, storage: &mut Storage, oracle: &PriceOracle, user: address): u256 {
        let health_collateral_value = user_health_collateral_value(clock, oracle, storage, user); // 202500000000000
        let dynamic_liquidation_threshold = dynamic_liquidation_threshold(clock, storage, oracle, user); // 650000000000000000000000000
        let health_loan_value = weighted_user_health_loan_value(clock, oracle, storage, user); // 49500000000
        if (health_loan_value > 0) {
            // H = TotalCollateral * LTV * Threshold / TotalBorrow
            let ratio = ray_math::ray_div(health_collateral_value, health_loan_value);
            ray_math::ray_mul(ratio, dynamic_liquidation_threshold)
        } else {
            address::max()
        }
    }

    public fun dynamic_liquidation_threshold(clock: &Clock, storage: &mut Storage, oracle: &PriceOracle, user: address): u256 {
        // Power by Erin
        let (collaterals, _) = storage::get_user_assets(storage, user);
        let len = vector::length(&collaterals);
        let i = 0;
        let in_emode = storage::is_in_emode(storage, user);

        let collateral_value = 0;
        let collateral_health_value = 0;

        while (i < len) {
            let asset = vector::borrow(&collaterals, i);
            let (_, _, threshold) = storage::get_liquidation_factors(storage, *asset);

            // emode override the threshold
            if (in_emode) {
                let emode_id = storage::get_user_emode_id(storage, user);
                 (_, threshold, _) = storage::get_emode_asset_info(storage, emode_id, *asset);
            };

            let user_collateral_value = user_collateral_value(clock, oracle, storage, *asset, user); // total collateral in usd

            collateral_health_value = collateral_health_value + ray_math::ray_mul(user_collateral_value, threshold);
            collateral_value = collateral_value + user_collateral_value;
            i = i + 1;
        };


        if (collateral_value > 0) {
            return ray_math::ray_div(collateral_health_value, collateral_value)
        };

        0
    }

    /**
     * Title: get the number of collateral (based on the liquidation threshold and LTV) that the user has in all assets.
     * Returns: USD amount.
     */
    public fun user_health_collateral_value(clock: &Clock, oracle: &PriceOracle, storage: &mut Storage, user: address): u256 {
        let (collaterals, _) = storage::get_user_assets(storage, user);
        let len = vector::length(&collaterals);
        let value = 0;
        let i = 0;

        while (i < len) {
            let asset = vector::borrow(&collaterals, i);
            // let ltv = storage::get_asset_ltv(storage, *asset); // ltv for coin

            // TotalCollateralValue = CollateralValue * LTV * Threshold
            let collateral_value = user_collateral_value(clock, oracle, storage, *asset, user); // total collateral in usd
            // value = value + ray_math::ray_mul(collateral_value, ltv);
            value = value + collateral_value;
            i = i + 1;
        };
        value
    }

    /**
     * Title: get the number of borrowings the user has in all asset.
     * Returns: USD amount.
     */
    public fun user_health_loan_value(clock: &Clock, oracle: &PriceOracle, storage: &mut Storage, user: address): u256 {
        let (_, loans) = storage::get_user_assets(storage, user);
        let len = vector::length(&loans);
        let value = 0;
        let i = 0;
        while (i < len) {
            let asset = vector::borrow(&loans, i);
            let loan_value = user_loan_value(clock, oracle, storage, *asset, user);
            value = value + loan_value;
            i = i + 1;
        };
        value
    }

    // user_health_loan_value scaled by borrow weight
    public fun weighted_user_health_loan_value(clock: &Clock, oracle: &PriceOracle, storage: &mut Storage, user: address): u256 {
        let (_, loans) = storage::get_user_assets(storage, user);
        let len = vector::length(&loans);
        let value = 0;
        let i = 0;
        while (i < len) {
            let asset = vector::borrow(&loans, i);
            let loan_value = user_loan_value(clock, oracle, storage, *asset, user);

            // borrow weight scaled loan value
            let borrow_weight = storage::get_borrow_weight(storage, *asset);
            let scaled_loan_value = loan_value * (borrow_weight as u256) / (constants::percentage_benchmark() as u256);

            value = value + scaled_loan_value;
            i = i + 1;
        };
        value
    }

    /**
     * Title: get the number of borrowings the user has in given asset.
     * Returns: USD amount.
     */
    public fun user_loan_value(clock: &Clock, oracle: &PriceOracle, storage: &mut Storage, asset: u8, user: address): u256 {
        let balance = user_loan_balance(storage, asset, user);
        let oracle_id = storage::get_oracle_id(storage, asset);

        calculator::calculate_value(clock, oracle, balance, oracle_id)
    }

    /**
     * Title: get the number of collaterals the user has in given asset.
     * Returns: USD amount.
     */
    public fun user_collateral_value(clock: &Clock, oracle: &PriceOracle, storage: &mut Storage, asset: u8, user: address): u256 {
        let balance = user_collateral_balance(storage, asset, user);
        let oracle_id = storage::get_oracle_id(storage, asset);

        calculator::calculate_value(clock, oracle, balance, oracle_id)
    }

    /**
     * Title: get the number of collaterals the user has in given asset, include interest.
     * Returns: token amount.
     */
    public fun user_collateral_balance(storage: &mut Storage, asset: u8, user: address): u256 {
        let (supply_balance, _) = storage::get_user_balance(storage, asset, user);
        let (supply_index, _) = storage::get_index(storage, asset);
        ray_math::ray_mul(supply_balance, supply_index) // scaled_amount
    }

    /**
     * Title: get the number of borrowings the user has in given asset, include interest.
     * Returns: token amount.
     */
    public fun user_loan_balance(storage: &mut Storage, asset: u8, user: address): u256 {
        let (_, borrow_balance) = storage::get_user_balance(storage, asset, user);
        let (_, borrow_index) = storage::get_index(storage, asset);
        ray_math::ray_mul(borrow_balance, borrow_index)
    }

    /**
     * Title: check if the user's collateral list contains assets.
     * Returns: true/false.
     */
    public fun is_collateral(storage: &mut Storage, asset: u8, user: address): bool {
        let (collaterals, _) = storage::get_user_assets(storage, user);
        vector::contains(&collaterals, &asset)
    }

    /** 
     * Title: check if the user's loan list contains assets.
     * Returns: true/false.
     */
    public fun is_loan(storage: &mut Storage, asset: u8, user: address): bool {
        let (_, loans) = storage::get_user_assets(storage, user);
        vector::contains(&loans, &asset)
    }
    
    fun calculate_liquidation(
        clock: &Clock,
        storage: &mut Storage,
        oracle: &PriceOracle,
        user: address,
        collateral_asset: u8,
        debt_asset: u8,
        repay_amount: u256, // 6000u
    ): (u256, u256, u256, u256, u256, bool) {
        let in_emode = storage::is_in_emode(storage, user);
        /*
            Assumed:
                liquidation_ratio = 35%, liquidation_bonus = 5%
                treasury_factor = 10%
        */
        let (liquidation_ratio, liquidation_bonus, _) = storage::get_liquidation_factors(storage, collateral_asset);

        // emode override the liquidation bonus
        if (in_emode) {
            let emode_id = storage::get_user_emode_id(storage, user);
            (_, _, liquidation_bonus) = storage::get_emode_asset_info(storage, emode_id, collateral_asset);
        };

        let treasury_factor = storage::get_treasury_factor(storage, collateral_asset);

        let collateral_value = user_collateral_value(clock, oracle, storage, collateral_asset, user);
        let loan_value = user_loan_value(clock, oracle, storage, debt_asset, user);

        let collateral_asset_oracle_id = storage::get_oracle_id(storage, collateral_asset);
        let debt_asset_oracle_id = storage::get_oracle_id(storage, debt_asset);
        let repay_value = calculator::calculate_value(clock, oracle, repay_amount, debt_asset_oracle_id);

        let liquidable_value = ray_math::ray_mul(collateral_value, liquidation_ratio); // 17000 * 35% = 5950u

        let is_max_loan_value = false;
        let excess_value;

        /*
            liquidable_value = 3500
            repay_value = 3000
            loan_value = 2000

            repay_value > liquidable_value = false (3000 > 3500 = false)
                excess_value = 0
                liquidable_value = 3000
            liquidable_value > loan_value = true (3000 >= 2000 = true)
                is_max_loan_value = true
                liquidable_value = 2000
                excess_value = 3000 - 2000 = 1000

            liquidable_value = 2000
            is_max_loan_value = true
            excess_value = 1000

            -------
            liquidable_value = 3500
            repay_value = 1000
            loan_value = 2000

            repay_value > liquidable_value = false (1000 > 3500 = false)
                excess_value = 0
                liquidable_value = 1000
            liquidable_value > loan_value = false (1000 >= 2000 = false)

            liquidable_value = 1000
            is_max_loan_value = false
            excess_value = 0

            -------
            liquidable_value = 3500
            repay_value = 2000
            loan_value = 5000

            repay_value > liquidable_value = false (2000 > 3500 = false)
                excess_value = 0
                liquidable_value = 2000
            liquidable_value > loan_value = false (2000 >= 2000 = false)

        */
        if (repay_value >= liquidable_value) { 
            excess_value = repay_value - liquidable_value;
        } else {
            excess_value = 0;
            liquidable_value = repay_value
        };

        if (liquidable_value >= loan_value) {
            is_max_loan_value = true;
            liquidable_value = loan_value;
            excess_value = repay_value - loan_value;
        };

        /*
            Assumed:
                liquidable_value = 3500u
            
            bonus = 3500 * 5% = 175u
            treasury_reserved_collateral = 175 * 10% = 17.5u

            executor_bonus_value = 3500 - 17.5 = 3482.5u

        */
        let total_bonus_value = ray_math::ray_mul(liquidable_value, liquidation_bonus);
        let treasury_value = ray_math::ray_mul(total_bonus_value, treasury_factor);
        let executor_bonus_value = total_bonus_value - treasury_value;

        let total_liquidable_amount_in_collateral = calculator::calculate_amount(clock, oracle, liquidable_value, collateral_asset_oracle_id);
        let total_liquidable_amount_in_debt = calculator::calculate_amount(clock, oracle, liquidable_value, debt_asset_oracle_id);
        let executor_bonus_amount_in_collateral = calculator::calculate_amount(clock, oracle, executor_bonus_value, collateral_asset_oracle_id);
        let treasury_amount_in_collateral = calculator::calculate_amount(clock, oracle, treasury_value, collateral_asset_oracle_id);
        let executor_excess_repayment_amount = calculator::calculate_amount(clock, oracle, excess_value, debt_asset_oracle_id);

        (
            total_liquidable_amount_in_collateral,
            total_liquidable_amount_in_debt,
            executor_bonus_amount_in_collateral,
            treasury_amount_in_collateral,
            executor_excess_repayment_amount,
            is_max_loan_value,
        )
    }

    public fun calculate_avg_ltv(clock: &Clock, oracle: &PriceOracle, storage: &mut Storage, user: address): u256 {
        let (collateral_assets, _) = storage::get_user_assets(storage, user);
        let in_emode = storage::is_in_emode(storage, user);

        let i = 0;
        let total_value = 0;
        let total_value_in_ltv = 0;

        while (i < vector::length(&collateral_assets)) {
            let asset_id = vector::borrow(&collateral_assets, i);
            let ltv = storage::get_asset_ltv(storage, *asset_id);

            // emode override the ltv
            if (in_emode) {
                let emode_id = storage::get_user_emode_id(storage, user);
                (ltv, _, _) = storage::get_emode_asset_info(storage, emode_id, *asset_id);
            };

            let user_collateral_value = user_collateral_value(clock, oracle, storage, *asset_id, user);
            total_value = total_value + user_collateral_value;
            total_value_in_ltv = total_value_in_ltv + ray_math::ray_mul(ltv, user_collateral_value);
            i = i + 1;
        };
        

        if (total_value > 0) {
            return ray_math::ray_div(total_value_in_ltv, total_value)
        };
        0
    }

    // this is logically the same as dynamic_liquidation_threshold
    // was used in old version, now is a pure getter function
    public fun calculate_avg_threshold(clock: &Clock, oracle: &PriceOracle, storage: &mut Storage, user: address): u256 {
        dynamic_liquidation_threshold(clock, storage, oracle, user)
    }

    fun emit_state_updated_event(storage: &mut Storage, asset: u8, user: address) {
        let (new_supply_index, new_borrow_index) = storage::get_index(storage, asset);
        let (user_supply_balance, user_borrow_balance) = storage::get_user_balance(storage, asset, user);
        let market_id = storage::get_market_id(storage);
        event::emit_state_updated(user, asset, user_supply_balance, user_borrow_balance, new_supply_index, new_borrow_index, market_id);
    }

    // ------------------ Emode related functions ------------------
    public(friend) fun enter_emode(storage: &mut Storage, emode_id: u64, user: address) {
        // check if user have any collateral or loan
        let (collateral_assets, loan_assets) = storage::get_user_assets(storage, user);
        assert!(vector::is_empty(&collateral_assets) && vector::is_empty(&loan_assets), error::ineligible_for_emode());
        storage::enter_emode(storage, emode_id, user)
    }

    public(friend) fun exit_emode(storage: &mut Storage, user: address) {
        let (collateral_assets, loan_assets) = storage::get_user_assets(storage, user);
        assert!(vector::is_empty(&collateral_assets) && vector::is_empty(&loan_assets), error::ineligible_for_emode());
        storage::exit_emode(storage, user)
    }

    #[test_only]
    public fun execute_deposit_for_testing<CoinType>(
        clock: &Clock, 
        storage: &mut Storage, 
        asset: u8, 
        user: address, 
        amount: u256
    ) {
        execute_deposit<CoinType>(clock, storage, asset, user, amount)
    }

    #[test_only]
    public fun execute_borrow_for_testing<CoinType>(
        clock: &Clock, 
        oracle: &PriceOracle, 
        storage: &mut Storage, 
        asset: u8, 
        user: address, 
        amount: u256
    ) {
        execute_borrow<CoinType>(clock, oracle, storage, asset, user, amount)
    }

    #[test_only]
    public fun execute_withdraw_for_testing<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        asset: u8,
        user: address,
        amount: u256
    ): u64 {
        execute_withdraw<CoinType>(clock, oracle, storage, asset, user, amount)
    }

    #[test_only]
    public fun execute_repay_for_testing<CoinType>(
        clock: &Clock, 
        _oracle: &PriceOracle, 
        storage: &mut Storage, 
        asset: u8, 
        user: address, 
        amount: u256
    ): u256 {
        execute_repay<CoinType>(clock, _oracle, storage, asset, user, amount)
    }

    #[test_only]
    public fun execute_liquidate_for_testing<CoinType, CollateralCoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        liquidated_user: address,
        collateral_asset: u8,
        loan_asset: u8,
        amount: u256
    ): (u256, u256, u256) {
        execute_liquidate<CoinType, CollateralCoinType>(clock, oracle, storage, liquidated_user, collateral_asset, loan_asset, amount)
    }

    #[test_only]
    public fun update_state_of_all_for_testing(clock: &Clock, storage: &mut Storage) {
        update_state_of_all(clock, storage)
    }

    #[test_only]
    public fun update_state_for_testing(clock: &Clock, storage: &mut Storage, asset: u8) {
        update_state(clock, storage, asset);
    }

    #[test_only]
    public fun increase_supply_balance_for_testing(storage: &mut Storage, asset: u8, user: address, amount: u256) {
        increase_supply_balance(storage, asset, user, amount);
    }

    #[test_only]
    public fun decrease_supply_balance_for_testing(storage: &mut Storage, asset: u8, user: address, amount: u256) {
        decrease_supply_balance(storage, asset, user, amount);
    }

    #[test_only]
    public fun increase_borrow_balance_for_testing(storage: &mut Storage, asset: u8, user: address, amount: u256) {
        increase_borrow_balance(storage, asset, user, amount);
    }

    #[test_only]
    public fun decrease_borrow_balance_for_testing(storage: &mut Storage, asset: u8, user: address, amount: u256) {
        decrease_borrow_balance(storage, asset, user, amount);
    }

    #[test_only]
    public fun calculate_liquidation_for_testing(
        clock: &Clock,
        storage: &mut Storage,
        oracle: &PriceOracle,
        liquidated_user: address,
        collateral_asset: u8,
        loan_asset: u8,
        repay_amount: u256
    ): (u256, u256, u256, u256, u256, bool) {
        calculate_liquidation(clock, storage, oracle, liquidated_user, collateral_asset, loan_asset, repay_amount)
    }

}