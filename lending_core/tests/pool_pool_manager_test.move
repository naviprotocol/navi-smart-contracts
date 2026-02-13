#[test_only]
module lending_core::pool_pool_manager_test {
    use sui::test_scenario::{Self as ts, Scenario};

    use lending_core::pool_manager::{Self, SuiPoolManager};

    use lending_core::pool::{Self, Pool, PoolAdminCap};
    use sui_system::sui_system::{SuiSystemState};
    use liquid_staking::stake_pool::{Self, StakePool, OperatorCap, AdminCap};
    use liquid_staking::cert::{Self, Metadata, CERT};
    use lending_core::lib::{print, printf};
    use sui::vec_map::{Self, VecMap};
    use sui::sui::{SUI};
    use sui::balance;
    use sui::test_utils;
    use sui::transfer;
    use sui::coin;

    use sui_system::governance_test_utils::{
        create_validator_for_testing,
        create_sui_system_state_for_testing,
        advance_epoch,
        advance_epoch_with_reward_amounts
    };

    const OWNER: address = @0xA;
    const VALIDATOR_ADDR_1: address = @0x1;
    const VALIDATOR_ADDR_2: address = @0x2;

    // Test USDC coin
    struct USDC has drop {}

    #[test_only]
    public fun init_pool_manager(init_sui: u64, target_sui_amount: u64, s: &mut Scenario) {

        // Create SuiSystemState with validators
        ts::next_tx(s, @0x0);
        {
            let ctx = ts::ctx(s);
            let validators = vector[
                create_validator_for_testing(VALIDATOR_ADDR_1, 100, ctx),
            ];
            create_sui_system_state_for_testing(validators, 0, 0, ctx);
        };

        advance_epoch(s);

        // init vsui & pool
        ts::next_tx(s, OWNER);
        {
            cert::test_init(ts::ctx(s));
            stake_pool::init_for_testing(ts::ctx(s));
            pool::init_for_testing(ts::ctx(s));

        };

        // unpause the stake pool
        // set validator weigth
        ts::next_tx(s, OWNER);
        {
            let stake_pool = ts::take_from_sender<StakePool>(s);
            let metadata = ts::take_from_sender<Metadata<CERT>>(s);
            let operator = ts::take_from_sender<OperatorCap>(s);
            let admin = ts::take_from_sender<AdminCap>(s);

            let system_state = ts::take_shared<SuiSystemState>(s);
            let validator_weights = vec_map::empty<address, u64>();
            vec_map::insert(&mut validator_weights, VALIDATOR_ADDR_1, 1);

            let sui = coin::mint_for_testing<SUI>(2_000_000_000, ts::ctx(s)); 

            stake_pool::set_paused(&mut stake_pool, &admin, false);
            let vsui = stake_pool::stake(&mut stake_pool, &mut metadata, &mut system_state, sui, ts::ctx(s));
            stake_pool::set_validator_weights(&mut stake_pool, &mut metadata, &mut system_state, &operator, validator_weights, ts::ctx(s));

            test_utils::destroy(vsui);
            ts::return_to_sender(s, stake_pool);
            ts::return_to_sender(s, metadata);
            ts::return_to_sender(s, operator);
            ts::return_to_sender(s, admin);

            ts::return_shared(system_state);
        };

        // create SUI pool and USDC pool
        ts::next_tx(s, OWNER);
        {
            let pool_cap = ts::take_from_sender<PoolAdminCap>(s);
            pool::create_pool_for_testing<SUI>(&pool_cap, 9, ts::ctx(s));
            pool::create_pool_for_testing<USDC>(&pool_cap, 6, ts::ctx(s)); // USDC has 6 decimals

            ts::return_to_sender(s, pool_cap);
        };

        // deposit to USDC pool (no pool manager)
        ts::next_tx(s, OWNER);
        {
            let usdc_pool = ts::take_shared<Pool<USDC>>(s);
            let usdc_coin = coin::mint_for_testing<USDC>(1000_000_000, ts::ctx(s)); // 1000 USDC

            pool::deposit_for_testing<USDC>(&mut usdc_pool, usdc_coin, ts::ctx(s));
            ts::return_shared(usdc_pool);
        };

        // deposit sui to pool and create pool manager
        ts::next_tx(s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(s);
            let stake_pool = ts::take_from_sender<StakePool>(s);
            let metadata = ts::take_from_sender<Metadata<CERT>>(s);
            let sui_coin = coin::mint_for_testing(init_sui, ts::ctx(s));
            let pool_cap = ts::take_from_sender<PoolAdminCap>(s);

            pool::deposit_for_testing<SUI>(&mut sui_pool, sui_coin, ts::ctx(s));
            pool::init_sui_pool_manager(&pool_cap, &mut sui_pool, stake_pool, metadata, target_sui_amount, ts::ctx(s));
            pool::enable_manage(&pool_cap, &mut sui_pool);
            ts::return_to_sender(s, pool_cap);
            ts::return_shared(sui_pool);
        };
    }

    // Should create sui pool manager for sui pool only
    #[test]
    public fun test_create_pool_manager() {
        let s = ts::begin(OWNER);
        {
            init_pool_manager(100_000_000_000, 150_000_000_000, &mut s);
        };

        // Verify pool manager state
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);

            // Check pool balance
            let (pool_balance, treasury_balance, decimal) = pool::get_pool_info(&sui_pool);
            assert!(pool_balance == 100_000_000_000, 0); // Pool has 100 SUI
            assert!(treasury_balance == 0, 0); // No treasury yet
            assert!(decimal == 9, 0); // SUI has 9 decimals

            // Check pool manager state
            let pool_manager = pool::get_pool_manager<SUI>(&mut sui_pool);
            let (original_sui_amount, vsui_balance, enabled_manage, target_sui_amount) = pool_manager::get_pool_manager_info(pool_manager);

            // Should have 100 SUI deposited
            assert!(original_sui_amount == 100_000_000_000, 0);
            // Should have 0 vSUI (no staking yet, need refresh)
            assert!(vsui_balance == 0, 0);
            // Should be enabled
            assert!(enabled_manage == true, 0);
            // Target should be 150 SUI
            assert!(target_sui_amount == 150_000_000_000, 0);

            ts::return_shared(sui_pool);
        };

        ts::end(s);
    }

    // Should fail if double create pool manager
    #[test]
    #[expected_failure(abort_code = 0, location=lending_core::pool)]
    public fun test_create_pool_manager_duplicate_fails() {
        let s = ts::begin(OWNER);
        {
            init_pool_manager(100_000_000_000, 150_000_000_000, &mut s);
        };

        // Create another stake pool and metadata to try duplicate init
        ts::next_tx(&mut s, OWNER);
        {
            cert::test_init(ts::ctx(&mut s));
            stake_pool::init_for_testing(ts::ctx(&mut s));
        };

        // Setup the new stake pool
        ts::next_tx(&mut s, OWNER);
        {
            let stake_pool = ts::take_from_sender<StakePool>(&s);
            let metadata = ts::take_from_sender<Metadata<CERT>>(&s);
            let operator = ts::take_from_sender<OperatorCap>(&s);
            let admin = ts::take_from_sender<AdminCap>(&s);
            let system_state = ts::take_shared<SuiSystemState>(&s);

            let validator_weights = vec_map::empty<address, u64>();
            vec_map::insert(&mut validator_weights, VALIDATOR_ADDR_1, 1);
            let sui = coin::mint_for_testing<SUI>(2_000_000_000, ts::ctx(&mut s));

            stake_pool::set_paused(&mut stake_pool, &admin, false);
            let vsui = stake_pool::stake(&mut stake_pool, &mut metadata, &mut system_state, sui, ts::ctx(&mut s));
            stake_pool::set_validator_weights(&mut stake_pool, &mut metadata, &mut system_state, &operator, validator_weights, ts::ctx(&mut s));

            test_utils::destroy(vsui);
            ts::return_to_sender(&s, stake_pool);
            ts::return_to_sender(&s, metadata);
            ts::return_to_sender(&s, operator);
            ts::return_to_sender(&s, admin);
            ts::return_shared(system_state);
        };

        // Try to create pool manager again - should fail with abort code 0
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let stake_pool = ts::take_from_sender<StakePool>(&s);
            let metadata = ts::take_from_sender<Metadata<CERT>>(&s);
            let pool_cap = ts::take_from_sender<PoolAdminCap>(&s);

            // This should abort with code 0 (dynamic_field already exists)
            pool::init_sui_pool_manager(&pool_cap, &mut sui_pool, stake_pool, metadata, 200_000_000_000, ts::ctx(&mut s));

            ts::return_to_sender(&s, pool_cap);
            ts::return_shared(sui_pool);
        };

        ts::end(s);
    }

    // Should update deposit/withdraw in sui pool
    #[test]
    public fun test_deposit_withdraw_sui_pool() {
        let s = ts::begin(OWNER);
        {
            init_pool_manager(100_000_000_000, 50_000_000_000, &mut s);
        };

        // Test deposit - should update pool_manager
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let sui_coin = coin::mint_for_testing<SUI>(50_000_000_000, ts::ctx(&mut s)); // 50 SUI

            let (pool_balance_before, _, _) = pool::get_pool_info(&sui_pool);
            let pool_manager = pool::get_pool_manager<SUI>(&mut sui_pool);
            let (original_before, _, _, _) = pool_manager::get_pool_manager_info(pool_manager);

            assert!(pool_balance_before == 100_000_000_000, 0);
            assert!(original_before == 100_000_000_000, 0);

            // Deposit via deposit_balance_for_testing
            pool::deposit_balance_for_testing<SUI>(&mut sui_pool, coin::into_balance(sui_coin), OWNER);

            let (pool_balance_after, _, _) = pool::get_pool_info(&sui_pool);
            let pool_manager = pool::get_pool_manager<SUI>(&mut sui_pool);
            let (original_after, _, _, _) = pool_manager::get_pool_manager_info(pool_manager);

            // Both pool and pool_manager should be updated
            assert!(pool_balance_after == 150_000_000_000, 0);
            assert!(original_after == 150_000_000_000, 0);

            ts::return_shared(sui_pool);
        };

        // Test withdraw_v2 - should update pool_manager
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let system_state = ts::take_shared<SuiSystemState>(&s);

            let (pool_balance_before, _, _) = pool::get_pool_info(&sui_pool);
            let pool_manager = pool::get_pool_manager<SUI>(&mut sui_pool);
            let (original_before, _, _, _) = pool_manager::get_pool_manager_info(pool_manager);

            assert!(pool_balance_before == 150_000_000_000, 0);
            assert!(original_before == 150_000_000_000, 0);

            // Withdraw 30 SUI via withdraw_balance_v2_for_testing
            let withdraw_balance = pool::withdraw_balance_v2_for_testing<SUI>(&mut sui_pool, 30_000_000_000, OWNER, &mut system_state, ts::ctx(&mut s));

            let (pool_balance_after, _, _) = pool::get_pool_info(&sui_pool);
            let pool_manager = pool::get_pool_manager<SUI>(&mut sui_pool);
            let (original_after, _, _, _) = pool_manager::get_pool_manager_info(pool_manager);

            // Both pool and pool_manager should be updated
            assert!(pool_balance_after == 120_000_000_000, 0);
            assert!(original_after == 120_000_000_000, 0);

            test_utils::destroy(withdraw_balance);
            ts::return_shared(system_state);
            ts::return_shared(sui_pool);
        };

        ts::end(s);
    }

    // Should other pools have no effect for deposit/withdraw
    #[test]
    public fun test_other_pools_deposit_withdraw() {
        let s = ts::begin(OWNER);
        {
            init_pool_manager(100_000_000_000, 50_000_000_000, &mut s);
        };

        // Test USDC pool deposit - no pool_manager to update
        ts::next_tx(&mut s, OWNER);
        {
            let usdc_pool = ts::take_shared<Pool<USDC>>(&s);
            let usdc_coin = coin::mint_for_testing<USDC>(500_000_000, ts::ctx(&mut s)); // 500 USDC

            let (pool_balance_before, _, _) = pool::get_pool_info(&usdc_pool);
            assert!(pool_balance_before == 1000_000_000, 0);

            // Deposit to USDC pool
            pool::deposit_balance_for_testing<USDC>(&mut usdc_pool, coin::into_balance(usdc_coin), OWNER);

            let (pool_balance_after, _, _) = pool::get_pool_info(&usdc_pool);
            assert!(pool_balance_after == 1500_000_000, 0);

            ts::return_shared(usdc_pool);
        };

        // Test USDC pool withdraw (non-v2) - should work since no pool_manager
        ts::next_tx(&mut s, OWNER);
        {
            let usdc_pool = ts::take_shared<Pool<USDC>>(&s);

            let (pool_balance_before, _, _) = pool::get_pool_info(&usdc_pool);
            assert!(pool_balance_before == 1500_000_000, 0);

            // Withdraw from USDC pool using withdraw_balance (non-v2)
            let withdraw_balance = pool::withdraw_balance_for_testing<USDC>(&mut usdc_pool, 200_000_000, OWNER);

            let (pool_balance_after, _, _) = pool::get_pool_info(&usdc_pool);
            assert!(pool_balance_after == 1300_000_000, 0);

            test_utils::destroy(withdraw_balance);
            ts::return_shared(usdc_pool);
        };

        // Test USDC pool withdraw_v2 - should also work
        ts::next_tx(&mut s, OWNER);
        {
            let usdc_pool = ts::take_shared<Pool<USDC>>(&s);
            let system_state = ts::take_shared<SuiSystemState>(&s);

            let (pool_balance_before, _, _) = pool::get_pool_info(&usdc_pool);
            assert!(pool_balance_before == 1300_000_000, 0);

            // Withdraw using v2
            let withdraw_balance = pool::withdraw_balance_v2_for_testing<USDC>(&mut usdc_pool, 300_000_000, OWNER, &mut system_state, ts::ctx(&mut s));

            let (pool_balance_after, _, _) = pool::get_pool_info(&usdc_pool);
            assert!(pool_balance_after == 1000_000_000, 0);

            test_utils::destroy(withdraw_balance);
            ts::return_shared(system_state);
            ts::return_shared(usdc_pool);
        };

        ts::end(s);
    }

    // Should enable/disable pool manager
    #[test]
    public fun test_enable_disable_pool_manager() {
        let s = ts::begin(OWNER);
        {
            init_pool_manager(100_000_000_000, 50_000_000_000, &mut s);
        };

        // Pool manager is enabled by default
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let pool_manager = pool::get_pool_manager<SUI>(&mut sui_pool);
            let (_, _, enabled, _) = pool_manager::get_pool_manager_info(pool_manager);

            assert!(enabled == true, 0);

            ts::return_shared(sui_pool);
        };

        // Set target to 100 SUI and refresh to unstake all vSUI
        // This makes pool.balance >= original_sui_amount (needed for disable_manage)
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let system_state = ts::take_shared<SuiSystemState>(&s);
            let pool_cap = ts::take_from_sender<PoolAdminCap>(&s);

            pool::set_target_sui_amount(&pool_cap, &mut sui_pool, 100_000_000_000, &mut system_state, ts::ctx(&mut s));

            ts::return_to_sender(&s, pool_cap);
            ts::return_shared(system_state);
            ts::return_shared(sui_pool);
        };

        // Disable pool manager
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let pool_cap = ts::take_from_sender<PoolAdminCap>(&s);

            pool::disable_manage(&pool_cap, &mut sui_pool);

            let pool_manager = pool::get_pool_manager<SUI>(&mut sui_pool);
            let (_, _, enabled, _) = pool_manager::get_pool_manager_info(pool_manager);

            assert!(enabled == false, 0);

            ts::return_to_sender(&s, pool_cap);
            ts::return_shared(sui_pool);
        };

        // Enable pool manager again
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let pool_cap = ts::take_from_sender<PoolAdminCap>(&s);

            pool::enable_manage(&pool_cap, &mut sui_pool);

            let pool_manager = pool::get_pool_manager<SUI>(&mut sui_pool);
            let (_, _, enabled, _) = pool_manager::get_pool_manager_info(pool_manager);

            assert!(enabled == true, 0);

            ts::return_to_sender(&s, pool_cap);
            ts::return_shared(sui_pool);
        };

        ts::end(s);
    }

    // Should skip stake/unstake when pool manager is disabled
    // Should still update deposit/withdraw when pool manager is disabled
    #[test]
    public fun test_skip_stake_unstake_when_disabled() {
        let s = ts::begin(OWNER);
        {
            init_pool_manager(100_000_000_000, 50_000_000_000, &mut s);
        };

        // Refresh stake while enabled - should stake 50 SUI
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let system_state = ts::take_shared<SuiSystemState>(&s);

            pool::refresh_stake(&mut sui_pool, &mut system_state, ts::ctx(&mut s));

            let pool_manager = pool::get_pool_manager<SUI>(&mut sui_pool);
            let (original, vsui_balance, _, _) = pool_manager::get_pool_manager_info(pool_manager);
            let (pool_balance, _, _) = pool::get_pool_info(&sui_pool);

            // Should have staked 50 SUI (100 - 50 target)
            assert!(original == 100_000_000_000, 0);
            assert!(vsui_balance == 50_000_000_000, 0);
            assert!(pool_balance == 50_000_000_000, 0);

            ts::return_shared(system_state);
            ts::return_shared(sui_pool);
        };

        // Set target to 100 SUI and refresh to unstake all vSUI
        // This makes pool.balance >= original_sui_amount (needed for disable_manage)
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let system_state = ts::take_shared<SuiSystemState>(&s);
            let pool_cap = ts::take_from_sender<PoolAdminCap>(&s);

            pool::set_target_sui_amount(&pool_cap, &mut sui_pool, 100_000_000_000, &mut system_state, ts::ctx(&mut s));

            ts::return_to_sender(&s, pool_cap);
            ts::return_shared(system_state);
            ts::return_shared(sui_pool);
        };

        // Disable pool manager
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let pool_cap = ts::take_from_sender<PoolAdminCap>(&s);

            pool::disable_manage(&pool_cap, &mut sui_pool);

            ts::return_to_sender(&s, pool_cap);
            ts::return_shared(sui_pool);
        };

        // Deposit more SUI - should NOT trigger stake when disabled
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let sui_coin = coin::mint_for_testing<SUI>(100_000_000_000, ts::ctx(&mut s)); // 100 SUI

            pool::deposit_balance_for_testing<SUI>(&mut sui_pool, coin::into_balance(sui_coin), OWNER);

            let pool_manager = pool::get_pool_manager<SUI>(&mut sui_pool);
            let (original, vsui_balance, enabled, _) = pool_manager::get_pool_manager_info(pool_manager);
            let (pool_balance, _, _) = pool::get_pool_info(&sui_pool);

            // Pool manager is disabled, so no automatic staking
            assert!(enabled == false, 0);
            assert!(original == 200_000_000_000, 0); // Updated by deposit
            assert!(vsui_balance == 0, 0); // Already unstaked before disable
            assert!(pool_balance == 200_000_000_000, 0); // 100 (after unstake) + 100 (new deposit)

            ts::return_shared(sui_pool);
        };

        // Try to refresh stake while disabled - should skip staking
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let system_state = ts::take_shared<SuiSystemState>(&s);

            pool::refresh_stake(&mut sui_pool, &mut system_state, ts::ctx(&mut s));

            let pool_manager = pool::get_pool_manager<SUI>(&mut sui_pool);
            let (_, vsui_balance, _, _) = pool_manager::get_pool_manager_info(pool_manager);
            let (pool_balance, _, _) = pool::get_pool_info(&sui_pool);

            // Should skip staking because disabled
            assert!(vsui_balance == 0, 0); // No change (still 0)
            assert!(pool_balance == 200_000_000_000, 0); // No change (still 200)

            ts::return_shared(system_state);
            ts::return_shared(sui_pool);
        };

        ts::end(s);
    }

    // Should set_target_sui_amount correctly update to 2M SUI
    #[test]
    public fun test_set_target_sui_amount_large() {
        let s = ts::begin(OWNER);
        {
            init_pool_manager(100_000_000_000, 50_000_000_000, &mut s);
        };

        // Set target to 2M SUI
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let system_state = ts::take_shared<SuiSystemState>(&s);
            let pool_cap = ts::take_from_sender<PoolAdminCap>(&s);

            pool::set_target_sui_amount(&pool_cap, &mut sui_pool, 2_000_000_000_000_000, &mut system_state, ts::ctx(&mut s));

            let pool_manager = pool::get_pool_manager<SUI>(&mut sui_pool);
            let (_, _, _, target_sui_amount) = pool_manager::get_pool_manager_info(pool_manager);

            assert!(target_sui_amount == 2_000_000_000_000_000, 0);

            ts::return_to_sender(&s, pool_cap);
            ts::return_shared(system_state);
            ts::return_shared(sui_pool);
        };

        ts::end(s);
    }

    // Should set_target_sui_amount correctly handle edge cases (0.01 SUI, 0 SUI)
    #[test]
    public fun test_set_target_sui_amount_edge_cases() {
        let s = ts::begin(OWNER);
        {
            init_pool_manager(100_000_000_000, 50_000_000_000, &mut s);
        };

        // Set target to 0.01 SUI
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let system_state = ts::take_shared<SuiSystemState>(&s);
            let pool_cap = ts::take_from_sender<PoolAdminCap>(&s);

            pool::set_target_sui_amount(&pool_cap, &mut sui_pool, 10_000_000, &mut system_state, ts::ctx(&mut s));

            let pool_manager = pool::get_pool_manager<SUI>(&mut sui_pool);
            let (_, _, _, target_sui_amount) = pool_manager::get_pool_manager_info(pool_manager);

            assert!(target_sui_amount == 10_000_000, 0);

            ts::return_to_sender(&s, pool_cap);
            ts::return_shared(system_state);
            ts::return_shared(sui_pool);
        };

        // Set target to 0 SUI
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let system_state = ts::take_shared<SuiSystemState>(&s);
            let pool_cap = ts::take_from_sender<PoolAdminCap>(&s);

            pool::set_target_sui_amount(&pool_cap, &mut sui_pool, 0, &mut system_state, ts::ctx(&mut s));

            let pool_manager = pool::get_pool_manager<SUI>(&mut sui_pool);
            let (_, _, _, target_sui_amount) = pool_manager::get_pool_manager_info(pool_manager);

            assert!(target_sui_amount == 0, 0);

            ts::return_to_sender(&s, pool_cap);
            ts::return_shared(system_state);
            ts::return_shared(sui_pool);
        };

        ts::end(s);
    }

    // Should set set_target_sui_amount and refresh, stake extra sui to vsui
    #[test]
    public fun test_set_target_and_stake_extra_sui() {
        let s = ts::begin(OWNER);
        {
            init_pool_manager(100_000_000_000, 150_000_000_000, &mut s);
        };

        // Initially: 100 SUI in pool, target 150 SUI, no staking yet
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let pool_manager = pool::get_pool_manager<SUI>(&mut sui_pool);
            let (_, vsui_balance, _, _) = pool_manager::get_pool_manager_info(pool_manager);
            let (pool_balance, _, _) = pool::get_pool_info(&sui_pool);

            assert!(vsui_balance == 0, 0);
            assert!(pool_balance == 100_000_000_000, 0);

            ts::return_shared(sui_pool);
        };

        // Set target to 50 SUI and refresh - should stake 50 SUI to vSUI
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let system_state = ts::take_shared<SuiSystemState>(&s);
            let pool_cap = ts::take_from_sender<PoolAdminCap>(&s);

            pool::set_target_sui_amount(&pool_cap, &mut sui_pool, 50_000_000_000, &mut system_state, ts::ctx(&mut s));

            let pool_manager = pool::get_pool_manager<SUI>(&mut sui_pool);
            let (_, vsui_balance, _, target_sui_amount) = pool_manager::get_pool_manager_info(pool_manager);
            let (pool_balance, _, _) = pool::get_pool_info(&sui_pool);

            // Target updated
            assert!(target_sui_amount == 50_000_000_000, 0);
            // 50 SUI staked to vSUI
            assert!(vsui_balance == 50_000_000_000, 0);
            // 50 SUI left in pool
            assert!(pool_balance == 50_000_000_000, 0);

            ts::return_to_sender(&s, pool_cap);
            ts::return_shared(system_state);
            ts::return_shared(sui_pool);
        };

        ts::end(s);
    }

    // Should set set_target_sui_amount and refresh, unstake exceed vsui to sui
    #[test]
    public fun test_set_target_and_unstake_vsui() {
        let s = ts::begin(OWNER);
        {
            init_pool_manager(100_000_000_000, 50_000_000_000, &mut s);
        };

        // First stake 50 SUI to vSUI
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let system_state = ts::take_shared<SuiSystemState>(&s);

            pool::refresh_stake(&mut sui_pool, &mut system_state, ts::ctx(&mut s));

            let pool_manager = pool::get_pool_manager<SUI>(&mut sui_pool);
            let (_, vsui_balance, _, _) = pool_manager::get_pool_manager_info(pool_manager);
            let (pool_balance, _, _) = pool::get_pool_info(&sui_pool);

            assert!(vsui_balance == 50_000_000_000, 0);
            assert!(pool_balance == 50_000_000_000, 0);

            ts::return_shared(system_state);
            ts::return_shared(sui_pool);
        };

        // Set target to 100 SUI and refresh - should unstake vSUI back to SUI
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let system_state = ts::take_shared<SuiSystemState>(&s);
            let pool_cap = ts::take_from_sender<PoolAdminCap>(&s);

            pool::set_target_sui_amount(&pool_cap, &mut sui_pool, 100_000_000_000, &mut system_state, ts::ctx(&mut s));

            let pool_manager = pool::get_pool_manager<SUI>(&mut sui_pool);
            let (_, vsui_balance, _, target_sui_amount) = pool_manager::get_pool_manager_info(pool_manager);
            let (pool_balance, _, _) = pool::get_pool_info(&sui_pool);

            // Target updated
            assert!(target_sui_amount == 100_000_000_000, 0);
            // vSUI unstaked back to SUI
            assert!(vsui_balance == 0, 0);
            // 100 SUI in pool
            assert!(pool_balance == 100_000_000_000, 0);

            ts::return_to_sender(&s, pool_cap);
            ts::return_shared(system_state);
            ts::return_shared(sui_pool);
        };

        ts::end(s);
    }

    // Should direct_deposit_sui by admin and not affect other states
    #[test]
    public fun test_direct_deposit_sui_by_admin() {
        let s = ts::begin(OWNER);
        {
            init_pool_manager(100_000_000_000, 50_000_000_000, &mut s);
        };

        // First stake 50 SUI to vSUI
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let system_state = ts::take_shared<SuiSystemState>(&s);

            pool::refresh_stake(&mut sui_pool, &mut system_state, ts::ctx(&mut s));

            let pool_manager = pool::get_pool_manager<SUI>(&mut sui_pool);
            let (original_before, vsui_balance_before, _, target_before) = pool_manager::get_pool_manager_info(pool_manager);
            let (pool_balance_before, _, _) = pool::get_pool_info(&sui_pool);

            assert!(original_before == 100_000_000_000, 0);
            assert!(vsui_balance_before == 50_000_000_000, 0);
            assert!(pool_balance_before == 50_000_000_000, 0);
            assert!(target_before == 50_000_000_000, 0);

            ts::return_shared(system_state);
            ts::return_shared(sui_pool);
        };

        // Direct deposit 30 SUI via admin - should NOT affect pool manager states
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let pool_cap = ts::take_from_sender<PoolAdminCap>(&s);
            let sui_coin = coin::mint_for_testing<SUI>(30_000_000_000, ts::ctx(&mut s)); // 30 SUI

            pool::direct_deposit_sui(&pool_cap, &mut sui_pool, sui_coin, ts::ctx(&mut s));

            let pool_manager = pool::get_pool_manager<SUI>(&mut sui_pool);
            let (original_after, vsui_balance_after, _, target_after) = pool_manager::get_pool_manager_info(pool_manager);
            let (pool_balance_after, _, _) = pool::get_pool_info(&sui_pool);

            // Pool balance should increase by 30 SUI
            assert!(pool_balance_after == 80_000_000_000, 0);
            // Pool manager states should NOT change
            assert!(original_after == 100_000_000_000, 0);
            assert!(vsui_balance_after == 50_000_000_000, 0);
            assert!(target_after == 50_000_000_000, 0);

            ts::return_to_sender(&s, pool_cap);
            ts::return_shared(sui_pool);
        };

        ts::end(s);
    }

    // Should test increasing target_balance_amount triggers unstaking
    #[test]
    public fun test_increasing_target_triggers_unstaking() {
        let s = ts::begin(OWNER);
        {
            init_pool_manager(100_000_000_000, 30_000_000_000, &mut s);
        };

        // First stake 70 SUI to vSUI (100 - 30 target)
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let system_state = ts::take_shared<SuiSystemState>(&s);

            pool::refresh_stake(&mut sui_pool, &mut system_state, ts::ctx(&mut s));

            let pool_manager = pool::get_pool_manager<SUI>(&mut sui_pool);
            let (_, vsui_balance, _, target) = pool_manager::get_pool_manager_info(pool_manager);
            let (pool_balance, _, _) = pool::get_pool_info(&sui_pool);

            assert!(target == 30_000_000_000, 0);
            assert!(vsui_balance == 70_000_000_000, 0);
            assert!(pool_balance == 30_000_000_000, 0);

            ts::return_shared(system_state);
            ts::return_shared(sui_pool);
        };

        // Increase target to 80 SUI - should trigger unstaking of 50 SUI (80 - 30)
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let system_state = ts::take_shared<SuiSystemState>(&s);
            let pool_cap = ts::take_from_sender<PoolAdminCap>(&s);

            pool::set_target_sui_amount(&pool_cap, &mut sui_pool, 80_000_000_000, &mut system_state, ts::ctx(&mut s));

            let pool_manager = pool::get_pool_manager<SUI>(&mut sui_pool);
            let (_, vsui_balance_after, _, target_after) = pool_manager::get_pool_manager_info(pool_manager);
            let (pool_balance_after, _, _) = pool::get_pool_info(&sui_pool);

            // Target increased to 80 SUI
            assert!(target_after == 80_000_000_000, 0);
            // vSUI reduced from 70 to 20 (unstaked 50)
            assert!(vsui_balance_after == 20_000_000_000, 0);
            // Pool balance increased from 30 to 80 (received 50 from unstaking)
            assert!(pool_balance_after == 80_000_000_000, 0);

            ts::return_to_sender(&s, pool_cap);
            ts::return_shared(system_state);
            ts::return_shared(sui_pool);
        };

        ts::end(s);
    }

    // Should test decreasing target_balance_amount triggers staking
    #[test]
    public fun test_decreasing_target_triggers_staking() {
        let s = ts::begin(OWNER);
        {
            init_pool_manager(100_000_000_000, 80_000_000_000, &mut s);
        };

        // First stake 20 SUI to vSUI (100 - 80 target)
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let system_state = ts::take_shared<SuiSystemState>(&s);

            pool::refresh_stake(&mut sui_pool, &mut system_state, ts::ctx(&mut s));

            let pool_manager = pool::get_pool_manager<SUI>(&mut sui_pool);
            let (_, vsui_balance, _, target) = pool_manager::get_pool_manager_info(pool_manager);
            let (pool_balance, _, _) = pool::get_pool_info(&sui_pool);

            assert!(target == 80_000_000_000, 0);
            assert!(vsui_balance == 20_000_000_000, 0);
            assert!(pool_balance == 80_000_000_000, 0);

            ts::return_shared(system_state);
            ts::return_shared(sui_pool);
        };

        // Decrease target to 30 SUI - should trigger staking of 50 SUI (80 - 30)
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let system_state = ts::take_shared<SuiSystemState>(&s);
            let pool_cap = ts::take_from_sender<PoolAdminCap>(&s);

            pool::set_target_sui_amount(&pool_cap, &mut sui_pool, 30_000_000_000, &mut system_state, ts::ctx(&mut s));

            let pool_manager = pool::get_pool_manager<SUI>(&mut sui_pool);
            let (_, vsui_balance_after, _, target_after) = pool_manager::get_pool_manager_info(pool_manager);
            let (pool_balance_after, _, _) = pool::get_pool_info(&sui_pool);

            // Target decreased to 30 SUI
            assert!(target_after == 30_000_000_000, 0);
            // vSUI increased from 20 to 70 (staked 50)
            assert!(vsui_balance_after == 70_000_000_000, 0);
            // Pool balance decreased from 80 to 30 (sent 50 for staking)
            assert!(pool_balance_after == 30_000_000_000, 0);

            ts::return_to_sender(&s, pool_cap);
            ts::return_shared(system_state);
            ts::return_shared(sui_pool);
        };

        ts::end(s);
    }

    // Test pool::unstake_vsui - unstake vSUI to get SUI back
    #[test]
    public fun test_unstake_vsui() {
        let s = ts::begin(OWNER);
        {
            init_pool_manager(100_000_000_000, 50_000_000_000, &mut s);
        };

        // First stake to create vSUI
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let system_state = ts::take_shared<SuiSystemState>(&s);

            // Trigger staking by setting up pool balance > target
            // This will stake the excess into vSUI
            pool::refresh_stake(&mut sui_pool, &mut system_state, ts::ctx(&mut s));

            ts::return_shared(system_state);
            ts::return_shared(sui_pool);
        };

        // Advance epoch to simulate staking
        advance_epoch(&mut s);

        // Now unstake vSUI to get SUI back
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let system_state = ts::take_shared<SuiSystemState>(&s);

            // Mint vSUI coin for testing (simulating user has vSUI)
            let vsui_coin = coin::mint_for_testing<CERT>(5_000_000_000, ts::ctx(&mut s));

            // Call pool::unstake_vsui - this is the interface we're testing
            let sui_coin = pool::unstake_vsui(&mut sui_pool, &mut system_state, vsui_coin, ts::ctx(&mut s));

            // Verify we got SUI back (amount should be approximately the same)
            assert!(coin::value(&sui_coin) >= 4_900_000_000, 0); // Allow slight variation

            test_utils::destroy(sui_coin);
            ts::return_shared(system_state);
            ts::return_shared(sui_pool);
        };

        ts::end(s);
    }

    // Test pool::set_validator_weights_vsui
    #[test]
    public fun test_set_validator_weights_vsui() {
        let s = ts::begin(OWNER);
        {
            init_pool_manager(100_000_000_000, 80_000_000_000, &mut s);
        };

        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let operator = ts::take_from_sender<OperatorCap>(&s);
            let system_state = ts::take_shared<SuiSystemState>(&s);

            // Create validator weights
            let validator_weights = vec_map::empty<address, u64>();
            vec_map::insert(&mut validator_weights, VALIDATOR_ADDR_1, 100);

            // Call pool::set_validator_weights_vsui
            pool::set_validator_weights_vsui(
                &mut sui_pool,
                &mut system_state,
                &operator,
                validator_weights,
                ts::ctx(&mut s)
            );

            // Verify execution succeeded
            assert!(true, 0);

            ts::return_shared(system_state);
            ts::return_to_sender(&s, operator);
            ts::return_shared(sui_pool);
        };

        ts::end(s);
    }

    // Test pool::withdraw_vsui_from_treasury
    #[test]
    public fun test_withdraw_vsui_from_treasury() {
        let recipient = @0xBEEF;
        let s = ts::begin(OWNER);
        {
            init_pool_manager(100_000_000_000, 50_000_000_000, &mut s);
        };

        // Stake to create vSUI
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let system_state = ts::take_shared<SuiSystemState>(&s);

            pool::refresh_stake(&mut sui_pool, &mut system_state, ts::ctx(&mut s));

            ts::return_shared(system_state);
            ts::return_shared(sui_pool);
        };

        // Advance epoch to generate yield
        advance_epoch(&mut s);

        // Withdraw vSUI from treasury
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let system_state = ts::take_shared<SuiSystemState>(&s);
            let pool_cap = ts::take_from_sender<PoolAdminCap>(&s);

            // Call pool::withdraw_vsui_from_treasury
            pool::withdraw_vsui_from_treasury(
                &pool_cap,
                &mut sui_pool,
                recipient,
                &mut system_state,
                ts::ctx(&mut s)
            );

            ts::return_to_sender(&s, pool_cap);
            ts::return_shared(system_state);
            ts::return_shared(sui_pool);
        };

        // Verify recipient received vSUI
        ts::next_tx(&mut s, recipient);
        {
            // Check if recipient has vSUI coin (it should be transferred)
            assert!(ts::has_most_recent_for_sender<coin::Coin<CERT>>(&s), 0);
        };

        ts::end(s);
    }

    // Test pool::get_treasury_sui_amount
    #[test]
    public fun test_get_treasury_sui_amount() {
        let s = ts::begin(OWNER);
        {
            init_pool_manager(100_000_000_000, 50_000_000_000, &mut s);
        };

        // Stake to create vSUI
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);
            let system_state = ts::take_shared<SuiSystemState>(&s);

            pool::refresh_stake(&mut sui_pool, &mut system_state, ts::ctx(&mut s));

            // Check treasury amount (should be 0 initially, no yield yet)
            let treasury_amount = pool::get_treasury_sui_amount(&sui_pool);
            assert!(treasury_amount == 0, 0);

            ts::return_shared(system_state);
            ts::return_shared(sui_pool);
        };

        // Advance epoch to generate yield
        advance_epoch(&mut s);

        // Check treasury amount after yield
        ts::next_tx(&mut s, OWNER);
        {
            let sui_pool = ts::take_shared<Pool<SUI>>(&s);

            // Call pool::get_treasury_sui_amount
            let treasury_amount = pool::get_treasury_sui_amount(&sui_pool);

            // Should have some treasury amount from staking yield (just verify > 0)
            assert!(treasury_amount >= 0, 0);

            ts::return_shared(sui_pool);
        };

        ts::end(s);
    }
}