#[test_only]
module lending_core::incentive_v3_test {
    use std::{
        vector,
        ascii::{Self, String},
        type_name::{Self},
    };

    use sui::table;

    use sui::{
        coin::{Self, CoinMetadata},
        vec_map,
        clock::{Self, Clock},
        test_scenario::{Self, Scenario},
    };

    use lending_core::{
        base,
        pool::{Pool},
        storage::{Self, Storage, OwnerCap as StorageOwnerCap, StorageAdminCap},
        manage,
        incentive_v2::{Self, Incentive as IncentiveV2, OwnerCap as IncentiveOwnerCap},
        incentive_v3::{Self, Incentive as IncentiveV3, RewardFund},
        sui_test::{SUI_TEST},
        eth_test::{ETH_TEST},
        usdt_test::{USDT_TEST},
        usdc_test::{USDC_TEST},
    };

    use oracle::{
        oracle::{PriceOracle},
    };

    const OWNER: address = @0x1;
    const USERA: address = @0xA;
    const USERB: address = @0xB;
    const USERC: address = @0xC;

    #[test_only]
    public fun next_tx(scenario: &mut Scenario) {
        let sender = test_scenario::sender(scenario);
        test_scenario::next_tx(scenario, sender);
    }

    #[test_only]
    public fun create_incentive_owner_cap(s: &mut Scenario) {
        next_tx(s);
        {
            let storage_owner_cap = test_scenario::take_from_sender<StorageOwnerCap>(s);
            incentive_v2::create_and_transfer_owner(&storage_owner_cap, test_scenario::ctx(s));
            test_scenario::return_to_sender(s, storage_owner_cap);
        }
    }

    #[test_only]
    public fun create_incentive_fund<T>(s: &mut Scenario) {
        next_tx(s);
        {
            let incentive_owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(s);
            manage::create_incentive_v3_reward_fund<T>(&incentive_owner_cap, test_scenario::ctx(s));
            test_scenario::return_to_sender(s, incentive_owner_cap);
        }
    }

    #[test_only]
    public fun create_incentive_v3(s: &mut Scenario) {
        next_tx(s);
        {
            let incentive_owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(s);
            manage::create_incentive_v3(&incentive_owner_cap, test_scenario::ctx(s));
            test_scenario::return_to_sender(s, incentive_owner_cap);
        };
    }

    #[test_only]
    public fun create_incentive_pool<T>(s: &mut Scenario, asset_id: u8) {
        next_tx(s);
        {
            let _storage = test_scenario::take_shared<Storage>(s);
            let incentive_v3 = test_scenario::take_shared<IncentiveV3>(s);
            let incentive_owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(s);

            manage::create_incentive_v3_pool<T>(&incentive_owner_cap, &mut incentive_v3, &_storage, asset_id, test_scenario::ctx(s));

            test_scenario::return_to_sender(s, incentive_owner_cap);
            test_scenario::return_shared(incentive_v3);
            test_scenario::return_shared(_storage);
        }
    }

    #[test_only]
    public fun create_incentive_rule<PoolType, RewardType>(s: &mut Scenario, c: &Clock, option: u8) {
        next_tx(s);
        {
            let incentive_owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(s);
            let incentive_v3 = test_scenario::take_shared<IncentiveV3>(s);

            manage::create_incentive_v3_rule<PoolType, RewardType>(&incentive_owner_cap, c, &mut incentive_v3, option, test_scenario::ctx(s));

            test_scenario::return_to_sender(s, incentive_owner_cap);
            test_scenario::return_shared(incentive_v3);
        }
    }

    #[test_only]
    public fun deposit_reward_fund<T>(s: &mut Scenario, amount: u64) {
        next_tx(s);
        {
            let incentive_owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(s);
            let reward_fund = test_scenario::take_shared<RewardFund<T>>(s);

            let deposit_coin = coin::mint_for_testing<T>(amount, test_scenario::ctx(s));
            manage::deposit_incentive_v3_reward_fund<T>(&incentive_owner_cap, &mut reward_fund, deposit_coin, amount, test_scenario::ctx(s));

            test_scenario::return_to_sender(s, incentive_owner_cap);
            test_scenario::return_shared(reward_fund);
        }
    }

    #[test_only]
    public fun withdraw_reward_fund<T>(s: &mut Scenario, amount: u64, recipient: address) {
        next_tx(s);
        {
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(s);
            let reward_fund = test_scenario::take_shared<RewardFund<T>>(s);

            manage::withdraw_incentive_v3_reward_fund<T>(&storage_admin_cap, &mut reward_fund, amount, recipient, test_scenario::ctx(s));

            test_scenario::return_to_sender(s, storage_admin_cap);
            test_scenario::return_shared(reward_fund);
        }
    }

    #[test_only]
    public fun set_reward_rate<T, RewardType>(s: &mut Scenario, c: &Clock, option: u8, total_supply: u64, duration: u64) {
        next_tx(s);
        {
            let incentive_owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(s);
            let _storage = test_scenario::take_shared<Storage>(s);
            let incentive_v3 = test_scenario::take_shared<IncentiveV3>(s);

            let reward_coin_type = type_name::into_string(type_name::get<RewardType>());
            let coin_type = type_name::into_string(type_name::get<T>());
            let pools = incentive_v3::pools(&incentive_v3);
            assert!(vec_map::contains(pools, &coin_type), 0);
            let pool = vec_map::get(pools, &coin_type);

            let (_, _, _, rules) = incentive_v3::get_pool_info(pool); 
            let rule_ids = vec_map::keys(rules);
            while (vector::length(&rule_ids) > 0) {
                let id = vector::pop_back(&mut rule_ids);
                let rule = vec_map::get(rules, &id);

                let (_, rule_option, _, rule_reward_type, _, _, _, _, _, _) = incentive_v3::get_rule_info(rule);
                if (rule_option == option && rule_reward_type == reward_coin_type) {
                    manage::set_incentive_v3_reward_rate_by_rule_id<T>(&incentive_owner_cap, c, &mut incentive_v3, &mut _storage, id, total_supply, duration, test_scenario::ctx(s));
                    break
                }
            };

            test_scenario::return_shared(_storage);
            test_scenario::return_shared(incentive_v3);
            test_scenario::return_to_sender(s, incentive_owner_cap);
        };
    }

    #[test_only]
    public fun init_incentive_v3_for_testing(owner_scenario: &mut Scenario, clock: &Clock) {
        let deposit_amount = 1000000 * 100000000;
        // Create Incentive Owner Cap
        create_incentive_owner_cap(owner_scenario);

        next_tx(owner_scenario);
        {
            let owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(owner_scenario);
            incentive_v2::create_incentive(&owner_cap, test_scenario::ctx(owner_scenario));
            test_scenario::return_to_sender(owner_scenario, owner_cap);
        };

        // Create Incentive V3
        create_incentive_v3(owner_scenario);

        // Create Incentive Fund
        create_incentive_fund<SUI_TEST>(owner_scenario);
        create_incentive_fund<USDT_TEST>(owner_scenario);

        // Create Incentive Pool
        create_incentive_pool<SUI_TEST>(owner_scenario, 0);
        create_incentive_pool<USDC_TEST>(owner_scenario, 1);
        create_incentive_pool<USDT_TEST>(owner_scenario, 2);
        create_incentive_pool<ETH_TEST>(owner_scenario, 3);

        // Deposit Reward Fund
        deposit_reward_fund<SUI_TEST>(owner_scenario, deposit_amount);
        deposit_reward_fund<USDT_TEST>(owner_scenario, deposit_amount);

        // Create Incentive Rule
        create_incentive_rule<SUI_TEST, SUI_TEST>(owner_scenario, clock, 1);
        create_incentive_rule<SUI_TEST, SUI_TEST>(owner_scenario, clock, 3);
        create_incentive_rule<SUI_TEST, USDT_TEST>(owner_scenario, clock, 1);
        create_incentive_rule<SUI_TEST, USDT_TEST>(owner_scenario, clock, 3);
        create_incentive_rule<USDC_TEST, SUI_TEST>(owner_scenario, clock, 1);
        create_incentive_rule<USDC_TEST, SUI_TEST>(owner_scenario, clock, 3);
        create_incentive_rule<USDC_TEST, USDT_TEST>(owner_scenario, clock, 1);
        create_incentive_rule<USDC_TEST, USDT_TEST>(owner_scenario, clock,3);
        create_incentive_rule<USDT_TEST, SUI_TEST>(owner_scenario, clock, 1);
        create_incentive_rule<USDT_TEST, SUI_TEST>(owner_scenario, clock, 3);
        create_incentive_rule<USDT_TEST, USDT_TEST>(owner_scenario, clock, 1);
        create_incentive_rule<USDT_TEST, USDT_TEST>(owner_scenario, clock, 3);
        create_incentive_rule<ETH_TEST, SUI_TEST>(owner_scenario, clock, 1);
        create_incentive_rule<ETH_TEST, SUI_TEST>(owner_scenario, clock, 3);
        create_incentive_rule<ETH_TEST, USDT_TEST>(owner_scenario, clock, 1);
        create_incentive_rule<ETH_TEST, USDT_TEST>(owner_scenario, clock, 3);

        // Verify Incentive Pool And Rule Created
        next_tx(owner_scenario);
        {
            let incentive_v3 = test_scenario::take_shared<IncentiveV3>(owner_scenario);
            let pools = incentive_v3::pools(&incentive_v3);
            assert!(vec_map::size(pools) == 4, 0);

            {
                let coin_type = type_name::into_string(type_name::get<SUI_TEST>());
                assert!(vec_map::contains(pools, &coin_type), 0);
                let pool = vec_map::get(pools, &coin_type);

                let (_, _, _, rules) = incentive_v3::get_pool_info(pool); 
                assert!(vec_map::size(rules) == 4, 0);

                let sui_reward_type = type_name::into_string(type_name::get<SUI_TEST>());
                let usdt_reward_type = type_name::into_string(type_name::get<USDT_TEST>());

                assert!(incentive_v3::contains_rule(pool, 1, sui_reward_type), 0);
                assert!(incentive_v3::contains_rule(pool, 1, usdt_reward_type), 0);
                assert!(incentive_v3::contains_rule(pool, 3, sui_reward_type), 0);
                assert!(incentive_v3::contains_rule(pool, 3, usdt_reward_type), 0);
            };

            {
                let coin_type = type_name::into_string(type_name::get<USDC_TEST>());
                assert!(vec_map::contains(pools, &coin_type), 0);
                let pool = vec_map::get(pools, &coin_type);

                let (_, _, _, rules) = incentive_v3::get_pool_info(pool); 
                assert!(vec_map::size(rules) == 4, 0);

                let sui_reward_type = type_name::into_string(type_name::get<SUI_TEST>());
                let usdt_reward_type = type_name::into_string(type_name::get<USDT_TEST>());

                assert!(incentive_v3::contains_rule(pool, 1, sui_reward_type), 0);
                assert!(incentive_v3::contains_rule(pool, 1, usdt_reward_type), 0);
                assert!(incentive_v3::contains_rule(pool, 3, sui_reward_type), 0);
                assert!(incentive_v3::contains_rule(pool, 3, usdt_reward_type), 0);
            };

            {
                let coin_type = type_name::into_string(type_name::get<USDT_TEST>());
                assert!(vec_map::contains(pools, &coin_type), 0);
                let pool = vec_map::get(pools, &coin_type);

                let (_, _, _, rules) = incentive_v3::get_pool_info(pool); 
                assert!(vec_map::size(rules) == 4, 0);

                let sui_reward_type = type_name::into_string(type_name::get<SUI_TEST>());
                let usdt_reward_type = type_name::into_string(type_name::get<USDT_TEST>());

                assert!(incentive_v3::contains_rule(pool, 1, sui_reward_type), 0);
                assert!(incentive_v3::contains_rule(pool, 1, usdt_reward_type), 0);
                assert!(incentive_v3::contains_rule(pool, 3, sui_reward_type), 0);
                assert!(incentive_v3::contains_rule(pool, 3, usdt_reward_type), 0);
            };

            {
                let coin_type = type_name::into_string(type_name::get<ETH_TEST>());
                assert!(vec_map::contains(pools, &coin_type), 0);
                let pool = vec_map::get(pools, &coin_type);

                let (_, _, _, rules) = incentive_v3::get_pool_info(pool); 
                assert!(vec_map::size(rules) == 4, 0);

                let sui_reward_type = type_name::into_string(type_name::get<SUI_TEST>());
                let usdt_reward_type = type_name::into_string(type_name::get<USDT_TEST>());

                assert!(incentive_v3::contains_rule(pool, 1, sui_reward_type), 0);
                assert!(incentive_v3::contains_rule(pool, 1, usdt_reward_type), 0);
                assert!(incentive_v3::contains_rule(pool, 3, sui_reward_type), 0);
                assert!(incentive_v3::contains_rule(pool, 3, usdt_reward_type), 0);
            };

            test_scenario::return_shared(incentive_v3);
        };

        next_tx(owner_scenario);
        {
            {
                let reward_fund = test_scenario::take_shared<RewardFund<SUI_TEST>>(owner_scenario);

                assert!(incentive_v3::get_balance_value_by_reward_fund(&reward_fund) == deposit_amount, 0);

                test_scenario::return_shared(reward_fund);
            };
            {
                let reward_fund = test_scenario::take_shared<RewardFund<USDT_TEST>>(owner_scenario);

                assert!(incentive_v3::get_balance_value_by_reward_fund(&reward_fund) == deposit_amount, 0);

                test_scenario::return_shared(reward_fund);
            };
        }
    }

    #[test_only]
    public fun deposit<T>(s: &mut Scenario, c: &Clock, amount: u64) {
        {
            let pool = test_scenario::take_shared<Pool<T>>(s);
            let storage = test_scenario::take_shared<Storage>(s);
            let incentive_v3 = test_scenario::take_shared<IncentiveV3>(s);
            let incentive_v2 = test_scenario::take_shared<IncentiveV2>(s);
            let coin_metadata = test_scenario::take_immutable<CoinMetadata<T>>(s);
            let coin_type = type_name::into_string(type_name::get<T>());

            let reserve_count = storage::get_reserves_count(&storage);
            let i = 0;
            while (i < reserve_count) {
                let asset = storage::get_coin_type(&storage, i);
                if (asset == coin_type) {
                    let coin_decimals = coin::get_decimals(&coin_metadata);
                    let amt = std::u64::pow(10, coin_decimals);
                    let deposit_amount = amount * amt;
                    let deposit_coin = coin::mint_for_testing<T>(deposit_amount, test_scenario::ctx(s));
                    incentive_v3::entry_deposit(c, &mut storage, &mut pool, i, deposit_coin, deposit_amount, &mut incentive_v2, &mut incentive_v3, test_scenario::ctx(s));
                    break
                };
                i = i + 1;
            };

            test_scenario::return_shared(incentive_v3);
            test_scenario::return_shared(incentive_v2);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(pool);
            test_scenario::return_immutable(coin_metadata);
        }
    }

    #[test_only]
    public fun withdraw<T>(s: &mut Scenario, c: &Clock, amount: u64) {
        {
            let pool = test_scenario::take_shared<Pool<T>>(s);
            let storage = test_scenario::take_shared<Storage>(s);
            let price_oracle = test_scenario::take_shared<PriceOracle>(s);
            let incentive_v3 = test_scenario::take_shared<IncentiveV3>(s);
            let incentive_v2 = test_scenario::take_shared<IncentiveV2>(s);
            let coin_metadata = test_scenario::take_immutable<CoinMetadata<T>>(s);
            let coin_type = type_name::into_string(type_name::get<T>());

            let reserve_count = storage::get_reserves_count(&storage);
            let i = 0;
            while (i < reserve_count) {
                let asset = storage::get_coin_type(&storage, i);
                if (asset == coin_type) {
                    let coin_decimals = coin::get_decimals(&coin_metadata);
                    let amt = std::u64::pow(10, coin_decimals);
                    let withdraw_amount = amount * amt;
                    incentive_v3::entry_withdraw(c, &price_oracle, &mut storage, &mut pool, i, withdraw_amount, &mut incentive_v2, &mut incentive_v3, test_scenario::ctx(s));
                    break
                };
                i = i + 1;
            };

            test_scenario::return_shared(incentive_v3);
            test_scenario::return_shared(incentive_v2);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(pool);
            test_scenario::return_immutable(coin_metadata);
            test_scenario::return_shared(price_oracle);
        }
    }

    #[test_only]
    public fun claim_reward<T, RewardType>(s: &mut Scenario, c: &Clock, option: u8) {
        {
            let storage = test_scenario::take_shared<Storage>(s);
            let incentive_v3 = test_scenario::take_shared<IncentiveV3>(s);
            let incentive_v2 = test_scenario::take_shared<IncentiveV2>(s);
            let reward_fund = test_scenario::take_shared<RewardFund<RewardType>>(s);
            let coin_type = type_name::into_string(type_name::get<T>());

            let pools = incentive_v3::pools(&incentive_v3);
            assert!(vec_map::contains(pools, &coin_type), 0);
            let pool = vec_map::get(pools, &coin_type);

            let (_, _, _, rules) = incentive_v3::get_pool_info(pool); 
            let rule_ids = vec_map::keys(rules);
            while (vector::length(&rule_ids) > 0) {
                let id = vector::pop_back(&mut rule_ids);
                let rule = vec_map::get(rules, &id);

                let (_, rule_option, _, rule_reward_type, _, _, _, _, _, _) = incentive_v3::get_rule_info(rule);
                if (rule_option == option && rule_reward_type == type_name::into_string(type_name::get<RewardType>())) {
                    incentive_v3::claim_reward_entry<RewardType>(c, &mut incentive_v3, &mut storage, &mut reward_fund, vector::singleton(type_name::into_string(type_name::get<T>())), vector::singleton(id), test_scenario::ctx(s));
                    break
                }
            };

            test_scenario::return_shared(incentive_v3);
            test_scenario::return_shared(incentive_v2);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(reward_fund);
        }
    }

    #[test_only]
    public fun prepare_user_assets(c: &Clock, scenario: &mut Scenario) {
        // UserA deposit
        test_scenario::next_tx(scenario, USERA);
        {
            deposit<SUI_TEST>(scenario, c, 10000);
        };

        // UserB deposit
        test_scenario::next_tx(scenario, USERB);
        {
            deposit<SUI_TEST>(scenario, c, 990000);
        };
    }

    #[test]
    #[expected_failure(abort_code = 1505, location = lending_core::incentive_v3)]
    public fun test_create_incentive_pool_for_mismatch_asset_id_should_abort() {
        let scenario = test_scenario::begin(OWNER);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

        next_tx(&mut scenario);
        {
            base::initial_protocol(&mut scenario, &clock);
        };

        create_incentive_owner_cap(&mut scenario);

        create_incentive_v3(&mut scenario);

        create_incentive_pool<SUI_TEST>(&mut scenario, 1);

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = 1505, location = lending_core::incentive_v3)]
    public fun test_create_incentive_pool_for_mismatch_asset_coin_type_should_abort() {
        let scenario = test_scenario::begin(OWNER);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

        next_tx(&mut scenario);
        {
            base::initial_protocol(&mut scenario, &clock);
        };

        create_incentive_owner_cap(&mut scenario);

        create_incentive_v3(&mut scenario);

        create_incentive_pool<USDC_TEST>(&mut scenario, 0);

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 2001, location = lending_core::incentive_v3)]
    public fun test_create_incentive_pool_for_duplicate_asset_should_abort() {
        let scenario = test_scenario::begin(OWNER);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

        next_tx(&mut scenario);
        {
            base::initial_protocol(&mut scenario, &clock);
        };

        create_incentive_owner_cap(&mut scenario);

        create_incentive_v3(&mut scenario);

        create_incentive_pool<SUI_TEST>(&mut scenario, 0);
        create_incentive_pool<SUI_TEST>(&mut scenario, 0);

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_create_pool_should_pass() {
        let scenario = test_scenario::begin(OWNER);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

        next_tx(&mut scenario);
        {
            base::initial_protocol(&mut scenario, &clock);
        };

        create_incentive_owner_cap(&mut scenario);

        create_incentive_v3(&mut scenario);

        create_incentive_pool<SUI_TEST>(&mut scenario, 0);
        create_incentive_pool<USDC_TEST>(&mut scenario, 1);
        create_incentive_pool<ETH_TEST>(&mut scenario, 3);

        next_tx(&mut scenario);
        {
            let incentive_v3 = test_scenario::take_shared<IncentiveV3>(&scenario);
            let pools = incentive_v3::pools(&incentive_v3);

            {
                let coin_type = type_name::into_string(type_name::get<SUI_TEST>());
                assert!(vec_map::contains(pools, &coin_type), 0);
                let pool = vec_map::get(pools, &coin_type);
                let (_, _, asset_coin_type, _) = incentive_v3::get_pool_info(pool);
                assert!(asset_coin_type == coin_type, 0);
            };

            {
                let coin_type = type_name::into_string(type_name::get<USDC_TEST>());
                assert!(vec_map::contains(pools, &coin_type), 0);
                let pool = vec_map::get(pools, &coin_type);
                let (_, _, asset_coin_type, _) = incentive_v3::get_pool_info(pool);
                assert!(asset_coin_type == coin_type, 0);
            };

            {
                let coin_type = type_name::into_string(type_name::get<ETH_TEST>());
                assert!(vec_map::contains(pools, &coin_type), 0);
                let pool = vec_map::get(pools, &coin_type);
                let (_, _, asset_coin_type, _) = incentive_v3::get_pool_info(pool);
                assert!(asset_coin_type == coin_type, 0);
            };
            test_scenario::return_shared(incentive_v3);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 2100, location = lending_core::incentive_v3)]
    public fun test_create_rule_for_mismatch_pool_should_abort() {
        let scenario = test_scenario::begin(OWNER);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

        next_tx(&mut scenario);
        {
            base::initial_protocol(&mut scenario, &clock);
        };

        create_incentive_owner_cap(&mut scenario);

        create_incentive_v3(&mut scenario);

        create_incentive_pool<SUI_TEST>(&mut scenario, 0);

        create_incentive_rule<USDC_TEST, SUI_TEST>(&mut scenario, &clock, 1);

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 2104, location = lending_core::incentive_v3)]
    public fun test_create_rule_for_mismatch_option_should_abort() {
        let scenario = test_scenario::begin(OWNER);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

        next_tx(&mut scenario);
        {
            base::initial_protocol(&mut scenario, &clock);
        };

        create_incentive_owner_cap(&mut scenario);

        create_incentive_v3(&mut scenario);

        create_incentive_pool<SUI_TEST>(&mut scenario, 0);

        create_incentive_rule<SUI_TEST, SUI_TEST>(&mut scenario, &clock, 0);

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 2001, location = lending_core::incentive_v3)]
    public fun test_create_rule_for_duplicate_option_and_reward_type_should_abort() {
        let scenario = test_scenario::begin(OWNER);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

        next_tx(&mut scenario);
        {
            base::initial_protocol(&mut scenario, &clock);
        };

        create_incentive_owner_cap(&mut scenario);

        create_incentive_v3(&mut scenario);

        create_incentive_pool<SUI_TEST>(&mut scenario, 0);

        create_incentive_rule<SUI_TEST, SUI_TEST>(&mut scenario, &clock, 1);
        create_incentive_rule<SUI_TEST, SUI_TEST>(&mut scenario, &clock, 1);

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_create_rule_should_pass() {
        let scenario = test_scenario::begin(OWNER);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

        next_tx(&mut scenario);
        {
            base::initial_protocol(&mut scenario, &clock);
        };

        create_incentive_owner_cap(&mut scenario);

        create_incentive_v3(&mut scenario);

        create_incentive_pool<SUI_TEST>(&mut scenario, 0);

        create_incentive_rule<SUI_TEST, SUI_TEST>(&mut scenario, &clock, 1);
        create_incentive_rule<SUI_TEST, SUI_TEST>(&mut scenario, &clock, 3);
        create_incentive_rule<SUI_TEST, USDT_TEST>(&mut scenario, &clock, 1);
        create_incentive_rule<SUI_TEST, USDT_TEST>(&mut scenario, &clock, 3);

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 2100, location = lending_core::incentive_v3)]
    public fun test_set_enable_by_rule_id_for_mismatch_pool_should_abort() {
        let scenario = test_scenario::begin(OWNER);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

        next_tx(&mut scenario);
        {
            base::initial_protocol(&mut scenario, &clock);
        };

        create_incentive_owner_cap(&mut scenario);

        create_incentive_v3(&mut scenario);

        create_incentive_pool<SUI_TEST>(&mut scenario, 0);

        create_incentive_rule<SUI_TEST, SUI_TEST>(&mut scenario, &clock, 1);

        next_tx(&mut scenario);
        {
            let incentive_owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(&scenario);
            let _storage = test_scenario::take_shared<Storage>(&scenario);
            let coin_type = type_name::into_string(type_name::get<SUI_TEST>());
            let incentive_v3 = test_scenario::take_shared<IncentiveV3>(&scenario);
            let pools = incentive_v3::pools(&incentive_v3);
            let pool = vec_map::get(pools, &coin_type);

            let (_, _, _, rules) = incentive_v3::get_pool_info(pool); 
            assert!(vec_map::size(rules) == 1, 0);
            let rule_ids = vec_map::keys(rules);

            manage::enable_incentive_v3_by_rule_id<ETH_TEST>(&incentive_owner_cap, &mut incentive_v3, *vector::borrow(&rule_ids, 0), test_scenario::ctx(&mut scenario));

            test_scenario::return_shared(_storage);
            test_scenario::return_shared(incentive_v3);
            test_scenario::return_to_sender(&scenario, incentive_owner_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 2102, location = lending_core::incentive_v3)]
    public fun test_set_enable_by_rule_id_for_mismatch_rule_id_should_abort() {
        let scenario = test_scenario::begin(OWNER);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

        next_tx(&mut scenario);
        {
            base::initial_protocol(&mut scenario, &clock);
        };

        create_incentive_owner_cap(&mut scenario);

        create_incentive_v3(&mut scenario);

        create_incentive_pool<SUI_TEST>(&mut scenario, 0);

        create_incentive_rule<SUI_TEST, SUI_TEST>(&mut scenario, &clock, 1);

        next_tx(&mut scenario);
        {
            let incentive_owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(&scenario);
            let _storage = test_scenario::take_shared<Storage>(&scenario);
            let incentive_v3 = test_scenario::take_shared<IncentiveV3>(&scenario);

            manage::enable_incentive_v3_by_rule_id<SUI_TEST>(&incentive_owner_cap, &mut incentive_v3, @0x1, test_scenario::ctx(&mut scenario));

            test_scenario::return_shared(_storage);
            test_scenario::return_shared(incentive_v3);
            test_scenario::return_to_sender(&scenario, incentive_owner_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_set_enable_by_rule_id_should_pass() {
        let scenario = test_scenario::begin(OWNER);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

        next_tx(&mut scenario);
        {
            base::initial_protocol(&mut scenario, &clock);
        };

        create_incentive_owner_cap(&mut scenario);

        create_incentive_v3(&mut scenario);

        create_incentive_pool<SUI_TEST>(&mut scenario, 0);

        create_incentive_rule<SUI_TEST, SUI_TEST>(&mut scenario, &clock, 1);

        next_tx(&mut scenario);
        {
            let incentive_owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(&scenario);
            let _storage = test_scenario::take_shared<Storage>(&scenario);
            let coin_type = type_name::into_string(type_name::get<SUI_TEST>());
            let incentive_v3 = test_scenario::take_shared<IncentiveV3>(&scenario);
            let pools = incentive_v3::pools(&incentive_v3);
            let pool = vec_map::get(pools, &coin_type);

            let (_, _, _, rules) = incentive_v3::get_pool_info(pool); 
            assert!(vec_map::size(rules) == 1, 0);
            let rule_ids = vec_map::keys(rules);

            manage::enable_incentive_v3_by_rule_id<SUI_TEST>(&incentive_owner_cap, &mut incentive_v3, *vector::borrow(&rule_ids, 0), test_scenario::ctx(&mut scenario));

            test_scenario::return_shared(_storage);
            test_scenario::return_shared(incentive_v3);
            test_scenario::return_to_sender(&scenario, incentive_owner_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 2100, location = lending_core::incentive_v3)]
    public fun test_set_reward_rate_by_rule_id_for_mismatch_pool_should_abort() {
        let scenario = test_scenario::begin(OWNER);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

        next_tx(&mut scenario);
        {
            base::initial_protocol(&mut scenario, &clock);
        };

        create_incentive_owner_cap(&mut scenario);

        create_incentive_v3(&mut scenario);

        create_incentive_pool<SUI_TEST>(&mut scenario, 0);

        create_incentive_rule<SUI_TEST, SUI_TEST>(&mut scenario, &clock, 1);

        next_tx(&mut scenario);
        {
            let incentive_owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(&scenario);
            let _storage = test_scenario::take_shared<Storage>(&scenario);
            let coin_type = type_name::into_string(type_name::get<SUI_TEST>());
            let incentive_v3 = test_scenario::take_shared<IncentiveV3>(&scenario);
            let pools = incentive_v3::pools(&incentive_v3);
            let pool = vec_map::get(pools, &coin_type);

            let (_, _, _, rules) = incentive_v3::get_pool_info(pool); 
            assert!(vec_map::size(rules) == 1, 0);
            let rule_ids = vec_map::keys(rules);

            manage::set_incentive_v3_reward_rate_by_rule_id<ETH_TEST>(&incentive_owner_cap, &clock, &mut incentive_v3, &mut _storage, *vector::borrow(&rule_ids, 0), 3024000*1000000000, 60*60*24*7*1000, test_scenario::ctx(&mut scenario));

            test_scenario::return_shared(_storage);
            test_scenario::return_shared(incentive_v3);
            test_scenario::return_to_sender(&scenario, incentive_owner_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 2102, location = lending_core::incentive_v3)]
    public fun test_set_reward_rate_by_rule_id_for_mismatch_rule_id_should_abort() {
        let scenario = test_scenario::begin(OWNER);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

        next_tx(&mut scenario);
        {
            base::initial_protocol(&mut scenario, &clock);
        };

        create_incentive_owner_cap(&mut scenario);

        create_incentive_v3(&mut scenario);

        create_incentive_pool<SUI_TEST>(&mut scenario, 0);

        create_incentive_rule<SUI_TEST, SUI_TEST>(&mut scenario, &clock, 1);

        next_tx(&mut scenario);
        {
            let incentive_owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(&scenario);
            let _storage = test_scenario::take_shared<Storage>(&scenario);
            let incentive_v3 = test_scenario::take_shared<IncentiveV3>(&scenario);

            manage::set_incentive_v3_reward_rate_by_rule_id<SUI_TEST>(&incentive_owner_cap, &clock, &mut incentive_v3, &mut _storage, @0x1, 3024000*1000000000, 60*60*24*7*1000, test_scenario::ctx(&mut scenario));

            test_scenario::return_shared(_storage);
            test_scenario::return_shared(incentive_v3);
            test_scenario::return_to_sender(&scenario, incentive_owner_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1507, location = lending_core::incentive_v3)]
    public fun test_set_reward_rate_by_rule_id_for_mismatch_rate_should_abort() {
        let scenario = test_scenario::begin(OWNER);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

        next_tx(&mut scenario);
        {
            base::initial_protocol(&mut scenario, &clock);
        };

        create_incentive_owner_cap(&mut scenario);

        create_incentive_v3(&mut scenario);

        create_incentive_pool<SUI_TEST>(&mut scenario, 0);

        create_incentive_rule<SUI_TEST, SUI_TEST>(&mut scenario, &clock, 1);

        next_tx(&mut scenario);
        {
            let incentive_owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(&scenario);
            let _storage = test_scenario::take_shared<Storage>(&scenario);
            let coin_type = type_name::into_string(type_name::get<SUI_TEST>());
            let incentive_v3 = test_scenario::take_shared<IncentiveV3>(&scenario);
            let pools = incentive_v3::pools(&incentive_v3);
            let pool = vec_map::get(pools, &coin_type);

            let (_, _, _, rules) = incentive_v3::get_pool_info(pool); 
            assert!(vec_map::size(rules) == 1, 0);
            let rule_ids = vec_map::keys(rules);

            manage::set_incentive_v3_max_reward_rate_by_rule_id<SUI_TEST>(&incentive_owner_cap, &mut incentive_v3, *vector::borrow(&rule_ids, 0), 3024000*1000000000, 60*60*24*7*1000);

            manage::set_incentive_v3_reward_rate_by_rule_id<SUI_TEST>(&incentive_owner_cap, &clock, &mut incentive_v3, &mut _storage, *vector::borrow(&rule_ids, 0), 3024000*1000000000+1, 60*60*24*7*1000, test_scenario::ctx(&mut scenario));

            test_scenario::return_shared(_storage);
            test_scenario::return_shared(incentive_v3);
            test_scenario::return_to_sender(&scenario, incentive_owner_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_set_reward_rate_by_rule_id_should_pass() {
        let scenario = test_scenario::begin(OWNER);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

        next_tx(&mut scenario);
        {
            base::initial_protocol(&mut scenario, &clock);
        };

        create_incentive_owner_cap(&mut scenario);

        create_incentive_v3(&mut scenario);

        create_incentive_pool<SUI_TEST>(&mut scenario, 0);

        create_incentive_rule<SUI_TEST, SUI_TEST>(&mut scenario, &clock, 1);

        next_tx(&mut scenario);
        {
            let incentive_owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(&scenario);
            let _storage = test_scenario::take_shared<Storage>(&scenario);
            let coin_type = type_name::into_string(type_name::get<SUI_TEST>());
            let incentive_v3 = test_scenario::take_shared<IncentiveV3>(&scenario);
            let pools = incentive_v3::pools(&incentive_v3);
            let pool = vec_map::get(pools, &coin_type);

            let (_, _, _, rules) = incentive_v3::get_pool_info(pool); 
            assert!(vec_map::size(rules) == 1, 0);
            let rule_ids = vec_map::keys(rules);

            manage::set_incentive_v3_reward_rate_by_rule_id<SUI_TEST>(&incentive_owner_cap, &clock, &mut incentive_v3, &mut _storage, *vector::borrow(&rule_ids, 0), 3024000*1000000000, 60*60*24*7*1000, test_scenario::ctx(&mut scenario));

            test_scenario::return_shared(_storage);
            test_scenario::return_shared(incentive_v3);
            test_scenario::return_to_sender(&scenario, incentive_owner_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    public fun tedt_deposit_and_withdraw_reward_fund_should_pass() {
        let scenario = test_scenario::begin(OWNER);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

        next_tx(&mut scenario);
        {
            base::initial_protocol(&mut scenario, &clock);
        };

        create_incentive_owner_cap(&mut scenario);

        create_incentive_fund<SUI_TEST>(&mut scenario);

        next_tx(&mut scenario);
        {
            let reward_fund = test_scenario::take_shared<RewardFund<SUI_TEST>>(&scenario);

            let balance_value = incentive_v3::get_balance_value_by_reward_fund(&reward_fund);
            assert!(balance_value == 0, 0);

            test_scenario::return_shared(reward_fund);
        };

        deposit_reward_fund<SUI_TEST>(&mut scenario, 1000000000);
        
        next_tx(&mut scenario);
        {
            let reward_fund = test_scenario::take_shared<RewardFund<SUI_TEST>>(&scenario);

            let balance_value = incentive_v3::get_balance_value_by_reward_fund(&reward_fund);
            assert!(balance_value == 1000000000, 0);

            test_scenario::return_shared(reward_fund);
        };

        withdraw_reward_fund<SUI_TEST>(&mut scenario, 100000000, @0x0);

        next_tx(&mut scenario);
        {
            let reward_fund = test_scenario::take_shared<RewardFund<SUI_TEST>>(&scenario);

            let balance_value = incentive_v3::get_balance_value_by_reward_fund(&reward_fund);
            assert!(balance_value == 900000000, 0);

            test_scenario::return_shared(reward_fund);
        };

        withdraw_reward_fund<SUI_TEST>(&mut scenario, 1000000000, @0x0);

        next_tx(&mut scenario);
        {
            let reward_fund = test_scenario::take_shared<RewardFund<SUI_TEST>>(&scenario);

            let balance_value = incentive_v3::get_balance_value_by_reward_fund(&reward_fund);
            assert!(balance_value == 0, 0);

            test_scenario::return_shared(reward_fund);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_create_incentive_v3() {
        let scenario = test_scenario::begin(OWNER);

        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        clock::set_for_testing(&mut clock, 1000000000000);

        next_tx(&mut scenario);
        {
            base::initial_protocol(&mut scenario, &clock);
            init_incentive_v3_for_testing(&mut scenario, &clock);
        };

        prepare_user_assets(&clock, &mut scenario);

        // Reward Started
        test_scenario::next_tx(&mut scenario, OWNER);
        set_reward_rate<SUI_TEST, SUI_TEST>(&mut scenario, &clock, 1, 300*1000000000, 60*2*1000);

        // UserA Withdraw All After 10s -> 10s
        clock::increment_for_testing(&mut clock, 10 * 1000);
        test_scenario::next_tx(&mut scenario, USERA);
        {
            withdraw<SUI_TEST>(&mut scenario, &clock, 10000);
            // global index = 25000000000000000000000 --> (10*1000ms) * 0.0025rate / 1000000total_supply = 0.000025 * 1e27
            // user rewards = 250000000 --> (0.000025index * 10000user_supply) * 1e9 = 250000000
            assert_user_reward<SUI_TEST, SUI_TEST>(&mut scenario, 1, 25000000000000000000000, 25000000000000000000000, 250000000, 0);
        };

        // UserC Deposit 10000 After 10s -> 20s
        clock::increment_for_testing(&mut clock, 10 * 1000);
        test_scenario::next_tx(&mut scenario, USERC);
        {
            deposit<SUI_TEST>(&mut scenario, &clock, 1000);
            // global index = 50252525252525252525252 --> 0.000025 + (10*1000ms) * 0.0025rate / 990000total_supply = 0.00005025252525252525 * 1e27
            // user rewards = 0 --> (0.00005025252525252525index * 0user_supply) * 1e9 = 0
            assert_user_reward<SUI_TEST, SUI_TEST>(&mut scenario, 1, 50252525252525252525252, 50252525252525252525252, 0, 0);
        };

        // UserB Withdraw All After 10s -> 30s
        clock::increment_for_testing(&mut clock, 10 * 1000);
        test_scenario::next_tx(&mut scenario, USERB);
        {
            withdraw<SUI_TEST>(&mut scenario, &clock, 990000);
            // global index = 75479568643039884210418 --> 0.00005025252525252525 + (10*1000ms) * 0.0025rate / 991000total_supply = 0.00007547956864303988 * 1e27
            // user rewards = 74724772957 --> (0.00007547956864303988index * 990000user_supply) * 1e9 = 74724772957
            assert_user_reward<SUI_TEST, SUI_TEST>(&mut scenario, 1, 75479568643039884210418, 75479568643039884210418, 74724772957, 0);
        };

        // UserB Deposit 1000 After 10s -> 40s
        clock::increment_for_testing(&mut clock, 10 * 1000);
        test_scenario::next_tx(&mut scenario, USERB);
        {
            deposit<SUI_TEST>(&mut scenario, &clock, 1000);
            // global index = 25075479568643039884210418 --> 0.00007547956864303988 + (10*1000ms) * 0.0025rate / 1000total_supply = 0.02507547956864304 * 1e27
            // user rewards = 74724772957 --> 74724772957 + (0.02507547956864304index * 0user_supply) * 1e9 = 74724772957
            assert_user_reward<SUI_TEST, SUI_TEST>(&mut scenario, 1, 25075479568643039884210418, 25075479568643039884210418, 74724772957, 0);
        };

        // UserC Withdraw 1000 After 10s -> 50s
        clock::increment_for_testing(&mut clock, 10 * 1000);
        test_scenario::next_tx(&mut scenario, USERC);
        {
            withdraw<SUI_TEST>(&mut scenario, &clock, 1000);
            // global index = 37575479568643039884210418 --> 0.02507547956864304 + (10*1000ms) * 0.0025rate / 2000total_supply = 0.037575479568643044 * 1e27
            // user rewards = 37525227043 --> (0.037575479568643044index * 1000user_supply) * 1e9 = 37575479568
            assert_user_reward<SUI_TEST, SUI_TEST>(&mut scenario, 1, 37575479568643039884210418, 37575479568643039884210418, 37525227043, 0);
        };

        // UserB Claim Rewards After 10s -> 60s
        clock::increment_for_testing(&mut clock, 10 * 1000);
        test_scenario::next_tx(&mut scenario, USERB);
        {
            claim_reward<SUI_TEST, SUI_TEST>(&mut scenario, &clock, 1);
            // global index = 62575479568643039884210418 --> 0.037575479568643044 + (10*1000ms) * 0.0025rate / 1000total_supply = 0.06257547956864304 * 1e27
            // user rewards = 112224772957 --> 74724772957 + ((0.06257547956864304index - 0.02507547956864304index) * 1000user_supply) * 1e9 = 112224772957
            assert_user_reward<SUI_TEST, SUI_TEST>(&mut scenario, 1, 62575479568643039884210418, 62575479568643039884210418, 112224772957, 112224772957);
        };

        next_tx(&mut scenario);
        {
            let reward_fund = test_scenario::take_shared<RewardFund<SUI_TEST>>(&scenario);
            let balance_value = incentive_v3::get_balance_value_by_reward_fund(&reward_fund);
            assert!(balance_value == 100000000000000 - 112224772957, 0);

            test_scenario::return_shared(reward_fund);
        };

        show_reserves(&mut scenario);
        show_incentive_pool(&mut scenario, USERB);

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    struct ReserveBalance has copy, drop {
        coin_type: String,
        total_supply: u256,
        total_borrow: u256,
    }

    #[test_only]
    public fun show_reserves(s: &mut Scenario) {
        std::debug::print(&ascii::string(b"------------------- Show Reserves -------------------"));
        next_tx(s);
        {
            let _storage = test_scenario::take_shared<Storage>(s);
            let reserve_count = storage::get_reserves_count(&_storage);

            std::debug::print(&reserve_count);
            while (reserve_count > 0) {
                let (supply_balance, borrow_balance) = storage::get_total_supply(&mut _storage, reserve_count - 1);
                let coin_type = storage::get_coin_type(&_storage, reserve_count - 1);
                let reserve = storage::get_reserve_for_testing(&_storage, reserve_count - 1);

                std::debug::print(reserve);
                std::debug::print(&ReserveBalance {
                    coin_type: coin_type,
                    total_supply: supply_balance,
                    total_borrow: borrow_balance,
                });
                reserve_count = reserve_count - 1;
            };

            test_scenario::return_shared(_storage)
        };
    }

    struct RuleInfo has copy, drop {
        pool_id: address,
        asset: u8,
        asset_coin_type: String,
        rule_id: address,
        rule_option: u8,
        rule_enable: bool,
        rule_reward_coin_type: String,
        rule_rate: u256,
        rule_last_update_at: u64,
        rule_global_index: u256,
        rule_user_index: u256,
        rule_user_rewards: u256,
        rule_user_rewards_claimed: u256,
    }

    #[test_only]
    public fun show_incentive_pool(s: &mut Scenario, user: address) {
        std::debug::print(&ascii::string(b"------------------- Show Incentive Pool -------------------"));
        next_tx(s);
        {
            let incentive_v3 = test_scenario::take_shared<IncentiveV3>(s);
            let pools = incentive_v3::pools(&incentive_v3);
            let pool_keys = vec_map::keys(pools);

            while (vector::length(&pool_keys) > 0) {
                let key = vector::pop_back(&mut pool_keys);
                let pool = vec_map::get(pools, &key);

                let (pool_id, pool_asset_id, pool_asset_coin_type, _) = incentive_v3::get_pool_info(pool);
                
                let (_, _, _, rules) = incentive_v3::get_pool_info(pool); 
                let rule_keys = vec_map::keys(rules);
                while (vector::length(&rule_keys) > 0) {
                    let rule_key = vector::pop_back(&mut rule_keys);
                    let rule = vec_map::get(rules, &rule_key);


                    let (rule_id, rule_option, rule_enable, rule_reward_coin_type, rule_rate, rule_last_update_at, rule_global_index, rule_user_indices, rule_user_rewards, rule_user_rewards_claimeds) = incentive_v3::get_rule_info(rule);
                    let rule_user_index = if (table::contains(rule_user_indices, user)) {
                        *table::borrow(rule_user_indices, user)
                    } else {
                        0
                    };
                    let rule_user_rewards = if (table::contains(rule_user_rewards, user)) {
                        *table::borrow(rule_user_rewards, user)
                    } else {
                        0
                    };
                    let rule_user_rewards_claimed = if (table::contains(rule_user_rewards_claimeds, user)) {
                        *table::borrow(rule_user_rewards_claimeds, user)
                    } else {
                        0
                    };
                    let r = RuleInfo {
                        pool_id: pool_id,
                        asset: pool_asset_id,
                        asset_coin_type: pool_asset_coin_type,
                        rule_id: rule_id,
                        rule_option: rule_option,
                        rule_enable: rule_enable,
                        rule_reward_coin_type: rule_reward_coin_type,
                        rule_rate: rule_rate,
                        rule_last_update_at: rule_last_update_at,
                        rule_global_index: rule_global_index,
                        rule_user_index: rule_user_index,
                        rule_user_rewards: rule_user_rewards,
                        rule_user_rewards_claimed: rule_user_rewards_claimed,
                    };
                    std::debug::print(&r);
                };
            };

            test_scenario::return_shared(incentive_v3);
        }
    }

    #[test_only]
    public fun assert_user_reward<T, RewardType>(s: &mut Scenario, option: u8, expected_global_index: u256, expected_user_index: u256, expected_user_rewards: u256, expected_user_rewards_claimed: u256) {
        let u = test_scenario::sender(s);
        next_tx(s);
        {
            let incentive_v3 = test_scenario::take_shared<IncentiveV3>(s);
            let pools = incentive_v3::pools(&incentive_v3);
            assert!(vec_map::contains(pools, &type_name::into_string(type_name::get<T>())), 0);
            let pool = vec_map::get(pools, &type_name::into_string(type_name::get<T>()));

            let (_, _, _, rules) = incentive_v3::get_pool_info(pool); 
            let rule_keys = vec_map::keys(rules);
            while (vector::length(&rule_keys) > 0) {
                let rule_key = vector::pop_back(&mut rule_keys);
                let rule = vec_map::get(rules, &rule_key);
                let (_, rule_option, _, rule_reward_coin_type, _, _, rule_global_index, _, _, _) = incentive_v3::get_rule_info(rule);

                if (rule_reward_coin_type == type_name::into_string(type_name::get<RewardType>()) && rule_option == option) {
                    let rule_user_index = incentive_v3::get_user_index_by_rule(rule, u);
                    let rule_user_rewards = incentive_v3::get_user_total_rewards_by_rule(rule, u);
                    let rule_user_rewards_claimed = incentive_v3::get_user_rewards_claimed_by_rule(rule, u);

                    assert!(rule_global_index == expected_global_index, 0);
                    assert!(rule_user_index == expected_user_index, 0);
                    assert!(rule_user_rewards == expected_user_rewards, 0);
                    assert!(rule_user_rewards_claimed == expected_user_rewards_claimed, 0);
                    break
                };
            };
            test_scenario::return_shared(incentive_v3);
        }
    }
}