#[test_only]
#[allow(unused_mut_ref)]
module lending_core::storage_test {
    use std::vector;
    use std::type_name;
    use sui::clock;
    use sui::coin::{CoinMetadata};
    use sui::test_scenario::{Self};

    use lending_core::ray_math;
    use lending_core::global;
    use lending_core::pool::{PoolAdminCap};
    use lending_core::btc_test::{BTC_TEST};
    use lending_core::usdt_test::{USDT_TEST};
    use lending_core::storage::{Self, Storage, OwnerCap, StorageAdminCap};

    const OWNER: address = @0xA;

    #[test]
    public fun test_init_reserve() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);

            let (_, reserves_count) = storage::get_storage_info_for_testing(&stg);
            assert!(reserves_count == 5, 0);
            
            let (is_isolated) = storage::get_reserve_info_for_testing(&stg, 0);
            assert!(is_isolated == false, 0);

            assert!(storage::get_supply_cap_ceiling(&mut stg, 0) == 20000000_000000000_000000000000000000000000000, 0);
            assert!(storage::get_borrow_cap_ceiling_ratio(&mut stg, 0) == 900000000000000000000000000, 0);

            test_scenario::return_shared(stg);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_increase_supply_balance() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);

            let (total_supply_balance_before, _) = storage::get_total_supply(&mut stg, 0);
            let (user_supply_balance_before, _) = storage::get_user_balance(&mut stg, 0, OWNER);
            assert!(total_supply_balance_before == 0, 0);
            assert!(user_supply_balance_before == 0, 0);

            storage::increase_supply_balance_for_testing(&mut stg, 0, OWNER, 100_000000000);

            let (total_supply_balance_after, _) = storage::get_total_supply(&mut stg, 0);
            let (user_supply_balance_after, _) = storage::get_user_balance(&mut stg, 0, OWNER);
            assert!(total_supply_balance_after == 100_000000000, 0);
            assert!(user_supply_balance_after == 100_000000000, 0);

            test_scenario::return_shared(stg);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_decrease_supply_balance() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);
            
            storage::increase_supply_balance_for_testing(&mut stg, 0, OWNER, 100_000000000);

            test_scenario::return_shared(stg);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);

            let (total_supply_balance_before, _) = storage::get_total_supply(&mut stg, 0);
            let (user_supply_balance_before, _) = storage::get_user_balance(&mut stg, 0, OWNER);
            assert!(total_supply_balance_before == 100_000000000, 0);
            assert!(user_supply_balance_before == 100_000000000, 0);

            storage::decrease_supply_balance_for_testing(&mut stg, 0, OWNER, 100_000000000);

            let (total_supply_balance_after, _) = storage::get_total_supply(&mut stg, 0);
            let (user_supply_balance_after, _) = storage::get_user_balance(&mut stg, 0, OWNER);
            assert!(total_supply_balance_after == 0, 0);
            assert!(user_supply_balance_after == 0, 0);

            test_scenario::return_shared(stg);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_increase_borrow_balance() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);

            let (_, total_borrow_balance_before) = storage::get_total_supply(&mut stg, 0);
            let (_, user_borrow_balance_before) = storage::get_user_balance(&mut stg, 0, OWNER);
            assert!(total_borrow_balance_before == 0, 0);
            assert!(user_borrow_balance_before == 0, 0);

            storage::increase_borrow_balance_for_testing(&mut stg, 0, OWNER, 100_000000000);

            let (_, total_borrow_balance_after) = storage::get_total_supply(&mut stg, 0);
            let (_, user_borrow_balance_after) = storage::get_user_balance(&mut stg, 0, OWNER);
            assert!(total_borrow_balance_after == 100_000000000, 0);
            assert!(user_borrow_balance_after == 100_000000000, 0);

            test_scenario::return_shared(stg);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_decrease_borrow_balance() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);

            storage::increase_borrow_balance_for_testing(&mut stg, 0, OWNER, 100_000000000);

            test_scenario::return_shared(stg);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);

            let (_, total_borrow_balance_before) = storage::get_total_supply(&mut stg, 0);
            let (_, user_borrow_balance_before) = storage::get_user_balance(&mut stg, 0, OWNER);
            assert!(total_borrow_balance_before == 100_000000000, 0);
            assert!(user_borrow_balance_before == 100_000000000, 0);

            storage::decrease_borrow_balance_for_testing(&mut stg, 0, OWNER, 100_000000000);

            let (_, total_borrow_balance_after) = storage::get_total_supply(&mut stg, 0);
            let (_, user_borrow_balance_after) = storage::get_user_balance(&mut stg, 0, OWNER);
            assert!(total_borrow_balance_after == 0, 0);
            assert!(user_borrow_balance_after == 0, 0);

            test_scenario::return_shared(stg);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_set_pause() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(&scenario);

            assert!(storage::pause(&stg) == false, 0);
            storage::set_pause(&owner_cap, &mut stg, true);
            assert!(storage::pause(&stg) == true, 0);

            test_scenario::return_shared(stg);
            test_scenario::return_to_sender(&scenario, owner_cap);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1701, location = lending_core::storage)]
    public fun test_reserve_validation() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);
            let metadata = test_scenario::take_immutable<CoinMetadata<BTC_TEST>>(&scenario);
            let pool_admin_cap = test_scenario::take_from_sender<PoolAdminCap>(&scenario);
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

            storage::init_reserve<BTC_TEST>(
                &storage_admin_cap,
                &pool_admin_cap,
                &clock,
                &mut stg,
                2,                                               // oracle id
                false,                                           // is_isolated
                20000000_000000000_000000000000000000000000000,  // supply_cap_ceiling: 20000000
                900000000000000000000000000,                     // borrow_cap_ceiling: 90%
                0,                                               // base_rate: 0%
                800000000000000000000000000,                     // optimal_utilization: 80%
                80000000000000000000000000,                      // multiplier: 8%
                3000000000000000000000000000,                    // jump_rate_multiplier: 300%
                100000000000000000000000000,                     // reserve_factor: 10%
                750000000000000000000000000,                     // ltv: 75%
                100000000000000000000000000,                     // treasury_factor: 10%
                350000000000000000000000000,                     // liquidation_ratio: 35%
                50000000000000000000000000,                      // liquidation_bonus: 5%
                800000000000000000000000000,                     // liquidation_threshold: 80%
                &metadata,                                       // metadata
                test_scenario::ctx(&mut scenario)
            );

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(stg);
            test_scenario::return_immutable(metadata);
            test_scenario::return_to_sender(&scenario, pool_admin_cap);
            test_scenario::return_to_sender(&scenario, storage_admin_cap);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_getters() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let asset_id = (0 as u8);
            let stg = test_scenario::take_shared<Storage>(&scenario);
            
            assert!(storage::pause(&stg) == false, 0);
            assert!(storage::get_supply_cap_ceiling(&mut stg, asset_id) == 20000000_000000000_000000000000000000000000000, 0);
            assert!(storage::get_borrow_cap_ceiling_ratio(&mut stg, asset_id) == 900000000000000000000000000, 0);

            let (total_supply, total_borrow) = storage::get_total_supply(&mut stg, asset_id);
            assert!(total_supply == 0 && total_borrow == 0, 0);

            let (index_supply, index_borrow) = storage::get_index(&mut stg, asset_id);
            assert!(index_supply == ray_math::ray() && index_borrow == ray_math::ray(), 0);

            let (base_rate, multiplier, jump_rate_multiplier, reserve_factor, optimal_utilization) = storage::get_borrow_rate_factors(&mut stg, asset_id);
            assert!(base_rate == 0 && multiplier == 50000000000000000000000000 && jump_rate_multiplier == 1090000000000000000000000000 && reserve_factor == 70000000000000000000000000 && optimal_utilization == 800000000000000000000000000, 0);

            let (ratio, bonus, threshold) = storage::get_liquidation_factors(&mut stg, asset_id);
            assert!(ratio == 350000000000000000000000000 && bonus == 50000000000000000000000000 && threshold == 850000000000000000000000000, 0);

            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            assert!(storage::get_treasury_factor(&mut stg, asset_id) == 100000000000000000000000000, 0);
            assert!(storage::get_last_update_timestamp(&stg, asset_id) == clock::timestamp_ms(&clock), 0);

            let (current_supply_rate, current_borrow_rate) = storage::get_current_rate(&mut stg, asset_id);
            assert!(current_supply_rate == 0 && current_borrow_rate == 0, 0);

            let (supply_balance, borrow_balance) = storage::get_user_balance(&mut stg, asset_id, OWNER);
            assert!(supply_balance == 0 && borrow_balance == 0, 0);

            let (collaterals, loans) = storage::get_user_assets(&stg, OWNER);
            assert!(collaterals == vector::empty<u8>() && loans == loans, 0);
            assert!(storage::get_asset_ltv(&stg, asset_id) == 800000000000000000000000000, 0);
            assert!(storage::get_coin_type(&mut stg, asset_id) == type_name::into_string(type_name::get<USDT_TEST>()), 0);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(stg);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_update_user_loans() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);

            let (_, loans) = storage::get_user_assets(&stg, OWNER);
            assert!(loans == vector::empty<u8>(), 0);

            storage::update_user_loans_for_testing(&mut stg, 0, OWNER);

            let (_, loans) = storage::get_user_assets(&stg, OWNER);
            let loansAfter = vector::empty<u8>();
            vector::push_back(&mut loansAfter, 0);
            assert!(loans == loansAfter, 0);

            test_scenario::return_shared(stg);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_update_user_collaterals() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);

            let (collaterals, _) = storage::get_user_assets(&stg, OWNER);
            assert!(collaterals == vector::empty<u8>(), 0);

            storage::update_user_collaterals_for_testing(&mut stg, 0, OWNER);

            let (collaterals, _) = storage::get_user_assets(&stg, OWNER);
            let collateralsAfter = vector::empty<u8>();
            vector::push_back(&mut collateralsAfter, 0);
            assert!(collaterals == collateralsAfter, 0);

            test_scenario::return_shared(stg);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_remove_user_loans() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);

            storage::update_user_loans_for_testing(&mut stg, 0, OWNER);

            test_scenario::return_shared(stg);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);

            let (_, loans) = storage::get_user_assets(&stg, OWNER);
            let loans_before = vector::empty<u8>();
            vector::push_back(&mut loans_before, 0);
            assert!(loans == loans_before, 0);

            storage::remove_user_loans_for_testing(&mut stg, 0, OWNER);

            let (_, loans) = storage::get_user_assets(&stg, OWNER);
            assert!(loans == vector::empty<u8>(), 0);

            test_scenario::return_shared(stg);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_remove_user_collaterals() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);

            storage::update_user_collaterals_for_testing(&mut stg, 0, OWNER);

            test_scenario::return_shared(stg);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);

            let (collaterals, _) = storage::get_user_assets(&stg, OWNER);
            let collaterals_before = vector::empty<u8>();
            vector::push_back(&mut collaterals_before, 0);
            assert!(collaterals == collaterals_before, 0);

            storage::remove_user_collaterals_for_testing(&mut stg, 0, OWNER);

            let (collaterals, _) = storage::get_user_assets(&stg, OWNER);
            assert!(collaterals == vector::empty<u8>(), 0);

            test_scenario::return_shared(stg);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_update_interest_rate() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);

            let (current_supply_rate_before, current_borrow_rate_before) = storage::get_current_rate(&mut stg, 0);
            assert!(current_supply_rate_before == 0 && current_borrow_rate_before == 0, 0);

            storage::update_interest_rate_for_testing(&mut stg, 0, 1, 1);

            let (current_supply_rate_after, current_borrow_rate_after) = storage::get_current_rate(&mut stg, 0);
            assert!(current_supply_rate_after == 1 && current_borrow_rate_after == 1, 0);

            test_scenario::return_shared(stg);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_update_state() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);

            let (current_supply_index_before, current_borrow_index_before) = storage::get_index(&mut stg, 0);
            assert!(current_supply_index_before == ray_math::ray(), 0);
            assert!(current_borrow_index_before == ray_math::ray(), 0);
            assert!(storage::get_treasury_balance(&stg, 0) == 0, 0);
            
            storage::update_state_for_testing(&mut stg, 0, 1, 1, 1, 1);

            let (current_supply_index_after, current_borrow_index_after) = storage::get_index(&mut stg, 0);
            assert!(current_supply_index_after == 1, 0);
            assert!(current_borrow_index_after == 1, 0);
            assert!(storage::get_treasury_balance(&stg, 0) == 1, 0);

            test_scenario::return_shared(stg);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_owner_cap_can_set_pause() {
        let s = test_scenario::begin(OWNER);

        // Init storage
        test_scenario::next_tx(&mut s, OWNER);
        {
            storage::init_for_testing(test_scenario::ctx(&mut s));
        };

        // Get shared storage and verify initial state (not paused)
        test_scenario::next_tx(&mut s, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&s);
            let (paused, _) = storage::get_storage_info_for_testing(&storage);
            assert!(paused == false, 0);
            test_scenario::return_shared(storage);
        };

        // Use OwnerCap to set pause
        test_scenario::next_tx(&mut s, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(&s);
            let storage = test_scenario::take_shared<Storage>(&s);

            storage::set_pause(&owner_cap, &mut storage, true);

            test_scenario::return_to_sender(&s, owner_cap);
            test_scenario::return_shared(storage);
        };

        // Verify new state (paused)
        test_scenario::next_tx(&mut s, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&s);
            let (paused, _) = storage::get_storage_info_for_testing(&storage);
            assert!(paused == true, 0);
            test_scenario::return_shared(storage);
        };

        test_scenario::end(s);
    }

    #[test]
    public fun test_owner_cap_can_set_supply_cap() {
        let s = test_scenario::begin(OWNER);

        // Init protocol with reserves
        test_scenario::next_tx(&mut s, OWNER);
        {
            global::init_protocol(&mut s);
        };

        // Verify initial supply cap
        test_scenario::next_tx(&mut s, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&s);
            let initial_cap = storage::get_supply_cap_ceiling(&mut storage, 0);
            assert!(initial_cap == 20000000_000000000_000000000000000000000000000, 0);
            test_scenario::return_shared(storage);
        };

        // Use OwnerCap to set new supply cap
        test_scenario::next_tx(&mut s, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(&s);
            let storage = test_scenario::take_shared<Storage>(&s);

            storage::set_supply_cap(&owner_cap, &mut storage, 0, 30000000_000000000_000000000000000000000000000);

            test_scenario::return_to_sender(&s, owner_cap);
            test_scenario::return_shared(storage);
        };

        // Verify new supply cap
        test_scenario::next_tx(&mut s, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&s);
            let new_cap = storage::get_supply_cap_ceiling(&mut storage, 0);
            assert!(new_cap == 30000000_000000000_000000000000000000000000000, 0);
            test_scenario::return_shared(storage);
        };

        test_scenario::end(s);
    }

    #[test]
    public fun test_owner_cap_can_set_borrow_cap() {
        let s = test_scenario::begin(OWNER);

        // Init protocol with reserves
        test_scenario::next_tx(&mut s, OWNER);
        {
            global::init_protocol(&mut s);
        };

        // Verify initial borrow cap
        test_scenario::next_tx(&mut s, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&s);
            let initial_cap = storage::get_borrow_cap_ceiling_ratio(&mut storage, 0);
            assert!(initial_cap == 900000000000000000000000000, 0);
            test_scenario::return_shared(storage);
        };

        // Use OwnerCap to set new borrow cap
        test_scenario::next_tx(&mut s, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(&s);
            let storage = test_scenario::take_shared<Storage>(&s);

            storage::set_borrow_cap(&owner_cap, &mut storage, 0, 950000000000000000000000000);

            test_scenario::return_to_sender(&s, owner_cap);
            test_scenario::return_shared(storage);
        };

        // Verify new borrow cap
        test_scenario::next_tx(&mut s, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&s);
            let new_cap = storage::get_borrow_cap_ceiling_ratio(&mut storage, 0);
            assert!(new_cap == 950000000000000000000000000, 0);
            test_scenario::return_shared(storage);
        };

        test_scenario::end(s);
    }

    #[test]
    public fun test_owner_cap_can_set_ltv() {
        let s = test_scenario::begin(OWNER);

        // Init protocol with reserves
        test_scenario::next_tx(&mut s, OWNER);
        {
            global::init_protocol(&mut s);
        };

        // Verify initial LTV
        test_scenario::next_tx(&mut s, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&s);
            let initial_ltv = storage::get_asset_ltv(&storage, 0);
            assert!(initial_ltv == 800000000000000000000000000, 0);
            test_scenario::return_shared(storage);
        };

        // Use OwnerCap to set new LTV
        test_scenario::next_tx(&mut s, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(&s);
            let storage = test_scenario::take_shared<Storage>(&s);

            storage::set_ltv(&owner_cap, &mut storage, 0, 850000000000000000000000000);

            test_scenario::return_to_sender(&s, owner_cap);
            test_scenario::return_shared(storage);
        };

        // Verify new LTV
        test_scenario::next_tx(&mut s, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&s);
            let new_ltv = storage::get_asset_ltv(&storage, 0);
            assert!(new_ltv == 850000000000000000000000000, 0);
            test_scenario::return_shared(storage);
        };

        test_scenario::end(s);
    }

    #[test]
    public fun test_owner_cap_can_set_treasury_factor() {
        let s = test_scenario::begin(OWNER);

        // Init protocol with reserves
        test_scenario::next_tx(&mut s, OWNER);
        {
            global::init_protocol(&mut s);
        };

        // Verify initial treasury factor
        test_scenario::next_tx(&mut s, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&s);
            let initial_factor = storage::get_treasury_factor(&mut storage, 0);
            assert!(initial_factor == 100000000000000000000000000, 0);
            test_scenario::return_shared(storage);
        };

        // Use OwnerCap to set new treasury factor
        test_scenario::next_tx(&mut s, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(&s);
            let storage = test_scenario::take_shared<Storage>(&s);

            storage::set_treasury_factor(&owner_cap, &mut storage, 0, 150000000000000000000000000);

            test_scenario::return_to_sender(&s, owner_cap);
            test_scenario::return_shared(storage);
        };

        // Verify new treasury factor
        test_scenario::next_tx(&mut s, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&s);
            let new_factor = storage::get_treasury_factor(&mut storage, 0);
            assert!(new_factor == 150000000000000000000000000, 0);
            test_scenario::return_shared(storage);
        };

        test_scenario::end(s);
    }

    #[test]
    public fun test_owner_cap_can_set_interest_rate_parameters() {
        let s = test_scenario::begin(OWNER);

        // Init protocol with reserves
        test_scenario::next_tx(&mut s, OWNER);
        {
            global::init_protocol(&mut s);
        };

        // Verify initial interest rate parameters
        test_scenario::next_tx(&mut s, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&s);
            let (base_rate, multiplier, jump_rate_multiplier, reserve_factor, optimal_utilization) = storage::get_borrow_rate_factors(&mut storage, 0);
            assert!(base_rate == 0, 0);
            assert!(multiplier == 50000000000000000000000000, 0);
            assert!(reserve_factor == 70000000000000000000000000, 0);
            test_scenario::return_shared(storage);
        };

        // Use OwnerCap to set new base rate, multiplier, and reserve factor
        test_scenario::next_tx(&mut s, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(&s);
            let storage = test_scenario::take_shared<Storage>(&s);

            storage::set_base_rate(&owner_cap, &mut storage, 0, 10000000000000000000000000);
            storage::set_multiplier(&owner_cap, &mut storage, 0, 60000000000000000000000000);
            storage::set_reserve_factor(&owner_cap, &mut storage, 0, 80000000000000000000000000);

            test_scenario::return_to_sender(&s, owner_cap);
            test_scenario::return_shared(storage);
        };

        // Verify new interest rate parameters
        test_scenario::next_tx(&mut s, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&s);
            let (base_rate, multiplier, jump_rate_multiplier, reserve_factor, optimal_utilization) = storage::get_borrow_rate_factors(&mut storage, 0);
            assert!(base_rate == 10000000000000000000000000, 0);
            assert!(multiplier == 60000000000000000000000000, 0);
            assert!(reserve_factor == 80000000000000000000000000, 0);
            test_scenario::return_shared(storage);
        };

        test_scenario::end(s);
    }

    #[test]
    public fun test_owner_cap_can_set_liquidation_parameters() {
        let s = test_scenario::begin(OWNER);

        // Init protocol with reserves
        test_scenario::next_tx(&mut s, OWNER);
        {
            global::init_protocol(&mut s);
        };

        // Verify initial liquidation parameters
        test_scenario::next_tx(&mut s, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&s);
            let (ratio, bonus, threshold) = storage::get_liquidation_factors(&mut storage, 0);
            assert!(ratio == 350000000000000000000000000, 0);
            assert!(bonus == 50000000000000000000000000, 0);
            assert!(threshold == 850000000000000000000000000, 0);
            test_scenario::return_shared(storage);
        };

        // Use OwnerCap to set new liquidation parameters
        test_scenario::next_tx(&mut s, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(&s);
            let storage = test_scenario::take_shared<Storage>(&s);

            storage::set_liquidation_ratio(&owner_cap, &mut storage, 0, 400000000000000000000000000);
            storage::set_liquidation_bonus(&owner_cap, &mut storage, 0, 60000000000000000000000000);
            storage::set_liquidation_threshold(&owner_cap, &mut storage, 0, 900000000000000000000000000);

            test_scenario::return_to_sender(&s, owner_cap);
            test_scenario::return_shared(storage);
        };

        // Verify new liquidation parameters
        test_scenario::next_tx(&mut s, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&s);
            let (ratio, bonus, threshold) = storage::get_liquidation_factors(&mut storage, 0);
            assert!(ratio == 400000000000000000000000000, 0);
            assert!(bonus == 60000000000000000000000000, 0);
            assert!(threshold == 900000000000000000000000000, 0);
            test_scenario::return_shared(storage);
        };

        test_scenario::end(s);
    }
}