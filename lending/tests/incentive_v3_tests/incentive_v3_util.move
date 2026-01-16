#[test_only]
module lending_core::incentive_v3_util {
    use sui::clock::{Self, Clock};
    use std::vector::{Self};
    use std::type_name::{Self};
    use sui::coin::{CoinMetadata, Coin};
    use sui::test_scenario::{Self, Scenario};

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

    use lending_core::storage::{Self, Storage, StorageAdminCap, OwnerCap as StorageOwnerCap};
    use lending_core::incentive_v2::{Self, OwnerCap as IncentiveOwnerCap, Incentive as Incentive_V2, IncentiveFundsPool};
    use lending_core::incentive_v3::{Self, Incentive as Incentive_V3, RewardFund};

    use lending_core::incentive_v2_test::{Self};

    const SUI_DECIMALS: u8 = 9;
    const SUI_ORACLE_ID: u8 = 0;
    const SUI_INITIAL_PRICE: u256 = 4_000000000;

    const USDC_DECIMALS: u8 = 6;
    const USDC_ORACLE_ID: u8 = 1;
    const USDC_INITIAL_PRICE: u256 = 1_000000;

    const ETH_DECIMALS: u8 = 8;
    const ETH_ORACLE_ID: u8 = 2;
    const ETH_INITIAL_PRICE: u256 = 3000_000000000;

    const BTC_DECIMALS: u8 = 8;
    const BTC_ORACLE_ID: u8 = 3;
    const BTC_INITIAL_PRICE: u256 = 100000_000000000;

    const TEST_COIN_DECIMALS: u8 = 12;
    const TEST_COIN_ORACLE_ID: u8 = 4;
    const TEST_COIN_INITIAL_PRICE: u256 = 1_000000000000;

    const OWNER: address = @0xA;

    #[test_only]
    public fun init_protocol(scenario_mut: &mut Scenario) {
        let owner = test_scenario::sender(scenario_mut);

        // Protocol init
        test_scenario::next_tx(scenario_mut, owner);
        {
            pool::init_for_testing(test_scenario::ctx(scenario_mut));      // Initialization of pool
            storage::init_for_testing(test_scenario::ctx(scenario_mut));   // Initialization of storage
            oracle::init_for_testing(test_scenario::ctx(scenario_mut));    // Initialization of oracel
            sui_test_v2::init_for_testing(test_scenario::ctx(scenario_mut)); // Initialization of SUI coin
            usdc_test_v2::init_for_testing(test_scenario::ctx(scenario_mut)); // Initialization of USDC coin
            btc_test_v2::init_for_testing(test_scenario::ctx(scenario_mut));  // Initialization of BTC coin
            eth_test_v2::init_for_testing(test_scenario::ctx(scenario_mut));  // Initialization of ETH coin
            coin_test_v2::init_for_testing(test_scenario::ctx(scenario_mut)); // Initialization of TEST coin
            incentive::init_for_testing(test_scenario::ctx(scenario_mut)); // Initialization of incentive
        };

        // Oracle: Init
        test_scenario::next_tx(scenario_mut, owner);
        {
            let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario_mut);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario_mut);
            
            // set update interval to 1000 days
            oracle::set_update_interval(&oracle_admin_cap, &mut price_oracle, 1000 * 86400 * 1000);

            oracle::register_token_price(
                &oracle_admin_cap,
                &clock,
                &mut price_oracle,
                SUI_ORACLE_ID,
                SUI_INITIAL_PRICE,
                SUI_DECIMALS,
            );

            oracle::register_token_price(
                &oracle_admin_cap,
                &clock,
                &mut price_oracle,
                USDC_ORACLE_ID,
                USDC_INITIAL_PRICE,
                USDC_DECIMALS,
            );

            oracle::register_token_price(
                &oracle_admin_cap,
                &clock,
                &mut price_oracle,
                ETH_ORACLE_ID,
                ETH_INITIAL_PRICE,
                ETH_DECIMALS,
            );

            oracle::register_token_price(
                &oracle_admin_cap,
                &clock,
                &mut price_oracle,
                BTC_ORACLE_ID,
                BTC_INITIAL_PRICE,
                BTC_DECIMALS,
            );
            
            oracle::register_token_price(
                &oracle_admin_cap,
                &clock,
                &mut price_oracle,
                TEST_COIN_ORACLE_ID,
                TEST_COIN_INITIAL_PRICE,
                TEST_COIN_DECIMALS,
            );

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_to_sender(scenario_mut, oracle_admin_cap);
        };

        // Protocol: Adding SUI pools
        test_scenario::next_tx(scenario_mut, owner);
        {
            let storage = test_scenario::take_shared<Storage>(scenario_mut);
            let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));
            let pool_admin_cap = test_scenario::take_from_sender<PoolAdminCap>(scenario_mut);
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(scenario_mut);
            let usdt_metadata = test_scenario::take_immutable<CoinMetadata<SUI_TEST_V2>>(scenario_mut);

            storage::init_reserve<SUI_TEST_V2>(
                &storage_admin_cap,
                &pool_admin_cap,
                &clock,
                &mut storage,
                SUI_ORACLE_ID,                                   // oracle id
                false,                                           // is_isolated
                2000000000000_000000000_000000000000000000000000000,  // supply_cap_ceiling: 20000000
                900000000000000000000000000,                     // borrow_cap_ceiling: 90%
                10000000000000000000000000,                                               // base_rate: 1%
                800000000000000000000000000,                     // optimal_utilization: 80%
                50000000000000000000000000,                      // multiplier: 5%
                1090000000000000000000000000,                     // jump_rate_multiplier: 109%
                0,                     // reserve_factor: 0%
                800000000000000000000000000,                     // ltv: 80%
                0,                     // treasury_factor: 0%
                350000000000000000000000000,                     // liquidation_ratio: 35%
                50000000000000000000000000,                      // liquidation_bonus: 5%
                850000000000000000000000000,                     // liquidation_threshold: 85%
                &usdt_metadata,                                  // metadata
                test_scenario::ctx(scenario_mut)
            );

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(storage);
            test_scenario::return_immutable(usdt_metadata);
            test_scenario::return_to_sender(scenario_mut, pool_admin_cap);
            test_scenario::return_to_sender(scenario_mut, storage_admin_cap);
        };

        // Protocol: Adding USDC pools
        test_scenario::next_tx(scenario_mut, owner);
        {
            let storage = test_scenario::take_shared<Storage>(scenario_mut);
            let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));
            let pool_admin_cap = test_scenario::take_from_sender<PoolAdminCap>(scenario_mut);
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(scenario_mut);
            let eth_metadata = test_scenario::take_immutable<CoinMetadata<USDC_TEST_V2>>(scenario_mut);

            storage::init_reserve<USDC_TEST_V2>(
                &storage_admin_cap,
                &pool_admin_cap,
                &clock,
                &mut storage,
                USDC_ORACLE_ID,                                   // oracle id
                false,                                           // is_isolated
                20000000_000000000_000000000000000000000000000,  // supply_cap_ceiling: 20000000
                900000000000000000000000000,                     // borrow_cap_ceiling: 90%
                10000000000000000000000000,                      // base_rate: 1%
                800000000000000000000000000,                     // optimal_utilization: 80%
                40000000000000000000000000,                      // multiplier: 4%
                800000000000000000000000000,                    // jump_rate_multiplier: 80%
                0,                     // reserve_factor: 10%
                700000000000000000000000000,                     // ltv: 70%
                0,                     // treasury_factor: 10%
                350000000000000000000000000,                     // liquidation_ratio: 35%
                50000000000000000000000000,                      // liquidation_bonus: 5%
                750000000000000000000000000,                     // liquidation_threshold: 75%
                &eth_metadata,                                   // metadata
                test_scenario::ctx(scenario_mut)
            );

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(storage);
            test_scenario::return_immutable(eth_metadata);
            test_scenario::return_to_sender(scenario_mut, pool_admin_cap);
            test_scenario::return_to_sender(scenario_mut, storage_admin_cap);
        };

        // Protocol: Adding ETH pools
        test_scenario::next_tx(scenario_mut, owner);
        {
            let storage = test_scenario::take_shared<Storage>(scenario_mut);
            let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));
            let pool_admin_cap = test_scenario::take_from_sender<PoolAdminCap>(scenario_mut);
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(scenario_mut);
            let btc_metadata = test_scenario::take_immutable<CoinMetadata<ETH_TEST_V2>>(scenario_mut);

            storage::init_reserve<ETH_TEST_V2>(
                &storage_admin_cap,
                &pool_admin_cap,
                &clock,
                &mut storage,
                ETH_ORACLE_ID,                                   // oracle id
                false,                                           // is_isolated
                20000000_000000000_000000000000000000000000000,  // supply_cap_ceiling: 20000000
                900000000000000000000000000,                     // borrow_cap_ceiling: 90%
                0,                                               // base_rate: 0%
                800000000000000000000000000,                     // optimal_utilization: 80%
                80000000000000000000000000,                      // multiplier: 8%
                3000000000000000000000000000,                    // jump_rate_multiplier: 300%
                0,                     // reserve_factor: 10%
                750000000000000000000000000,                     // ltv: 75%
                100000000000000000000000000,                     // treasury_factor: 10%
                350000000000000000000000000,                     // liquidation_ratio: 35%
                50000000000000000000000000,                      // liquidation_bonus: 5%
                800000000000000000000000000,                     // liquidation_threshold: 80%
                &btc_metadata,                                   // metadata
                test_scenario::ctx(scenario_mut)
            );

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(storage);
            test_scenario::return_immutable(btc_metadata);
            test_scenario::return_to_sender(scenario_mut, pool_admin_cap);
            test_scenario::return_to_sender(scenario_mut, storage_admin_cap);
        };

        // Protocol: Adding BTC pools
        test_scenario::next_tx(scenario_mut, owner);
        {
            let storage = test_scenario::take_shared<Storage>(scenario_mut);
            let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));
            let pool_admin_cap = test_scenario::take_from_sender<PoolAdminCap>(scenario_mut);
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(scenario_mut);
            let usdc_metadata = test_scenario::take_immutable<CoinMetadata<BTC_TEST_V2>>(scenario_mut);

            storage::init_reserve<BTC_TEST_V2>(
                &storage_admin_cap,
                &pool_admin_cap,
                &clock,
                &mut storage,
                BTC_ORACLE_ID,                                   // oracle id
                false,                                           // is_isolated
                20000000_000000000_000000000000000000000000000,  // supply_cap_ceiling: 20000000
                900000000000000000000000000,                     // borrow_cap_ceiling: 90%
                0,                                               // base_rate: 0%
                800000000000000000000000000,                     // optimal_utilization: 80%
                80000000000000000000000000,                      // multiplier: 8%
                3000000000000000000000000000,                    // jump_rate_multiplier: 300%
                0,                     // reserve_factor: 10%
                750000000000000000000000000,                     // ltv: 75%
                100000000000000000000000000,                     // treasury_factor: 10%
                350000000000000000000000000,                     // liquidation_ratio: 35%
                50000000000000000000000000,                      // liquidation_bonus: 5%
                800000000000000000000000000,                     // liquidation_threshold: 80%
                &usdc_metadata,                                   // metadata
                test_scenario::ctx(scenario_mut)
            );

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(storage);
            test_scenario::return_immutable(usdc_metadata);
            test_scenario::return_to_sender(scenario_mut, pool_admin_cap);
            test_scenario::return_to_sender(scenario_mut, storage_admin_cap);
        };

        // Protocol: Adding TestCoin pools
        test_scenario::next_tx(scenario_mut, owner);
        {
            let storage = test_scenario::take_shared<Storage>(scenario_mut);
            let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));
            let pool_admin_cap = test_scenario::take_from_sender<PoolAdminCap>(scenario_mut);
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(scenario_mut);
            let test_coin_metadata = test_scenario::take_immutable<CoinMetadata<COIN_TEST_V2>>(scenario_mut);

            storage::init_reserve<COIN_TEST_V2>(
                &storage_admin_cap,
                &pool_admin_cap,
                &clock,
                &mut storage,
                TEST_COIN_ORACLE_ID,                                   // oracle id
                false,                                           // is_isolated
                20000000_000000000_000000000000000000000000000,  // supply_cap_ceiling: 20000000
                900000000000000000000000000,                     // borrow_cap_ceiling: 90%
                0,                                               // base_rate: 0%
                800000000000000000000000000,                     // optimal_utilization: 80%
                80000000000000000000000000,                      // multiplier: 8%
                3000000000000000000000000000,                    // jump_rate_multiplier: 300%
                0,                     // reserve_factor: 10%
                0,                     // ltv: 75%
                100000000000000000000000000,                     // treasury_factor: 10%
                350000000000000000000000000,                     // liquidation_ratio: 35%
                50000000000000000000000000,                      // liquidation_bonus: 5%
                0,                     // liquidation_threshold: 80%
                &test_coin_metadata,                                   // metadata
                test_scenario::ctx(scenario_mut)
            );

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(storage);
            test_scenario::return_immutable(test_coin_metadata);
            test_scenario::return_to_sender(scenario_mut, pool_admin_cap);
            test_scenario::return_to_sender(scenario_mut, storage_admin_cap);
        };

        test_scenario::next_tx(scenario_mut, owner);
        {
            initial_incentive_v2(scenario_mut);
        };

        test_scenario::next_tx(scenario_mut, owner);
        {
            initial_incentive_v3(scenario_mut);
        };
    }

    #[test_only]
    public fun initial_incentive_v2(scenario: &mut Scenario) {
        // create incentive owner cap
        test_scenario::next_tx(scenario, OWNER);
        {
            let storage_owner_cap = test_scenario::take_from_sender<StorageOwnerCap>(scenario);
            incentive_v2::create_and_transfer_owner(&storage_owner_cap, test_scenario::ctx(scenario));
            test_scenario::return_to_sender(scenario, storage_owner_cap);
        };
        
        // create incentive
        test_scenario::next_tx(scenario, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(scenario);
            incentive_v2::create_incentive(&owner_cap, test_scenario::ctx(scenario));
            test_scenario::return_to_sender(scenario, owner_cap);
        };

        // create funds pool
        test_scenario::next_tx(scenario, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(scenario);
            let incentive = test_scenario::take_shared<Incentive_V2>(scenario);
            incentive_v2::create_funds_pool<SUI_TEST_V2>(&owner_cap, &mut incentive, 1, false, test_scenario::ctx(scenario));
            incentive_v2::create_funds_pool<USDC_TEST_V2>(&owner_cap, &mut incentive, 2, false, test_scenario::ctx(scenario));
            incentive_v2::create_funds_pool<COIN_TEST_V2>(&owner_cap, &mut incentive, 3, false, test_scenario::ctx(scenario));

            test_scenario::return_shared(incentive);
            test_scenario::return_to_sender(scenario, owner_cap);
        };

        // increase SUI pool funds
        // increase USDC pool funds
        // increase TEST_COIN pool funds
        test_scenario::next_tx(scenario, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(scenario);

            let sui_funds = test_scenario::take_shared<IncentiveFundsPool<SUI_TEST_V2>>(scenario);
            let coin = coin::mint_for_testing<SUI_TEST_V2>(10000_000000000, test_scenario::ctx(scenario));
            incentive_v2::add_funds(&owner_cap, &mut sui_funds, coin, 10000_000000000, test_scenario::ctx(scenario));

            let usdc_funds = test_scenario::take_shared<IncentiveFundsPool<USDC_TEST_V2>>(scenario);
            let usdc_coin = coin::mint_for_testing<USDC_TEST_V2>(10000_000000, test_scenario::ctx(scenario));
            incentive_v2::add_funds(&owner_cap, &mut usdc_funds, usdc_coin, 10000_000000, test_scenario::ctx(scenario));

            let coin_test_funds = test_scenario::take_shared<IncentiveFundsPool<COIN_TEST_V2>>(scenario);
            let coin_test_coin = coin::mint_for_testing<COIN_TEST_V2>(100000_000000000000, test_scenario::ctx(scenario));
            incentive_v2::add_funds(&owner_cap, &mut coin_test_funds, coin_test_coin, 100000_000000000000, test_scenario::ctx(scenario));

            test_scenario::return_shared(sui_funds);
            test_scenario::return_shared(usdc_funds);
            test_scenario::return_shared(coin_test_funds);
            test_scenario::return_to_sender(scenario, owner_cap);
        };

        // create incentive pool
        test_scenario::next_tx(scenario, OWNER);
        {
            let sui_funds = test_scenario::take_shared<IncentiveFundsPool<SUI_TEST_V2>>(scenario);

            incentive_v2_test::create_incentive_pool_for_testing(
                scenario,
                &sui_funds,
                0, // phase
                0, // start
                365 * 86400 * 1000 * 3 / 4, // end
                0, // closed
                10000_000000000, // total_supply
                1, // option
                0, // asset
                1000000000000000000 // factor
            );        
            test_scenario::return_shared(sui_funds);
        };

        test_scenario::next_tx(scenario, OWNER);
        {
            let usdc_funds = test_scenario::take_shared<IncentiveFundsPool<USDC_TEST_V2>>(scenario);

            incentive_v2_test::create_incentive_pool_for_testing(
                scenario,
                &usdc_funds,
                0, // phase
                0, // start
                365 * 86400 * 1000, // end
                0, // closed
                1000_000000, // total_supply
                1, // option
                0, // asset
                1000000000000000000 // factor
            );    
            test_scenario::return_shared(usdc_funds);      
        };
        
        test_scenario::next_tx(scenario, OWNER);
        {
            let coin_test_funds = test_scenario::take_shared<IncentiveFundsPool<COIN_TEST_V2>>(scenario);

            incentive_v2_test::create_incentive_pool_for_testing(
                scenario,
                &coin_test_funds,
                0, // phase
                0, // start
                365 * 86400 * 1000, // end
                0, // closed
                100000_000000000000, // total_supply
                3, // option
                1, // asset
                1000000000000000000 // factor
            );    
            test_scenario::return_shared(coin_test_funds);      
        };
    }

    #[test_only]
    public fun initial_incentive_v3(scenario: &mut Scenario) {
        
        // create incentive
        test_scenario::next_tx(scenario, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(scenario);
            manage::create_incentive_v3(&owner_cap, test_scenario::ctx(scenario));
            test_scenario::return_to_sender(scenario, owner_cap);
        };

        // create pool
        test_scenario::next_tx(scenario, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(scenario);
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario);
            let storage = test_scenario::take_shared<Storage>(scenario);

            manage::create_incentive_v3_pool<SUI_TEST_V2>(&owner_cap, &mut incentive, &storage, 0, test_scenario::ctx(scenario));
            manage::create_incentive_v3_pool<USDC_TEST_V2>(&owner_cap, &mut incentive, &storage, 1, test_scenario::ctx(scenario));
            manage::create_incentive_v3_pool<ETH_TEST_V2>(&owner_cap, &mut incentive, &storage, 2, test_scenario::ctx(scenario));
            // BTC pool not created by default 
            manage::create_incentive_v3_pool<COIN_TEST_V2>(&owner_cap, &mut incentive, &storage, 4, test_scenario::ctx(scenario));

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
            test_scenario::return_to_sender(scenario, owner_cap);
        };

        // create rule
        test_scenario::next_tx(scenario, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(scenario);
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(scenario));

            // SUI_TEST_V2 -> SUI, USDC, ETH, TEST -> supply, borrow
            manage::create_incentive_v3_rule<SUI_TEST_V2, SUI_TEST_V2>(&owner_cap, &clock, &mut incentive, 1, test_scenario::ctx(scenario));
            manage::create_incentive_v3_rule<SUI_TEST_V2, USDC_TEST_V2>(&owner_cap, &clock, &mut incentive, 1, test_scenario::ctx(scenario));
            manage::create_incentive_v3_rule<SUI_TEST_V2, ETH_TEST_V2>(&owner_cap, &clock, &mut incentive, 1, test_scenario::ctx(scenario));
            manage::create_incentive_v3_rule<SUI_TEST_V2, COIN_TEST_V2>(&owner_cap, &clock, &mut incentive, 1, test_scenario::ctx(scenario));

            manage::create_incentive_v3_rule<SUI_TEST_V2, SUI_TEST_V2>(&owner_cap, &clock, &mut incentive, 3, test_scenario::ctx(scenario));
            manage::create_incentive_v3_rule<SUI_TEST_V2, USDC_TEST_V2>(&owner_cap, &clock, &mut incentive, 3, test_scenario::ctx(scenario));
            manage::create_incentive_v3_rule<SUI_TEST_V2, ETH_TEST_V2>(&owner_cap, &clock, &mut incentive, 3, test_scenario::ctx(scenario));
            manage::create_incentive_v3_rule<SUI_TEST_V2, COIN_TEST_V2>(&owner_cap, &clock, &mut incentive, 3, test_scenario::ctx(scenario));
            
            // USDC_TEST_V2 -> SUI, USDC, ETH, TEST -> supply, borrow
            manage::create_incentive_v3_rule<USDC_TEST_V2, SUI_TEST_V2>(&owner_cap, &clock, &mut incentive, 1, test_scenario::ctx(scenario));
            manage::create_incentive_v3_rule<USDC_TEST_V2, USDC_TEST_V2>(&owner_cap, &clock, &mut incentive, 1, test_scenario::ctx(scenario));
            manage::create_incentive_v3_rule<USDC_TEST_V2, ETH_TEST_V2>(&owner_cap, &clock, &mut incentive, 1, test_scenario::ctx(scenario));
            manage::create_incentive_v3_rule<USDC_TEST_V2, COIN_TEST_V2>(&owner_cap, &clock, &mut incentive, 1, test_scenario::ctx(scenario));

            manage::create_incentive_v3_rule<USDC_TEST_V2, SUI_TEST_V2>(&owner_cap, &clock, &mut incentive, 3, test_scenario::ctx(scenario));
            manage::create_incentive_v3_rule<USDC_TEST_V2, USDC_TEST_V2>(&owner_cap, &clock, &mut incentive, 3, test_scenario::ctx(scenario));
            manage::create_incentive_v3_rule<USDC_TEST_V2, ETH_TEST_V2>(&owner_cap, &clock, &mut incentive, 3, test_scenario::ctx(scenario));
            manage::create_incentive_v3_rule<USDC_TEST_V2, COIN_TEST_V2>(&owner_cap, &clock, &mut incentive, 3, test_scenario::ctx(scenario));

            // TEST_COIN -> SUI, USDC, ETH, TEST -> borrow
            manage::create_incentive_v3_rule<COIN_TEST_V2, SUI_TEST_V2>(&owner_cap, &clock, &mut incentive, 3, test_scenario::ctx(scenario));
            manage::create_incentive_v3_rule<COIN_TEST_V2, USDC_TEST_V2>(&owner_cap, &clock, &mut incentive, 3, test_scenario::ctx(scenario));
            manage::create_incentive_v3_rule<COIN_TEST_V2, ETH_TEST_V2>(&owner_cap, &clock, &mut incentive, 3, test_scenario::ctx(scenario));
            manage::create_incentive_v3_rule<COIN_TEST_V2, COIN_TEST_V2>(&owner_cap, &clock, &mut incentive, 3, test_scenario::ctx(scenario));

            test_scenario::return_shared(incentive);
            clock::destroy_for_testing(clock);
            test_scenario::return_to_sender(scenario, owner_cap);
        };

        // deposit reward fund 
        test_scenario::next_tx(scenario, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(scenario);

            manage::create_incentive_v3_reward_fund<SUI_TEST_V2>(&owner_cap, test_scenario::ctx(scenario));
            manage::create_incentive_v3_reward_fund<USDC_TEST_V2>(&owner_cap, test_scenario::ctx(scenario));
            manage::create_incentive_v3_reward_fund<ETH_TEST_V2>(&owner_cap, test_scenario::ctx(scenario));
            manage::create_incentive_v3_reward_fund<COIN_TEST_V2>(&owner_cap, test_scenario::ctx(scenario));
            test_scenario::return_to_sender(scenario, owner_cap);
        };

        // deposit fund 
        test_scenario::next_tx(scenario, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(scenario);
            let sui_funds = test_scenario::take_shared<RewardFund<SUI_TEST_V2>>(scenario);
            let usdc_funds = test_scenario::take_shared<RewardFund<USDC_TEST_V2>>(scenario);
            let eth_funds = test_scenario::take_shared<RewardFund<ETH_TEST_V2>>(scenario);
            let coin_test_funds = test_scenario::take_shared<RewardFund<COIN_TEST_V2>>(scenario);

            let amount = 1000000_000000000;
            let coin = coin::mint_for_testing<SUI_TEST_V2>(amount, test_scenario::ctx(scenario));
            manage::deposit_incentive_v3_reward_fund(&owner_cap, &mut sui_funds, coin, amount, test_scenario::ctx(scenario));

            let amount = 1000000_000000;
            let coin = coin::mint_for_testing<USDC_TEST_V2>(amount, test_scenario::ctx(scenario));
            manage::deposit_incentive_v3_reward_fund(&owner_cap, &mut usdc_funds, coin, amount, test_scenario::ctx(scenario));

            let amount = 1000000_00000000;
            let coin = coin::mint_for_testing<ETH_TEST_V2>(amount, test_scenario::ctx(scenario));
            manage::deposit_incentive_v3_reward_fund(&owner_cap, &mut eth_funds, coin, amount, test_scenario::ctx(scenario));

            let amount = 1000000_000000000000;
            let coin = coin::mint_for_testing<COIN_TEST_V2>(amount, test_scenario::ctx(scenario));
            manage::deposit_incentive_v3_reward_fund(&owner_cap, &mut coin_test_funds, coin, amount, test_scenario::ctx(scenario));

            test_scenario::return_shared(sui_funds);
            test_scenario::return_shared(usdc_funds);
            test_scenario::return_shared(eth_funds);
            test_scenario::return_shared(coin_test_funds);
            test_scenario::return_to_sender(scenario, owner_cap);
        };

        // set SUI reward rate 
        // 100 SUI per day for supply
        // 50 SUI per day for borrow
        test_scenario::next_tx(scenario, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<IncentiveOwnerCap>(scenario);
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario);
            let storage = test_scenario::take_shared<Storage>(scenario);

            let clock = clock::create_for_testing(test_scenario::ctx(scenario));

            let sui_funds = test_scenario::take_shared<RewardFund<SUI_TEST_V2>>(scenario);
            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 1);

            // set supply rate
            let e27: u256 = 1_000000000000000000000000000;
            let rate_per_day = 100_000000000;
            let rate_time = 86400000;
            manage::set_incentive_v3_reward_rate_by_rule_id<SUI_TEST_V2>(&owner_cap, &clock, &mut incentive, &mut storage, addr, rate_per_day, rate_time, test_scenario::ctx(scenario));

            // set borrow rate
            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<SUI_TEST_V2, SUI_TEST_V2>(&incentive, 3);
            let rate_per_day = 50_000000000;
            let rate_time = 86400000;

            manage::set_incentive_v3_reward_rate_by_rule_id<SUI_TEST_V2>(&owner_cap, &clock, &mut incentive, &mut storage, addr, rate_per_day, rate_time, test_scenario::ctx(scenario));

            test_scenario::return_shared(sui_funds);
            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
            clock::destroy_for_testing(clock);
            test_scenario::return_to_sender(scenario, owner_cap);
        };
    }

    #[test_only]
    public fun user_deposit<CoinType>(scenario: &mut Scenario, user: address, asset: u8, amount: u64, clock: &Clock) {
        test_scenario::next_tx(scenario, user);
        {
            let pool = test_scenario::take_shared<Pool<CoinType>>(scenario);
            let storage = test_scenario::take_shared<Storage>(scenario);
            let incentive_v2 = test_scenario::take_shared<Incentive_V2>(scenario);
            let incentive_v3 = test_scenario::take_shared<Incentive_V3>(scenario);
            let coin = coin::mint_for_testing<CoinType>(amount, test_scenario::ctx(scenario));
            incentive_v3::entry_deposit<CoinType>(clock, &mut storage, &mut pool, asset, coin, amount, &mut incentive_v2, &mut incentive_v3, test_scenario::ctx(scenario));
            test_scenario::return_shared(pool);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(incentive_v2);
            test_scenario::return_shared(incentive_v3);
        }; 
    }

    #[test_only]
    public fun user_withdraw<CoinType>(scenario: &mut Scenario, user: address, asset: u8, amount: u64, clock: &Clock) {
        test_scenario::next_tx(scenario, user);
        {
            let pool = test_scenario::take_shared<Pool<CoinType>>(scenario);
            let storage = test_scenario::take_shared<Storage>(scenario);
            let oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let incentive_v2 = test_scenario::take_shared<Incentive_V2>(scenario);
            let incentive_v3 = test_scenario::take_shared<Incentive_V3>(scenario);
            incentive_v3::entry_withdraw<CoinType>(clock, &oracle, &mut storage, &mut pool, asset, amount, &mut incentive_v2, &mut incentive_v3, test_scenario::ctx(scenario));
            test_scenario::return_shared(pool);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(oracle);
            test_scenario::return_shared(incentive_v2);
            test_scenario::return_shared(incentive_v3);
        }; 
    }

    #[test_only]
    public fun user_borrow<CoinType>(scenario: &mut Scenario, user: address, asset: u8, amount: u64, clock: &Clock) {
        test_scenario::next_tx(scenario, user);
        {
            let pool = test_scenario::take_shared<Pool<CoinType>>(scenario);
            let storage = test_scenario::take_shared<Storage>(scenario);
            let oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let incentive_v2 = test_scenario::take_shared<Incentive_V2>(scenario);
            let incentive_v3 = test_scenario::take_shared<Incentive_V3>(scenario);
            incentive_v3::entry_borrow<CoinType>(clock, &oracle, &mut storage, &mut pool, asset, amount, &mut incentive_v2, &mut incentive_v3, test_scenario::ctx(scenario));
            test_scenario::return_shared(pool);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(oracle);
            test_scenario::return_shared(incentive_v2);
            test_scenario::return_shared(incentive_v3);
        }; 
    }

    #[test_only]
    public fun user_repay<CoinType>(scenario: &mut Scenario, user: address, asset: u8, amount: u64, clock: &Clock) {
        test_scenario::next_tx(scenario, user);
        {
            let pool = test_scenario::take_shared<Pool<CoinType>>(scenario);
            let storage = test_scenario::take_shared<Storage>(scenario);
            let incentive_v2 = test_scenario::take_shared<Incentive_V2>(scenario);
            let incentive_v3 = test_scenario::take_shared<Incentive_V3>(scenario);
            let oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let coin = coin::mint_for_testing<CoinType>(amount, test_scenario::ctx(scenario));
            incentive_v3::entry_repay<CoinType>(clock, &oracle, &mut storage, &mut pool, asset, coin, amount, &mut incentive_v2, &mut incentive_v3, test_scenario::ctx(scenario));
            test_scenario::return_shared(pool);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(oracle);
            test_scenario::return_shared(incentive_v2);
            test_scenario::return_shared(incentive_v3);
        };
    }

    #[test_only]
    public fun user_claim_reward<AssetCoinType, RewardCoinType>(scenario: &mut Scenario, user: address, option: u8, clock: &Clock) {
        test_scenario::next_tx(scenario, user);
        {            
            let incentive = test_scenario::take_shared<Incentive_V3>(scenario);
            let storage = test_scenario::take_shared<Storage>(scenario);
            let funds = test_scenario::take_shared<RewardFund<RewardCoinType>>(scenario);

            let rule_ids = vector::empty<address>();
            let (addr, _, _, _, _) = incentive_v3::get_rule_params_for_testing<AssetCoinType, RewardCoinType>(&incentive, option);
            vector::push_back(&mut rule_ids, addr);

            incentive_v3::claim_reward_entry<RewardCoinType>(clock, &mut incentive, &mut storage, &mut funds, vector::singleton(type_name::into_string(type_name::get<AssetCoinType>())), rule_ids, test_scenario::ctx(scenario));

            test_scenario::return_shared(incentive);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(funds);
        };
    }

    #[test_only]
    public fun get_coin_amount<CoinType>(scenario: &mut Scenario, user: address): u64 {
        let amount: u64 = 0;
        test_scenario::next_tx(scenario, user);
        {
            let coin = test_scenario::take_from_sender<Coin<CoinType>>(scenario);
            amount = amount + coin::value(&coin);
            
            test_scenario::return_to_sender(scenario, coin);
        };      
        return amount
    }


    // A convenient function to initialize deposit and borrow for testing
    // user B deposit 
    // user A deposit 10 BTC
    // user A borrow 
    #[test_only]
    public fun init_base_deposit_borrow_for_testing<CoinType>(scenario: &mut Scenario, asset: u8, alice: address, alice_borrow: u64, bob: address, bob_supply: u64, clock: &Clock) {
        // user B deposit 
        test_scenario::next_tx(scenario, bob);
        {
            user_deposit<CoinType>(scenario, bob, asset, bob_supply, clock);
        }; 

        // user A deposit BTC
        test_scenario::next_tx(scenario, alice);
        {
            user_deposit<BTC_TEST_V2>(scenario, alice, 3, 1000000_00000000, clock);
        }; 

        // user A borrow
        test_scenario::next_tx(scenario, alice);
        {
            user_borrow<CoinType>(scenario, alice, asset, alice_borrow, clock);
        }; 
    }

    #[test_only]
    public fun assert_approximately_equal(a: u256, b: u256, tolerance: u256) {
    if (a > b) {
        assert!(a - b <= tolerance, 0);
    } else {
            assert!(b - a <= tolerance, 0);
        }
    }
}


#[test_only]
module lending_core::sui_test_v2 {
    use sui::coin;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct SUI_TEST_V2 has drop {}

    fun init(witness: SUI_TEST_V2, ctx: &mut TxContext) {
        let decimals = 9;
        let name = b"Sui";
        let symbol = b"SUI";
        
        let (treasury_cap, metadata) = coin::create_currency<SUI_TEST_V2>(
            witness,         // witness
            decimals,        // decimals
            symbol,          // symbol
            name,            // name
            b"",             // description
            option::none(),  // icon_url
            ctx
        );

        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx))
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(SUI_TEST_V2 {}, ctx)
    }
}

#[test_only]
module lending_core::usdc_test_v2 {
    use sui::coin;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct USDC_TEST_V2 has drop {}

    fun init(witness: USDC_TEST_V2, ctx: &mut TxContext) {
        let decimals = 6;
        let name = b"Wrapped USDC";
        let symbol = b"USDC_TEST_V2";
        
        let (treasury_cap, metadata) = coin::create_currency<USDC_TEST_V2>(
            witness,         // witness
            decimals,        // decimals
            symbol,          // symbol
            name,            // name
            b"",             // description
            option::none(),  // icon_url
            ctx
        );

        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx))
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(USDC_TEST_V2 {}, ctx)
    }
}

#[test_only]
module lending_core::usdt_test_v2 {
    use sui::coin;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct USDT_TEST_V2 has drop {}

    fun init(witness: USDT_TEST_V2, ctx: &mut TxContext) {
        let decimals = 6;
        let name = b"Wrapped USDT";
        let symbol = b"USDT_TEST_V2";
        
        let (treasury_cap, metadata) = coin::create_currency<USDT_TEST_V2>(
            witness,         // witness
            decimals,        // decimals
            symbol,          // symbol
            name,            // name
            b"",             // description
            option::none(),  // icon_url
            ctx
        );

        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx))
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(USDT_TEST_V2 {}, ctx)
    }
}

#[test_only]
module lending_core::eth_test_v2 {
    use sui::coin;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct ETH_TEST_V2 has drop {}

    fun init(witness: ETH_TEST_V2, ctx: &mut TxContext) {
        let decimals = 9;
        let name = b"Wrapped ETH";
        let symbol = b"ETH_TEST_V2";
        
        let (treasury_cap, metadata) = coin::create_currency<ETH_TEST_V2>(
            witness,         // witness
            decimals,        // decimals
            symbol,          // symbol
            name,            // name
            b"",             // description
            option::none(),  // icon_url
            ctx
        );

        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx))
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ETH_TEST_V2 {}, ctx)
    }
}

#[test_only]
module lending_core::eth2_test_v2 {
    use sui::coin;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct ETH2_TEST_V2 has drop {}

    fun init(witness: ETH2_TEST_V2, ctx: &mut TxContext) {
        let decimals = 9;
        let name = b"Wrapped ETH";
        let symbol = b"ETH2_TEST_V2";
        
        let (treasury_cap, metadata) = coin::create_currency<ETH2_TEST_V2>(
            witness,         // witness
            decimals,        // decimals
            symbol,          // symbol
            name,            // name
            b"",             // description
            option::none(),  // icon_url
            ctx
        );

        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx))
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ETH2_TEST_V2 {}, ctx)
    }
}

#[test_only]
module lending_core::btc_test_v2 {
    use sui::coin;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct BTC_TEST_V2 has drop {}

    fun init(witness: BTC_TEST_V2, ctx: &mut TxContext) {
        let decimals = 9;
        let name = b"Wrapped BTC";
        let symbol = b"BTC_TEST_V2";
        
        let (treasury_cap, metadata) = coin::create_currency<BTC_TEST_V2>(
            witness,         // witness
            decimals,        // decimals
            symbol,          // symbol
            name,            // name
            b"",             // description
            option::none(),  // icon_url
            ctx
        );

        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx))
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(BTC_TEST_V2 {}, ctx)
    }
}

#[test_only]
module lending_core::coin_test_v2 {
    use sui::coin;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct COIN_TEST_V2 has drop {}

    fun init(witness: COIN_TEST_V2, ctx: &mut TxContext) {
        let decimals = 12;
        let name = b"Test Coin";
        let symbol = b"TEST_COIN";
        
        let (treasury_cap, metadata) = coin::create_currency<COIN_TEST_V2>(
            witness,         // witness
            decimals,        // decimals
            symbol,          // symbol
            name,            // name
            b"",             // description
            option::none(),  // icon_url
            ctx
        );

        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx))
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(COIN_TEST_V2 {}, ctx)
    }
}
