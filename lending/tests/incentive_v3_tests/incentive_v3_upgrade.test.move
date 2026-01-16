#[test_only]
#[allow(unused_use)]
module lending_core::incentive_v3_upgrade_test {
    use sui::clock::{Self, Clock};
    use sui::coin::{CoinMetadata, Coin};
    use sui::test_scenario::{Self, Scenario};
    use std::type_name::{Self};
    use std::vector::{Self};
    use sui::transfer;
    use sui::balance::{Self, Balance};
    use math::ray_math::{Self};
    use sui::vec_map::{Self, VecMap};

    use oracle::oracle::{Self, OracleAdminCap, PriceOracle};
    use lending_core::manage;

    use lending_core::pool::{Self, PoolAdminCap, Pool};
    use lending_core::btc_test_v2::{Self, BTC_TEST_V2};
    use lending_core::eth_test_v2::{Self, ETH_TEST_V2};
    use lending_core::sui_test_v2::{Self, SUI_TEST_V2};
    use lending_core::usdc_test_v2::{Self, USDC_TEST_V2};
    use lending_core::coin_test_v2::{Self, COIN_TEST_V2};
    use sui::coin::{Self};
    use sui::table::{Self};
    use lending_core::lib::{Self};
    use lending_core::base::{Self};
    use lending_core::base_lending_tests::{Self};
    use lending_core::account::{Self, AccountCap};

    use lending_core::storage::{Self, Storage, StorageAdminCap, OwnerCap as StorageOwnerCap};
    use lending_core::incentive::{Self, Incentive as Incentive_V1};
    use lending_core::incentive_v2::{Self, OwnerCap as IncentiveOwnerCap, Incentive as Incentive_V2, IncentiveFundsPool};
    use lending_core::incentive_v3::{Self, Incentive as Incentive_V3, RewardFund};

    use lending_core::incentive_v2_test::{Self};
    use lending_core::incentive_v3_util::{Self};

    const OWNER: address = @0xA;
    const USER_A: address = @0x1;
    const USER_B: address = @0x2;

    
    #[test_only]
    public fun user_deposit_v2<CoinType>(scenario: &mut Scenario, user: address, asset: u8, amount: u64, clock: &Clock) {
        test_scenario::next_tx(scenario, user);
        {
            let pool = test_scenario::take_shared<Pool<CoinType>>(scenario);
            let storage = test_scenario::take_shared<Storage>(scenario);
            let incentive_v1 = test_scenario::take_shared<Incentive_V1>(scenario);
            let incentive_v2 = test_scenario::take_shared<Incentive_V2>(scenario);
            let coin = coin::mint_for_testing<CoinType>(amount, test_scenario::ctx(scenario));
            incentive_v2::entry_deposit_for_testing<CoinType>(clock, &mut storage, &mut pool, asset, coin, amount, &mut incentive_v1, &mut incentive_v2, test_scenario::ctx(scenario));
            test_scenario::return_shared(pool);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(incentive_v1);
            test_scenario::return_shared(incentive_v2);
        }; 
    }

    #[test_only]
    public fun user_borrow_v2<CoinType>(scenario: &mut Scenario, user: address, asset: u8, amount: u64, clock: &Clock) {
        test_scenario::next_tx(scenario, user);
        {
            let pool = test_scenario::take_shared<Pool<CoinType>>(scenario);
            let storage = test_scenario::take_shared<Storage>(scenario);
            let oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let incentive_v2 = test_scenario::take_shared<Incentive_V2>(scenario);
            incentive_v2::entry_borrow_for_testing<CoinType>(clock, &oracle, &mut storage, &mut pool, asset, amount, &mut incentive_v2, test_scenario::ctx(scenario));
            test_scenario::return_shared(pool);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(oracle);
            test_scenario::return_shared(incentive_v2);
        }; 
    }

    #[test]
    public fun test_incentive_v3_upgrade() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));

        // 1.a V2 create reward pools
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            incentive_v3_util::init_protocol(scenario_mut);
        };

        // 1.b Delete the existing rules (Supply SUI and Borrow SUI)
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(scenario_mut);
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);

            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            incentive_v3::delete_rule_for_testing<SUI_TEST_V2>(&mut incentive, addr);

            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            incentive_v3::delete_rule_for_testing<SUI_TEST_V2>(&mut incentive, addr);

            // supply USDC
            user_deposit_v2<USDC_TEST_V2>(scenario_mut, OWNER, 1, 10000_000000, &clock);

            test_scenario::return_shared(incentive);
            test_scenario::return_to_sender(scenario_mut, owner_cap);
        };

        // 2. User A deposits 1000 SUI and borrows 1000 USDC
        test_scenario::next_tx(scenario_mut, USER_A);
        {
            user_deposit_v2<SUI_TEST_V2>(scenario_mut, USER_A, 0, 1000_000000000, &clock);
            user_borrow_v2<USDC_TEST_V2>(scenario_mut, USER_A, 1, 1000_000000, &clock);
        };

        // 3. pass half year
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            clock::increment_for_testing(&mut clock, 365 * 86400 * 1000 / 2);
        };

        // 4. User A claim parts of the reward pools(deposit SUI->SUI), remains the other part(deposit SUI->USDC, borrow USDC->COIN_TEST_V2)
        test_scenario::next_tx(scenario_mut, USER_A);
        {
            let sui_funds = test_scenario::take_shared<IncentiveFundsPool<SUI_TEST_V2>>(scenario_mut);
            incentive_v2_test::claim_reward_for_testing(scenario_mut, &clock, &mut sui_funds, 0, 1);
            let user_a_sui_amount = incentive_v3_util::get_coin_amount<SUI_TEST_V2>(scenario_mut, USER_A);
            assert!(user_a_sui_amount == 6666_666666666, 0);
            test_scenario::return_shared(sui_funds);
        };

        // Simulate upgrade

        // 5. Create v3 reward on the same asset
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            manage::create_incentive_v3_rule<SUI_TEST_V2, SUI_TEST_V2>(&owner_cap, &clock, &mut incentive, 1, test_scenario::ctx(scenario_mut));
            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            let rate_per_day = 100_000000000;
            let rate_time = 86400000;
            manage::set_incentive_v3_reward_rate_by_rule_id<SUI_TEST_V2>(&owner_cap, &clock, &mut incentive, &mut storage, addr, rate_per_day, rate_time, test_scenario::ctx(scenario_mut));

            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, USDC_TEST_V2>(&incentive, 1);
            let rate_per_day = 50_000000;
            let rate_time = 86400000;
            manage::set_incentive_v3_reward_rate_by_rule_id<SUI_TEST_V2>(&owner_cap, &clock, &mut incentive, &mut storage, addr, rate_per_day, rate_time, test_scenario::ctx(scenario_mut));

            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<USDC_TEST_V2, COIN_TEST_V2>(&incentive, 3);
            let rate_per_day = 200_000000000000;
            let rate_time = 86400000;
            manage::set_incentive_v3_reward_rate_by_rule_id<USDC_TEST_V2>(&owner_cap, &clock, &mut incentive, &mut storage, addr, rate_per_day, rate_time, test_scenario::ctx(scenario_mut));

            let (_, enable, rate, last_update_at, global_index) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            assert!(enable, 0);
            assert!(rate == 100_000000000 * 1_000000000000000000000000000 / 86400000, 0);   // 100 per day
            assert!(last_update_at == 365 * 86400 * 1000 / 2, 0);
            assert!(global_index == 0, 0);

            let (_, enable, rate, last_update_at, global_index) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, USDC_TEST_V2>(&incentive, 1);
            assert!(enable, 0);
            incentive_v3_util::assert_approximately_equal(rate, 50_000000 * 1_000000000000000000000000000 / 86400000, 1);   // 50 per day
            assert!(last_update_at == 365 * 86400 * 1000 / 2, 0);
            assert!(global_index == 0, 0);

            let (_, enable, rate, last_update_at, global_index) = incentive_v3::get_rule_params_for_testing<USDC_TEST_V2, COIN_TEST_V2>(&incentive, 3);
            assert!(enable, 0);
            incentive_v3_util::assert_approximately_equal(rate, 200_000000000000 * 1_000000000000000000000000000 / 86400000, 1);   // 200 per day
            assert!(last_update_at == 365 * 86400 * 1000 / 2, 0);
            assert!(global_index == 0, 0);

            test_scenario::return_shared(storage);
            test_scenario::return_shared(incentive);
            test_scenario::return_to_sender(scenario_mut, owner_cap);
        };

        // 6. Pass half year
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            clock::increment_for_testing(&mut clock, 365 * 86400 * 1000 / 2);
        };

        // 7.a Claim v2 rewards
        test_scenario::next_tx(scenario_mut, USER_A);
        {
            let sui_funds = test_scenario::take_shared<IncentiveFundsPool<SUI_TEST_V2>>(scenario_mut);
            incentive_v2_test::claim_reward_for_testing(scenario_mut, &clock, &mut sui_funds, 0, 1);
            let user_a_sui_amount = incentive_v3_util::get_coin_amount<SUI_TEST_V2>(scenario_mut, USER_A);
            assert!(user_a_sui_amount == 3333_333333333, 0);
            test_scenario::return_shared(sui_funds);

            let usdc_funds = test_scenario::take_shared<IncentiveFundsPool<USDC_TEST_V2>>(scenario_mut);
            incentive_v2_test::claim_reward_for_testing(scenario_mut, &clock, &mut usdc_funds, 0, 1);
            let user_a_usdc_amount = incentive_v3_util::get_coin_amount<USDC_TEST_V2>(scenario_mut, USER_A);
            assert!(user_a_usdc_amount == 1000_000000, 0);
            test_scenario::return_shared(usdc_funds);

            let coin_test_funds = test_scenario::take_shared<IncentiveFundsPool<COIN_TEST_V2>>(scenario_mut);
            incentive_v2_test::claim_reward_for_testing(scenario_mut, &clock, &mut coin_test_funds, 1, 3);
            let user_a_coin_test_amount = (incentive_v3_util::get_coin_amount<COIN_TEST_V2>(scenario_mut, USER_A) as u256);
            incentive_v3_util::assert_approximately_equal(user_a_coin_test_amount, 100000_000000000000, 1);
            test_scenario::return_shared(coin_test_funds);
        };

        // 7.b Claim v3 rewards(deposit SUI->SUI)
        test_scenario::next_tx(scenario_mut, USER_A);
        {
            incentive_v3_util::user_claim_reward<SUI_TEST_V2, SUI_TEST_V2>(scenario_mut, USER_A, 1, &clock);
        };

        // check state
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            let user_a_sui_amount = incentive_v3_util::get_coin_amount<SUI_TEST_V2>(scenario_mut, USER_A);
            assert!(user_a_sui_amount == 100_000000000 * 365 / 2, 0);

            let user_a_rewards = incentive_v3::get_user_claimable_rewards(&clock, &mut storage, &incentive, USER_A);
            assert!(vector::length(&user_a_rewards) == 3, 0);

            let (asset_coin_types, reward_coin_types, user_claimable_rewards, user_claimed_rewards, rule_ids) = incentive_v3::parse_claimable_rewards(user_a_rewards);
            
            assert!(vector::length(&asset_coin_types) == 3, 0);
            assert!(*vector::borrow(&asset_coin_types, 0) == type_name::into_string(type_name::get<USDC_TEST_V2>()), 0);
            assert!(*vector::borrow(&asset_coin_types, 1) == type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);
            assert!(*vector::borrow(&asset_coin_types, 2) == type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);

            assert!(vector::length(&reward_coin_types) == 3, 0);
            assert!(*vector::borrow(&reward_coin_types, 0) == type_name::into_string(type_name::get<COIN_TEST_V2>()), 0);
            assert!(*vector::borrow(&reward_coin_types, 1) == type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);
            assert!(*vector::borrow(&reward_coin_types, 2) == type_name::into_string(type_name::get<USDC_TEST_V2>()), 0);

            assert!(vector::length(&user_claimable_rewards) == 3, 0);
            assert!(*vector::borrow(&user_claimable_rewards, 0) == 200_000000000000 * 365 / 2, 0);
            assert!(*vector::borrow(&user_claimable_rewards, 1) == 0, 0);
            assert!(*vector::borrow(&user_claimable_rewards, 2) == 50_000000 * 365 / 2, 0);

            assert!(vector::length(&user_claimed_rewards) == 3, 0);
            assert!(*vector::borrow(&user_claimed_rewards, 0) == 0, 0);
            assert!(*vector::borrow(&user_claimed_rewards, 1) == 100_000000000 * 365 / 2, 0);
            assert!(*vector::borrow(&user_claimed_rewards, 2) == 0, 0);

            assert!(vector::length(&rule_ids) == 3, 0);
            let rules0 = vector::borrow(&rule_ids, 0);
            let rules1 = vector::borrow(&rule_ids, 1);
            let rules2 = vector::borrow(&rule_ids, 2);
            assert!(vector::length(rules0) == 1, 0);
            assert!(vector::length(rules1) == 0, 0);
            assert!(vector::length(rules2) == 1, 0);

            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<USDC_TEST_V2, COIN_TEST_V2>(&incentive, 3);
            assert!(vector::contains(rules0, &addr), 0);

            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, USDC_TEST_V2>(&incentive, 1);
            assert!(vector::contains(rules2, &addr), 0);

            test_scenario::return_shared(storage);
            test_scenario::return_shared(incentive);
        };

        // 8. Pass 1 year
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            clock::increment_for_testing(&mut clock, 365 * 86400 * 1000);
        };

        // 9. Claim all v3 rewards
        test_scenario::next_tx(scenario_mut, USER_A);
        {
            incentive_v3_util::user_claim_reward<SUI_TEST_V2, USDC_TEST_V2>(scenario_mut, USER_A, 1, &clock);
            incentive_v3_util::user_claim_reward<SUI_TEST_V2, SUI_TEST_V2>(scenario_mut, USER_A, 1, &clock);
            incentive_v3_util::user_claim_reward<USDC_TEST_V2, COIN_TEST_V2>(scenario_mut, USER_A, 3, &clock);
        };

        // check state
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            let user_a_sui_amount = incentive_v3_util::get_coin_amount<SUI_TEST_V2>(scenario_mut, USER_A);
            assert!(user_a_sui_amount == 100_000000000 * 365, 0);

            let user_a_usdc_amount = incentive_v3_util::get_coin_amount<USDC_TEST_V2>(scenario_mut, USER_A);
            assert!(user_a_usdc_amount == 50_000000 * 365 *  3 / 2, 0);

            let user_a_coin_test_amount = incentive_v3_util::get_coin_amount<COIN_TEST_V2>(scenario_mut, USER_A);
            assert!(user_a_coin_test_amount == 200_000000000000 * 365 * 3 / 2, 0);

            let user_a_rewards = incentive_v3::get_user_claimable_rewards(&clock, &mut storage, &incentive, USER_A);
            assert!(vector::length(&user_a_rewards) == 3, 0);

            let (asset_coin_types, reward_coin_types, user_claimable_rewards, user_claimed_rewards, rule_ids) = incentive_v3::parse_claimable_rewards(user_a_rewards);
            
            assert!(vector::length(&asset_coin_types) == 3, 0);
            assert!(*vector::borrow(&asset_coin_types, 0) == type_name::into_string(type_name::get<USDC_TEST_V2>()), 0);
            assert!(*vector::borrow(&asset_coin_types, 1) == type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);
            assert!(*vector::borrow(&asset_coin_types, 2) == type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);

            assert!(vector::length(&reward_coin_types) == 3, 0);
            assert!(*vector::borrow(&reward_coin_types, 0) == type_name::into_string(type_name::get<COIN_TEST_V2>()), 0);
            assert!(*vector::borrow(&reward_coin_types, 1) == type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);
            assert!(*vector::borrow(&reward_coin_types, 2) == type_name::into_string(type_name::get<USDC_TEST_V2>()), 0);

            assert!(vector::length(&user_claimable_rewards) == 3, 0);
            assert!(*vector::borrow(&user_claimable_rewards, 0) == 0 * 365 / 2, 0);
            assert!(*vector::borrow(&user_claimable_rewards, 1) == 0, 0);
            assert!(*vector::borrow(&user_claimable_rewards, 2) == 0 * 365 / 2, 0);

            assert!(vector::length(&user_claimed_rewards) == 3, 0);
            assert!(*vector::borrow(&user_claimed_rewards, 0) == 200_000000000000 * 365 * 3 / 2, 0);
            assert!(*vector::borrow(&user_claimed_rewards, 1) == 100_000000000 * 365 * 3 / 2, 0);
            assert!(*vector::borrow(&user_claimed_rewards, 2) == 50_000000 * 365 *  3 / 2, 0);

            assert!(vector::length(&rule_ids) == 3, 0);
            let rules0 = vector::borrow(&rule_ids, 0);
            let rules1 = vector::borrow(&rule_ids, 1);
            let rules2 = vector::borrow(&rule_ids, 2);
            assert!(vector::length(rules0) == 0, 0);
            assert!(vector::length(rules1) == 0, 0);
            assert!(vector::length(rules2) == 0, 0);

            test_scenario::return_shared(storage);
            test_scenario::return_shared(incentive);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }
}