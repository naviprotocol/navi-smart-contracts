#[test_only]
module lending_core::global {
    use sui::clock;
    use sui::coin::{CoinMetadata};
    use sui::test_scenario::{Self, Scenario};

    use oracle::oracle::{Self, OracleAdminCap, PriceOracle};
    use lending_core::incentive;
    use lending_core::pool::{Self, PoolAdminCap};
    use lending_core::btc_test::{Self, BTC_TEST};
    use lending_core::eth_test::{Self, ETH_TEST};
    use lending_core::usdt_test::{Self, USDT_TEST};
    use lending_core::usdc_test::{Self, USDC_TEST};
    use lending_core::test_coin::{Self, TEST_COIN};
    use lending_core::storage::{Self, Storage, StorageAdminCap};

    /**
    USDT:
        poolId: 0
        oracleId: 0
    ETH:
        poolId: 1
        oracleId: 1
    BTC:
        poolId: 2
        oracleId: 2
    */

    const USDT_DECIMALS: u8 = 9;
    const USDT_ORACLE_ID: u8 = 0;
    const USDT_INITIAL_PRICE: u256 = 1_000000000;

    const ETH_DECIMALS: u8 = 9;
    const ETH_ORACLE_ID: u8 = 1;
    const ETH_INITIAL_PRICE: u256 = 1800_000000000;

    const BTC_DECIMALS: u8 = 9;
    const BTC_ORACLE_ID: u8 = 2;
    const BTC_INITIAL_PRICE: u256 = 27000_000000000;

    const USDC_DECIMALS: u8 = 6;
    const USDC_ORACLE_ID: u8 = 3;
    const USDC_INITIAL_PRICE: u256 = 1_000000;

    const TEST_COIN_DECIMALS: u8 = 6;
    const TEST_COIN_ORACLE_ID: u8 = 4;
    const TEST_COIN_INITIAL_PRICE: u256 = 1_0000;

    #[test_only]
    public fun init_protocol(scenario_mut: &mut Scenario) {
        let owner = test_scenario::sender(scenario_mut);

        // Protocol init
        test_scenario::next_tx(scenario_mut, owner);
        {
            pool::init_for_testing(test_scenario::ctx(scenario_mut));      // Initialization of pool
            storage::init_for_testing(test_scenario::ctx(scenario_mut));   // Initialization of storage
            oracle::init_for_testing(test_scenario::ctx(scenario_mut));    // Initialization of oracel
            btc_test::init_for_testing(test_scenario::ctx(scenario_mut));  // Initialization of BTC coin
            eth_test::init_for_testing(test_scenario::ctx(scenario_mut));  // Initialization of ETH coin
            usdt_test::init_for_testing(test_scenario::ctx(scenario_mut)); // Initialization of USDT coin
            usdc_test::init_for_testing(test_scenario::ctx(scenario_mut)); // Initialization of USDC coin
            test_coin::init_for_testing(test_scenario::ctx(scenario_mut)); // Initialization of TEST coin
            incentive::init_for_testing(test_scenario::ctx(scenario_mut)); // Initialization of incentive
        };

        // Oracle: Init
        test_scenario::next_tx(scenario_mut, owner);
        {
            let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario_mut);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario_mut);

            // register USDT token
            oracle::register_token_price(
                &oracle_admin_cap,
                &clock,
                &mut price_oracle,
                USDT_ORACLE_ID,
                USDT_INITIAL_PRICE,
                USDT_DECIMALS,
            );

            // register ETH token
            oracle::register_token_price(
                &oracle_admin_cap,
                &clock,
                &mut price_oracle,
                ETH_ORACLE_ID,
                ETH_INITIAL_PRICE,
                ETH_DECIMALS,
            );

            // register BTC token
            oracle::register_token_price(
                &oracle_admin_cap,
                &clock,
                &mut price_oracle,
                BTC_ORACLE_ID,
                BTC_INITIAL_PRICE,
                BTC_DECIMALS,
            );

            // register USDC token
            oracle::register_token_price(
                &oracle_admin_cap,
                &clock,
                &mut price_oracle,
                USDC_ORACLE_ID,
                USDC_INITIAL_PRICE,
                USDC_DECIMALS,
            );
            
            // register USDC token
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

        // Protocol: Adding USDT pools
        test_scenario::next_tx(scenario_mut, owner);
        {
            let storage = test_scenario::take_shared<Storage>(scenario_mut);
            let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));
            let pool_admin_cap = test_scenario::take_from_sender<PoolAdminCap>(scenario_mut);
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(scenario_mut);
            let usdt_metadata = test_scenario::take_immutable<CoinMetadata<USDT_TEST>>(scenario_mut);

            storage::init_reserve<USDT_TEST>(
                &storage_admin_cap,
                &pool_admin_cap,
                &clock,
                &mut storage,
                USDT_ORACLE_ID,                                   // oracle id
                false,                                           // is_isolated
                20000000_000000000_000000000000000000000000000,  // supply_cap_ceiling: 20000000
                900000000000000000000000000,                     // borrow_cap_ceiling: 90%
                0,                                               // base_rate: 0%
                800000000000000000000000000,                     // optimal_utilization: 80%
                50000000000000000000000000,                      // multiplier: 5%
                1090000000000000000000000000,                     // jump_rate_multiplier: 109%
                70000000000000000000000000,                     // reserve_factor: 7%
                800000000000000000000000000,                     // ltv: 80%
                100000000000000000000000000,                     // treasury_factor: 10%
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

        // Protocol: Adding ETH pools
        test_scenario::next_tx(scenario_mut, owner);
        {
            let storage = test_scenario::take_shared<Storage>(scenario_mut);
            let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));
            let pool_admin_cap = test_scenario::take_from_sender<PoolAdminCap>(scenario_mut);
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(scenario_mut);
            let eth_metadata = test_scenario::take_immutable<CoinMetadata<ETH_TEST>>(scenario_mut);

            storage::init_reserve<ETH_TEST>(
                &storage_admin_cap,
                &pool_admin_cap,
                &clock,
                &mut storage,
                ETH_ORACLE_ID,                                   // oracle id
                false,                                           // is_isolated
                20000000_000000000_000000000000000000000000000,  // supply_cap_ceiling: 20000000
                900000000000000000000000000,                     // borrow_cap_ceiling: 90%
                10000000000000000000000000,                      // base_rate: 1%
                800000000000000000000000000,                     // optimal_utilization: 80%
                40000000000000000000000000,                      // multiplier: 4%
                800000000000000000000000000,                    // jump_rate_multiplier: 80%
                100000000000000000000000000,                     // reserve_factor: 10%
                700000000000000000000000000,                     // ltv: 70%
                100000000000000000000000000,                     // treasury_factor: 10%
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

        // Protocol: Adding BTC pools
        test_scenario::next_tx(scenario_mut, owner);
        {
            let storage = test_scenario::take_shared<Storage>(scenario_mut);
            let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));
            let pool_admin_cap = test_scenario::take_from_sender<PoolAdminCap>(scenario_mut);
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(scenario_mut);
            let btc_metadata = test_scenario::take_immutable<CoinMetadata<BTC_TEST>>(scenario_mut);

            storage::init_reserve<BTC_TEST>(
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
                100000000000000000000000000,                     // reserve_factor: 10%
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

        // Protocol: Adding USDC pools
        test_scenario::next_tx(scenario_mut, owner);
        {
            let storage = test_scenario::take_shared<Storage>(scenario_mut);
            let clock = clock::create_for_testing(test_scenario::ctx(scenario_mut));
            let pool_admin_cap = test_scenario::take_from_sender<PoolAdminCap>(scenario_mut);
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(scenario_mut);
            let usdc_metadata = test_scenario::take_immutable<CoinMetadata<USDC_TEST>>(scenario_mut);

            storage::init_reserve<USDC_TEST>(
                &storage_admin_cap,
                &pool_admin_cap,
                &clock,
                &mut storage,
                USDC_ORACLE_ID,                                   // oracle id
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
            let test_coin_metadata = test_scenario::take_immutable<CoinMetadata<TEST_COIN>>(scenario_mut);

            storage::init_reserve<TEST_COIN>(
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
                100000000000000000000000000,                     // reserve_factor: 10%
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
    }
}
