#[test_only]
#[allow(unused_mut_ref)]
module lending_core::logic_test {
    use std::vector;
    use sui::clock;
    use sui::test_scenario::{Self};

    use lending_core::ray_math;
    use oracle::oracle::{PriceOracle};
    use lending_core::global;
    use lending_core::logic::{Self};
    use lending_core::eth_test::{ETH_TEST};
    use lending_core::usdt_test::{USDT_TEST};
    use lending_core::btc_test::{BTC_TEST};
    use lending_core::usdc_test::{USDC_TEST};
    use lending_core::storage::{Self, Storage};

    const OWNER: address = @0xA;

    #[test]
    public fun test_execute_deposit() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };
        
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

            logic::execute_deposit_for_testing<USDT_TEST>(&clock, &mut storage, 0, OWNER, 100);

            let (current_supply_index, current_borrow_index) = storage::get_index(&mut storage, 0);
            assert!(current_supply_index == ray_math::ray(), 0);
            assert!(current_borrow_index == ray_math::ray(), 0);
            
            let (total_supply, total_borrow) = storage::get_total_supply(&mut storage, 0);
            assert!(total_supply == 100, 0);
            assert!(total_borrow == 0, 0);

            let (collaterals, _) = storage::get_user_assets(&storage, OWNER);
            let collaterals_after = vector::empty<u8>();
            vector::push_back(&mut collaterals_after, 0);
            assert!(collaterals == collaterals_after, 0);

            let (current_supply_rate, current_borrow_rate) = storage::get_current_rate(&mut storage, 0);
            assert!(current_supply_rate == 0 && current_borrow_rate == 0, 0);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(storage);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1600, location = lending_core::logic)]
    public fun test_execute_borrow_unhealth() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };
        
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);

            let ctx = test_scenario::ctx(&mut scenario);
            let clock = clock::create_for_testing(ctx);
            logic::execute_deposit_for_testing<USDT_TEST>(&clock, &mut stg, 0, OWNER, 100);

            logic::execute_borrow_for_testing<USDT_TEST>(&clock, &price_oracle, &mut stg, 0, OWNER, 90);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(stg);
            test_scenario::return_shared(price_oracle);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_execute_borrow() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };
        
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);

            let ctx = test_scenario::ctx(&mut scenario);
            let clock = clock::create_for_testing(ctx);
            logic::execute_deposit_for_testing<USDT_TEST>(&clock, &mut stg, 0, OWNER, 100);

            logic::execute_borrow_for_testing<USDT_TEST>(&clock, &price_oracle, &mut stg, 0, OWNER, 1);

            let (total_supply, total_borrow) = storage::get_total_supply(&mut stg, 0);
            assert!(total_supply == 100, 0);
            assert!(total_borrow == 1, 0);

            let (collaterals, loans) = storage::get_user_assets(&stg, OWNER);
            let collaterals_after = vector::empty<u8>();
            vector::push_back(&mut collaterals_after, 0);
            assert!(collaterals == collaterals_after, 0);
            assert!(loans == collaterals_after, 0);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(stg);
            test_scenario::return_shared(price_oracle);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1600, location = lending_core::logic)]
    public fun test_execute_withdraw_unhealth() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

            logic::execute_deposit_for_testing<USDT_TEST>(&clock, &mut stg, 0, OWNER, 100_000000000);

            logic::execute_borrow_for_testing<USDT_TEST>(&clock, &price_oracle, &mut stg, 0, OWNER, 46_000000000);

            logic::execute_withdraw_for_testing<USDT_TEST>(&clock, &price_oracle, &mut stg, 0, OWNER, 50_000000000);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(stg);
            test_scenario::return_shared(price_oracle);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_execute_withdraw() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);

            let ctx = test_scenario::ctx(&mut scenario);
            let clock = clock::create_for_testing(ctx);
            logic::execute_deposit_for_testing<USDT_TEST>(&clock, &mut stg, 0, OWNER, 100);
            let (total_supply, _) = storage::get_total_supply(&mut stg, 0);
            assert!(total_supply == 100, 0);

            logic::execute_withdraw_for_testing<USDT_TEST>(&clock, &price_oracle, &mut stg, 0, OWNER, 1);
            let (total_supply, _) = storage::get_total_supply(&mut stg, 0);
            assert!(total_supply == 99, 0);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(stg);
            test_scenario::return_shared(price_oracle);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_execute_repay() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);

            let ctx = test_scenario::ctx(&mut scenario);
            let clock = clock::create_for_testing(ctx);

            logic::execute_deposit_for_testing<USDT_TEST>(&clock, &mut stg, 0, OWNER, 100);

            logic::execute_borrow_for_testing<USDT_TEST>(&clock, &price_oracle, &mut stg, 0, OWNER, 45);
            let (_, loans) = storage::get_user_assets(&stg, OWNER);
            let collaterals_before = vector::empty<u8>();
            vector::push_back(&mut collaterals_before, 0);
            assert!(loans == collaterals_before, 0);

            let excess_amount = logic::execute_repay_for_testing<USDT_TEST>(&clock, &price_oracle, &mut stg, 0, OWNER, 46);
            assert!(excess_amount == 1, 0);
            let (_, loans) = storage::get_user_assets(&stg, OWNER);
            assert!(loans == vector::empty<u8>(), 0);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(stg);
            test_scenario::return_shared(price_oracle);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1602, location = lending_core::logic)]
    public fun test_execute_liquidate_not_loan() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);

            let ctx = test_scenario::ctx(&mut scenario);
            let clock = clock::create_for_testing(ctx);

            logic::execute_liquidate_for_testing<USDT_TEST, USDT_TEST>(&clock, &price_oracle, &mut stg, OWNER, 0, 0, 100);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(stg);
            test_scenario::return_shared(price_oracle);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1602, location = lending_core::logic)]
    public fun test_execute_liquidate_not_collateral() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);

            let ctx = test_scenario::ctx(&mut scenario);
            let clock = clock::create_for_testing(ctx);
            logic::execute_deposit_for_testing<USDT_TEST>(&clock, &mut stg, 0, OWNER, 100);

            logic::execute_borrow_for_testing<USDT_TEST>(&clock, &price_oracle, &mut stg, 0, OWNER, 45);

            logic::execute_liquidate_for_testing<USDT_TEST, ETH_TEST>(&clock, &price_oracle, &mut stg, OWNER, 0, 1, 100);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(stg);
            test_scenario::return_shared(price_oracle);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1606, location = lending_core::logic)]
    public fun test_execute_liquidate_still_health() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);

            let ctx = test_scenario::ctx(&mut scenario);
            let clock = clock::create_for_testing(ctx);
            logic::execute_deposit_for_testing<USDT_TEST>(&clock, &mut stg, 0, OWNER, 100);

            logic::execute_borrow_for_testing<USDT_TEST>(&clock, &price_oracle, &mut stg, 0, OWNER, 45);

            logic::execute_liquidate_for_testing<USDT_TEST, USDT_TEST>(&clock, &price_oracle, &mut stg, OWNER, 0, 0, 100);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(stg);
            test_scenario::return_shared(price_oracle);
        };

        test_scenario::end(scenario);
    }

    // // TODO
    // Deposits and then borrows on USDT(asset 0) so that both interest rates are non-zero,
    // leaving last_update_timestamp at `at_ms`
    fun setup_borrowed_reserve(scenario: &mut test_scenario::Scenario, at_ms: u64) {
        test_scenario::next_tx(scenario, OWNER);
        let stg = test_scenario::take_shared<Storage>(scenario);
        let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        logic::execute_deposit_for_testing<USDT_TEST>(&clock, &mut stg, 0, OWNER, 1000_000000000);

        clock::set_for_testing(&mut clock, at_ms);
        logic::execute_borrow_for_testing<USDT_TEST>(&clock, &price_oracle, &mut stg, 0, OWNER, 500_000000000);

        let (current_supply_rate, current_borrow_rate) = storage::get_current_rate(&mut stg, 0);
        assert!(current_supply_rate > 0 && current_borrow_rate > 0, 0);
        assert!(storage::get_last_update_timestamp(&stg, 0) == at_ms, 0);

        clock::destroy_for_testing(clock);
        test_scenario::return_shared(stg);
        test_scenario::return_shared(price_oracle);
    }

    fun abs_diff(a: u256, b: u256): u256 {
        if (a > b) { a - b } else { b - a }
    }

    // An update with no whole second elapsed must write nothing at all, neither the indexes
    // nor the timestamp, otherwise the elapsed interval is consumed without any accrual
    #[test]
    public fun test_update_state_zero_elapsed_is_a_no_op() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };

        setup_borrowed_reserve(&mut scenario, 5000);

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 5000);

            let (supply_index_before, borrow_index_before) = storage::get_index(&mut stg, 0);

            // Same millisecond as the last update
            logic::update_state_for_testing(&clock, &mut stg, 0);

            let (supply_index_after, borrow_index_after) = storage::get_index(&mut stg, 0);
            assert!(supply_index_after == supply_index_before, 0);
            assert!(borrow_index_after == borrow_index_before, 0);
            assert!(storage::get_last_update_timestamp(&stg, 0) == 5000, 0);

            // Sub-second later: still nothing settled, so the timestamp must not move either
            clock::increment_for_testing(&mut clock, 400);
            logic::update_state_for_testing(&clock, &mut stg, 0);

            let (supply_index_final, borrow_index_final) = storage::get_index(&mut stg, 0);
            assert!(supply_index_final == supply_index_before, 0);
            assert!(borrow_index_final == borrow_index_before, 0);
            assert!(storage::get_last_update_timestamp(&stg, 0) == 5000, 0);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(stg);
        };

        test_scenario::end(scenario);
    }

    // Repeated sub-second updates must not consume the elapsed time: once a whole second has
    // passed the interest for that second is still accrued, and the remainder carries over
    #[test]
    public fun test_update_state_carries_sub_second_remainder() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };

        setup_borrowed_reserve(&mut scenario, 5000);

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 5000);

            let (supply_index_before, borrow_index_before) = storage::get_index(&mut stg, 0);

            // Three updates 400ms apart: the first two settle nothing, the third settles one
            // whole second and leaves the remaining 200ms for the next interval
            clock::increment_for_testing(&mut clock, 400);
            logic::update_state_for_testing(&clock, &mut stg, 0);
            assert!(storage::get_last_update_timestamp(&stg, 0) == 5000, 0);

            clock::increment_for_testing(&mut clock, 400);
            logic::update_state_for_testing(&clock, &mut stg, 0);
            assert!(storage::get_last_update_timestamp(&stg, 0) == 5000, 0);

            clock::increment_for_testing(&mut clock, 400);
            logic::update_state_for_testing(&clock, &mut stg, 0);
            assert!(storage::get_last_update_timestamp(&stg, 0) == 6000, 0);

            let (supply_index_after, borrow_index_after) = storage::get_index(&mut stg, 0);
            assert!(supply_index_after > supply_index_before, 0);
            assert!(borrow_index_after > borrow_index_before, 0);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(stg);
        };

        test_scenario::end(scenario);
    }

    // The accrual over one long interval and the accrual over the same span broken into many
    // sub-second updates must agree; the sub-second updates used to accrue nothing at all
    #[test]
    public fun test_update_state_split_accrual_matches_single_accrual() {
        let scenario = test_scenario::begin(OWNER);
        {
            global::init_protocol(&mut scenario);
        };

        // BTC(asset 2) and USDC(asset 3) are configured with the same rate parameters, so the
        // same utilization gives them the same rates and their indexes move in lockstep
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

            logic::execute_deposit_for_testing<BTC_TEST>(&clock, &mut stg, 2, OWNER, 1000_000000000);
            logic::execute_deposit_for_testing<USDC_TEST>(&clock, &mut stg, 3, OWNER, 1000_000000000);

            clock::set_for_testing(&mut clock, 5000);
            logic::execute_borrow_for_testing<BTC_TEST>(&clock, &price_oracle, &mut stg, 2, OWNER, 500_000000000);
            logic::execute_borrow_for_testing<USDC_TEST>(&clock, &price_oracle, &mut stg, 3, OWNER, 500_000000000);

            let (btc_supply_rate, btc_borrow_rate) = storage::get_current_rate(&mut stg, 2);
            let (usdc_supply_rate, usdc_borrow_rate) = storage::get_current_rate(&mut stg, 3);
            assert!(btc_supply_rate > 0 && btc_borrow_rate > 0, 0);
            assert!(btc_supply_rate == usdc_supply_rate, 0);
            assert!(btc_borrow_rate == usdc_borrow_rate, 0);
            assert!(storage::get_last_update_timestamp(&stg, 2) == 5000, 0);
            assert!(storage::get_last_update_timestamp(&stg, 3) == 5000, 0);

            // USDC: forty updates 250ms apart, covering ten seconds
            let i = 0;
            while (i < 40) {
                clock::increment_for_testing(&mut clock, 250);
                logic::update_state_for_testing(&clock, &mut stg, 3);
                i = i + 1;
            };

            // BTC: a single update covering the same ten seconds
            logic::update_state_for_testing(&clock, &mut stg, 2);

            assert!(storage::get_last_update_timestamp(&stg, 2) == 15000, 0);
            assert!(storage::get_last_update_timestamp(&stg, 3) == 15000, 0);

            let (single_supply_index, single_borrow_index) = storage::get_index(&mut stg, 2);
            let (split_supply_index, split_borrow_index) = storage::get_index(&mut stg, 3);

            // Interest was actually earned in both cases
            assert!(single_supply_index > ray_math::ray(), 0);
            assert!(single_borrow_index > ray_math::ray(), 0);
            assert!(split_supply_index > ray_math::ray(), 0);
            assert!(split_borrow_index > ray_math::ray(), 0);

            // Settling second by second compounds a fraction more than settling once, so the
            // two agree to within 1e-6 of the accrual rather than exactly
            let single_supply_growth = single_supply_index - ray_math::ray();
            let single_borrow_growth = single_borrow_index - ray_math::ray();
            assert!(split_supply_index >= single_supply_index, 0);
            assert!(split_borrow_index >= single_borrow_index, 0);
            assert!(abs_diff(split_supply_index, single_supply_index) * 1000000 <= single_supply_growth, 0);
            assert!(abs_diff(split_borrow_index, single_borrow_index) * 1000000 <= single_borrow_growth, 0);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(stg);
            test_scenario::return_shared(price_oracle);
        };

        test_scenario::end(scenario);
    }

    // #[test]
    // public fun test_execute_liquidate() {
        

        // let alice = @0xace;
        // let bob = @0xb0b;
        // init_for_testing(owner);

        // let owner_scenario = test_scenario::begin(owner);
        // {
        //     let stg = test_scenario::take_shared<Storage>(&owner_scenario);
        //     let price_oracle = test_scenario::take_shared<PriceOracle>(&owner_scenario);

        //     let ctx = test_scenario::ctx(&mut owner_scenario);
        //     let clock = clock::create_for_testing(ctx);
        //     execute_deposit(&clock, &mut stg, 0, alice, 27000 * (sui::math::pow(10, 9) as u256));   // deposit SUI
        //     execute_deposit(&clock, &mut stg, 1, bob, 1 * (sui::math::pow(10, 9) as u256)); // deposit WBTC

        //     execute_borrow(&clock, &price_oracle, &mut stg, 0, bob, 16199 * (sui::math::pow(10, 9) as u256));

        //     clock::destroy_for_testing(clock);
        //     test_scenario::return_shared(stg);
        //     test_scenario::return_shared(price_oracle);
        // };

        // // Drop the WBTC price
        // test_scenario::next_tx(&mut owner_scenario, owner);
        // {
        //     let price_oracle = test_scenario::take_shared<PriceOracle>(&owner_scenario);
        //     let oracle_cap = test_scenario::take_shared<OracleCap>(&owner_scenario);

        //     oracle::update_token_price(
        //         &oracle_cap,
        //         &mut price_oracle,
        //         1,
        //         26980 * (sui::math::pow(10, 9) as u256),
        //         test_scenario::ctx(&mut owner_scenario),
        //     );

        //     test_scenario::return_shared(price_oracle); 
        //     test_scenario::return_shared(oracle_cap);
        // };

        // // liquidate bob's position
        // test_scenario::next_tx(&mut owner_scenario, owner);
        // {
        //     let stg = test_scenario::take_shared<Storage>(&owner_scenario);
        //     let price_oracle = test_scenario::take_shared<PriceOracle>(&owner_scenario);

        //     let ctx = test_scenario::ctx(&mut owner_scenario);
        //     let clock = clock::create_for_testing(ctx);

        //     std::debug::print(&user_health_factor(&mut stg, &price_oracle, bob));
        //     std::debug::print(&is_health(&price_oracle, &mut stg, bob));

        //     let (max_liquidable_collateral, max_liquidable_debt) = calculate_max_liquidation(
        //         &mut stg,
        //         &price_oracle,
        //         bob,
        //         1,
        //         0
        //     );
        //     std::debug::print(&max_liquidable_collateral);
        //     std::debug::print(&max_liquidable_debt);
            

        //     execute_liquidate(&clock, &price_oracle, &mut stg, bob, 1, 0, 1);
        //     assert!(is_health(&price_oracle, &mut stg, bob), 0);

        //     clock::destroy_for_testing(clock);
        //     test_scenario::return_shared(stg);
        //     test_scenario::return_shared(price_oracle);
        // };

        // test_scenario::end(owner_scenario);
    // }
}