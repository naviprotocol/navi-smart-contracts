module lending_ui::incentive_v3_getter {
    use std::vector::{Self};
    use std::ascii::String;
    use sui::clock::{Self, Clock};

    use sui::vec_map::{Self};
    use math::ray_math::{Self};
    use std::type_name::{Self};
    use lending_core::constants::{Self};
    use lending_core::storage::{Storage};
    use lending_core::incentive_v3::{Self, Incentive as IncentiveV3, Rule};

    public fun get_user_atomic_claimable_rewards(clock: &Clock, storage: &mut Storage, incentive: &IncentiveV3, user: address): (vector<String>, vector<String>, vector<u8>, vector<address>, vector<u256>){

        let asset_types = vector::empty<String>();
        let reward_types = vector::empty<String>();
        let options = vector::empty<u8>();
        let rule_ids = vector::empty<address>();
        let user_rewards = vector::empty<u256>();

        let pools = incentive_v3::pools(incentive);
        let pool_keys = vec_map::keys(pools);
        while (vector::length(&pool_keys) > 0) {
            let pool_key = vector::pop_back(&mut pool_keys);
            let asset_pool = vec_map::get(pools, &pool_key);
            
            let (_, asset, _, rules) = incentive_v3::get_pool_info(asset_pool);
            let rules_keys = vec_map::keys(rules);

            let (user_effective_supply, user_effective_borrow, total_supply, total_borrow) = incentive_v3::get_effective_balance(storage, asset, user);

            while (vector::length(&rules_keys) > 0) {
                let rule_key = vector::pop_back(&mut rules_keys);
                let rule = vec_map::get(rules, &rule_key);

                let (_, option, _, reward_coin_type, _, _, _, _, _, _) = incentive_v3::get_rule_info(rule);

                let global_index = calculate_global_index(clock, rule, total_supply, total_borrow);
                let user_total_reward = calculate_user_reward(rule, global_index, user, user_effective_supply, user_effective_borrow);
                let user_claimed_reward = incentive_v3::get_user_rewards_claimed_by_rule(rule, user);

                let user_claimable_reward = if (user_total_reward > user_claimed_reward) {
                    user_total_reward - user_claimed_reward
                } else {
                    0
                };

                if (user_claimable_reward > 0) {
                    vector::push_back(&mut asset_types, pool_key);
                    vector::push_back(&mut reward_types, reward_coin_type);
                    vector::push_back(&mut options, option);
                    vector::push_back(&mut rule_ids, rule_key);
                    vector::push_back(&mut user_rewards, user_claimable_reward);
                };
            };
        };

        (asset_types, reward_types, options, rule_ids, user_rewards)
    }

    public fun verify_rule_id_config<RewardCoinType>(incentive: &IncentiveV3, rule_id: address, check_asset_type: String, check_asset_id: u8, check_option: u8) {
        let pools = incentive_v3::pools(incentive);
        let asset_pool = vec_map::get(pools, &check_asset_type);
        let (_, asset, _, rules) = incentive_v3::get_pool_info(asset_pool);
        assert!(asset == check_asset_id, 1);

        let rule = vec_map::get(rules, &rule_id);
        let (_, option, _, reward_coin_type, _, _, _, _, _, _) = incentive_v3::get_rule_info(rule);
        assert!(check_option == option, 2);
        assert!(type_name::into_string(type_name::get<RewardCoinType>()) == reward_coin_type, 3);
    }

    fun calculate_global_index(clock: &Clock, rule: &Rule, total_supply: u256, total_borrow: u256): u256 {
        let (_, option, _, _, rate, last_update_at, global_index, _, _, _) = incentive_v3::get_rule_info(rule);
        let total_balance = if (option == constants::option_type_supply()) {
            total_supply
        } else if (option == constants::option_type_borrow()) {
            total_borrow
        } else {
            abort 0
        };
        
        let now = clock::timestamp_ms(clock);
        let duration = now - last_update_at;
        let index_increased = if (duration == 0 || total_balance == 0) {
            0
        } else {
            (rate * (duration as u256)) / total_balance
        };
        global_index + index_increased
    }

    fun calculate_user_reward(rule: &Rule, global_index: u256, user: address, user_effective_supply: u256, user_effective_borrow: u256): u256 {
        let (_, option, _, _, _, _, _, _, _, _) = incentive_v3::get_rule_info(rule);
        let user_balance = if (option == constants::option_type_supply()) {
            user_effective_supply
        } else if (option == constants::option_type_borrow()) {
            user_effective_borrow
        } else {
            abort 0
        };
        let user_index_diff = global_index - incentive_v3::get_user_index_by_rule(rule, user);
        let user_reward = incentive_v3::get_user_total_rewards_by_rule(rule, user);
        user_reward + ray_math::ray_mul(user_balance, user_index_diff)
    }
}