#[test_only]
#[allow(unused_use)]
module lending_core::incentive_v3_test_target {
    use sui::clock;
    use sui::coin::{CoinMetadata, Coin};
    use sui::test_scenario::{Self, Scenario};
    use std::type_name::{Self};
    use std::ascii::{Self, String};
    use std::vector::{Self};
    use sui::transfer;
    use lending_core::ray_math::{Self};
    use sui::vec_map::{Self, VecMap};

    use oracle::oracle::{Self, OracleAdminCap, PriceOracle};
    use lending_core::incentive;
    use lending_core::manage;
    use lending_core::version;
    use lending_core::pool::{Self, PoolAdminCap, Pool};
    use lending_core::btc_test_v2::{Self, BTC_TEST_V2};
    use lending_core::eth_test_v2::{Self, ETH_TEST_V2};
    use lending_core::sui_test_v2::{Self, SUI_TEST_V2};
    use lending_core::usdc_test_v2::{Self, USDC_TEST_V2};
    use lending_core::coin_test_v2::{Self, COIN_TEST_V2};
    use lending_core::usdt_test_v2::{Self, USDT_TEST_V2};
    use sui::coin::{Self};
    use sui::table::{Self};
    use lending_core::lib::{Self};

    use lending_core::storage::{Self, Storage, StorageAdminCap, OwnerCap as StorageOwnerCap};
    use lending_core::incentive_v2::{Self, OwnerCap as IncentiveOwnerCap, Incentive as Incentive_V2, IncentiveFundsPool};
    use lending_core::incentive_v3::{Self, Incentive as Incentive_V3, RewardFund};

    use lending_core::incentive_v2_test::{Self};
    use lending_core::incentive_v3_util::{Self};


    const OWNER: address = @0xA;

    // Should create_incentive with correct parameters
    #[test]
    public fun test_init_incentive_v3() {
        let scenario = test_scenario::begin(OWNER);
        {
            incentive_v3_util::init_protocol(&mut scenario);
        };
        test_scenario::end(scenario);
    }

    //--------Lending Entry---------------

    // Should deposit/borrow/repay/withdraw successfully
    #[test]
    public fun test_deposit_borrow_repay_withdraw() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));

        {
            incentive_v3_util::init_protocol( scenario_mut);
        };

        incentive_v3_util::user_deposit<SUI_TEST_V2>(scenario_mut, OWNER, 0, 1000_000000000, &clock);
        incentive_v3_util::user_borrow<SUI_TEST_V2>(scenario_mut, OWNER, 0, 10_000000000, &clock);
        incentive_v3_util::user_repay<SUI_TEST_V2>(scenario_mut, OWNER, 0, 10_000000000, &clock);
        incentive_v3_util::user_withdraw<SUI_TEST_V2>(scenario_mut, OWNER, 0, 1000_000000000, &clock);

        incentive_v3_util::user_deposit<USDC_TEST_V2>(scenario_mut, OWNER, 1, 1000_000000000, &clock);
        incentive_v3_util::user_borrow<USDC_TEST_V2>(scenario_mut, OWNER, 1, 10_000000000, &clock);
        incentive_v3_util::user_repay<USDC_TEST_V2>(scenario_mut, OWNER, 1, 10_000000000, &clock);
        incentive_v3_util::user_withdraw<USDC_TEST_V2>(scenario_mut, OWNER, 1, 1000_000000000, &clock);

        incentive_v3_util::user_deposit<ETH_TEST_V2>(scenario_mut, OWNER, 2, 1000_000000000, &clock);
        incentive_v3_util::user_borrow<ETH_TEST_V2>(scenario_mut, OWNER, 2, 10_000000000, &clock);
        incentive_v3_util::user_repay<ETH_TEST_V2>(scenario_mut, OWNER, 2, 10_000000000, &clock);
        incentive_v3_util::user_withdraw<ETH_TEST_V2>(scenario_mut, OWNER, 2, 1000_000000000, &clock);

        incentive_v3_util::user_deposit<BTC_TEST_V2>(scenario_mut, OWNER, 3, 1000_000000000, &clock);
        incentive_v3_util::user_borrow<BTC_TEST_V2>(scenario_mut, OWNER, 3, 10_000000000, &clock);
        incentive_v3_util::user_repay<BTC_TEST_V2>(scenario_mut, OWNER, 3, 10_000000000, &clock);
        incentive_v3_util::user_withdraw<BTC_TEST_V2>(scenario_mut, OWNER, 3, 1000_000000000, &clock);

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);  
    }



    //--------Pool/Rule---------------

    // Should create_incentive_pool successfully create an incentive pool with valid parameters and cap
    #[test]
    public fun test_create_incentive_pool() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;

        {
            incentive_v3_util::init_protocol( scenario_mut);
        };

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            // configured from init_protocol
            let (_, asset_id, coin_type, rule_num) = incentive_v3::get_asset_pool_params_for_testing<SUI_TEST_V2>(&incentive);
            
            assert!(asset_id == 0, 0);
            assert!(coin_type == type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);
            assert!(rule_num == 8, 0);

            test_scenario::return_shared(incentive);
        };
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1505, location = lending_core::incentive_v3)]
    // Should create_incentive_pool failed when provided with invalid asset id
    public fun test_failed_create_incentive_pool_invalid_asset() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        {
            incentive_v3_util::init_protocol( scenario_mut);
        };

        // create pool
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(scenario_mut);
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            manage::create_incentive_v3_pool<BTC_TEST_V2>(&owner_cap, &mut incentive, &storage, 0, test_scenario::ctx(scenario_mut));
            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
            test_scenario::return_to_sender(scenario_mut, owner_cap);
        };
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1, location = sui::dynamic_field)]
    // Should create_incentive_pool failed when provided with non-existed asset id
    public fun test_failed_create_incentive_pool_non_existed_asset() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        {
            incentive_v3_util::init_protocol( scenario_mut);
        };

        // create pool
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(scenario_mut);
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            manage::create_incentive_v3_pool<BTC_TEST_V2>(&owner_cap, &mut incentive, &storage, 100, test_scenario::ctx(scenario_mut));
            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
            test_scenario::return_to_sender(scenario_mut, owner_cap);
        };
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 2001, location = lending_core::incentive_v3)]
    // Should create_incentive_pool failed when provided with duplicated asset id
    public fun test_failed_create_incentive_pool_duplicated_asset() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        {
            incentive_v3_util::init_protocol( scenario_mut);
        };

        // create pool
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(scenario_mut);
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            manage::create_incentive_v3_pool<SUI_TEST_V2>(&owner_cap, &mut incentive, &storage, 0, test_scenario::ctx(scenario_mut));
            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
            test_scenario::return_to_sender(scenario_mut, owner_cap);
        };
        test_scenario::end(scenario);
    }

    #[test]
    // Should create_rule successfully with valid parameters and cap
    public fun test_create_rule() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;

        {
            incentive_v3_util::init_protocol( scenario_mut);
        };

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            // configured from init_protocol
            let (_, enable, rate, last_update_at, global_index) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            assert!(enable, 0);
            assert!(rate == 100_000000000 * 1_000000000000000000000000000 / 86400000, 0);
            assert!(last_update_at == 0, 0);
            assert!(global_index == 0, 0);

            let (_, enable, rate, last_update_at, global_index) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            assert!(enable, 0);
            assert!(rate == ray_math::ray_div(50_000000000, 86400000), 0);
            assert!(last_update_at == 0, 0);
            assert!(global_index == 0, 0);

            let (_, enable, rate, last_update_at, global_index) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, USDC_TEST_V2>(&incentive, 1);
            assert!(enable, 0);
            assert!(rate == 0, 0);
            assert!(last_update_at == 0, 0);
            assert!(global_index == 0, 0);

            let (_, enable, rate, last_update_at, global_index) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, USDC_TEST_V2>(&incentive, 3);
            assert!(enable, 0);
            assert!(rate == 0, 0);
            assert!(last_update_at == 0, 0);
            assert!(global_index == 0, 0);

            test_scenario::return_shared(incentive);
        };
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 2001, location = lending_core::incentive_v3)]
    // Should create_rule failed if create duplicated option and pool
    public fun test_failed_create_rule_duplicated() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;

        { 
            incentive_v3_util::init_protocol( scenario_mut);
        };

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(scenario_mut);
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));

            manage::create_incentive_v3_rule<SUI_TEST_V2, SUI_TEST_V2>(&owner_cap, &clock, &mut incentive, 1, test_scenario::ctx(scenario_mut));

            test_scenario::return_shared(incentive);
            clock::destroy_for_testing(clock);
            test_scenario::return_to_sender(scenario_mut, owner_cap);
        };
        test_scenario::end(scenario);
    }

    //--------RewardFund---------------

    #[test]
    // Should add_funds successfully add funds to an incentive funds pool
    public fun test_add_funds() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;

        {
            incentive_v3_util::init_protocol( scenario_mut);
        };

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let sui_funds = test_scenario::take_shared<RewardFund<SUI_TEST_V2>>(scenario_mut);
            let usdc_funds = test_scenario::take_shared<RewardFund<USDC_TEST_V2>>(scenario_mut);
            let eth_funds = test_scenario::take_shared<RewardFund<ETH_TEST_V2>>(scenario_mut);
            let coin_test_funds = test_scenario::take_shared<RewardFund<COIN_TEST_V2>>(scenario_mut);

            let (coin_type, amount) = incentive_v3::get_reward_fund_params_for_testing<SUI_TEST_V2>(&sui_funds);
            assert!(coin_type == type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);
            assert!(amount == 1000000_000000000, 0);

            let (coin_type, amount) = incentive_v3::get_reward_fund_params_for_testing<USDC_TEST_V2>(&usdc_funds);
            assert!(coin_type == type_name::into_string(type_name::get<USDC_TEST_V2>()), 0);
            assert!(amount == 1000000_000000, 0);  

            let (coin_type, amount) = incentive_v3::get_reward_fund_params_for_testing<ETH_TEST_V2>(&eth_funds);
            assert!(coin_type == type_name::into_string(type_name::get<ETH_TEST_V2>()), 0);
            assert!(amount == 1000000_00000000, 0);

            let (coin_type, amount) = incentive_v3::get_reward_fund_params_for_testing<COIN_TEST_V2>(&coin_test_funds);
            assert!(coin_type == type_name::into_string(type_name::get<COIN_TEST_V2>()), 0);
            assert!(amount == 1000000_000000000000, 0);

            test_scenario::return_shared(sui_funds);
            test_scenario::return_shared(usdc_funds);
            test_scenario::return_shared(eth_funds);
            test_scenario::return_shared(coin_test_funds);
        };
        test_scenario::end(scenario);
    }

    // Should add_funds fail when the funds to be added exceed the coin balance
    #[test]
    #[expected_failure(abort_code = 1503, location = lending_core::manage)]
    public fun test_failed_add_funds_exceed_max_balance() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;

        {
            incentive_v3_util::init_protocol( scenario_mut);
        };

        // deposit fund 
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(scenario_mut);
            let sui_funds = test_scenario::take_shared<RewardFund<SUI_TEST_V2>>(scenario_mut);

            let amount = 10000_000000000;
            let coin = coin::mint_for_testing<SUI_TEST_V2>(amount, test_scenario::ctx(scenario_mut));
            manage::deposit_incentive_v3_reward_fund(&owner_cap, &mut sui_funds, coin, amount + 1, test_scenario::ctx(scenario_mut));

            test_scenario::return_shared(sui_funds);

            test_scenario::return_to_sender(scenario_mut, owner_cap);
        };
        test_scenario::end(scenario);
    }

    // Should withdraw_funds successfully withdraw funds from an incentive funds pool
    #[test]
    public fun test_withdraw_funds() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        {
            incentive_v3_util::init_protocol( scenario_mut);
        };

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(scenario_mut);
            let sui_funds = test_scenario::take_shared<RewardFund<SUI_TEST_V2>>(scenario_mut);

            let withdraw_amount = 6000_000000000;
            manage::withdraw_incentive_v3_reward_fund(&storage_admin_cap, &mut sui_funds, withdraw_amount, OWNER, test_scenario::ctx(scenario_mut));

            test_scenario::return_shared(sui_funds);
            test_scenario::return_to_sender(scenario_mut, storage_admin_cap);
        };

        // check the balance of the reward fund
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let sui_funds = test_scenario::take_shared<RewardFund<SUI_TEST_V2>>(scenario_mut);
            let coin = test_scenario::take_from_sender<Coin<SUI_TEST_V2>>(scenario_mut);
            let (coin_type, amount) = incentive_v3::get_reward_fund_params_for_testing<SUI_TEST_V2>(&sui_funds);
            assert!(coin_type == type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);
            assert!(amount == 994000_000000000, 0);
            assert!(coin::value(&coin) == 6000_000000000, 0);

            test_scenario::return_shared(sui_funds);
            test_scenario::return_to_sender(scenario_mut, coin);
        };
        
        test_scenario::end(scenario);  
    }

    // Should withdraw_funds fail when the withdrawal amount exceeds the available balance
    #[test]
    public fun test_withdraw_funds_exceed_max_balance() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        {
            incentive_v3_util::init_protocol( scenario_mut);
        };

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(scenario_mut);
            let sui_funds = test_scenario::take_shared<RewardFund<SUI_TEST_V2>>(scenario_mut);

            let withdraw_amount = 10000_000000001;
            manage::withdraw_incentive_v3_reward_fund(&storage_admin_cap, &mut sui_funds, withdraw_amount, OWNER, test_scenario::ctx(scenario_mut));

            test_scenario::return_shared(sui_funds);
            test_scenario::return_to_sender(scenario_mut, storage_admin_cap);
        };
        test_scenario::end(scenario);
    }

    //--------Reward Entry---------------

    // Should claim_reward successfully with a rule id for supply
    #[test]
    public fun test_claim_reward_supply() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        let alice = @0xaaaaaaaa;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));
        {
            incentive_v3_util::init_protocol( scenario_mut);
        };

        // user A deposit 1000 SUI
        test_scenario::next_tx(scenario_mut, alice);
        {
            incentive_v3_util::user_deposit<SUI_TEST_V2>(scenario_mut, alice, 0, 1000_000000000, &clock);
        }; 


        // claim half day reward
        test_scenario::next_tx(scenario_mut, alice);
        {
            clock::increment_for_testing(&mut clock, 86400 * 1000 / 2);
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);
            let sui_funds = test_scenario::take_shared<RewardFund<SUI_TEST_V2>>(scenario_mut);

            let rule_ids = vector::empty<address>();
            let (addr, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"index1:");
            lib::print(&idx);
            vector::push_back(&mut rule_ids, addr);

            incentive_v3::claim_reward_entry<SUI_TEST_V2>(&clock, &mut incentive, &mut storage, &mut sui_funds, vector::singleton(type_name::into_string(type_name::get<SUI_TEST_V2>())), rule_ids, test_scenario::ctx(scenario_mut));

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"index2:");
            lib::print(&idx);
            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(sui_funds);
        };

        let alice_sui_amount = incentive_v3_util::get_coin_amount<SUI_TEST_V2>(scenario_mut, alice);
        assert!(alice_sui_amount == 50_000000000, 0);

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // Should claim_reward 0 if no reward(double claim)
    #[test]
    public fun test_claim_reward_double_claim() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        let alice = @0xaaaaaaaa;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));
        {
            incentive_v3_util::init_protocol( scenario_mut);
        };

        incentive_v3_util::user_deposit<SUI_TEST_V2>(scenario_mut, alice, 0, 1000_000000000, &clock);
        clock::increment_for_testing(&mut clock, 86400 * 1000);
        incentive_v3_util::user_claim_reward<SUI_TEST_V2, SUI_TEST_V2>(scenario_mut, alice, 1, &clock);
        let alice_sui_amount = incentive_v3_util::get_coin_amount<SUI_TEST_V2>(scenario_mut, alice);
        assert!(alice_sui_amount != 0, 0);

        incentive_v3_util::user_claim_reward<SUI_TEST_V2, SUI_TEST_V2>(scenario_mut, alice, 1, &clock);
        let alice_sui_amount = incentive_v3_util::get_coin_amount<SUI_TEST_V2>(scenario_mut, alice);
        assert!(alice_sui_amount == 0, 0);

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }


    // Should claim_reward successfully with a rule id for borrow
    #[test]
    public fun test_claim_reward_borrow() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        let alice = @0xaaaaaaaa;
        let bob = @0xb;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));
        {
            incentive_v3_util::init_protocol( scenario_mut);
        };

        // user B deposit 1000 SUI
        test_scenario::next_tx(scenario_mut, bob);
        {
            incentive_v3_util::user_deposit<SUI_TEST_V2>(scenario_mut, bob, 0, 1000_000000000, &clock);
        }; 

        // user A deposit 10000 USDC
        test_scenario::next_tx(scenario_mut, alice);
        {
            incentive_v3_util::user_deposit<USDC_TEST_V2>(scenario_mut, alice, 1, 10000_000000, &clock);
        }; 

        // user A borrow 100 SUI
        test_scenario::next_tx(scenario_mut, alice);
        {
            incentive_v3_util::user_borrow<SUI_TEST_V2>(scenario_mut, alice, 0, 100_000000000, &clock);
        }; 
        let alice_sui_amount = incentive_v3_util::get_coin_amount<SUI_TEST_V2>(scenario_mut, alice);
        assert!(alice_sui_amount == 100_000000000, 0);
        

        // claim half day reward
        test_scenario::next_tx(scenario_mut, alice);
        {
            clock::increment_for_testing(&mut clock, 86400 * 1000 / 2);
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);
            let sui_funds = test_scenario::take_shared<RewardFund<SUI_TEST_V2>>(scenario_mut);

            let rule_ids = vector::empty<address>();
            let (addr, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"index1:");
            lib::print(&idx);
            
            vector::push_back(&mut rule_ids, addr);

            incentive_v3::claim_reward_entry<SUI_TEST_V2>(&clock, &mut incentive, &mut storage, &mut sui_funds, vector::singleton(type_name::into_string(type_name::get<SUI_TEST_V2>())), rule_ids, test_scenario::ctx(scenario_mut));

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"index2:");
            lib::print(&idx);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(sui_funds);
        };

        let alice_sui_amount = incentive_v3_util::get_coin_amount<SUI_TEST_V2>(scenario_mut, alice);
        assert!(alice_sui_amount == 25_000000000, 0);

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    //--------Index---------------
    // Should update pool index and user index successfully for coins with 6/9/12 decmals in 1mintues/1hour/1day/1year/10years starting for zero/non-zero index
    #[test]
    public fun test_update_index_9_decimals() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        let alice = @0xaaaaaaaa;
        let bob = @0xb;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));
        {
            incentive_v3_util::init_protocol( scenario_mut);
        };

        // 100 SUI per day for supply
        // 50 SUI per day for borrow
        // user B deposit 1000 SUI
        // user A borrow 100 SUI
        incentive_v3_util::init_base_deposit_borrow_for_testing<SUI_TEST_V2>(
            scenario_mut, 
            0, 
            alice, 
            100_000000000, 
            bob, 
            1000_000000000, 
            &clock);

        // update index
        test_scenario::next_tx(scenario_mut, alice);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            // update index for 1 second
            clock::set_for_testing(&mut clock, 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"1s index1:");
            // 100 * 10^9 / 86400000 * 1000 * (10^27) / 1000 / 10^9 = 1.1574074074×10²¹
            lib::print(&idx); // 1157407407407407407407
            assert!(idx == 1157407407407407407407, 0);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"1s index3:");
            // 50 * 10^9 / 86400000 * 1000 * (10^27) / 100 / 10^9 = 5.787037037×10²¹
            lib::print(&idx);  // 5787037037037037037037
            assert!(idx == 5787037037037037037037, 0);

            // update index for 1 minute
            clock::set_for_testing(&mut clock, 60 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"1m index1:");
            // 100 * 10^9 / 86400000 * 1000 * 60 * (10^27) / 1000 / 10^9 = 6.9444444444×10²²
            lib::print(&idx); // 69444444444444444444444
            assert!(idx == 69444444444444444444444, 0);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"1m index3:"); // 347222222222222222222222
            // 50 * 10^9 / 86400000 * 1000 * 60 * (10^27) / 100 / 10^9 = 3.4722222222×10²³
            assert!(idx == 347222222222222222222222, 0);
            lib::print(&idx); // 347222222222222222222222

            // update index for 1 hour
            clock::set_for_testing(&mut clock, 60 * 60 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"1h index1:");
            // 100 * 10^9 / 86400000 * 1000 * 60 * 60 * (10^27) / 1000 / 10^9 = 4.1666666667×10²⁴
            lib::print(&idx); // 4166666666666666666666666
            assert!(idx == 4166666666666666666666666, 0);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"1h index3:"); // 20833333333333333333333333
            // 50 * 10^9 / 86400000 * 1000 * 60 * 60 * (10^27) / 100 / 10^9 = 2.08333333333×10²⁵
            assert!(idx == 20833333333333333333333333, 0);
            lib::print(&idx);

            // update index for 1 day
            clock::set_for_testing(&mut clock, 60 * 60 * 24 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage); 

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"1d index1:");
            // 100 * 10^9 / 86400000 * 1000 * 60 * 60 * 24 * (10^27) / 1000 / 10^9 = 1×10²⁶
            lib::print(&idx); // 99999999999999999999999999
            assert!(idx == 99999999999999999999999999, 0);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"1d index3:"); // 499999999999999999999999999
            // 50 * 10^9 / 86400000 * 1000 * 60 * 60 * 24 * (10^27) / 100 / 10^9 = 5×10²⁶
            assert!(idx == 499999999999999999999999999, 0);
            lib::print(&idx);

            // update index for 1 year
            clock::set_for_testing(&mut clock, 60 * 60 * 24 * 365 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"1y index1:");
            // 100 * 10^9 / 86400000 * 1000 * 60 * 60 * 24 * 365 * (10^27) / 1000 / 10^9 = 3.65×10²⁸
            lib::print(&idx); // 36499999999999999999999999998
            assert!(idx == 36499999999999999999999999998, 0);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"1y index3:"); // 182499999999999999999999999999
            // 50 * 10^9 / 86400000 * 1000 * 60 * 60 * 24 * 365 * (10^27) / 100 / 10^9 = 1.825×10²⁹
            assert!(idx == 182499999999999999999999999999, 0);
            lib::print(&idx);

            // update index for 10 year
            clock::set_for_testing(&mut clock, 60 * 60 * 24 * 365 * 10 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"10y index1:");
            // 100 * 10^9 / 86400000 * 1000 * 60 * 60 * 24 * 3650 * (10^27) / 1000 / 10^9 = 3.65×10²⁹
            lib::print(&idx); // 364999999999999999999999999997
            assert!(idx == 364999999999999999999999999997, 0);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"10y index3:"); // 1824999999999999999999999999999
            // 50 * 10^9 / 86400000 * 1000 * 60 * 60 * 24 * 3650 * (10^27) / 100 / 10^9 = 1.825×10³⁰
            assert!(idx == 1824999999999999999999999999999, 0);
            lib::print(&idx);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };

        // alice claim reward
        incentive_v3_util::user_claim_reward<SUI_TEST_V2, SUI_TEST_V2>(scenario_mut, alice, 3, &clock);
        let alice_sui_amount = incentive_v3_util::get_coin_amount<SUI_TEST_V2>(scenario_mut, alice);
        lib::printf(b"alice_sui_amount:");
        lib::print(&alice_sui_amount);
        // 50 * 3650*1e9 = 182,500,000,000,000
        assert!(alice_sui_amount == 182500000000000, 0);

        // bob claim reward 
        incentive_v3_util::user_claim_reward<SUI_TEST_V2, SUI_TEST_V2>(scenario_mut, bob, 1, &clock);
        let bob_sui_amount = incentive_v3_util::get_coin_amount<SUI_TEST_V2>(scenario_mut, bob);
        lib::printf(b"bob_sui_amount:");
        lib::print(&bob_sui_amount);
        // 100 * 3650 * 1e9 = 365,000,000,000,000
        assert!(bob_sui_amount == 365000000000000, 0);

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_update_index_6_decimals() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        let alice = @0xaaaaaaaa;
        let bob = @0xb;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));
        {
            incentive_v3_util::init_protocol( scenario_mut);
        };

        // set reward rate 100, 50 per day for supply and borrow
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(scenario_mut);
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));
            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, USDC_TEST_V2>(&incentive, 1);

            // set supply rate
            let rate_per_day = 100_000000;
            let rate_time = 86400000;
            manage::set_incentive_v3_reward_rate_by_rule_id<SUI_TEST_V2>(&owner_cap, &clock, &mut incentive, &mut storage, addr, rate_per_day, rate_time, test_scenario::ctx(scenario_mut));

            // set borrow rate
            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, USDC_TEST_V2>(&incentive, 3);
            let rate_per_day = 50_000000;
            let rate_time = 86400000;

            manage::set_incentive_v3_reward_rate_by_rule_id<SUI_TEST_V2>(&owner_cap, &clock, &mut incentive, &mut storage, addr, rate_per_day, rate_time, test_scenario::ctx(scenario_mut));

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
            clock::destroy_for_testing(clock);
            test_scenario::return_to_sender(scenario_mut, owner_cap);
        };

        // 100 USDC per day for supply
        // 50 USDC per day for borrow
        // user B deposit 1000 SUI
        // user A borrow 100 SUI
        incentive_v3_util::init_base_deposit_borrow_for_testing<SUI_TEST_V2>(
            scenario_mut, 
            0, 
            alice, 
            100_000000000, 
            bob, 
            1000_000000000, 
            &clock);

        // update index
        test_scenario::next_tx(scenario_mut, alice);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            // update index for 1 second
            clock::set_for_testing(&mut clock, 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, USDC_TEST_V2>(&incentive, 1);
            lib::printf(b"1s index1:");
            // 100 * 10^6 / 86400000 * 1000 * (10^27) / 1000 / 10^9 = 1.1574074074×1e18
            lib::print(&idx); // 1157407407407407407
            assert!(idx == 1157407407407407407, 0);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, USDC_TEST_V2>(&incentive, 3);
            lib::printf(b"1s index3:");
            // 50 * 10^6 / 86400000 * 1000 * (10^27) / 100 / 10^9 = 5.787037037×1e18
            lib::print(&idx);  // 5787037037037037037
            assert!(idx == 5787037037037037037, 0);

            // update index for 1 minute
            clock::set_for_testing(&mut clock, 60 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, USDC_TEST_V2>(&incentive, 1);
            lib::printf(b"1m index1:");
            // 100 * 10^6 / 86400000 * 1000 * 60 * (10^27) / 1000 / 10^9 = 6.9444444444×1e19
            lib::print(&idx); // 69444444444444444444
            assert!(idx == 69444444444444444444, 0);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, USDC_TEST_V2>(&incentive, 3);
            lib::printf(b"1m index3:"); // 347222222222222222222
            // 50 * 10^6 / 86400000 * 1000 * 60 * (10^27) / 100 / 10^9 = 3.4722222222×1e20
            assert!(idx == 347222222222222222222, 0);
            lib::print(&idx); // 347222222222222222222222

            // update index for 1 hour
            clock::set_for_testing(&mut clock, 60 * 60 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, USDC_TEST_V2>(&incentive, 1);
            lib::printf(b"1h index1:");
            // 100 * 10^6 / 86400000 * 1000 * 60 * 60 * (10^27) / 1000 / 10^9 = 4.1666666667×1e21
            lib::print(&idx); // 4166666666666666666666
            assert!(idx == 4166666666666666666666, 0);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, USDC_TEST_V2>(&incentive, 3);
            lib::printf(b"1h index3:"); // 20833333333333333333333
            // 50 * 10^6 / 86400000 * 1000 * 60 * 60 * (10^27) / 100 / 10^9 = 2.08333333333×1e22
            assert!(idx == 20833333333333333333333, 0);
            lib::print(&idx);

            // update index for 1 day
            clock::set_for_testing(&mut clock, 60 * 60 * 24 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage); 

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, USDC_TEST_V2>(&incentive, 1);
            lib::printf(b"1d index1:");
            // 100 * 10^6 / 86400000 * 1000 * 60 * 60 * 24 * (10^27) / 1000 / 10^9 = 1×1e23
            lib::print(&idx); // 99999999999999999999999
            assert!(idx == 99999999999999999999999, 0);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, USDC_TEST_V2>(&incentive, 3);
            lib::printf(b"1d index3:"); // 499999999999999999999999
            // 50 * 10^6 / 86400000 * 1000 * 60 * 60 * 24 * (10^27) / 100 / 10^9 = 5×1e23
            assert!(idx == 499999999999999999999999, 0);
            lib::print(&idx);

            // update index for 1 year
            clock::set_for_testing(&mut clock, 60 * 60 * 24 * 365 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, USDC_TEST_V2>(&incentive, 1);
            lib::printf(b"1y index1:");
            // 100 * 10^6 / 86400000 * 1000 * 60 * 60 * 24 * 365 * (10^27) / 1000 / 10^9 = 3.65×1e25
            lib::print(&idx); // 36499999999999999999999998
            assert!(idx == 36499999999999999999999998, 0);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, USDC_TEST_V2>(&incentive, 3);
            lib::printf(b"1y index3:"); // 182499999999999999999999999
            // 50 * 10^6 / 86400000 * 1000 * 60 * 60 * 24 * 365 * (10^27) / 100 / 10^9 = 1.825×1e26
            lib::print(&idx);
            assert!(idx == 182499999999999999999999999, 0);

            // update index for 10 year
            clock::set_for_testing(&mut clock, 60 * 60 * 24 * 365 * 10 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, USDC_TEST_V2>(&incentive, 1);
            lib::printf(b"10y index1:");
            // 100 * 10^6 / 86400000 * 1000 * 60 * 60 * 24 * 3650 * (10^27) / 1000 / 10^9 = 3.65×1e26
            lib::print(&idx); // 364999999999999999999999997
            assert!(idx == 364999999999999999999999997, 0);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, USDC_TEST_V2>(&incentive, 3);
            lib::printf(b"10y index3:"); // 1824999999999999999999999999
            // 50 * 10^6 / 86400000 * 1000 * 60 * 60 * 24 * 3650 * (10^27) / 100 / 10^9 = 1.825×1e27
            lib::print(&idx);
            assert!(idx == 1824999999999999999999999999, 0);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };

        // alice claim reward
        incentive_v3_util::user_claim_reward<SUI_TEST_V2, USDC_TEST_V2>(scenario_mut, alice, 3, &clock);
        let alice_sui_amount = incentive_v3_util::get_coin_amount<USDC_TEST_V2>(scenario_mut, alice);
        lib::printf(b"alice_usdc_amount:");
        lib::print(&alice_sui_amount);
        // 50 * 3650*1e6 = 182,500,000,000
        assert!(alice_sui_amount == 182500000000, 0);

        // bob claim reward 
        incentive_v3_util::user_claim_reward<SUI_TEST_V2, USDC_TEST_V2>(scenario_mut, bob, 1, &clock);
        let bob_sui_amount = incentive_v3_util::get_coin_amount<USDC_TEST_V2>(scenario_mut, bob);
        lib::printf(b"bob_usdc_amount:");
        lib::print(&bob_sui_amount);
        // 100 * 3650 * 1e6 = 365,000,000,000
        assert!(bob_sui_amount == 365000000000, 0);

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_update_index_12_decimals() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        let alice = @0xaaaaaaaa;
        let bob = @0xb;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));
        {
            incentive_v3_util::init_protocol( scenario_mut);
        };

        // set reward rate 100, 50 per day for supply and borrow
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(scenario_mut);
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));
            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, COIN_TEST_V2>(&incentive, 1);

            // set supply rate
            let e27: u256 = 1_000000000000000000000000000;
            let rate_per_day = 100_000000000000;
            let rate_time =  86400000;
            manage::set_incentive_v3_reward_rate_by_rule_id<SUI_TEST_V2>(&owner_cap, &clock, &mut incentive, &mut storage, addr, rate_per_day, rate_time, test_scenario::ctx(scenario_mut));

            // set borrow rate
            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, COIN_TEST_V2>(&incentive, 3);
            let rate_per_day = 50_000000000000;
            let rate_time =  86400000;

            manage::set_incentive_v3_reward_rate_by_rule_id<SUI_TEST_V2>(&owner_cap, &clock, &mut incentive, &mut storage, addr, rate_per_day, rate_time, test_scenario::ctx(scenario_mut));

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
            clock::destroy_for_testing(clock);
            test_scenario::return_to_sender(scenario_mut, owner_cap);
        };

        // 100 USDC per day for supply
        // 50 USDC per day for borrow
        // user B deposit 1000 SUI
        // user A borrow 100 SUI
        incentive_v3_util::init_base_deposit_borrow_for_testing<SUI_TEST_V2>(
            scenario_mut, 
            0, 
            alice, 
            100_000000000, 
            bob, 
            1000_000000000, 
            &clock);

        // update index
        test_scenario::next_tx(scenario_mut, alice);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            // update index for 1 second
            clock::set_for_testing(&mut clock, 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, COIN_TEST_V2>(&incentive, 1);
            lib::printf(b"1s index1:");
            lib::print(&idx); 
            assert!(idx == 1157407407407407407407407, 0);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, COIN_TEST_V2>(&incentive, 3);
            lib::printf(b"1s index3:");
            lib::print(&idx);  
            assert!(idx == 5787037037037037037037037, 0);

            // update index for 1 minute
            clock::set_for_testing(&mut clock, 60 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, COIN_TEST_V2>(&incentive, 1);
            lib::printf(b"1m index1:");
            lib::print(&idx); // 
            assert!(idx == 69444444444444444444444444, 0);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, COIN_TEST_V2>(&incentive, 3);
            lib::printf(b"1m index3:"); // 
            assert!(idx == 347222222222222222222222222, 0);
            lib::print(&idx); // 

            // update index for 1 hour
            clock::set_for_testing(&mut clock, 60 * 60 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, COIN_TEST_V2>(&incentive, 1);
            lib::printf(b"1h index1:");
            lib::print(&idx); // 
            assert!(idx == 4166666666666666666666666666, 0);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, COIN_TEST_V2>(&incentive, 3);
            lib::printf(b"1h index3:"); // 
            assert!(idx == 20833333333333333333333333333, 0);
            lib::print(&idx);

            // update index for 1 day
            clock::set_for_testing(&mut clock, 60 * 60 * 24 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage); 

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, COIN_TEST_V2>(&incentive, 1);
            lib::printf(b"1d index1:");
            lib::print(&idx); // 
            assert!(idx == 99999999999999999999999999999, 0);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, COIN_TEST_V2>(&incentive, 3);
            lib::printf(b"1d index3:"); // 
            assert!(idx == 499999999999999999999999999999, 0);
            lib::print(&idx);

            // update index for 1 year
            clock::set_for_testing(&mut clock, 60 * 60 * 24 * 365 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, COIN_TEST_V2>(&incentive, 1);
            lib::printf(b"1y index1:");
            lib::print(&idx); // 
            assert!(idx == 36499999999999999999999999999998, 0);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, COIN_TEST_V2>(&incentive, 3);
            lib::printf(b"1y index3:"); // 
            lib::print(&idx);
            assert!(idx == 182499999999999999999999999999999, 0);

            // update index for 10 year
            clock::set_for_testing(&mut clock, 60 * 60 * 24 * 365 * 10 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, COIN_TEST_V2>(&incentive, 1);
            lib::printf(b"10y index1:");
            lib::print(&idx); 
            assert!(idx == 364999999999999999999999999999997, 0);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, COIN_TEST_V2>(&incentive, 3);
            lib::printf(b"10y index3:"); 
            lib::print(&idx);
            assert!(idx == 1824999999999999999999999999999999, 0);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };

        // alice claim reward
        incentive_v3_util::user_claim_reward<SUI_TEST_V2, COIN_TEST_V2>(scenario_mut, alice, 3, &clock);
        let alice_sui_amount = incentive_v3_util::get_coin_amount<COIN_TEST_V2>(scenario_mut, alice);
        lib::printf(b"alice_test_amount:");
        lib::print(&alice_sui_amount);
        assert!(alice_sui_amount == 182500000000000000, 0);

        // bob claim reward 
        incentive_v3_util::user_claim_reward<SUI_TEST_V2, COIN_TEST_V2>(scenario_mut, bob, 1, &clock);
        let bob_sui_amount = incentive_v3_util::get_coin_amount<COIN_TEST_V2>(scenario_mut, bob);
        lib::printf(b"bob_test_amount:");
        lib::print(&bob_sui_amount);
        assert!(bob_sui_amount == 365000000000000000, 0);

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_update_index_9_decimals_non_zero_start() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        let alice = @0xaaaaaaaa;
        let bob = @0xb;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));
        {
            incentive_v3_util::init_protocol( scenario_mut);
        };

        // 100 SUI per day for supply
        // 50 SUI per day for borrow
        // user d deposit 1000 SUI
        // user c borrow 100 SUI
        incentive_v3_util::init_base_deposit_borrow_for_testing<SUI_TEST_V2>(
            scenario_mut, 
            0, 
            @0xcc, 
            100_000000000, 
            @0xdd, 
            1000_000000000, 
            &clock);

        test_scenario::next_tx(scenario_mut, alice);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            // update index for 1 year
            clock::set_for_testing(&mut clock, 60 * 60 * 24 * 365 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };

        let year_supply_idx:u256 = 36499999999999999999999999998;
        let year_borrow_idx:u256 = 182499999999999999999999999998;
        let year_ms = 60 * 60 * 24 * 365 * 1000;
        let e27: u256 = 1_000000000000000000000000000;



        // 100 SUI per day for supply
        // 50 SUI per day for borrow
        // user B deposit 1000 SUI
        // user A borrow 100 SUI
        incentive_v3_util::init_base_deposit_borrow_for_testing<SUI_TEST_V2>(
            scenario_mut, 
            0, 
            alice, 
            100_000000000, 
            bob, 
            1000_000000000, 
            &clock);

        // update index
        test_scenario::next_tx(scenario_mut, alice);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            // update index for 1 second
            clock::set_for_testing(&mut clock, 1000 + year_ms);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"1s index1:");
            // 100 * 10^6 / 86400000 * 1000 * (10^27) / 1000 / 10^9 = 1.1574074074×10²¹
            lib::print(&idx); // 1157407407407407407407

            lib::close_to_p(idx, 1157407407407407407407 / 2 + year_supply_idx, 100);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"1s index3:");
            // 50 * 10^6 / 86400000 * 1000 * (10^27) / 100 / 10^9 = 5.787037037×10²¹
            lib::print(&idx);  // 5787037037037037037037
            lib::close_to_p(idx, 5787037037037037037037 / 2+ year_borrow_idx, 100);

            // update index for 1 minute
            clock::set_for_testing(&mut clock, 60 * 1000 + year_ms);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"1m index1:");
            // 100 * 10^6 / 86400000 * 1000 * 60 * (10^27) / 1000 / 10^9 = 6.9444444444×10²²
            lib::print(&idx); // 69444444444444444444444
            lib::close_to_p(idx, 69444444444444444444444 / 2 + year_supply_idx, 100);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"1m index3:"); // 347222222222222222222222
            // 50 * 10^6 / 86400000 * 1000 * 60 * (10^27) / 100 / 10^9 = 3.4722222222×10²³
            lib::close_to_p(idx, 347222222222222222222222 / 2 + year_borrow_idx, 100);
            lib::print(&idx); // 347222222222222222222222

            // update index for 1 hour
            clock::set_for_testing(&mut clock, 60 * 60 * 1000 + year_ms);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"1h index1:");
            // 100 * 10^6 / 86400000 * 1000 * 60 * 60 * (10^27) / 1000 / 10^9 = 4.1666666667×10²⁴
            lib::print(&idx); // 4166666666666666666666666
            lib::close_to_p(idx, 4166666666666666666666666 / 2+ year_supply_idx, 100);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"1h index3:"); // 20833333333333333333333333
            // 50 * 10^6 / 86400000 * 1000 * 60 * 60 * (10^27) / 100 / 10^9 = 2.08333333333×10²⁵
            lib::close_to_p(idx, 20833333333333333333333333 / 2 + year_borrow_idx, 100);
            lib::print(&idx);

            // update index for 1 day
            clock::set_for_testing(&mut clock, 60 * 60 * 24 * 1000 + year_ms);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage); 

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"1d index1:");
            // 100 * 10^6 / 86400000 * 1000 * 60 * 60 * 24 * (10^27) / 1000 / 10^9 = 1×10²⁶
            lib::print(&idx); // 99999999999999999999999999
            lib::close_to_p(idx, 99999999999999999999999999 / 2 + year_supply_idx, 100);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"1d index3:"); // 499999999999999999999999999
            // 50 * 10^6 / 86400000 * 1000 * 60 * 60 * 24 * (10^27) / 100 / 10^9 = 5×10²⁶
            lib::close_to_p(idx, 499999999999999999999999999 / 2+ year_borrow_idx, 100);
            lib::print(&idx);

            // update index for 1 year
            clock::set_for_testing(&mut clock, 60 * 60 * 24 * 365 * 1000 + year_ms);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"1y index1:");
            // 100 * 10^6 / 86400000 * 1000 * 60 * 60 * 24 * 365 * (10^27) / 1000 / 10^9 = 3.65×10²⁸
            lib::print(&idx); // 36499999999999999999999999998
            lib::close_to_p(idx, 36499999999999999999999999998 / 2+ year_supply_idx, 100);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"1y index3:"); // 182499999999999999999999999998
            // 50 * 10^6 / 86400000 * 1000 * 60 * 60 * 24 * 365 * (10^27) / 100 / 10^9 = 1.825×10²⁹
            lib::print(&(182499999999999999999999999998 / 2 + year_borrow_idx));
            lib::print(&idx);
            lib::close_to_p(idx, 182499999999999999999999999998 / 2 + year_borrow_idx, 100);

            // update index for 10 year
            clock::set_for_testing(&mut clock, 60 * 60 * 24 * 365 * 10 * 1000 + year_ms);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"10y index1:");
            // 100 * 10^6 / 86400000 * 1000 * 60 * 60 * 24 * 3650 * (10^27) / 1000 / 10^9 = 3.65×10²⁹
            lib::print(&idx); // 364999999999999999999999999997
            lib::close_to_p(idx, 364999999999999999999999999997 / 2+ year_supply_idx, 100);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"10y index3:"); // 1824999999999999999999999999996
            // 50 * 10^6 / 86400000 * 1000 * 60 * 60 * 24 * 3650 * (10^27) / 100 / 10^9 = 1.825×10³⁰
            lib::close_to_p(idx, 1824999999999999999999999999996 / 2 + year_borrow_idx, 100);
            lib::print(&idx);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };

        // alice claim reward
        incentive_v3_util::user_claim_reward<SUI_TEST_V2, SUI_TEST_V2>(scenario_mut, alice, 3, &clock);
        let alice_sui_amount = incentive_v3_util::get_coin_amount<SUI_TEST_V2>(scenario_mut, alice);
        lib::printf(b"alice_sui_amount:");
        lib::print(&alice_sui_amount);
        // 50 * 3650*1e9 = 182,500,000,000,000
        lib::close_to_p((alice_sui_amount as u256), 182500000000000 / 2, 100);

        // bob claim reward 
        incentive_v3_util::user_claim_reward<SUI_TEST_V2, SUI_TEST_V2>(scenario_mut, bob, 1, &clock);
        let bob_sui_amount = incentive_v3_util::get_coin_amount<SUI_TEST_V2>(scenario_mut, bob);
        lib::printf(b"bob_sui_amount:");
        lib::print(&bob_sui_amount);
        // 100 * 3650 * 1e9 = 365,000,000,000,000
        lib::close_to_p((bob_sui_amount as u256), 365000000000000 / 2, 100);

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // Should update index correcly for effective with looping supply assets 
    #[test]
    public fun test_update_index_9_decimals_looping_assets() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        let alice = @0xaaaaaaaa;
        let bob = @0xb;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));
        {
            incentive_v3_util::init_protocol( scenario_mut);
        };

        // 100 SUI per day for supply
        // 50 SUI per day for borrow
        // user B deposit 900 SUI
        // user A borrow 100 SUI
        incentive_v3_util::init_base_deposit_borrow_for_testing<SUI_TEST_V2>(
            scenario_mut, 
            0, 
            alice, 
            100_000000000, 
            bob, 
            900_000000000, 
            &clock);

        // user A deposit 100 SUI
        incentive_v3_util::user_deposit<SUI_TEST_V2>(scenario_mut, alice, 0, 100_000000000, &clock);

        // update index
        test_scenario::next_tx(scenario_mut, alice);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            // update index for 1 second
            clock::set_for_testing(&mut clock, 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"1s index1:");
            // 100 * 10^9 / 86400000 * 1000 * (10^27) / 1000 / 10^9 = 1.1574074074×10²¹
            lib::print(&idx); // 1157407407407407407407
            assert!(idx == 1157407407407407407407, 0);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"1s index3:");
            // 50 * 10^9 / 86400000 * 1000 * (10^27) / 100 / 10^9 = 5.787037037×10²¹
            lib::print(&idx);  // 5787037037037037037037
            assert!(idx == 5787037037037037037037, 0);

            // update index for 1 minute
            clock::set_for_testing(&mut clock, 60 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"1m index1:");
            // 100 * 10^9 / 86400000 * 1000 * 60 * (10^27) / 1000 / 10^9 = 6.9444444444×10²²
            lib::print(&idx); // 69444444444444444444444
            assert!(idx == 69444444444444444444444, 0);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"1m index3:"); // 347222222222222222222222
            // 50 * 10^9 / 86400000 * 1000 * 60 * (10^27) / 100 / 10^9 = 3.4722222222×10²³
            assert!(idx == 347222222222222222222222, 0);
            lib::print(&idx); // 347222222222222222222222

            // update index for 1 hour
            clock::set_for_testing(&mut clock, 60 * 60 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"1h index1:");
            // 100 * 10^9 / 86400000 * 1000 * 60 * 60 * (10^27) / 1000 / 10^9 = 4.1666666667×10²⁴
            lib::print(&idx); // 4166666666666666666666666
            assert!(idx == 4166666666666666666666666, 0);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"1h index3:"); // 20833333333333333333333333
            // 50 * 10^9 / 86400000 * 1000 * 60 * 60 * (10^27) / 100 / 10^9 = 2.08333333333×10²⁵
            assert!(idx == 20833333333333333333333333, 0);
            lib::print(&idx);

            // update index for 1 day
            clock::set_for_testing(&mut clock, 60 * 60 * 24 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage); 

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"1d index1:");
            // 100 * 10^9 / 86400000 * 1000 * 60 * 60 * 24 * (10^27) / 1000 / 10^9 = 1×10²⁶
            lib::print(&idx); // 99999999999999999999999999
            assert!(idx == 99999999999999999999999999, 0);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"1d index3:"); // 499999999999999999999999999
            // 50 * 10^9 / 86400000 * 1000 * 60 * 60 * 24 * (10^27) / 100 / 10^9 = 5×10²⁶
            assert!(idx == 499999999999999999999999999, 0);
            lib::print(&idx);

            // update index for 1 year
            clock::set_for_testing(&mut clock, 60 * 60 * 24 * 365 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"1y index1:");
            // 100 * 10^9 / 86400000 * 1000 * 60 * 60 * 24 * 365 * (10^27) / 1000 / 10^9 = 3.65×10²⁸
            lib::print(&idx); // 36499999999999999999999999998
            assert!(idx == 36499999999999999999999999998, 0);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"1y index3:"); // 182499999999999999999999999999
            // 50 * 10^9 / 86400000 * 1000 * 60 * 60 * 24 * 365 * (10^27) / 100 / 10^9 = 1.825×10²⁹
            assert!(idx == 182499999999999999999999999999, 0);
            lib::print(&idx);

            // update index for 10 year
            clock::set_for_testing(&mut clock, 60 * 60 * 24 * 365 * 10 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"10y index1:");
            // 100 * 10^9 / 86400000 * 1000 * 60 * 60 * 24 * 3650 * (10^27) / 1000 / 10^9 = 3.65×10²⁹
            lib::print(&idx); // 364999999999999999999999999997
            assert!(idx == 364999999999999999999999999997, 0);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"10y index3:"); // 1824999999999999999999999999999
            // 50 * 10^9 / 86400000 * 1000 * 60 * 60 * 24 * 3650 * (10^27) / 100 / 10^9 = 1.825×10³⁰
            assert!(idx == 1824999999999999999999999999999, 0);
            lib::print(&idx);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };

        // alice claim reward
        incentive_v3_util::user_claim_reward<SUI_TEST_V2, SUI_TEST_V2>(scenario_mut, alice, 3, &clock);
        let alice_sui_amount = incentive_v3_util::get_coin_amount<SUI_TEST_V2>(scenario_mut, alice);
        lib::printf(b"alice_sui_amount:");
        lib::print(&alice_sui_amount);
        // 50 * 3650*1e9 = 182,500,000,000,000
        assert!(alice_sui_amount == 0, 0);

        // bob claim reward 
        incentive_v3_util::user_claim_reward<SUI_TEST_V2, SUI_TEST_V2>(scenario_mut, bob, 1, &clock);
        let bob_sui_amount = incentive_v3_util::get_coin_amount<SUI_TEST_V2>(scenario_mut, bob);
        lib::printf(b"bob_sui_amount:");
        lib::print(&bob_sui_amount);
        // 100 * 3650 * 1e9 = 365,000,000,000,000
        lib::close_to((bob_sui_amount as u256), 365000000000000 / 10 * 9, 10);

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // Should update index correcly for effective with looping borrow assets 
    #[test]
    public fun test_update_index_9_decimals_looping_borrow_assets() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        let alice = @0xaaaaaaaa;
        let bob = @0xb;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));
        {
            incentive_v3_util::init_protocol( scenario_mut);
        };

        // 100 SUI per day for supply
        // 50 SUI per day for borrow
        // user B deposit 950 SUI
        // user A borrow 100 SUI
        incentive_v3_util::init_base_deposit_borrow_for_testing<SUI_TEST_V2>(
            scenario_mut, 
            0, 
            alice, 
            100_000000000, 
            bob, 
            950_000000000, 
            &clock);

        // user A deposit 50 SUI
        incentive_v3_util::user_deposit<SUI_TEST_V2>(scenario_mut, alice, 0, 50_000000000, &clock);

        // update index
        test_scenario::next_tx(scenario_mut, alice);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            // update index for 1 second
            clock::set_for_testing(&mut clock, 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"1s index1:");
            // 100 * 10^9 / 86400000 * 1000 * (10^27) / 1000 / 10^9 = 1.1574074074×10²¹
            lib::print(&idx); // 1157407407407407407407
            assert!(idx == 1157407407407407407407, 0);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"1s index3:");
            // 50 * 10^9 / 86400000 * 1000 * (10^27) / 100 / 10^9 = 5.787037037×10²¹
            lib::print(&idx);  // 5787037037037037037037
            assert!(idx == 5787037037037037037037, 0);

            // update index for 1 minute
            clock::set_for_testing(&mut clock, 60 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"1m index1:");
            // 100 * 10^9 / 86400000 * 1000 * 60 * (10^27) / 1000 / 10^9 = 6.9444444444×10²²
            lib::print(&idx); // 69444444444444444444444
            assert!(idx == 69444444444444444444444, 0);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"1m index3:"); // 347222222222222222222222
            // 50 * 10^9 / 86400000 * 1000 * 60 * (10^27) / 100 / 10^9 = 3.4722222222×10²³
            assert!(idx == 347222222222222222222222, 0);
            lib::print(&idx); // 347222222222222222222222

            // update index for 1 hour
            clock::set_for_testing(&mut clock, 60 * 60 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"1h index1:");
            // 100 * 10^9 / 86400000 * 1000 * 60 * 60 * (10^27) / 1000 / 10^9 = 4.1666666667×10²⁴
            lib::print(&idx); // 4166666666666666666666666
            assert!(idx == 4166666666666666666666666, 0);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"1h index3:"); // 20833333333333333333333333
            // 50 * 10^9 / 86400000 * 1000 * 60 * 60 * (10^27) / 100 / 10^9 = 2.08333333333×10²⁵
            assert!(idx == 20833333333333333333333333, 0);
            lib::print(&idx);

            // update index for 1 day
            clock::set_for_testing(&mut clock, 60 * 60 * 24 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage); 

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"1d index1:");
            // 100 * 10^9 / 86400000 * 1000 * 60 * 60 * 24 * (10^27) / 1000 / 10^9 = 1×10²⁶
            lib::print(&idx); // 99999999999999999999999999
            assert!(idx == 99999999999999999999999999, 0);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"1d index3:"); // 499999999999999999999999999
            // 50 * 10^9 / 86400000 * 1000 * 60 * 60 * 24 * (10^27) / 100 / 10^9 = 5×10²⁶
            assert!(idx == 499999999999999999999999999, 0);
            lib::print(&idx);

            // update index for 1 year
            clock::set_for_testing(&mut clock, 60 * 60 * 24 * 365 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"1y index1:");
            // 100 * 10^9 / 86400000 * 1000 * 60 * 60 * 24 * 365 * (10^27) / 1000 / 10^9 = 3.65×10²⁸
            lib::print(&idx); // 36499999999999999999999999998
            assert!(idx == 36499999999999999999999999998, 0);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"1y index3:"); // 182499999999999999999999999999
            // 50 * 10^9 / 86400000 * 1000 * 60 * 60 * 24 * 365 * (10^27) / 100 / 10^9 = 1.825×10²⁹
            assert!(idx == 182499999999999999999999999999, 0);
            lib::print(&idx);

            // update index for 10 year
            clock::set_for_testing(&mut clock, 60 * 60 * 24 * 365 * 10 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"10y index1:");
            // 100 * 10^9 / 86400000 * 1000 * 60 * 60 * 24 * 3650 * (10^27) / 1000 / 10^9 = 3.65×10²⁹
            lib::print(&idx); // 364999999999999999999999999997
            assert!(idx == 364999999999999999999999999997, 0);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"10y index3:"); // 1824999999999999999999999999999
            // 50 * 10^9 / 86400000 * 1000 * 60 * 60 * 24 * 3650 * (10^27) / 100 / 10^9 = 1.825×10³⁰
            assert!(idx == 1824999999999999999999999999999, 0);
            lib::print(&idx);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };

        // alice claim reward
        incentive_v3_util::user_claim_reward<SUI_TEST_V2, SUI_TEST_V2>(scenario_mut, alice, 3, &clock);
        let alice_sui_amount = incentive_v3_util::get_coin_amount<SUI_TEST_V2>(scenario_mut, alice);
        lib::printf(b"alice_sui_amount:");
        lib::print(&alice_sui_amount);
        // 50 * 3650*1e9 = 182,500,000,000,000
        assert!(alice_sui_amount == 182500000000000 /2, 0);

        // bob claim reward 
        incentive_v3_util::user_claim_reward<SUI_TEST_V2, SUI_TEST_V2>(scenario_mut, bob, 1, &clock);
        let bob_sui_amount = incentive_v3_util::get_coin_amount<SUI_TEST_V2>(scenario_mut, bob);
        lib::printf(b"bob_sui_amount:");
        lib::print(&bob_sui_amount);
        // 100 * 3650 * 1e9 = 365,000,000,000,000
        lib::close_to((bob_sui_amount as u256), 365000000000000 / 100 * 95, 10);

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // Should update index correcly for small user balance and large total balance
    // Should update correctly with low/medium/high total supply
    #[test]
    public fun test_update_index_small_user_balance_large_total_balance() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        let alice = @0xaaaaaaaa;
        let bob = @0xb;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));
        {
            incentive_v3_util::init_protocol( scenario_mut);
        };

        // 100 SUI per day for supply
        // 50 SUI per day for borrow
        // user B deposit 1000 SUI
        // user A borrow 100 SUI
        incentive_v3_util::init_base_deposit_borrow_for_testing<SUI_TEST_V2>(
            scenario_mut, 
            0, 
            alice, 
            100_000000000, 
            bob, 
            1000_000000000, 
            &clock);

        incentive_v3_util::init_base_deposit_borrow_for_testing<SUI_TEST_V2>(
            scenario_mut, 
            0, 
            @0xc, 
            (1000000 - 1) * 100_000000000, 
            @0xd, 
            (1000000 - 1) *1000_000000000, 
            &clock);
            
        // update index
        test_scenario::next_tx(scenario_mut, alice);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            // update index for 1 second
            clock::set_for_testing(&mut clock, 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"1s index1:");
            // 100 * 10^9 / 86400000 * 1000 * (10^27) / 1000 / 10^9 = 1.1574074074×10²¹
            lib::print(&idx); // 1157407407407407407407
            lib::close_to(idx, 1157407407407407407407 / 1000000, 10);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"1s index3:");
            // 50 * 10^9 / 86400000 * 1000 * (10^27) / 100 / 10^9 = 5.787037037×10²¹
            lib::print(&idx);  // 5787037037037037037037
            lib::close_to(idx, 5787037037037037037037 / 1000000, 10);

            // update index for 1 minute
            clock::set_for_testing(&mut clock, 60 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"1m index1:");
            // 100 * 10^9 / 86400000 * 1000 * 60 * (10^27) / 1000 / 10^9 = 6.9444444444×10²²
            lib::print(&idx); // 69444444444444444444444
            lib::close_to(idx, 69444444444444444444444 / 1000000, 10);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"1m index3:"); // 347222222222222222222222
            // 50 * 10^9 / 86400000 * 1000 * 60 * (10^27) / 100 / 10^9 = 3.4722222222×10²³
            lib::close_to(idx, 347222222222222222222222 / 1000000, 10);
            lib::print(&idx); // 347222222222222222222222

            // update index for 1 hour
            clock::set_for_testing(&mut clock, 60 * 60 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"1h index1:");
            // 100 * 10^9 / 86400000 * 1000 * 60 * 60 * (10^27) / 1000 / 10^9 = 4.1666666667×10²⁴
            lib::print(&idx); // 4166666666666666666666666
            lib::close_to(idx, 4166666666666666666666666 / 1000000, 10);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"1h index3:"); // 20833333333333333333333333
            // 50 * 10^9 / 86400000 * 1000 * 60 * 60 * (10^27) / 100 / 10^9 = 2.08333333333×10²⁵
            lib::close_to(idx, 20833333333333333333333333 / 1000000, 10);
            lib::print(&idx);

            // update index for 1 day
            clock::set_for_testing(&mut clock, 60 * 60 * 24 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage); 

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"1d index1:");
            // 100 * 10^9 / 86400000 * 1000 * 60 * 60 * 24 * (10^27) / 1000 / 10^9 = 1×10²⁶
            lib::print(&idx); // 99999999999999999999999999
            lib::close_to(idx, 99999999999999999999999999 / 1000000, 10);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"1d index3:"); // 499999999999999999999999999
            // 50 * 10^9 / 86400000 * 1000 * 60 * 60 * 24 * (10^27) / 100 / 10^9 = 5×10²⁶
            lib::close_to(idx, 499999999999999999999999999 / 1000000, 10);
            lib::print(&idx);

            // update index for 1 year
            clock::set_for_testing(&mut clock, 60 * 60 * 24 * 365 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"1y index1:");
            // 100 * 10^9 / 86400000 * 1000 * 60 * 60 * 24 * 365 * (10^27) / 1000 / 10^9 = 3.65×10²⁸
            lib::print(&idx); // 36499999999999999999999999998
            lib::close_to(idx, 36499999999999999999999999998 / 1000000, 10);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"1y index3:"); // 182499999999999999999999999998
            // 50 * 10^9 / 86400000 * 1000 * 60 * 60 * 24 * 365 * (10^27) / 100 / 10^9 = 1.825×10²⁹
            lib::close_to(idx, 182499999999999999999999999998 / 1000000, 10);
            lib::print(&idx);

            // update index for 10 year
            clock::set_for_testing(&mut clock, 60 * 60 * 24 * 365 * 10 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            lib::printf(b"10y index1:");
            // 100 * 10^9 / 86400000 * 1000 * 60 * 60 * 24 * 3650 * (10^27) / 1000 / 10^9 = 3.65×10²⁹
            lib::print(&idx); // 364999999999999999999999999997
            lib::close_to(idx, 364999999999999999999999999997 / 1000000, 10);
            let (_, _, _, _, idx) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            lib::printf(b"10y index3:"); // 1824999999999999999999999999996
            // 50 * 10^9 / 86400000 * 1000 * 60 * 60 * 24 * 3650 * (10^27) / 100 / 10^9 = 1.825×10³⁰
            lib::close_to(idx, 1824999999999999999999999999996 / 1000000, 10);
            lib::print(&idx);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };

        // alice claim reward
        incentive_v3_util::user_claim_reward<SUI_TEST_V2, SUI_TEST_V2>(scenario_mut, alice, 3, &clock);
        let alice_sui_amount = incentive_v3_util::get_coin_amount<SUI_TEST_V2>(scenario_mut, alice);
        lib::printf(b"alice_sui_amount:");
        lib::print(&alice_sui_amount);
        // 50 * 3650*1e9 = 182,500,000,000,000
        assert!(alice_sui_amount == 182500000000000 / 1000000, 0);

        // bob claim reward 
        incentive_v3_util::user_claim_reward<SUI_TEST_V2, SUI_TEST_V2>(scenario_mut, bob, 1, &clock);
        let bob_sui_amount = incentive_v3_util::get_coin_amount<SUI_TEST_V2>(scenario_mut, bob);
        lib::printf(b"bob_sui_amount:");
        lib::print(&bob_sui_amount);
        // 100 * 3650 * 1e9 = 365,000,000,000,000
        assert!(bob_sui_amount == 365000000000000 / 1000000, 0);

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // Should update correctly with 0/medium/high rate
    #[test]
    public fun test_update_index_with_0_medium_high_rate() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        let alice = @0xaaaaaaaa;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));
        {
            incentive_v3_util::init_protocol( scenario_mut);
        };

        incentive_v3_util::user_deposit<SUI_TEST_V2>(scenario_mut, alice, 0, 1000_000000000, &clock);

        // update index
        // 100 SUI per day for supply
        test_scenario::next_tx(scenario_mut, alice);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            // update index for 1 day
            clock::set_for_testing(&mut clock, 86400 * 1000);
            incentive_v3::update_index_for_testing<SUI_TEST_V2>(&clock, &mut incentive, &mut storage);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };
        // alice claim reward
        incentive_v3_util::user_claim_reward<SUI_TEST_V2, SUI_TEST_V2>(scenario_mut, alice, 1, &clock);
        let alice_sui_amount = incentive_v3_util::get_coin_amount<SUI_TEST_V2>(scenario_mut, alice);
        lib::printf(b"alice_sui_amount:");
        lib::print(&alice_sui_amount);
        assert!(alice_sui_amount == 100_000000000, 0);

        // set supply rate to 100k

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(scenario_mut);
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);
            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);

            // set supply rate
            manage::set_incentive_v3_reward_rate_by_rule_id<SUI_TEST_V2>(&owner_cap, &clock, &mut incentive, &mut storage, addr, 100000_000000000, 86400000, test_scenario::ctx(scenario_mut));

            test_scenario::return_to_sender(scenario_mut, owner_cap);
            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };

        test_scenario::next_tx(scenario_mut, alice);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            // update index for 1 day
            clock::increment_for_testing(&mut clock, 86400 * 1000);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };

        // alice claim reward
        incentive_v3_util::user_claim_reward<SUI_TEST_V2, SUI_TEST_V2>(scenario_mut, alice, 1, &clock);
        let alice_sui_amount = incentive_v3_util::get_coin_amount<SUI_TEST_V2>(scenario_mut, alice);
        lib::printf(b"alice_sui_amount:");
        lib::print(&alice_sui_amount);
        assert!(alice_sui_amount == 100000_000000000, 0);

        // set supply rate to 0
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(scenario_mut);
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);
            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);

            // set supply rate
            manage::set_incentive_v3_reward_rate_by_rule_id<SUI_TEST_V2>(&owner_cap, &clock, &mut incentive, &mut storage, addr, 0, 86400000, test_scenario::ctx(scenario_mut));

            test_scenario::return_to_sender(scenario_mut, owner_cap);
            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };

        test_scenario::next_tx(scenario_mut, alice);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            // update index for 1 day
            clock::increment_for_testing(&mut clock, 86400 * 1000);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };
        // alice claim reward
        incentive_v3_util::user_claim_reward<SUI_TEST_V2, SUI_TEST_V2>(scenario_mut, alice, 1, &clock);
        let alice_sui_amount = incentive_v3_util::get_coin_amount<SUI_TEST_V2>(scenario_mut, alice);
        assert!(alice_sui_amount == 0, 0);

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }
    
    //-------------Getter/Setter-------------
    // Should get updated claimable reward and rule id for users
    // Should get latest claimable reward and rule id for users
    // Should get multiple claimables reward with claimed/unclaimed reward (Integration)
    #[test]
    public fun test_updated_claimable_reward_and_rule_id_for_users() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        let alice = @0xaaaaaaaa;
        let bob = @0xb;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));
        {
            incentive_v3_util::init_protocol( scenario_mut);
        };

        // 100 SUI per day for supply
        // 50 SUI per day for borrow
        // user B deposit 1000 SUI
        // user A borrow 100 SUI
        incentive_v3_util::init_base_deposit_borrow_for_testing<SUI_TEST_V2>(
            scenario_mut, 
            0, 
            alice, 
            100_000000000, 
            bob, 
            1000_000000000, 
            &clock);
        
        // no reward for alice at the beginning
        test_scenario::next_tx(scenario_mut, alice);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            let claimable_rewards = incentive_v3::get_user_claimable_rewards(&clock, &mut storage, &incentive, alice);
            lib::printf(b"claimable_rewards:");
            lib::print(&claimable_rewards);
            let (asset_tokens, reward_tokens, claimable_rewards, claimed_rewards,rule_ids) = incentive_v3::parse_claimable_rewards(claimable_rewards);
            assert!(vector::length(&asset_tokens) == 0, 0);
            assert!(vector::length(&reward_tokens) == 0, 0);
            assert!(vector::length(&claimable_rewards) == 0, 0);
            assert!(vector::length(&claimed_rewards) == 0, 0);
            assert!(vector::length(&rule_ids) == 0, 0);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };

        // pass 1 day
        test_scenario::next_tx(scenario_mut, alice);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            clock::increment_for_testing(&mut clock, 86400 * 1000);
            // keep the state updated
            incentive_v3::update_reward_state_by_asset<SUI_TEST_V2>(&clock, &mut incentive, &mut storage, alice);

            let claimable_rewards = incentive_v3::get_user_claimable_rewards(&clock, &mut storage, &incentive, alice);
            lib::printf(b"claimable_rewards:");
            lib::print(&claimable_rewards);
            // [debug] [
            // 0x0::incentive_v3::ClaimableReward {
            //     asset_coin_type: "0000000000000000000000000000000000000000000000000000000000000000::sui_test_v2::SUI_TEST_V2",
            //     reward_coin_type: "0000000000000000000000000000000000000000000000000000000000000000::sui_test_v2::SUI_TEST_V2",
            //     user_claimable_reward: 50000000000,
            //     user_claimed_reward: 0,
            //     rule_ids: [ @0xd5e5d1491d6e64c361bf737e0d2aba42dda073b9d3345c06fda8d71465b7b734 ]
            // }
            // ]
            let (asset_tokens, reward_tokens, claimable_rewards, claimed_rewards,rule_ids) = incentive_v3::parse_claimable_rewards(claimable_rewards);
            let (id, _, _, _, _) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            assert!(vector::length(&asset_tokens) == 1, 0);
            assert!(vector::length(&reward_tokens) == 1, 0);
            assert!(vector::borrow(&asset_tokens, 0) == &type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);
            assert!(vector::borrow(&reward_tokens, 0) == &type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);
            assert!(vector::borrow(&claimable_rewards, 0) == &50000000000, 0);
            assert!(vector::borrow(&claimed_rewards, 0) == &0, 0);
            assert!(vector::borrow(vector::borrow(&rule_ids, 0), 0) == &id, 0);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };

        // pass 1 day without update
        test_scenario::next_tx(scenario_mut, alice);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            clock::increment_for_testing(&mut clock, 86400 * 1000);

            let claimable_rewards = incentive_v3::get_user_claimable_rewards(&clock, &mut storage, &incentive, alice);
            lib::printf(b"claimable_rewards:");
            lib::print(&claimable_rewards);
            // [debug] [
            // 0x0::incentive_v3::ClaimableReward {
            //     asset_coin_type: "0000000000000000000000000000000000000000000000000000000000000000::sui_test_v2::SUI_TEST_V2",
            //     reward_coin_type: "0000000000000000000000000000000000000000000000000000000000000000::sui_test_v2::SUI_TEST_V2",
            //     user_claimable_reward: 100000000000,
            //     user_claimed_reward: 0,
            //     rule_ids: [ @0xd5e5d1491d6e64c361bf737e0d2aba42dda073b9d3345c06fda8d71465b7b734 ]
            // }
            let (asset_tokens, reward_tokens, claimable_rewards, claimed_rewards,rule_ids) = incentive_v3::parse_claimable_rewards(claimable_rewards);
            let (id, _, _, _, _) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            assert!(vector::length(&asset_tokens) == 1, 0);
            assert!(vector::length(&reward_tokens) == 1, 0);
            assert!(vector::borrow(&asset_tokens, 0) == &type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);
            assert!(vector::borrow(&reward_tokens, 0) == &type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);
            assert!(vector::borrow(&claimable_rewards, 0) == &100000000000, 0);
            assert!(vector::borrow(&claimed_rewards, 0) == &0, 0);
            assert!(vector::borrow(vector::borrow(&rule_ids, 0), 0) == &id, 0);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };

        // get bob reward
        test_scenario::next_tx(scenario_mut, bob);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            let claimable_rewards = incentive_v3::get_user_claimable_rewards(&clock, &mut storage, &incentive, bob);
            lib::printf(b"claimable_rewards:");
            lib::print(&claimable_rewards);
            // [debug] "claimable_rewards:"
            // [debug] [
            //   0x0::incentive_v3::ClaimableReward {
            //     asset_coin_type: "0000000000000000000000000000000000000000000000000000000000000000::sui_test_v2::SUI_TEST_V2",
            //     reward_coin_type: "0000000000000000000000000000000000000000000000000000000000000000::sui_test_v2::SUI_TEST_V2",
            //     user_claimable_reward: 200000000000,
            //     user_claimed_reward: 0,
            //     rule_ids: [ @0x340ad90170e5c6d799c6b8759b93e9289d3ea823209427aa51d7866d71cf35af ]
            //   }
            let (asset_tokens, reward_tokens, claimable_rewards, claimed_rewards,rule_ids) = incentive_v3::parse_claimable_rewards(claimable_rewards);
            let (id, _, _, _, _) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            assert!(vector::length(&asset_tokens) == 1, 0);
            assert!(vector::length(&reward_tokens) == 1, 0);
            assert!(vector::borrow(&asset_tokens, 0) == &type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);
            assert!(vector::borrow(&reward_tokens, 0) == &type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);
            assert!(vector::borrow(&claimable_rewards, 0) == &200000000000, 0);
            assert!(vector::borrow(&claimed_rewards, 0) == &0, 0);
            assert!(vector::borrow(vector::borrow(&rule_ids, 0), 0) == &id, 0);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };

        // add complex reward

        incentive_v3_util::user_claim_reward<SUI_TEST_V2, SUI_TEST_V2>(scenario_mut, alice, 3, &clock);
        let alice_sui_amount = incentive_v3_util::get_coin_amount<SUI_TEST_V2>(scenario_mut, alice);
        lib::printf(b"alice_sui_amount:");
        lib::print(&alice_sui_amount);
        
        incentive_v3_util::user_deposit<USDC_TEST_V2>(scenario_mut, alice, 1, 1000_000000, &clock);
        incentive_v3_util::user_deposit<COIN_TEST_V2>(scenario_mut, alice, 4, 1000_000000000000, &clock);
        incentive_v3_util::user_borrow<SUI_TEST_V2>(scenario_mut, bob, 0, 100_000000000, &clock);
        // create rule
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(scenario_mut);
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);
            manage::create_incentive_v3_rule<COIN_TEST_V2, USDC_TEST_V2>(&owner_cap, &clock, &mut incentive, 1, test_scenario::ctx(scenario_mut));

            test_scenario::return_to_sender(scenario_mut, owner_cap);
            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(scenario_mut);
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            // add 100 USDC per day for COIN_TEST_V2 supply
            // add 100 SUI_TEST_V2 per day for USDC_TEST_V2 supply
            // add 100 COIN_TEST_V2 per day for USDC_TEST_V2 supply
            let (id, _, _, _, _) = incentive_v3::get_rule_params_for_testing<COIN_TEST_V2, USDC_TEST_V2>(&incentive, 1);
            manage::set_incentive_v3_reward_rate_by_rule_id<COIN_TEST_V2>(&owner_cap, &clock, &mut incentive, &mut storage, id, 100_000000, 86400000, test_scenario::ctx(scenario_mut));
            let (id, _, _, _, _) = incentive_v3::get_rule_params_for_testing<USDC_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            manage::set_incentive_v3_reward_rate_by_rule_id<USDC_TEST_V2>(&owner_cap, &clock, &mut incentive, &mut storage, id, 100_000000000, 86400000, test_scenario::ctx(scenario_mut));
            let (id, _, _, _, _) = incentive_v3::get_rule_params_for_testing<USDC_TEST_V2, COIN_TEST_V2>(&incentive, 1);
            manage::set_incentive_v3_reward_rate_by_rule_id<USDC_TEST_V2>(&owner_cap, &clock, &mut incentive, &mut storage, id, 100_000000000000, 86400000, test_scenario::ctx(scenario_mut));

            test_scenario::return_to_sender(scenario_mut, owner_cap);
            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };

        test_scenario::next_tx(scenario_mut, alice);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);

            clock::increment_for_testing(&mut clock, 86400 * 1000);
            incentive_v3::update_reward_state_by_asset<SUI_TEST_V2>(&clock, &mut incentive, &mut storage, alice);

            let claimable_rewards = incentive_v3::get_user_claimable_rewards(&clock, &mut storage, &incentive, alice);
            lib::printf(b"claimable_rewards:");
            lib::print(&claimable_rewards);

            // [debug] [
            //   0x0::incentive_v3::ClaimableReward {
            //     asset_coin_type: "0000000000000000000000000000000000000000000000000000000000000000::sui_test_v2::SUI_TEST_V2",
            //     reward_coin_type: "0000000000000000000000000000000000000000000000000000000000000000::sui_test_v2::SUI_TEST_V2",
            //     user_claimable_reward: 25001027397,
            //     user_claimed_reward: 100000000000,
            //     rule_ids: [ @0xd5e5d1491d6e64c361bf737e0d2aba42dda073b9d3345c06fda8d71465b7b734 ]
            //   },
            //   0x0::incentive_v3::ClaimableReward {
            //     asset_coin_type: "0000000000000000000000000000000000000000000000000000000000000000::usdc_test_v2::USDC_TEST_V2",
            //     reward_coin_type: "0000000000000000000000000000000000000000000000000000000000000000::sui_test_v2::SUI_TEST_V2",
            //     user_claimable_reward: 100000000000,
            //     user_claimed_reward: 0,
            //     rule_ids: [ @0x11fc74a3a32c47392d86065e9958536e779be8697bb93fbb960389bcac4623e4 ]
            //   },
            //   0x0::incentive_v3::ClaimableReward {
            //     asset_coin_type: "0000000000000000000000000000000000000000000000000000000000000000::usdc_test_v2::USDC_TEST_V2",
            //     reward_coin_type: "0000000000000000000000000000000000000000000000000000000000000000::coin_test_v2::COIN_TEST_V2",
            //     user_claimable_reward: 100000000000000,
            //     user_claimed_reward: 0,
            //     rule_ids: [ @0x32c695ddac969cf5e9070d3f1fa7c5927d4b0ccce3364328210670f0d404ade5 ]
            //   },
            //   0x0::incentive_v3::ClaimableReward {
            //     asset_coin_type: "0000000000000000000000000000000000000000000000000000000000000000::coin_test_v2::COIN_TEST_V2",
            //     reward_coin_type: "0000000000000000000000000000000000000000000000000000000000000000::usdc_test_v2::USDC_TEST_V2",
            //     user_claimable_reward: 100000000,
            //     user_claimed_reward: 0,
            //     rule_ids: [ @0x3bc6d08cac26df7cddc44a954531b734a0d6f714f223ce1b85320392c8a90285 ]
            //   }
            // ]

            // looping is pop_back, so the order is reverse
            let (asset_tokens, reward_tokens, claimable_rewards, claimed_rewards, rule_ids) = incentive_v3::parse_claimable_rewards(claimable_rewards);
            lib::printf(b"asset_tokens:");
            assert!(vector::borrow(&asset_tokens, 3) == &type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);
            assert!(vector::borrow(&asset_tokens, 2) == &type_name::into_string(type_name::get<USDC_TEST_V2>()), 0);
            assert!(vector::borrow(&asset_tokens, 1) == &type_name::into_string(type_name::get<USDC_TEST_V2>()), 0);
            assert!(vector::borrow(&asset_tokens, 0) == &type_name::into_string(type_name::get<COIN_TEST_V2>()), 0);
            
            lib::printf(b"reward_tokens:");
            assert!(vector::borrow(&reward_tokens, 2) == &type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);
            assert!(vector::borrow(&reward_tokens, 2) == &type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);
            assert!(vector::borrow(&reward_tokens, 1) == &type_name::into_string(type_name::get<COIN_TEST_V2>()), 0);
            assert!(vector::borrow(&reward_tokens, 0) == &type_name::into_string(type_name::get<USDC_TEST_V2>()), 0);

            assert!(vector::borrow(&claimable_rewards, 3) == &25001027397, 0);
            assert!(vector::borrow(&claimable_rewards, 2) == &100000000000, 0);
            assert!(vector::borrow(&claimable_rewards, 1) == &100000000000000, 0);
            assert!(vector::borrow(&claimable_rewards, 0) == &100000000, 0);

            assert!(vector::borrow(&claimed_rewards, 3) == &100000000000, 0);
            assert!(vector::borrow(&claimed_rewards, 2) == &0, 0);
            assert!(vector::borrow(&claimed_rewards, 1) == &0, 0);
            assert!(vector::borrow(&claimed_rewards, 0) == &0, 0);

            lib::print(&rule_ids);
            let (id, _, _, _, _) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            assert!(vector::borrow(vector::borrow(&rule_ids, 3), 0) == &id, 0);

            let (id, _, _, _, _) = incentive_v3::get_rule_params_for_testing<USDC_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            assert!(vector::borrow(vector::borrow(&rule_ids, 2), 0) == &id, 0);

            let (id, _, _, _, _) = incentive_v3::get_rule_params_for_testing<USDC_TEST_V2, COIN_TEST_V2>(&incentive, 1);
            assert!(vector::borrow(vector::borrow(&rule_ids, 1), 0) == &id, 0);

            let (id, _, _, _, _) = incentive_v3::get_rule_params_for_testing<COIN_TEST_V2, USDC_TEST_V2>(&incentive, 1);
            assert!(vector::borrow(vector::borrow(&rule_ids, 0), 0) == &id, 0);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
        };

        // batch claim reward
        test_scenario::next_tx(scenario_mut, alice);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);   
            let funds = test_scenario::take_shared<RewardFund<SUI_TEST_V2>>(scenario_mut);

            let rule_ids = vector::empty<address>();
            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            vector::push_back(&mut rule_ids, addr);

            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<USDC_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            vector::push_back(&mut rule_ids, addr);

            let coin_types = vector::empty<String>();
            vector::push_back(&mut coin_types, type_name::into_string(type_name::get<SUI_TEST_V2>()));
            vector::push_back(&mut coin_types, type_name::into_string(type_name::get<USDC_TEST_V2>()));

            incentive_v3::claim_reward_entry<SUI_TEST_V2>(&clock, &mut incentive, &mut storage, &mut funds, coin_types, rule_ids, test_scenario::ctx(scenario_mut));

            let claimable_rewards = incentive_v3::get_user_claimable_rewards(&clock, &mut storage, &incentive, alice);
            lib::printf(b"claimable_rewards:");
            lib::print(&claimable_rewards);

            // [debug] [
            //   0x0::incentive_v3::ClaimableReward {
            //     asset_coin_type: "0000000000000000000000000000000000000000000000000000000000000000::sui_test_v2::SUI_TEST_V2",
            //     reward_coin_type: "0000000000000000000000000000000000000000000000000000000000000000::sui_test_v2::SUI_TEST_V2",
            //     user_claimable_reward: 0,
            //     user_claimed_reward: 125001027397,
            //     rule_ids: []
            //   },
            //   0x0::incentive_v3::ClaimableReward {
            //     asset_coin_type: "0000000000000000000000000000000000000000000000000000000000000000::usdc_test_v2::USDC_TEST_V2",
            //     reward_coin_type: "0000000000000000000000000000000000000000000000000000000000000000::sui_test_v2::SUI_TEST_V2",
            //     user_claimable_reward: 0,
            //     user_claimed_reward: 100000000000,
            //     rule_ids: []
            //   },
            //   0x0::incentive_v3::ClaimableReward {
            //     asset_coin_type: "0000000000000000000000000000000000000000000000000000000000000000::usdc_test_v2::USDC_TEST_V2",
            //     reward_coin_type: "0000000000000000000000000000000000000000000000000000000000000000::coin_test_v2::COIN_TEST_V2",
            //     user_claimable_reward: 100000000000000,
            //     user_claimed_reward: 0,
            //     rule_ids: [ @0x32c695ddac969cf5e9070d3f1fa7c5927d4b0ccce3364328210670f0d404ade5 ]
            //   },
            //   0x0::incentive_v3::ClaimableReward {
            //     asset_coin_type: "0000000000000000000000000000000000000000000000000000000000000000::coin_test_v2::COIN_TEST_V2",
            //     reward_coin_type: "0000000000000000000000000000000000000000000000000000000000000000::usdc_test_v2::USDC_TEST_V2",
            //     user_claimable_reward: 100000000,
            //     user_claimed_reward: 0,
            //     rule_ids: [ @0x3bc6d08cac26df7cddc44a954531b734a0d6f714f223ce1b85320392c8a90285 ]
            //   }
            // ]

            // looping is pop_back, so the order is reverse
            let (asset_tokens, reward_tokens, claimable_rewards, claimed_rewards, rule_ids) = incentive_v3::parse_claimable_rewards(claimable_rewards);
            lib::printf(b"asset_tokens:");
            assert!(vector::borrow(&asset_tokens, 3) == &type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);
            assert!(vector::borrow(&asset_tokens, 2) == &type_name::into_string(type_name::get<USDC_TEST_V2>()), 0);
            assert!(vector::borrow(&asset_tokens, 1) == &type_name::into_string(type_name::get<USDC_TEST_V2>()), 0);
            assert!(vector::borrow(&asset_tokens, 0) == &type_name::into_string(type_name::get<COIN_TEST_V2>()), 0);
            
            lib::printf(b"reward_tokens:");
            assert!(vector::borrow(&reward_tokens, 2) == &type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);
            assert!(vector::borrow(&reward_tokens, 2) == &type_name::into_string(type_name::get<SUI_TEST_V2>()), 0);
            assert!(vector::borrow(&reward_tokens, 1) == &type_name::into_string(type_name::get<COIN_TEST_V2>()), 0);
            assert!(vector::borrow(&reward_tokens, 0) == &type_name::into_string(type_name::get<USDC_TEST_V2>()), 0);

            assert!(vector::borrow(&claimable_rewards, 3) == &0, 0);
            assert!(vector::borrow(&claimable_rewards, 2) == &0, 0);
            assert!(vector::borrow(&claimable_rewards, 1) == &100000000000000, 0);
            assert!(vector::borrow(&claimable_rewards, 0) == &100000000, 0);

            assert!(vector::borrow(&claimed_rewards, 3) == &125001027397, 0);
            assert!(vector::borrow(&claimed_rewards, 2) == &100000000000, 0);
            assert!(vector::borrow(&claimed_rewards, 1) == &0, 0);
            assert!(vector::borrow(&claimed_rewards, 0) == &0, 0);

            lib::print(&rule_ids);
            let (id, _, _, _, _) = incentive_v3::get_rule_params_for_testing<USDC_TEST_V2, COIN_TEST_V2>(&incentive, 1);
            assert!(vector::borrow(vector::borrow(&rule_ids, 1), 0) == &id, 0);

            let (id, _, _, _, _) = incentive_v3::get_rule_params_for_testing<COIN_TEST_V2, USDC_TEST_V2>(&incentive, 1);
            assert!(vector::borrow(vector::borrow(&rule_ids, 0), 0) == &id, 0);

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(funds);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    
    // Should claim reward failed because pool not found
    #[test]
    #[expected_failure(abort_code = 2100, location = lending_core::incentive_v3)]
    public fun test_claim_reward_failed_because_pool_not_found() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            incentive_v3_util::init_protocol(scenario_mut);
            incentive_v3_util::user_deposit<USDC_TEST_V2>(scenario_mut, OWNER, 1, 1000_000000000, &clock);
        };

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            incentive_v3_util::user_deposit<SUI_TEST_V2>(scenario_mut, OWNER, 0, 1000_000000000, &clock);
            incentive_v3_util::user_borrow<USDC_TEST_V2>(scenario_mut, OWNER, 1, 1000_000000, &clock);
        };

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);
            let funds = test_scenario::take_shared<RewardFund<SUI_TEST_V2>>(scenario_mut);

            let rule_ids = vector::empty<address>();
            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            vector::push_back(&mut rule_ids, addr);

            incentive_v3::claim_reward_entry<SUI_TEST_V2>(&clock, &mut incentive, &mut storage, &mut funds, vector::singleton(type_name::into_string(type_name::get<USDT_TEST_V2>())), rule_ids, test_scenario::ctx(scenario_mut));

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(funds);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // Should claim reward failed because rule not found
    #[test]
    #[expected_failure(abort_code = 2102, location = lending_core::incentive_v3)]
    public fun test_claim_reward_failed_because_rule_not_found() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            incentive_v3_util::init_protocol(scenario_mut);
            incentive_v3_util::user_deposit<USDC_TEST_V2>(scenario_mut, OWNER, 1, 1000_000000000, &clock);
        };

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            incentive_v3_util::user_deposit<SUI_TEST_V2>(scenario_mut, OWNER, 0, 1000_000000000, &clock);
            incentive_v3_util::user_borrow<USDC_TEST_V2>(scenario_mut, OWNER, 1, 1000_000000, &clock);
        };

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);
            let funds = test_scenario::take_shared<RewardFund<SUI_TEST_V2>>(scenario_mut);

            let rule_ids = vector::empty<address>();
            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            vector::push_back(&mut rule_ids, addr);

            incentive_v3::claim_reward_entry<SUI_TEST_V2>(&clock, &mut incentive, &mut storage, &mut funds, vector::singleton(type_name::into_string(type_name::get<USDC_TEST_V2>())), rule_ids, test_scenario::ctx(scenario_mut));

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(funds);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // Should claim reward failed because invalid coin type
    #[test]
    #[expected_failure(abort_code = 1505, location = lending_core::incentive_v3)]
    public fun test_claim_reward_failed_because_invalid_coin_type() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            incentive_v3_util::init_protocol(scenario_mut);
            incentive_v3_util::user_deposit<USDC_TEST_V2>(scenario_mut, OWNER, 1, 1000_000000000, &clock);
        };

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            incentive_v3_util::user_deposit<SUI_TEST_V2>(scenario_mut, OWNER, 0, 1000_000000000, &clock);
            incentive_v3_util::user_borrow<USDC_TEST_V2>(scenario_mut, OWNER, 1, 1000_000000, &clock);
        };

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);
            let funds = test_scenario::take_shared<RewardFund<USDC_TEST_V2>>(scenario_mut);

            let rule_ids = vector::empty<address>();
            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            vector::push_back(&mut rule_ids, addr);

            incentive_v3::claim_reward_entry<USDC_TEST_V2>(&clock, &mut incentive, &mut storage, &mut funds, vector::singleton(type_name::into_string(type_name::get<SUI_TEST_V2>())), rule_ids, test_scenario::ctx(scenario_mut));

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(funds);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // Should claim reward failed because `coin_types` and `rule_ids` have different length
    #[test]
    #[expected_failure(abort_code = 1505, location = lending_core::incentive_v3)]
    public fun test_claim_reward_failed_because_mismatch_length() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            incentive_v3_util::init_protocol(scenario_mut);
            incentive_v3_util::user_deposit<USDC_TEST_V2>(scenario_mut, OWNER, 1, 1000_000000000, &clock);
        };

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            incentive_v3_util::user_deposit<SUI_TEST_V2>(scenario_mut, OWNER, 0, 1000_000000000, &clock);
            incentive_v3_util::user_borrow<USDC_TEST_V2>(scenario_mut, OWNER, 1, 1000_000000, &clock);
        };

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let storage = test_scenario::take_shared<Storage>(scenario_mut);
            let funds = test_scenario::take_shared<RewardFund<SUI_TEST_V2>>(scenario_mut);

            let rule_ids = vector::empty<address>();
            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
            vector::push_back(&mut rule_ids, addr);

            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            vector::push_back(&mut rule_ids, addr); 

            incentive_v3::claim_reward_entry<SUI_TEST_V2>(&clock, &mut incentive, &mut storage, &mut funds, vector::singleton(type_name::into_string(type_name::get<SUI_TEST_V2>())), rule_ids, test_scenario::ctx(scenario_mut));

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(funds);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    
    // Should set borrow fee  and get borrow fee correctly
    #[test]
    public fun test_borrow_fee() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));

        {
            incentive_v3_util::init_protocol( scenario_mut);
        };

        incentive_v3_util::user_deposit<SUI_TEST_V2>(scenario_mut, OWNER, 0, 1000_000000000, &clock);
        clock::increment_for_testing(&mut clock, 86400 * 1000);

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            
            let borrow_fee = incentive_v3::get_borrow_fee_for_testing(&incentive, 100000000000);
            assert!(borrow_fee == 0, 0);

            test_scenario::return_shared(incentive);
        };

        // set borrow fee
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let admin_cap = test_scenario::take_from_sender<StorageAdminCap>(scenario_mut);
                  
            manage::set_incentive_v3_borrow_fee_rate(&admin_cap, &mut incentive, 100, test_scenario::ctx(scenario_mut));   // 1%
            let borrow_fee = incentive_v3::get_borrow_fee_for_testing(&incentive, 100_000000000);
            assert!(borrow_fee == 1_000000000, 0);

            test_scenario::return_shared(incentive);
            test_scenario::return_to_sender(scenario_mut, admin_cap);
        };

        // deposit and borrow
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            incentive_v3_util::user_deposit<SUI_TEST_V2>(scenario_mut, OWNER, 0, 1000_000000000, &clock);
            incentive_v3_util::user_borrow<SUI_TEST_V2>(scenario_mut, OWNER, 0, 50_000000000, &clock);
            incentive_v3_util::user_borrow<SUI_TEST_V2>(scenario_mut, OWNER, 0, 50_000000000, &clock);
        };  

        // admin withdraw borrow fee
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let admin_cap = test_scenario::take_from_sender<StorageAdminCap>(scenario_mut);

            manage::withdraw_borrow_fee<SUI_TEST_V2>(&admin_cap, &mut incentive, 1_000000000, OWNER, test_scenario::ctx(scenario_mut));
            let owner_sui_amount = incentive_v3_util::get_coin_amount<SUI_TEST_V2>(scenario_mut, OWNER);
            assert!(owner_sui_amount == 1_000000000, 0);
            
            test_scenario::return_shared(incentive);
            test_scenario::return_to_sender(scenario_mut, admin_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // Should withdraw borrow fee failed
    #[test]
    #[expected_failure(abort_code = 1505)]
    public fun test_withdraw_borrow_fee_failed() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));

        {
            incentive_v3_util::init_protocol( scenario_mut);
        };

        incentive_v3_util::user_deposit<SUI_TEST_V2>(scenario_mut, OWNER, 0, 1000_000000000, &clock);
        clock::increment_for_testing(&mut clock, 86400 * 1000);

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            
            let borrow_fee = incentive_v3::get_borrow_fee_for_testing(&incentive, 100000000000);
            assert!(borrow_fee == 0, 0);

            test_scenario::return_shared(incentive);
        };

        // set borrow fee
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let admin_cap = test_scenario::take_from_sender<StorageAdminCap>(scenario_mut);
                  
            manage::set_incentive_v3_borrow_fee_rate(&admin_cap, &mut incentive, 100, test_scenario::ctx(scenario_mut));   // 1%
            let borrow_fee = incentive_v3::get_borrow_fee_for_testing(&incentive, 100_000000000);
            assert!(borrow_fee == 1_000000000, 0);

            test_scenario::return_shared(incentive);
            test_scenario::return_to_sender(scenario_mut, admin_cap);
        };

        // deposit and borrow
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            incentive_v3_util::user_deposit<SUI_TEST_V2>(scenario_mut, OWNER, 0, 1000_000000000, &clock);
            incentive_v3_util::user_borrow<SUI_TEST_V2>(scenario_mut, OWNER, 0, 50_000000000, &clock);
        };  

        // admin withdraw borrow fee
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let admin_cap = test_scenario::take_from_sender<StorageAdminCap>(scenario_mut);

            manage::withdraw_borrow_fee<USDC_TEST_V2>(&admin_cap, &mut incentive, 1_000000000, OWNER, test_scenario::ctx(scenario_mut));

            test_scenario::return_shared(incentive);
            test_scenario::return_to_sender(scenario_mut, admin_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // Should set borrow fee failed
    #[test]
    #[expected_failure(abort_code = 1507)]
    public fun test_set_borrow_fee_failed() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));

        {
            incentive_v3_util::init_protocol( scenario_mut);
        };

        incentive_v3_util::user_deposit<SUI_TEST_V2>(scenario_mut, OWNER, 0, 1000_000000000, &clock);
        clock::increment_for_testing(&mut clock, 86400 * 1000);

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            
            let borrow_fee = incentive_v3::get_borrow_fee_for_testing(&incentive, 100000000000);
            assert!(borrow_fee == 0, 0);

            test_scenario::return_shared(incentive);
        };

        // set borrow fee
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
            let admin_cap = test_scenario::take_from_sender<StorageAdminCap>(scenario_mut);
                  
            manage::set_incentive_v3_borrow_fee_rate(&admin_cap, &mut incentive, 10001, test_scenario::ctx(scenario_mut));   // 1%
            let borrow_fee = incentive_v3::get_borrow_fee_for_testing(&incentive, 100_000000000);
            assert!(borrow_fee == 1_000000000, 0);

            test_scenario::return_shared(incentive);
            test_scenario::return_to_sender(scenario_mut, admin_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // Should get version correctly
    #[test]
    public fun test_version() {
        let scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;

        {
            incentive_v3_util::init_protocol( scenario_mut);
        };

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);

            let version = incentive_v3::version(&incentive);
            assert!(version == version::this_version(), 0);

            test_scenario::return_shared(incentive);
        };

        test_scenario::end(scenario);
    }

    // Should all basic getters return correct values
    // #[test]
    // public fun test_basic_getters() {
    //     let scenario = test_scenario::begin(OWNER);
    //     let scenario_mut = &mut scenario;
    //     let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));
    //     {
    //         incentive_v3_util::init_protocol( scenario_mut);
    //     };

    //     incentive_v3_util::user_deposit<SUI_TEST_V2>(scenario_mut, OWNER, 0, 1000_000000000, &clock);
    //     clock::increment_for_testing(&mut clock, 86400 * 1000);

    //     test_scenario::next_tx(scenario_mut, OWNER);
    //     {
    //         let incentive = test_scenario::take_shared<Incentive_V3>(scenario_mut);
    //         let storage = test_scenario::take_shared<Storage>(scenario_mut);
    //         let sui_funds = test_scenario::take_shared<RewardFund<SUI_TEST_V2>>(scenario_mut);
    //         let (pool_addr, asset, _, rule_num) = incentive_v3::get_asset_pool_params_for_testing<SUI_TEST_V2>(&incentive);
    //         let (rule_addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);
    
    //         let sui_type_str =  type_name::into_string(type_name::get<SUI_TEST_V2>());
    //         let version = incentive_v3::version(&incentive);
    //         assert!(version == 12, 0);

    //         let pools = incentive_v3::pools(&incentive);
    //         let sui_pool = vec_map::get(pools, &sui_type_str);

    //         let pool_size = vec_map::size(pools);
    //         assert!(pool_size == 4, 0);

    //         let contains_rule = incentive_v3::contains_rule(sui_pool, 1, sui_type_str);
    //         assert!(contains_rule, 0);

    //         let rules = incentive_v3::get_rules_by_pool(sui_pool);
    //         let rule_size = vec_map::size(rules);
    //         assert!(rule_size == rule_num, 0);

    //         let sui_supply_rule = vec_map::get(rules, &rule_addr);

    //         let get_id_by_rule = incentive_v3::get_id_by_rule(sui_supply_rule);
    //         assert!(&get_id_by_rule == &rule_addr, 0);

    //         let get_id_by_pool = incentive_v3::get_id_by_pool(sui_pool);
    //         assert!(get_id_by_pool == pool_addr, 0);

    //         let get_asset_id_by_pool = incentive_v3::get_asset_id_by_pool(sui_pool);
    //         assert!(get_asset_id_by_pool == asset, 0);

    //         let get_asset_coin_type_by_pool = incentive_v3::get_asset_coin_type_by_pool(sui_pool);
    //         assert!(&get_asset_coin_type_by_pool == &sui_type_str, 0);


    //         let get_option_by_rule = incentive_v3::get_option_by_rule(sui_supply_rule);
    //         assert!(get_option_by_rule == 1, 0);

    //         let get_enable_by_rule = incentive_v3::get_enable_by_rule(sui_supply_rule);
    //         assert!(get_enable_by_rule == true, 0);

    //         let get_reward_coin_type_by_rule = incentive_v3::get_reward_coin_type_by_rule(sui_supply_rule);
    //         assert!(&get_reward_coin_type_by_rule == &sui_type_str, 0);

    //         let get_rate_by_rule = incentive_v3::get_rate_by_rule(sui_supply_rule);
    //         assert!(get_rate_by_rule == ray_math::ray_div(100_000000000, 86400000), 0);

    //         let get_last_update_at_by_rule = incentive_v3::get_last_update_at_by_rule(sui_supply_rule);
    //         assert!(get_last_update_at_by_rule == 0, 0);

    //         let get_global_index_by_rule = incentive_v3::get_global_index_by_rule(sui_supply_rule);
    //         assert!(get_global_index_by_rule == 0, 0);

    //         let get_user_index_table_by_rule = incentive_v3::get_user_index_table_by_rule(sui_supply_rule);
    //         let user_index = table::borrow(get_user_index_table_by_rule, OWNER);
    //         assert!(*user_index == 0, 0);

    //         let get_user_index_by_rule = incentive_v3::get_user_index_by_rule(sui_supply_rule, OWNER);
    //         assert!(get_user_index_by_rule == 0, 0);

    //         let get_user_rewards_table_by_rule = incentive_v3::get_user_total_rewards_table_by_rule(sui_supply_rule);
    //         let user_rewards = table::borrow(get_user_rewards_table_by_rule, OWNER);
    //         assert!(*user_rewards == 0, 0);

    //         let get_user_rewards_by_rule = incentive_v3::get_user_total_rewards_by_rule(sui_supply_rule, OWNER);
    //         assert!(get_user_rewards_by_rule == 0, 0);

    //         let get_user_rewards_claimed_table_by_rule = incentive_v3::get_user_rewards_claimed_table_by_rule(sui_supply_rule);
    //         assert!(table::length(get_user_rewards_claimed_table_by_rule) == 0, 0);

    //         let get_user_rewards_claimed_by_rule = incentive_v3::get_user_rewards_claimed_by_rule(sui_supply_rule, OWNER);
    //         assert!(get_user_rewards_claimed_by_rule == 0, 0);

    //         let get_balance_value_by_reward_fund = incentive_v3::get_balance_value_by_reward_fund<SUI_TEST_V2>(&sui_funds);
    //         assert!(get_balance_value_by_reward_fund == 1000000_000000000, 0);



    //         test_scenario::return_shared(incentive);
    //         test_scenario::return_shared(storage);
    //         test_scenario::return_shared(sui_funds);
    //     };
    
    //     clock::destroy_for_testing(clock);
    //     test_scenario::end(scenario);
    // }
}