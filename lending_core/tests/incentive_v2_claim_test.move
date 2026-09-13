#[test_only]
module lending_core::incentive_v2_claim_test {
    use sui::clock;
    use sui::coin::{Self};
    use sui::balance::{Self};
    use sui::test_scenario::{Self, Scenario};

    use lending_core::ray_math;
    use lending_core::global;
    use lending_core::logic::{Self};
    use lending_core::storage::{Storage, OwnerCap as StorageOwnerCap};
    use lending_core::incentive_v2::{Self, OwnerCap as IncentiveOwnerCap, Incentive, IncentiveFundsPool};
    use lending_core::usdt_test::{USDT_TEST};

    const OWNER: address = @0xA;
    const USER: address = @0xB;

    // A USDT supply pool distributing its whole budget between 0ms and 20_000ms, with USER
    // holding the entire supply of asset 0 and no reward checkpoint of their own
    const POOL_END_AT: u64 = 20000;
    const POOL_BUDGET: u64 = 1000_000000000;
    const USER_SUPPLY: u256 = 1000_000000000;

    fun setup_legacy_pool(scenario: &mut Scenario) {
        {
            global::init_protocol(scenario);
        };

        // Create the incentive owner cap and the v2 incentive object
        test_scenario::next_tx(scenario, OWNER);
        {
            let storage_owner_cap = test_scenario::take_from_sender<StorageOwnerCap>(scenario);
            incentive_v2::create_and_transfer_owner(&storage_owner_cap, test_scenario::ctx(scenario));
            test_scenario::return_to_sender(scenario, storage_owner_cap);
        };

        test_scenario::next_tx(scenario, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(scenario);
            incentive_v2::create_incentive(&owner_cap, test_scenario::ctx(scenario));
            test_scenario::return_to_sender(scenario, owner_cap);
        };

        // Create the funds pool and fund it
        test_scenario::next_tx(scenario, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(scenario);
            let incentive = test_scenario::take_shared<Incentive>(scenario);

            incentive_v2::create_funds_pool<USDT_TEST>(&owner_cap, &mut incentive, 0, true, test_scenario::ctx(scenario));

            test_scenario::return_shared(incentive);
            test_scenario::return_to_sender(scenario, owner_cap);
        };

        test_scenario::next_tx(scenario, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(scenario);
            let incentive = test_scenario::take_shared<Incentive>(scenario);
            let funds_pool = test_scenario::take_shared<IncentiveFundsPool<USDT_TEST>>(scenario);
            let funds_coin = coin::mint_for_testing<USDT_TEST>(POOL_BUDGET, test_scenario::ctx(scenario));

            incentive_v2::add_funds<USDT_TEST>(&owner_cap, &mut funds_pool, funds_coin, POOL_BUDGET, test_scenario::ctx(scenario));
            assert!(incentive_v2::get_funds_value<USDT_TEST>(&funds_pool) == POOL_BUDGET, 0);

            incentive_v2::create_incentive_pool<USDT_TEST>(
                &owner_cap,
                &mut incentive,
                &funds_pool,
                1,                                // phase
                0,                                // start_at
                POOL_END_AT,                      // end_at
                0,                                // closed_at: can always be claimed
                POOL_BUDGET,                      // total_supply
                incentive_v2::option_supply(),    // option
                0,                                // asset_id: USDT
                ray_math::ray(),                  // factor
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(funds_pool);
            test_scenario::return_shared(incentive);
            test_scenario::return_to_sender(scenario, owner_cap);
        };

        // USER acquires their supply balance without ever being settled against the pool,
        // which is the state left behind by the deprecated v2 mutation entry points
        test_scenario::next_tx(scenario, OWNER);
        {
            let stg = test_scenario::take_shared<Storage>(scenario);

            logic::increase_supply_balance_for_testing(&mut stg, 0, USER, USER_SUPPLY);

            test_scenario::return_shared(stg);
        };
    }

    // A first claim by a user with no reward checkpoint must pay nothing: the pool's whole
    // historical index is not theirs to collect against a balance they only hold now
    #[test]
    public fun test_claim_without_checkpoint_pays_zero() {
        let scenario = test_scenario::begin(OWNER);
        setup_legacy_pool(&mut scenario);

        test_scenario::next_tx(&mut scenario, USER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);
            let incentive = test_scenario::take_shared<Incentive>(&scenario);
            let funds_pool = test_scenario::take_shared<IncentiveFundsPool<USDT_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, POOL_END_AT);

            let reward = incentive_v2::claim_reward_non_entry<USDT_TEST>(
                &clock,
                &mut incentive,
                &mut funds_pool,
                &mut stg,
                0,
                incentive_v2::option_supply(),
                test_scenario::ctx(&mut scenario)
            );

            assert!(balance::value(&reward) == 0, 0);
            // The funds pool is untouched
            assert!(incentive_v2::get_funds_value<USDT_TEST>(&funds_pool) == POOL_BUDGET, 0);
            balance::destroy_zero(reward);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(funds_pool);
            test_scenario::return_shared(incentive);
            test_scenario::return_shared(stg);
        };

        test_scenario::end(scenario);
    }

    // Once the first claim has written the checkpoint, the next claim pays the delta accrued
    // over the window the user was actually settled across
    #[test]
    public fun test_claim_with_checkpoint_pays_delta() {
        let scenario = test_scenario::begin(OWNER);
        setup_legacy_pool(&mut scenario);

        // Halfway through the programme: establishes the checkpoint, pays nothing
        test_scenario::next_tx(&mut scenario, USER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);
            let incentive = test_scenario::take_shared<Incentive>(&scenario);
            let funds_pool = test_scenario::take_shared<IncentiveFundsPool<USDT_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, POOL_END_AT / 2);

            let reward = incentive_v2::claim_reward_non_entry<USDT_TEST>(
                &clock,
                &mut incentive,
                &mut funds_pool,
                &mut stg,
                0,
                incentive_v2::option_supply(),
                test_scenario::ctx(&mut scenario)
            );

            assert!(balance::value(&reward) == 0, 0);
            balance::destroy_zero(reward);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(funds_pool);
            test_scenario::return_shared(incentive);
            test_scenario::return_shared(stg);
        };

        // End of the programme: pays the second half of the budget, and nothing for the first
        test_scenario::next_tx(&mut scenario, USER);
        {
            let stg = test_scenario::take_shared<Storage>(&scenario);
            let incentive = test_scenario::take_shared<Incentive>(&scenario);
            let funds_pool = test_scenario::take_shared<IncentiveFundsPool<USDT_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, POOL_END_AT);

            let reward = incentive_v2::claim_reward_non_entry<USDT_TEST>(
                &clock,
                &mut incentive,
                &mut funds_pool,
                &mut stg,
                0,
                incentive_v2::option_supply(),
                test_scenario::ctx(&mut scenario)
            );

            assert!(balance::value(&reward) == POOL_BUDGET / 2, 0);
            assert!(incentive_v2::get_funds_value<USDT_TEST>(&funds_pool) == POOL_BUDGET - POOL_BUDGET / 2, 0);
            let _ = balance::destroy_for_testing(reward);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(funds_pool);
            test_scenario::return_shared(incentive);
            test_scenario::return_shared(stg);
        };

        test_scenario::end(scenario);
    }
}
