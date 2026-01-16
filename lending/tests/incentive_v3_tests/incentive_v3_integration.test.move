#[test_only]
#[allow(unused_use)]
module lending_core::incentive_v3_integration_test {
    use sui::clock;
    use sui::coin::{CoinMetadata, Coin};
    use sui::test_scenario::{Self, Scenario};
    use std::type_name::{Self};
    use std::vector::{Self};
    use sui::transfer;
    use sui::balance::{Self, Balance};
    use lending_core::ray_math::{Self};
    use sui::vec_map::{Self, VecMap};

    use oracle::oracle::{Self, OracleAdminCap, PriceOracle};
    use lending_core::incentive;
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
    use lending_core::incentive_v2::{Self, OwnerCap as IncentiveOwnerCap, Incentive as Incentive_V2, IncentiveFundsPool};
    use lending_core::incentive_v3::{Self, Incentive as Incentive_V3, RewardFund};

    use lending_core::incentive_v2_test::{Self};
    use lending_core::incentive_v3_util::{Self};

    const OWNER: address = @0xA;
    const USER_A: address = @0x1;
    const USER_B: address = @0x2;

    #[test]
    public fun test_incentive_v3_integration() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));

        {
            incentive_v3_util::init_protocol( scenario_mut);
            incentive_v3_util::user_deposit<USDC_TEST_V2>(scenario_mut, OWNER, 1, 10000_000000, &clock);
        
        };

        // 1. User A deposits 1000 SUI and borrows 1000 USDC
        test_scenario::next_tx(scenario_mut, USER_A);
        {
            incentive_v3_util::user_deposit<SUI_TEST_V2>(scenario_mut, USER_A, 0, 1000_000000000, &clock);
            incentive_v3_util::user_borrow<USDC_TEST_V2>(scenario_mut, USER_A, 1, 1000_000000, &clock);
        };

        // 2. set emission rate for SUI and USDC
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            // SUI supply rate
            let (_, enable, rate, last_update_at, global_index) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            assert!(enable, 0);
            assert!(rate == 100_000000000 * 1_000000000000000000000000000 / 86400000, 0);   // 100 per day
            assert!(last_update_at == 0, 0);
            assert!(global_index == 0, 0);

            let (_, enable, rate, last_update_at, global_index) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, USDC_TEST_V2>(&incentive, 1);
            assert!(enable, 0);
            assert!(rate == 0, 0);
            assert!(last_update_at == 0, 0);
            assert!(global_index == 0, 0);

            let (_, enable, rate, last_update_at, global_index) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, ETH_TEST_V2>(&incentive, 1);
            assert!(enable, 0);
            assert!(rate == 0, 0);
            assert!(last_update_at == 0, 0);
            assert!(global_index == 0, 0);

            let (_, enable, rate, last_update_at, global_index) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, COIN_TEST_V2>(&incentive, 1);
            assert!(enable, 0);
            assert!(rate == 0, 0);
            assert!(last_update_at == 0, 0);
            assert!(global_index == 0, 0);

            // set usdc borrow rate
            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<USDC_TEST_V2, USDC_TEST_V2>(&incentive, 3);
            let rate_per_day = 15_500000;
            let rate_time = 86400000;
            manage::set_incentive_v3_reward_rate_by_rule_id<USDC_TEST_V2>(&owner_cap, &clock, &mut incentive, &mut storage, addr, rate_per_day, rate_time, test_scenario::ctx(scenario_mut));
            manage::enable_incentive_v3_by_rule_id<USDC_TEST_V2>(&owner_cap, &mut incentive, addr, test_scenario::ctx(scenario_mut));

            //  USDC borrow rate
            let (_, enable, rate, last_update_at, global_index) = incentive_v3::get_rule_params_for_testing<USDC_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            assert!(enable, 0);
            assert!(rate == 0, 0);
            assert!(last_update_at == 0, 0);
            assert!(global_index == 0, 0);

            let (_, enable, rate, last_update_at, global_index) = incentive_v3::get_rule_params_for_testing<USDC_TEST_V2, ETH_TEST_V2>(&incentive, 3);
            assert!(enable, 0);
            assert!(rate == 0, 0);
            assert!(last_update_at == 0, 0);
            assert!(global_index == 0, 0);

            let (_, enable, rate, last_update_at, global_index) = incentive_v3::get_rule_params_for_testing<USDC_TEST_V2, USDC_TEST_V2>(&incentive, 3);
            assert!(enable, 0);
            assert!(rate == 15_500000 * 1_000000000000000000000000000 / 86400000, 0);   // 15.5 per day
            assert!(last_update_at == 0, 0);
            assert!(global_index == 0, 0);

            let (_, enable, rate, last_update_at, global_index) = incentive_v3::get_rule_params_for_testing<USDC_TEST_V2, COIN_TEST_V2>(&incentive, 3);
            assert!(enable, 0);
            assert!(rate == 0, 0);
            assert!(last_update_at == 0, 0);
            assert!(global_index == 0, 0);

            test_scenario::return_shared(storage);
            test_scenario::return_shared(incentive);
            test_scenario::return_to_sender(scenario_mut, owner_cap);
        };

        // 3. Pass 1 Year
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            clock::increment_for_testing(&mut clock, 365 * 86400 * 1000); // 1 year in milliseconds
        };

        // 4-1. User B deposits 1000 SUI
        test_scenario::next_tx(scenario_mut, USER_B);
        {
            incentive_v3_util::user_deposit<SUI_TEST_V2>(scenario_mut, USER_B, 0, 1000_000000000, &clock);
        };

        // Get USDC total borrow
        let total_borrow_usdc;
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            // Get effective balance for USDC
            let (_, _, _, total_borrow) = incentive_v3::get_effective_balance(&mut storage, 1, USER_A);
            total_borrow_usdc = total_borrow;

            test_scenario::return_shared(storage);
        };

        // 4-2. User B borrows 1000 USDC
        test_scenario::next_tx(scenario_mut, USER_B);
        {
            incentive_v3_util::user_borrow<USDC_TEST_V2>(scenario_mut, USER_B, 1, 1000_000000, &clock);
        };

        // check state
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            // check state
            let user_a_rewards = incentive_v3::get_user_claimable_rewards(&clock, &mut storage, &incentive, USER_A);
            assert!(vector::length(&user_a_rewards) == 2, 0);

            let (asset_coin_types,reward_coin_types, user_claimable_rewards, user_claimed_rewards, rule_ids) = incentive_v3::parse_claimable_rewards(user_a_rewards);

            // Check asset coin types
            assert!(vector::length(&asset_coin_types) == 2, 0);
            assert!(*vector::borrow(&asset_coin_types, 0) == type_name::into_string(type_name::get<USDC_TEST_V2>()), 0);
            assert!(*vector::borrow(&asset_coin_types, 1) == type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);

            // Check reward coin types
            assert!(vector::length(&reward_coin_types) == 2, 0);
            assert!(*vector::borrow(&reward_coin_types, 0) == type_name::into_string(type_name::get<USDC_TEST_V2>()), 0);
            assert!(*vector::borrow(&reward_coin_types, 1) == type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);

            // Check claimable rewards
            assert!(vector::length(&user_claimable_rewards) == 2, 0);
            assert!(*vector::borrow(&user_claimable_rewards, 0) == 15_500000 * 365, 0); // USDC rewards
            assert!(*vector::borrow(&user_claimable_rewards, 1) == 100_000000000 * 365, 0); // SUI rewards

            // Check claimed rewards
            assert!(vector::length(&user_claimed_rewards) == 2, 0);
            assert!(*vector::borrow(&user_claimed_rewards, 0) == 0, 0); // No USDC claimed yet
            assert!(*vector::borrow(&user_claimed_rewards, 1) == 0, 0); // No SUI claimed yet

            // Check rule IDs and rule info
            assert!(vector::length(&rule_ids) == 2, 0);
            let usdc_rules = vector::borrow(&rule_ids, 0);
            let sui_rules = vector::borrow(&rule_ids, 1);
            assert!(vector::length(usdc_rules) == 1, 0); // One rule ID for USDC
            assert!(vector::length(sui_rules) == 1, 0); // One rule ID for SUI

            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<USDC_TEST_V2, USDC_TEST_V2>(&incentive, 3);
            assert!(vector::contains(usdc_rules, &addr), 0);

            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            assert!(vector::contains(sui_rules, &addr), 0);

            test_scenario::return_shared(storage);
            test_scenario::return_shared(incentive);
        };

        // 5. Set emission rate for SUI and USDC
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            // Set SUI supply rate
            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, ETH_TEST_V2>(&incentive, 1);
            let rate_per_day = 1_000000000;
            let rate_time = 86400000;
            manage::set_incentive_v3_reward_rate_by_rule_id<SUI_TEST_V2>(&owner_cap, &clock, &mut incentive, &mut storage, addr, rate_per_day, rate_time, test_scenario::ctx(scenario_mut));
            manage::enable_incentive_v3_by_rule_id<SUI_TEST_V2>(&owner_cap, &mut incentive, addr, test_scenario::ctx(scenario_mut));

            // SUI supply rate
            let (_, enable, rate, last_update_at, global_index) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            assert!(enable, 0);
            assert!(rate == 100_000000000 * 1_000000000000000000000000000 / 86400000, 0);   // 100 per day
            assert!(last_update_at == 365 * 86400 * 1000, 0);
            // global index = 36499999999999999999999999999 --> 100_000000000 * 1_000000000000000000000000000 / 86400000 * 86400000 * 365 / 1000_000000000
            assert!(global_index == 100_000000000 * 1_000000000000000000000000000 / 86400000 * 86400000 * 365 / 1000_000000000, 0);

            let (_, enable, rate, last_update_at, global_index) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, USDC_TEST_V2>(&incentive, 1);
            assert!(enable, 0);
            assert!(rate == 0, 0);
            assert!(last_update_at == 365 * 86400 * 1000, 0);
            assert!(global_index == 0, 0);

            let (_, enable, rate, last_update_at, global_index) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, ETH_TEST_V2>(&incentive, 1);
            assert!(enable, 0);
            assert!(rate == 1_000000000 * 1_000000000000000000000000000 / 86400000, 0); // 1 per day
            assert!(last_update_at == 365 * 86400 * 1000, 0);
            assert!(global_index == 0, 0);

            let (_, enable, rate, last_update_at, global_index) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, COIN_TEST_V2>(&incentive, 1);
            assert!(enable, 0);
            assert!(rate == 0, 0);
            assert!(last_update_at == 365 * 86400 * 1000, 0);
            assert!(global_index == 0, 0);

            // set usdc borrow rate
            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<USDC_TEST_V2, USDC_TEST_V2>(&incentive, 3);
            let rate_per_day = 30_000000;
            let rate_time = 86400000;
            manage::set_incentive_v3_reward_rate_by_rule_id<USDC_TEST_V2>(&owner_cap, &clock, &mut incentive, &mut storage, addr, rate_per_day, rate_time, test_scenario::ctx(scenario_mut));
            manage::enable_incentive_v3_by_rule_id<USDC_TEST_V2>(&owner_cap, &mut incentive, addr, test_scenario::ctx(scenario_mut));

            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<USDC_TEST_V2, COIN_TEST_V2>(&incentive, 3);
            let rate_per_day = 15_000000000000;
            let rate_time = 86400000;

            manage::set_incentive_v3_reward_rate_by_rule_id<USDC_TEST_V2>(&owner_cap, &clock, &mut incentive, &mut storage, addr, rate_per_day, rate_time, test_scenario::ctx(scenario_mut));
            manage::enable_incentive_v3_by_rule_id<USDC_TEST_V2>(&owner_cap, &mut incentive, addr, test_scenario::ctx(scenario_mut));

            //  USDC borrow rate
            let (_, enable, rate, last_update_at, global_index) = incentive_v3::get_rule_params_for_testing<USDC_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            assert!(enable, 0);
            assert!(rate == 0, 0);
            assert!(last_update_at == 365 * 86400 * 1000, 0);
            assert!(global_index == 0, 0);

            let (_, enable, rate, last_update_at, global_index) = incentive_v3::get_rule_params_for_testing<USDC_TEST_V2, ETH_TEST_V2>(&incentive, 3);
            assert!(enable, 0);
            assert!(rate == 0, 0);
            assert!(last_update_at == 365 * 86400 * 1000, 0);
            assert!(global_index == 0, 0);

            let (_, enable, rate, last_update_at, global_index) = incentive_v3::get_rule_params_for_testing<USDC_TEST_V2, USDC_TEST_V2>(&incentive, 3);
            assert!(enable, 0);
            assert!(rate == 30_000000 * 1_000000000000000000000000000 / 86400000, 0);  
            assert!(last_update_at == 365 * 86400 * 1000, 0);
            // global index = 5578849381437234417328810 --> 15_500000 * 1_000000000000000000000000000 / 86400000 * 86400000 * 365 / 1014_097999997(total_borrow_usdc)
            assert!(global_index == 15_500000 * 1_000000000000000000000000000 / 86400000 * 86400000 * 365 / total_borrow_usdc, 0);

            let (_, enable, rate, last_update_at, global_index) = incentive_v3::get_rule_params_for_testing<USDC_TEST_V2, COIN_TEST_V2>(&incentive, 3);
            assert!(enable, 0);
            assert!(rate == 15_000000000000 * 1_000000000000000000000000000 / 86400000, 0);  
            assert!(last_update_at == 365 * 86400 * 1000, 0);
            assert!(global_index == 0, 0);

            test_scenario::return_shared(storage);
            test_scenario::return_shared(incentive);
            test_scenario::return_to_sender(scenario_mut, owner_cap);
        };

        // 6. Claim reward for borrow for user A
        test_scenario::next_tx(scenario_mut, USER_A);
        {
            incentive_v3_util::user_claim_reward<USDC_TEST_V2, USDC_TEST_V2>(scenario_mut, USER_A, 3, &clock);
        };

        // check state
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            // check how many rewards user A get
            let user_a_usdc_amount = incentive_v3_util::get_coin_amount<USDC_TEST_V2>(scenario_mut, USER_A);
            assert!(user_a_usdc_amount == 15_500000 * 365, 0);

            // check state
            let user_a_rewards = incentive_v3::get_user_claimable_rewards(&clock, &mut storage, &incentive, USER_A);
            assert!(vector::length(&user_a_rewards) == 2, 0);

            let (asset_coin_types, reward_coin_types, user_claimable_rewards, user_claimed_rewards, rule_ids) = incentive_v3::parse_claimable_rewards(user_a_rewards);

            // Check asset coin types   
            assert!(vector::length(&asset_coin_types) == 2, 0);
            assert!(*vector::borrow(&asset_coin_types, 0) == type_name::into_string(type_name::get<USDC_TEST_V2>()), 0);
            assert!(*vector::borrow(&asset_coin_types, 1) == type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);

            // Check reward coin types
            assert!(vector::length(&reward_coin_types) == 2, 0);
            assert!(*vector::borrow(&reward_coin_types, 0) == type_name::into_string(type_name::get<USDC_TEST_V2>()), 0);
            assert!(*vector::borrow(&reward_coin_types, 1) == type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);
            
            // Check claimable rewards
            assert!(vector::length(&user_claimable_rewards) == 2, 0);
            assert!(*vector::borrow(&user_claimable_rewards, 0) == 0, 0); // USDC rewards
            assert!(*vector::borrow(&user_claimable_rewards, 1) == 100_000000000 * 365, 0); // SUI rewards
    
            // Check claimed rewards
            assert!(vector::length(&user_claimed_rewards) == 2, 0);
            assert!(*vector::borrow(&user_claimed_rewards, 0) == 15_500000 * 365, 0); // USDC claimed
            assert!(*vector::borrow(&user_claimed_rewards, 1) == 0, 0); // No SUI claimed yet

            // Check rule IDs and rule info
            assert!(vector::length(&rule_ids) == 2, 0);
            let usdc_rules = vector::borrow(&rule_ids, 0);
            let sui_rules = vector::borrow(&rule_ids, 1);
            assert!(vector::length(usdc_rules) == 0, 0); // Zero rule ID for USDC
            assert!(vector::length(sui_rules) == 1, 0); // One rule ID for SUI

            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            assert!(vector::contains(sui_rules, &addr), 0);

            test_scenario::return_shared(storage);
            test_scenario::return_shared(incentive);
        };

        // 7. pass 1 year
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            clock::increment_for_testing(&mut clock, 365 * 86400 * 1000); // 1 year in milliseconds
        };

        // 8. Claim reward for supply for user A
        test_scenario::next_tx(scenario_mut, USER_A);
        {
            // claim reward for supply
            incentive_v3_util::user_claim_reward<SUI_TEST_V2, SUI_TEST_V2>(scenario_mut, USER_A, 1, &clock);
            incentive_v3_util::user_claim_reward<SUI_TEST_V2, ETH_TEST_V2>(scenario_mut, USER_A, 1, &clock);
        };

        // check state
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            // check how many rewards user A get
            let user_a_sui_amount = incentive_v3_util::get_coin_amount<SUI_TEST_V2>(scenario_mut, USER_A);
            assert!(user_a_sui_amount == 100_000000000 * 365 + 50_000000000 * 365, 0);

            let user_a_eth_amount = incentive_v3_util::get_coin_amount<ETH_TEST_V2>(scenario_mut, USER_A);
            assert!(user_a_eth_amount == 500000000 * 365, 0);

            // check state for user A
            let user_a_rewards = incentive_v3::get_user_claimable_rewards(&clock, &mut storage, &incentive, USER_A);
            assert!(vector::length(&user_a_rewards) == 4, 0);

            let (asset_coin_types, reward_coin_types, user_claimable_rewards, user_claimed_rewards, rule_ids) = incentive_v3::parse_claimable_rewards(user_a_rewards);

            // Check asset coin types
            assert!(vector::length(&asset_coin_types) == 4, 0);
            assert!(*vector::borrow(&asset_coin_types, 0) == type_name::into_string(type_name::get<USDC_TEST_V2>()), 0);
            assert!(*vector::borrow(&asset_coin_types, 1) == type_name::into_string(type_name::get<USDC_TEST_V2>()), 0);
            assert!(*vector::borrow(&asset_coin_types, 2) == type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);
            assert!(*vector::borrow(&asset_coin_types, 3) == type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);

            // Check reward coin types
            assert!(vector::length(&reward_coin_types) == 4, 0);
            assert!(*vector::borrow(&reward_coin_types, 0) == type_name::into_string(type_name::get<COIN_TEST_V2>()), 0);
            assert!(*vector::borrow(&reward_coin_types, 1) == type_name::into_string(type_name::get<USDC_TEST_V2>()), 0);
            assert!(*vector::borrow(&reward_coin_types, 2) == type_name::into_string(type_name::get<ETH_TEST_V2>()), 0);
            assert!(*vector::borrow(&reward_coin_types, 3) == type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);
            
            // Get effective balance for USDC
            let (_, user_effective_borrow, _, total_borrow) = incentive_v3::get_effective_balance(&mut storage, 1, USER_A);

            // Check claimable rewards
            assert!(vector::length(&user_claimable_rewards) == 4, 0);
            assert!(*vector::borrow(&user_claimable_rewards, 0) == 15_000000000000 * 365 * user_effective_borrow / total_borrow, 0); // COIN rewards
            assert!(*vector::borrow(&user_claimable_rewards, 1) == 30_000000 * 365 * user_effective_borrow / total_borrow, 0); // USDC rewards
            assert!(*vector::borrow(&user_claimable_rewards, 2) == 0, 0); // ETH rewards
            assert!(*vector::borrow(&user_claimable_rewards, 3) == 0, 0); // SUI rewards
    
            // Check claimed rewards
            assert!(vector::length(&user_claimed_rewards) == 4, 0);
            assert!(*vector::borrow(&user_claimed_rewards, 0) == 0, 0); // No COIN claimed yet
            assert!(*vector::borrow(&user_claimed_rewards, 1) == 15_500000 * 365, 0); // USDC claimed
            assert!(*vector::borrow(&user_claimed_rewards, 2) == 500000000 * 365, 0); // ETH claimed
            assert!(*vector::borrow(&user_claimed_rewards, 3) == 100_000000000 * 365 + 50_000000000 * 365, 0); // SUI claimed

            // Check rule IDs and rule info
            assert!(vector::length(&rule_ids) == 4, 0);
            let coin_rules = vector::borrow(&rule_ids, 0);
            let usdc_rules = vector::borrow(&rule_ids, 1);
            let eth_rules = vector::borrow(&rule_ids, 2);
            let sui_rules = vector::borrow(&rule_ids, 3);
            assert!(vector::length(coin_rules) == 1, 0); // One rule ID for COIN
            assert!(vector::length(usdc_rules) == 1, 0); // One rule ID for USDC
            assert!(vector::length(eth_rules) == 0, 0); // Zero rule ID for ETH
            assert!(vector::length(sui_rules) == 0, 0); // Zero rule ID for SUI

            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<USDC_TEST_V2, USDC_TEST_V2>(&incentive, 3);
            assert!(vector::contains(usdc_rules, &addr), 0);

            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<USDC_TEST_V2, COIN_TEST_V2>(&incentive, 3);
            assert!(vector::contains(coin_rules, &addr), 0);
            
            test_scenario::return_shared(storage);
            test_scenario::return_shared(incentive);
        };

        // 9. Claim reward for supply and borrow for user B
        test_scenario::next_tx(scenario_mut, USER_B);
        {
            // claim reward for supply
            incentive_v3_util::user_claim_reward<SUI_TEST_V2, SUI_TEST_V2>(scenario_mut, USER_B, 1, &clock);
            incentive_v3_util::user_claim_reward<SUI_TEST_V2, ETH_TEST_V2>(scenario_mut, USER_B, 1, &clock);

            // claim reward for borrow
            incentive_v3_util::user_claim_reward<USDC_TEST_V2, USDC_TEST_V2>(scenario_mut, USER_B, 3, &clock);
            incentive_v3_util::user_claim_reward<USDC_TEST_V2, COIN_TEST_V2>(scenario_mut, USER_B, 3, &clock);
        };

        // check state
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            // check how many rewards user B get
            let user_b_sui_amount = (incentive_v3_util::get_coin_amount<SUI_TEST_V2>(scenario_mut, USER_B) as u256);
            assert!(user_b_sui_amount == 50_000000000 * 365, 0);

            let user_b_eth_amount = (incentive_v3_util::get_coin_amount<ETH_TEST_V2>(scenario_mut, USER_B) as u256);
            assert!(user_b_eth_amount == 500000000 * 365, 0);

            // Get effective balance for USDC
            let (_, user_effective_borrow, _, total_borrow) = incentive_v3::get_effective_balance(&mut storage, 1, USER_B);

            let user_b_usdc_amount = (incentive_v3_util::get_coin_amount<USDC_TEST_V2>(scenario_mut, USER_B) as u256);
            let calculated_usdc_reward = 30_000000 * 365 * user_effective_borrow / total_borrow;
            lib::print(&user_b_usdc_amount);
            lib::print(&calculated_usdc_reward);
            incentive_v3_util::assert_approximately_equal(user_b_usdc_amount, calculated_usdc_reward, 1);

            let user_b_coin_amount = (incentive_v3_util::get_coin_amount<COIN_TEST_V2>(scenario_mut, USER_B) as u256);
            let calculated_coin_reward = 15_000000000000 * 365 * user_effective_borrow / total_borrow;
            lib::print(&user_b_coin_amount);
            lib::print(&calculated_coin_reward);
            incentive_v3_util::assert_approximately_equal(user_b_coin_amount, calculated_coin_reward, 1);

            // check state for user B
            let user_b_rewards = incentive_v3::get_user_claimable_rewards(&clock, &mut storage, &incentive, USER_B);
            assert!(vector::length(&user_b_rewards) == 4, 0);

            let (asset_coin_types, reward_coin_types, user_claimable_rewards, user_claimed_rewards, rule_ids) = incentive_v3::parse_claimable_rewards(user_b_rewards);

            // Check asset coin types
            assert!(vector::length(&asset_coin_types) == 4, 0);
            assert!(*vector::borrow(&asset_coin_types, 0) == type_name::into_string(type_name::get<USDC_TEST_V2>()), 0);
            assert!(*vector::borrow(&asset_coin_types, 1) == type_name::into_string(type_name::get<USDC_TEST_V2>()), 0);
            assert!(*vector::borrow(&asset_coin_types, 2) == type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);
            assert!(*vector::borrow(&asset_coin_types, 3) == type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);

            // Check reward coin types
            assert!(vector::length(&reward_coin_types) == 4, 0);
            assert!(*vector::borrow(&reward_coin_types, 0) == type_name::into_string(type_name::get<COIN_TEST_V2>()), 0);
            assert!(*vector::borrow(&reward_coin_types, 1) == type_name::into_string(type_name::get<USDC_TEST_V2>()), 0);
            assert!(*vector::borrow(&reward_coin_types, 2) == type_name::into_string(type_name::get<ETH_TEST_V2>()), 0);
            assert!(*vector::borrow(&reward_coin_types, 3) == type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);

            // Check claimable rewards
            assert!(vector::length(&user_claimable_rewards) == 4, 0);
            assert!(*vector::borrow(&user_claimable_rewards, 0) == 0, 0); // COIN rewards
            assert!(*vector::borrow(&user_claimable_rewards, 1) == 0, 0); // USDC rewards
            assert!(*vector::borrow(&user_claimable_rewards, 2) == 0, 0); // ETH rewards
            assert!(*vector::borrow(&user_claimable_rewards, 3) == 0, 0); // SUI rewards
    
            // Check claimed rewards
            assert!(vector::length(&user_claimed_rewards) == 4, 0);
            assert!(*vector::borrow(&user_claimed_rewards, 0) == user_b_coin_amount, 0); // COIN claimed
            assert!(*vector::borrow(&user_claimed_rewards, 1) == user_b_usdc_amount, 0); // USDC claimed
            assert!(*vector::borrow(&user_claimed_rewards, 2) == user_b_eth_amount, 0); // ETH claimed
            assert!(*vector::borrow(&user_claimed_rewards, 3) == user_b_sui_amount, 0); // SUI claimed

            // Check rule IDs and rule info
            assert!(vector::length(&rule_ids) == 4, 0);
            let coin_rules = vector::borrow(&rule_ids, 0);
            let usdc_rules = vector::borrow(&rule_ids, 1);
            let eth_rules = vector::borrow(&rule_ids, 2);
            let sui_rules = vector::borrow(&rule_ids, 3);
            assert!(vector::length(coin_rules) == 0, 0); // Zero rule ID for COIN
            assert!(vector::length(usdc_rules) == 0, 0); // Zero rule ID for USDC
            assert!(vector::length(eth_rules) == 0, 0); // Zero rule ID for ETH
            assert!(vector::length(sui_rules) == 0, 0); // Zero rule ID for SUI

            test_scenario::return_shared(storage);
            test_scenario::return_shared(incentive);
        };

        // 10. Claim reward for user A
        test_scenario::next_tx(scenario_mut, USER_A);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);
            let funds = test_scenario::take_shared<RewardFund<USDC_TEST_V2>>(scenario_mut);

            let rule_ids = vector::empty<address>();
            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<USDC_TEST_V2, USDC_TEST_V2>(&incentive, 3);
            vector::push_back(&mut rule_ids, addr);


            incentive_v3::claim_reward_entry<USDC_TEST_V2>(&clock, &mut incentive, &mut storage, &mut funds, vector::singleton(type_name::into_string(type_name::get<USDC_TEST_V2>())), rule_ids, test_scenario::ctx(scenario_mut));

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(funds);
        };
        
        // check state
        test_scenario::next_tx(scenario_mut, USER_A);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            // get effective borrow for USDC
            let (_, user_effective_borrow, _, total_borrow) = incentive_v3::get_effective_balance(&mut storage, 1, USER_A);
        
            // check how many rewards user A get
            let coin_second = test_scenario::take_from_sender<Coin<USDC_TEST_V2>>(scenario_mut);
            let user_a_usdc_amount_second:u256 = (coin::value(&coin_second) as u256);
            assert!(user_a_usdc_amount_second == (30_000000 * 365 * user_effective_borrow / total_borrow), 0);

            let coin_first = test_scenario::take_from_sender<Coin<USDC_TEST_V2>>(scenario_mut);
            let user_a_usdc_amount_first = (coin::value(&coin_first) as u256);
            assert!(user_a_usdc_amount_first == (15_500000 * 365), 0);
            
            // check state for user A
            let user_a_rewards = incentive_v3::get_user_claimable_rewards(&clock, &mut storage, &incentive, USER_A);
            assert!(vector::length(&user_a_rewards) == 4, 0);

            let (asset_coin_types, reward_coin_types, user_claimable_rewards, user_claimed_rewards, rule_ids) = incentive_v3::parse_claimable_rewards(user_a_rewards);

            // Check asset coin types
            assert!(vector::length(&asset_coin_types) == 4, 0);
            assert!(*vector::borrow(&asset_coin_types, 0) == type_name::into_string(type_name::get<USDC_TEST_V2>()), 0);
            assert!(*vector::borrow(&asset_coin_types, 1) == type_name::into_string(type_name::get<USDC_TEST_V2>()), 0);
            assert!(*vector::borrow(&asset_coin_types, 2) == type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);
            assert!(*vector::borrow(&asset_coin_types, 3) == type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);

            // Check reward coin types
            assert!(vector::length(&reward_coin_types) == 4, 0);
            assert!(*vector::borrow(&reward_coin_types, 0) == type_name::into_string(type_name::get<COIN_TEST_V2>()), 0);
            assert!(*vector::borrow(&reward_coin_types, 1) == type_name::into_string(type_name::get<USDC_TEST_V2>()), 0);
            assert!(*vector::borrow(&reward_coin_types, 2) == type_name::into_string(type_name::get<ETH_TEST_V2>()), 0);
            assert!(*vector::borrow(&reward_coin_types, 3) == type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);
            
            // Get effective balance for USDC
            let (_, user_effective_borrow, _, total_borrow) = incentive_v3::get_effective_balance(&mut storage, 1, USER_A);

            // Check claimable rewards
            assert!(vector::length(&user_claimable_rewards) == 4, 0);
            assert!(*vector::borrow(&user_claimable_rewards, 0) == 15_000000000000 * 365 * user_effective_borrow / total_borrow, 0); // COIN rewards
            assert!(*vector::borrow(&user_claimable_rewards, 1) == 0, 0); // USDC rewards
            assert!(*vector::borrow(&user_claimable_rewards, 2) == 0, 0); // ETH rewards
            assert!(*vector::borrow(&user_claimable_rewards, 3) == 0, 0); // SUI rewards
    
            // Check claimed rewards
            assert!(vector::length(&user_claimed_rewards) == 4, 0);
            assert!(*vector::borrow(&user_claimed_rewards, 0) == 0, 0); // No COIN claimed yet
            assert!(*vector::borrow(&user_claimed_rewards, 1) == (15_500000 * 365) + (30_000000 * 365 * user_effective_borrow / total_borrow), 0); // USDC claimed
            assert!(*vector::borrow(&user_claimed_rewards, 2) == 500000000 * 365, 0); // ETH claimed
            assert!(*vector::borrow(&user_claimed_rewards, 3) == 100_000000000 * 365 + 50_000000000 * 365, 0); // SUI claimed

            // Check rule IDs and rule info
            assert!(vector::length(&rule_ids) == 4, 0);
            let coin_rules = vector::borrow(&rule_ids, 0);
            let usdc_rules = vector::borrow(&rule_ids, 1);
            let eth_rules = vector::borrow(&rule_ids, 2);
            let sui_rules = vector::borrow(&rule_ids, 3);
            assert!(vector::length(coin_rules) == 1, 0); // One rule ID for COIN
            assert!(vector::length(usdc_rules) == 0, 0); // Zero rule ID for USDC
            assert!(vector::length(eth_rules) == 0, 0); // Zero rule ID for ETH
            assert!(vector::length(sui_rules) == 0, 0); // Zero rule ID for SUI

            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<USDC_TEST_V2, COIN_TEST_V2>(&incentive, 3);
            assert!(vector::contains(coin_rules, &addr), 0);
            
            test_scenario::return_to_sender(scenario_mut, coin_first);  
            test_scenario::return_to_sender(scenario_mut, coin_second);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(incentive);
        };

        // 11. Disable the USDC->USDC borrow rule for user A
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(scenario_mut);
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            
            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<USDC_TEST_V2, COIN_TEST_V2>(&incentive, 3);
            manage::disable_incentive_v3_by_rule_id<USDC_TEST_V2>(&owner_cap, &mut incentive, addr, test_scenario::ctx(scenario_mut));

            test_scenario::return_shared(incentive);
            test_scenario::return_to_sender(scenario_mut, owner_cap);
        };

        // 12. Claim 0 reward for user A
        test_scenario::next_tx(scenario_mut, USER_A);
        {
            incentive_v3_util::user_claim_reward<USDC_TEST_V2, COIN_TEST_V2>(scenario_mut, USER_A, 3, &clock);
        };

        // check state
        test_scenario::next_tx(scenario_mut, USER_A);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            // get effective borrow for USDC
            let (_, user_effective_borrow, _, total_borrow) = incentive_v3::get_effective_balance(&mut storage, 1, USER_A);
        
            // check how many rewards user A get
            let user_a_coin_amount = (incentive_v3_util::get_coin_amount<COIN_TEST_V2>(scenario_mut, USER_A) as u256);
            assert!(user_a_coin_amount == 0, 0);

            // check state for user A
            let user_a_rewards = incentive_v3::get_user_claimable_rewards(&clock, &mut storage, &incentive, USER_A);
            assert!(vector::length(&user_a_rewards) == 4, 0);

            let (asset_coin_types, reward_coin_types, user_claimable_rewards, user_claimed_rewards, rule_ids) = incentive_v3::parse_claimable_rewards(user_a_rewards);

            // Check asset coin types
            assert!(vector::length(&asset_coin_types) == 4, 0);
            assert!(*vector::borrow(&asset_coin_types, 0) == type_name::into_string(type_name::get<USDC_TEST_V2>()), 0);
            assert!(*vector::borrow(&asset_coin_types, 1) == type_name::into_string(type_name::get<USDC_TEST_V2>()), 0);
            assert!(*vector::borrow(&asset_coin_types, 2) == type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);
            assert!(*vector::borrow(&asset_coin_types, 3) == type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);

            // Check reward coin types
            assert!(vector::length(&reward_coin_types) == 4, 0);
            assert!(*vector::borrow(&reward_coin_types, 0) == type_name::into_string(type_name::get<COIN_TEST_V2>()), 0);
            assert!(*vector::borrow(&reward_coin_types, 1) == type_name::into_string(type_name::get<USDC_TEST_V2>()), 0);
            assert!(*vector::borrow(&reward_coin_types, 2) == type_name::into_string(type_name::get<ETH_TEST_V2>()), 0);
            assert!(*vector::borrow(&reward_coin_types, 3) == type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);
            
            // Get effective balance for USDC
            let (_, user_effective_borrow, _, total_borrow) = incentive_v3::get_effective_balance(&mut storage, 1, USER_A);

            // Check claimable rewards
            assert!(vector::length(&user_claimable_rewards) == 4, 0);
            assert!(*vector::borrow(&user_claimable_rewards, 0) == 15_000000000000 * 365 * user_effective_borrow / total_borrow, 0); // COIN rewards
            assert!(*vector::borrow(&user_claimable_rewards, 1) == 0, 0); // USDC rewards
            assert!(*vector::borrow(&user_claimable_rewards, 2) == 0, 0); // ETH rewards
            assert!(*vector::borrow(&user_claimable_rewards, 3) == 0, 0); // SUI rewards
    
            // Check claimed rewards
            assert!(vector::length(&user_claimed_rewards) == 4, 0);
            assert!(*vector::borrow(&user_claimed_rewards, 0) == 0, 0); // No COIN claimed yet
            assert!(*vector::borrow(&user_claimed_rewards, 1) == (15_500000 * 365) + (30_000000 * 365 * user_effective_borrow / total_borrow), 0); // USDC claimed
            assert!(*vector::borrow(&user_claimed_rewards, 2) == 500000000 * 365, 0); // ETH claimed
            assert!(*vector::borrow(&user_claimed_rewards, 3) == 100_000000000 * 365 + 50_000000000 * 365, 0); // SUI claimed

            // Check rule IDs and rule info
            assert!(vector::length(&rule_ids) == 4, 0);
            let coin_rules = vector::borrow(&rule_ids, 0);
            let usdc_rules = vector::borrow(&rule_ids, 1);
            let eth_rules = vector::borrow(&rule_ids, 2);
            let sui_rules = vector::borrow(&rule_ids, 3);
            assert!(vector::length(coin_rules) == 1, 0); // One rule ID for COIN
            assert!(vector::length(usdc_rules) == 0, 0); // Zero rule ID for USDC
            assert!(vector::length(eth_rules) == 0, 0); // Zero rule ID for ETH
            assert!(vector::length(sui_rules) == 0, 0); // Zero rule ID for SUI

            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<USDC_TEST_V2, COIN_TEST_V2>(&incentive, 3);
            assert!(vector::contains(coin_rules, &addr), 0);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);  
    }
    
    #[test]
    public fun test_deposit_borrow_repay_withdraw_claim() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));

        {
            incentive_v3_util::init_protocol( scenario_mut);
        };

        // deposit SUI
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            incentive_v3_util::user_deposit<SUI_TEST_V2>(scenario_mut, OWNER, 0, 100_000000000, &clock);
        };

        // borrow SUI
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI_TEST_V2>>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);
            let oracle = test_scenario::take_shared<PriceOracle>(scenario_mut);
            let incentive_v2 = test_scenario::take_shared<Incentive_V2>(scenario_mut);
            let incentive_v3 = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            
            let balance =incentive_v3::borrow<SUI_TEST_V2>(&clock, &oracle, &mut storage, &mut pool, 0, 10_000000000, &mut incentive_v2, &mut incentive_v3, test_scenario::ctx(scenario_mut));
            assert!(balance::value(&balance) == 10_000000000, 0);

            let coin = coin::from_balance(balance, test_scenario::ctx(scenario_mut));
            transfer::public_transfer(coin, test_scenario::sender(scenario_mut));

            test_scenario::return_shared(pool);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(oracle);
            test_scenario::return_shared(incentive_v2);
            test_scenario::return_shared(incentive_v3);
        };

        // repay SUI
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI_TEST_V2>>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);
            let incentive_v2 = test_scenario::take_shared<Incentive_V2>(scenario_mut);
            let incentive_v3 = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let oracle = test_scenario::take_shared<PriceOracle>(scenario_mut);

            let coin = test_scenario::take_from_sender<Coin<SUI_TEST_V2>>(scenario_mut);
            let balance = incentive_v3::repay<SUI_TEST_V2>(&clock, &oracle, &mut storage, &mut pool, 0, coin, 10_000000000, &mut incentive_v2, &mut incentive_v3, test_scenario::ctx(scenario_mut));
            
            balance::destroy_zero(balance);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(oracle);
            test_scenario::return_shared(incentive_v2);
            test_scenario::return_shared(incentive_v3);
        };

        // pass 1 year
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            
            // SUI supply rate
            let (_, enable, rate, last_update_at, global_index) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            assert!(enable, 0);
            assert!(rate == 100_000000000 * 1_000000000000000000000000000 / 86400000, 0);   // 100 per day
            assert!(last_update_at == 0, 0);
            assert!(global_index == 0, 0);

            clock::increment_for_testing(&mut clock, 365 * 86400 * 1000); // 1 year in milliseconds

            test_scenario::return_shared(incentive);
        };

        // claim reward
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);
            let funds = test_scenario::take_shared<RewardFund<SUI_TEST_V2>>(scenario_mut);

            let rule_ids = vector::empty<address>();
            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            vector::push_back(&mut rule_ids, addr);

            let balance = incentive_v3::claim_reward<SUI_TEST_V2>(&clock, &mut incentive, &mut storage, &mut funds, vector::singleton(type_name::into_string(type_name::get<SUI_TEST_V2>())), rule_ids, test_scenario::ctx(scenario_mut));
            assert!(balance::value(&balance) == 100_000000000 * 365, 0);

            let coin = coin::from_balance(balance, test_scenario::ctx(scenario_mut));
            transfer::public_transfer(coin, test_scenario::sender(scenario_mut));

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(funds);
        };

        // withdraw SUI
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI_TEST_V2>>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);
            let oracle = test_scenario::take_shared<PriceOracle>(scenario_mut);
            let incentive_v2 = test_scenario::take_shared<Incentive_V2>(scenario_mut);
            let incentive_v3 = test_scenario::take_shared<Incentive_V3>(scenario_mut);

            let balance = incentive_v3::withdraw<SUI_TEST_V2>(&clock, &oracle, &mut storage, &mut pool, 0, 100_000000000, &mut incentive_v2, &mut incentive_v3, test_scenario::ctx(scenario_mut));
            assert!(balance::value(&balance) == 100_000000000, 0);

            let coin = coin::from_balance(balance, test_scenario::ctx(scenario_mut));
            transfer::public_transfer(coin, test_scenario::sender(scenario_mut));
            
            test_scenario::return_shared(pool);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(oracle);
            test_scenario::return_shared(incentive_v2);
            test_scenario::return_shared(incentive_v3);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_deposit_borrow_repay_withdraw_claim_with_account_cap() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));

        {
            incentive_v3_util::init_protocol( scenario_mut);
            base_lending_tests::create_account_cap_for_testing(scenario_mut);
        };

        // deposit SUI
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(scenario_mut);
            let incentive_V2 = test_scenario::take_shared<Incentive_V2>(scenario_mut);
            let incentive_v3 = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let account_cap = test_scenario::take_from_sender<AccountCap>(scenario_mut);
            let pool = test_scenario::take_shared<Pool<SUI_TEST_V2>>(scenario_mut);

            let deposit_coin = coin::mint_for_testing<SUI_TEST_V2>(100_000000000, test_scenario::ctx(scenario_mut));
            incentive_v3::deposit_with_account_cap(&clock, &mut storage, &mut pool, 0, deposit_coin, &mut incentive_V2, &mut incentive_v3, &account_cap);

            test_scenario::return_shared(storage);
            test_scenario::return_shared(incentive_V2);
            test_scenario::return_shared(incentive_v3);
            test_scenario::return_shared(pool);
            test_scenario::return_to_sender(scenario_mut, account_cap);
        };

        // borrow SUI
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI_TEST_V2>>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);
            let oracle = test_scenario::take_shared<PriceOracle>(scenario_mut);
            let incentive_v2 = test_scenario::take_shared<Incentive_V2>(scenario_mut);
            let incentive_v3 = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let account_cap = test_scenario::take_from_sender<AccountCap>(scenario_mut);
            
            let balance =incentive_v3::borrow_with_account_cap<SUI_TEST_V2>(&clock, &oracle, &mut storage, &mut pool, 0, 10_000000000, &mut incentive_v2, &mut incentive_v3, &account_cap);
            assert!(balance::value(&balance) == 10_000000000, 0);

            let coin = coin::from_balance(balance, test_scenario::ctx(scenario_mut));
            transfer::public_transfer(coin, test_scenario::sender(scenario_mut));

            test_scenario::return_shared(pool);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(oracle);
            test_scenario::return_shared(incentive_v2);
            test_scenario::return_shared(incentive_v3);
            test_scenario::return_to_sender(scenario_mut, account_cap);
        };

        // repay SUI
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI_TEST_V2>>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);
            let incentive_v2 = test_scenario::take_shared<Incentive_V2>(scenario_mut);
            let incentive_v3 = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let oracle = test_scenario::take_shared<PriceOracle>(scenario_mut);
            let account_cap = test_scenario::take_from_sender<AccountCap>(scenario_mut);

            let coin = test_scenario::take_from_sender<Coin<SUI_TEST_V2>>(scenario_mut);
            let balance = incentive_v3::repay_with_account_cap<SUI_TEST_V2>(&clock, &oracle, &mut storage, &mut pool, 0, coin, &mut incentive_v2, &mut incentive_v3, &account_cap);
            
            balance::destroy_zero(balance);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(oracle);
            test_scenario::return_shared(incentive_v2);
            test_scenario::return_shared(incentive_v3);
            test_scenario::return_to_sender(scenario_mut, account_cap);
        };

        // pass 1 year
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);

            // SUI supply rate
            let (_, enable, rate, last_update_at, global_index) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            assert!(enable, 0);
            assert!(rate == 100_000000000 * 1_000000000000000000000000000 / 86400000, 0);   // 100 per day
            assert!(last_update_at == 0, 0);
            assert!(global_index == 0, 0);

            clock::increment_for_testing(&mut clock, 365 * 86400 * 1000); // 1 year in milliseconds

            test_scenario::return_shared(incentive);
        };

        // claim reward
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);
            let funds = test_scenario::take_shared<RewardFund<SUI_TEST_V2>>(scenario_mut);
            let account_cap = test_scenario::take_from_sender<AccountCap>(scenario_mut);

            let rule_ids = vector::empty<address>();
            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            vector::push_back(&mut rule_ids, addr);

            let balance = incentive_v3::claim_reward_with_account_cap<SUI_TEST_V2>(&clock, &mut incentive, &mut storage, &mut funds, vector::singleton(type_name::into_string(type_name::get<SUI_TEST_V2>())), rule_ids, &account_cap);
            assert!(balance::value(&balance) == 100_000000000 * 365, 0);

            let coin = coin::from_balance(balance, test_scenario::ctx(scenario_mut));
            transfer::public_transfer(coin, test_scenario::sender(scenario_mut));

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(funds);
            test_scenario::return_to_sender(scenario_mut, account_cap);
        };

        // withdraw SUI
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI_TEST_V2>>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);
            let oracle = test_scenario::take_shared<PriceOracle>(scenario_mut);
            let incentive_v2 = test_scenario::take_shared<Incentive_V2>(scenario_mut);
            let incentive_v3 = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let account_cap = test_scenario::take_from_sender<AccountCap>(scenario_mut);

            let balance = incentive_v3::withdraw_with_account_cap<SUI_TEST_V2>(&clock, &oracle, &mut storage, &mut pool, 0, 100_000000000, &mut incentive_v2, &mut incentive_v3, &account_cap);
            assert!(balance::value(&balance) == 100_000000000, 0);

            let coin = coin::from_balance(balance, test_scenario::ctx(scenario_mut));
            transfer::public_transfer(coin, test_scenario::sender(scenario_mut));
            
            test_scenario::return_shared(pool);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(oracle);
            test_scenario::return_shared(incentive_v2);
            test_scenario::return_shared(incentive_v3);
            test_scenario::return_to_sender(scenario_mut, account_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }
}