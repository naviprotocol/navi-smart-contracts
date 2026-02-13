#[test_only]
module lending_core::base_sui {
    use sui::clock::{Clock};
    use sui::coin::{CoinMetadata};
    use sui::test_scenario::{Self, Scenario};
    use sui::coin::{Self};

    use sui_system::sui_system::{SuiSystemState};
    use liquid_staking::stake_pool::{Self, StakePool, OperatorCap, AdminCap};
    use liquid_staking::cert::{Self, Metadata, CERT};

    use oracle::oracle::{Self, OracleAdminCap, PriceOracle};

    use lending_core::incentive;
    use lending_core::pool::{Self, Pool, PoolAdminCap};
    use lending_core::manage::{Self};
    use lending_core::usdc_test::{Self, USDC_TEST};
    use sui::sui::{SUI};
    use lending_core::storage::{Self, Storage, StorageAdminCap};
    use lending_core::flash_loan::{Config as FlashLoanConfig};
    use sui::vec_map::{Self, VecMap};
    use sui::test_utils;

    use sui_system::governance_test_utils::{
        create_validator_for_testing,
        create_sui_system_state_for_testing,
        advance_epoch,
        advance_epoch_with_reward_amounts
    };

    const VALIDATOR_ADDR_1: address = @0x1;
    const VALIDATOR_ADDR_2: address = @0x2;

    #[test_only]
    public fun initial_protocol(scenario: &mut Scenario, clock: &Clock, with_manager: bool) {
        let owner = test_scenario::sender(scenario);

        test_scenario::next_tx(scenario, owner);
        {
            pool::init_for_testing(test_scenario::ctx(scenario));      // Initialization of pool
            storage::init_for_testing(test_scenario::ctx(scenario));   // Initialization of storage
            oracle::init_for_testing(test_scenario::ctx(scenario));    // Initialization of oracel
            usdc_test::init_for_testing(test_scenario::ctx(scenario)); // Initialization of USDC coin
            incentive::init_for_testing(test_scenario::ctx(scenario)); // Initialization of incentive
        };

        test_scenario::next_tx(scenario, owner);
        {
            create_pool_from_sui(scenario, clock)
        };

        if (with_manager) {
            init_pool_manager(0, 50_000_000_000, scenario);
        };

        test_scenario::next_tx(scenario, owner);
        {
            create_pool_from_usdc(scenario, clock)
        };

        test_scenario::next_tx(scenario, owner);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);

            oracle::set_update_interval(&oracle_admin_cap, &mut price_oracle, 1000 * 60 * 5);
            
            test_scenario::return_to_sender(scenario, oracle_admin_cap);
            test_scenario::return_shared(price_oracle);
        };

        test_scenario::next_tx(scenario, owner);
        {
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(scenario);
            let storage = test_scenario::take_shared<Storage>(scenario);
            manage::create_flash_loan_config_with_storage(&storage_admin_cap, &storage, test_scenario::ctx(scenario));

            test_scenario::return_shared(storage);
            test_scenario::return_to_sender(scenario, storage_admin_cap);
        };

        test_scenario::next_tx(scenario, owner);
        {
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(scenario);
            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(scenario);
            let storage = test_scenario::take_shared<Storage>(scenario);
            let pool = test_scenario::take_shared<Pool<SUI>>(scenario);

            manage::create_flash_loan_asset<SUI>(
                &storage_admin_cap,
                &mut flash_loan_config,
                &storage,
                &pool,
                0,
                16, // 0.2% * 80% = 0.0016 -> 0.0016 * 10000 = 16
                4, // 0.2% * 20% = 0.0004 -> 0.0004 * 10000 = 4
                100000_000000000, // 100k
                0, // 1
                test_scenario::ctx(scenario)
            );
            test_scenario::return_shared(pool);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(flash_loan_config);
            test_scenario::return_to_sender(scenario, storage_admin_cap);
        };

        test_scenario::next_tx(scenario, owner);
        {
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(scenario);
            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(scenario);
            let storage = test_scenario::take_shared<Storage>(scenario);
            let pool = test_scenario::take_shared<Pool<USDC_TEST>>(scenario);

            manage::create_flash_loan_asset<USDC_TEST>(
                &storage_admin_cap,
                &mut flash_loan_config,
                &storage,
                &pool,
                1,
                16, // 0.2% * 80% = 0.0016 -> 0.0016 * 10000 = 16
                4, // 0.2% * 20% = 0.0004 -> 0.0004 * 10000 = 4
                100000_000000, // 100k
                0, // 1
                test_scenario::ctx(scenario)
            );
            test_scenario::return_shared(pool);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(flash_loan_config);
            test_scenario::return_to_sender(scenario, storage_admin_cap);
        }
    }

    #[test_only]
    public fun init_pool_manager(init_sui: u64, target_sui_amount: u64, s: &mut Scenario) {
        let owner = test_scenario::sender(s);

        // Create SuiSystemState with validators
        test_scenario::next_tx(s, @0x0);
        {
            let ctx = test_scenario::ctx(s);
            let validators = vector[
                create_validator_for_testing(VALIDATOR_ADDR_1, 100, ctx),
            ];
            create_sui_system_state_for_testing(validators, 0, 0, ctx);
        };

        advance_epoch(s);

        // init vsui & pool
        test_scenario::next_tx(s, owner);
        {
            cert::test_init(test_scenario::ctx(s));
            stake_pool::init_for_testing(test_scenario::ctx(s));
            pool::init_for_testing(test_scenario::ctx(s));

        };

        // unpause the stake pool
        // set validator weigth
        test_scenario::next_tx(s, owner);
        {
            let stake_pool = test_scenario::take_from_sender<StakePool>(s);
            let metadata = test_scenario::take_from_sender<Metadata<CERT>>(s);
            let operator = test_scenario::take_from_sender<OperatorCap>(s);
            let admin = test_scenario::take_from_sender<AdminCap>(s);

            let system_state = test_scenario::take_shared<SuiSystemState>(s);
            let validator_weights = vec_map::empty<address, u64>();
            vec_map::insert(&mut validator_weights, VALIDATOR_ADDR_1, 1);

            let sui = coin::mint_for_testing<SUI>(2_000_000_000, test_scenario::ctx(s)); 

            stake_pool::set_paused(&mut stake_pool, &admin, false);
            let vsui = stake_pool::stake(&mut stake_pool, &mut metadata, &mut system_state, sui, test_scenario::ctx(s));
            stake_pool::set_validator_weights(&mut stake_pool, &mut metadata, &mut system_state, &operator, validator_weights, test_scenario::ctx(s));

            test_utils::destroy(vsui);
            test_scenario::return_to_sender(s, stake_pool);
            test_scenario::return_to_sender(s, metadata);
            test_scenario::return_to_sender(s, operator);
            test_scenario::return_to_sender(s, admin);

            test_scenario::return_shared(system_state);
        };

        // deposit sui to pool and create pool manager
        test_scenario::next_tx(s, owner);
        {
            let sui_pool = test_scenario::take_shared<Pool<SUI>>(s);
            let stake_pool = test_scenario::take_from_sender<StakePool>(s);
            let metadata = test_scenario::take_from_sender<Metadata<CERT>>(s);
            let sui_coin = coin::mint_for_testing(init_sui, test_scenario::ctx(s));
            let pool_cap = test_scenario::take_from_sender<PoolAdminCap>(s);

            pool::deposit_for_testing<SUI>(&mut sui_pool, sui_coin, test_scenario::ctx(s));
            pool::init_sui_pool_manager(&pool_cap, &mut sui_pool, stake_pool, metadata, target_sui_amount, test_scenario::ctx(s));
            pool::enable_manage(&pool_cap, &mut sui_pool);
            test_scenario::return_to_sender(s, pool_cap);
            test_scenario::return_shared(sui_pool);
        };
    }


    #[test_only]
    public fun create_pool_from_sui(scenario: &mut Scenario, clock: &Clock) {
        let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
        let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);
        let storage = test_scenario::take_shared<Storage>(scenario);
        let pool_admin_cap = test_scenario::take_from_sender<PoolAdminCap>(scenario);
        let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(scenario);

        oracle::register_token_price(
            &oracle_admin_cap,
            clock,
            &mut price_oracle,
            0, // oracle_id
            500000000, // token_price
            9, // decimals
        );

        storage::init_reserve_without_metadata_for_testing<SUI>(
            &storage_admin_cap,
            &pool_admin_cap,
            clock,
            &mut storage,
            0, // oracle id
            false, // is_isolated
            20000000000000000000000000000000000000000000, // supply_cap_ceiling: 20000000
            900000000000000000000000000, // borrow_cap_ceiling: 90%
            0, // base_rate: 0%
            550000000000000000000000000, // optimal_utilization: 80%
            116360000000000000000000000, // multiplier: 5%
            3000000000000000000000000000, // jump_rate_multiplier: 109%
            200000000000000000000000000, // reserve_factor: 7%
            550000000000000000000000000, // ltv: 55%
            100000000000000000000000000, // treasury_factor: 10%
            350000000000000000000000000, // liquidation_ratio: 35%
            100000000000000000000000000, // liquidation_bonus: 10%
            700000000000000000000000000, // liquidation_threshold: 70%
            9, // metadata
            test_scenario::ctx(scenario)
        );

        test_scenario::return_shared(storage);
        test_scenario::return_shared(price_oracle);
        test_scenario::return_to_sender(scenario, oracle_admin_cap);
        test_scenario::return_to_sender(scenario, pool_admin_cap);
        test_scenario::return_to_sender(scenario, storage_admin_cap);
    }

    #[test_only]
    public fun create_pool_from_usdc(scenario: &mut Scenario, clock: &Clock) {
        let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
        let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);
        let storage = test_scenario::take_shared<Storage>(scenario);
        let pool_admin_cap = test_scenario::take_from_sender<PoolAdminCap>(scenario);
        let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(scenario);
        let metadata = test_scenario::take_immutable<CoinMetadata<USDC_TEST>>(scenario);

        oracle::register_token_price(
            &oracle_admin_cap,
            clock,
            &mut price_oracle,
            1, // oracle_id
            999900, // token_price
            6, // decimals
        );

        storage::init_reserve<USDC_TEST>(
            &storage_admin_cap,
            &pool_admin_cap,
            clock,
            &mut storage,
            1, // oracle id
            false, // is_isolated
            30000000000000000000000000000000000000000000, // supply_cap_ceiling: 20000000
            900000000000000000000000000, // borrow_cap_ceiling: 90%
            0, // base_rate: 0%
            500000000000000000000000000, // optimal_utilization: 80%
            128000000000000000000000000, // multiplier: 5%
            3000000000000000000000000000, // jump_rate_multiplier: 109%
            200000000000000000000000000, // reserve_factor: 7%
            600000000000000000000000000, // ltv: 60%
            100000000000000000000000000, // treasury_factor: 10%
            350000000000000000000000000, // liquidation_ratio: 35%
            50000000000000000000000000, // liquidation_bonus: 5%
            850000000000000000000000000, // liquidation_threshold: 85%
            &metadata, // metadata
            test_scenario::ctx(scenario)
        );

        test_scenario::return_shared(storage);
        test_scenario::return_shared(price_oracle);
        test_scenario::return_immutable(metadata);
        test_scenario::return_to_sender(scenario, oracle_admin_cap);
        test_scenario::return_to_sender(scenario, pool_admin_cap);
        test_scenario::return_to_sender(scenario, storage_admin_cap);
    }
}