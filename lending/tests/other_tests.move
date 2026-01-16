#[test_only]
module lending_core::d_test {
    use sui::clock;
    use sui::coin::{Self};
    use sui::test_scenario::{Self};

    use math::ray_math;
    use oracle::oracle::{PriceOracle};
    use lending_core::calculator; 
    use lending_core::base::{Self};
    use lending_core::pool::{Pool};
    use lending_core::logic::{Self};
    use lending_core::eth_test::{ETH_TEST};
    use lending_core::usdt_test::{USDT_TEST};
    use lending_core::storage::{Self, Storage};
    use lending_core::base_lending_tests::{Self};

    const OWNER: address = @0xA;

    #[test]
    public fun test_ttt() {
        let x = calculator::calculate_compounded_interest(3597, 149000000000000000000000000);
        std::debug::print(&x);
    }

    #[test]
    public fun test_test() {
        let userA = @0xA;
        let userB = @0xB;
        let liquidator = @0xC;
        let scenarioA = test_scenario::begin(userA);
        let scenarioB = test_scenario::begin(userB);
        let scenario_liquidator = test_scenario::begin(liquidator);

        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };

        // lending: userA deposit USDT 1000000
        test_scenario::next_tx(&mut scenarioA, userA);
        {
            let pool = test_scenario::take_shared<Pool<USDT_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            let coin = coin::mint_for_testing<USDT_TEST>(1000_000000000, test_scenario::ctx(&mut scenarioA));

            base_lending_tests::base_deposit_for_testing(&mut scenarioA, &clock, &mut pool, coin, 2, 1000_000000000);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(pool);
        };

        // lending: userB deposit ETH 1000000
        test_scenario::next_tx(&mut scenarioB, userB);
        {

            let pool = test_scenario::take_shared<Pool<ETH_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            let coin = coin::mint_for_testing<ETH_TEST>(100_000000000, test_scenario::ctx(&mut scenarioB));

            base_lending_tests::base_deposit_for_testing(&mut scenarioB, &clock, &mut pool, coin, 3, 100_000000000);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(pool);
        };

        // lending: userB borrow USDT
        test_scenario::next_tx(&mut scenarioB, userB);
        {
            let pool = test_scenario::take_shared<Pool<USDT_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

            base_lending_tests::base_borrow_for_testing(&mut scenario, &clock, &mut pool, 2, 900_000000);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(pool);
        };

        test_scenario::next_tx(&mut scenarioB, userB);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let usdt_pool = test_scenario::take_shared<Pool<USDT_TEST>>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenarioB));
            clock::set_for_testing(&mut clock, 60*60*1000);

            logic::update_state_of_all_for_testing(&clock, &mut storage);

            let (supply_balance, borrow_balance) = storage::get_total_supply(&mut storage, 2);
            let (current_supply_index, current_borrow_index) = storage::get_index(&mut storage, 2);

            let scale_supply_balance = ray_math::ray_mul(supply_balance, current_supply_index);
            let scale_borrow_balance = ray_math::ray_mul(borrow_balance, current_borrow_index);

            std::debug::print(&scale_supply_balance);
            std::debug::print(&scale_borrow_balance);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(usdt_pool);
            test_scenario::return_shared(price_oracle);
        };

        test_scenario::end(scenario);
        test_scenario::end(scenarioA);
        test_scenario::end(scenarioB);
        test_scenario::end(scenario_liquidator);
        clock::destroy_for_testing(_clock);
    }
}