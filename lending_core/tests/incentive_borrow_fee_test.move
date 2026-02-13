#[test_only]
module lending_core::incentive_borrow_fee_test {
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::clock;
    use sui::coin;
    use lending_core::incentive_v3::{Self, Incentive as IncentiveV3};
    use lending_core::incentive_v2::{Self, OwnerCap as IncentiveOwnerCap, Incentive};
    use lending_core::manage::{Self, BorrowFeeCap};
    use lending_core::storage::{Self, StorageAdminCap, OwnerCap as StorageOwnerCap};
    use lending_core::pool::{Self, Pool};
    use lending_core::sui_test::{SUI_TEST};
    use lending_core::usdt_test::{USDT_TEST};
    use lending_core::base;
    use lending_core::base_lending_tests::{Self};
    use oracle::oracle::{PriceOracle};
    use lending_core::storage::{Storage};
    use lending_core::account::{Self as account, AccountCap};
    use sui_system::sui_system::{SuiSystemState};
    use sui_system::governance_test_utils::{
        create_validator_for_testing,
        create_sui_system_state_for_testing,
        advance_epoch
    };

    const ADMIN: address = @0xAD;
    const USER_1: address = @0x001;
    const USER_2: address = @0x002;
    const ASSET_ID_SUI: u8 = 0;
    const ASSET_ID_USDT: u8 = 1;
    const ASSET_ID_USDC: u8 = 2;

    #[test_only]
    public fun create_incentive(s: &mut Scenario) {
        ts::next_tx( s, ADMIN);
        {
            let owner_cap = ts::take_from_sender<IncentiveOwnerCap>(s);
            let storage = ts::take_shared<Storage>(s);
            incentive_v2::create_incentive(&owner_cap, ts::ctx(s));
            manage::create_incentive_v3_with_storage(&owner_cap, &storage, ts::ctx(s));
            ts::return_shared(storage);
            ts::return_to_sender(s, owner_cap);
        };
    }

    // Should apply default borrow fee rate when no specific overrides exist
    #[test]
    public fun test_default_borrow_fee_rate() {
        let s = ts::begin(ADMIN);

        // Init storage
        ts::next_tx(&mut s, ADMIN);
        {
            storage::init_for_testing(ts::ctx(&mut s));
        };

        // Create IncentiveOwnerCap
        ts::next_tx(&mut s, ADMIN);
        {
            let storage_owner_cap = ts::take_from_sender<StorageOwnerCap>(&s);
            incentive_v2::create_and_transfer_owner(&storage_owner_cap, ts::ctx(&mut s));
            ts::return_to_sender(&s, storage_owner_cap);
        };

        // Create IncentiveV2 and V3
        create_incentive(&mut s);

        // Set default borrow fee rate to 1% (100 out of 10000)
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let admin_cap = ts::take_from_sender<StorageAdminCap>(&s);

            manage::set_incentive_v3_borrow_fee_rate(&admin_cap, &mut incentive_v3, 100, ts::ctx(&mut s));

            let amount = 100_000_000; // 100 SUI
            let fee = incentive_v3::get_borrow_fee_for_testing(&incentive_v3, amount);
            assert!(fee == 1_000_000, 0); // 1% of 100 SUI = 1 SUI

            ts::return_shared(incentive_v3);
            ts::return_to_sender(&s, admin_cap);
        };

        ts::end(s);
    }

    // Should override default rate with asset-specific rate when configured
    // Should fall back to default rate for assets without specific configuration
    #[test]
    public fun test_asset_specific_borrow_fee_rate() {
        let s = ts::begin(ADMIN);

        // Init storage
        ts::next_tx(&mut s, ADMIN);
        {
            storage::init_for_testing(ts::ctx(&mut s));
        };

        // Create IncentiveOwnerCap
        ts::next_tx(&mut s, ADMIN);
        {
            let storage_owner_cap = ts::take_from_sender<StorageOwnerCap>(&s);
            incentive_v2::create_and_transfer_owner(&storage_owner_cap, ts::ctx(&mut s));
            ts::return_to_sender(&s, storage_owner_cap);
        };

        // Create IncentiveV2 and V3
        create_incentive(&mut s);

        // Mint BorrowFeeCap
        ts::next_tx(&mut s, ADMIN);
        {
            let admin_cap = ts::take_from_sender<StorageAdminCap>(&s);
            manage::mint_borrow_fee_cap(&admin_cap, ADMIN, ts::ctx(&mut s));
            ts::return_to_sender(&s, admin_cap);
        };

        // Set default rate to 1%, asset-specific rate to 2% for ASSET_ID_SUI
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let borrow_fee_cap = ts::take_from_sender<BorrowFeeCap>(&s);

            manage::set_borrow_fee_rate(&borrow_fee_cap, &mut incentive_v3, 100, ts::ctx(&mut s));
            manage::set_asset_borrow_fee_rate(&borrow_fee_cap, &mut incentive_v3, ASSET_ID_SUI, 200, ts::ctx(&mut s));

            ts::return_shared(incentive_v3);
            ts::return_to_sender(&s, borrow_fee_cap);
        };

        // Test: asset-specific rate should override default rate
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);

            let amount = 100_000_000; // 100 units

            // For ASSET_ID_SUI, should use asset-specific rate (2%)
            let fee_sui = incentive_v3::get_borrow_fee_v2_for_testing(&mut incentive_v3, USER_1, ASSET_ID_SUI, amount);
            assert!(fee_sui == 2_000_000, 0); // 2% of 100 = 2

            // For ASSET_ID_USDT, should use default rate (1%)
            let fee_usdt = incentive_v3::get_borrow_fee_v2_for_testing(&mut incentive_v3, USER_1, ASSET_ID_USDT, amount);
            assert!(fee_usdt == 1_000_000, 0); // 1% of 100 = 1

            ts::return_shared(incentive_v3);
        };

        ts::end(s);
    }

    // Should override both asset-specific and default rates with user-specific rate (highest priority)
    // Should fall back to asset-specific rate for users without specific configuration
    #[test]
    public fun test_user_specific_borrow_fee_rate() {
        let s = ts::begin(ADMIN);

        // Init storage
        ts::next_tx(&mut s, ADMIN);
        {
            storage::init_for_testing(ts::ctx(&mut s));
        };

        // Create IncentiveOwnerCap
        ts::next_tx(&mut s, ADMIN);
        {
            let storage_owner_cap = ts::take_from_sender<StorageOwnerCap>(&s);
            incentive_v2::create_and_transfer_owner(&storage_owner_cap, ts::ctx(&mut s));
            ts::return_to_sender(&s, storage_owner_cap);
        };

        // Create IncentiveV2 and V3
        create_incentive(&mut s);

        // Mint BorrowFeeCap
        ts::next_tx(&mut s, ADMIN);
        {
            let admin_cap = ts::take_from_sender<StorageAdminCap>(&s);
            manage::mint_borrow_fee_cap(&admin_cap, ADMIN, ts::ctx(&mut s));
            ts::return_to_sender(&s, admin_cap);
        };

        // Set rates: default 1%, asset-specific 2%, user-specific 0.5%
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let borrow_fee_cap = ts::take_from_sender<BorrowFeeCap>(&s);

            manage::set_borrow_fee_rate(&borrow_fee_cap, &mut incentive_v3, 100, ts::ctx(&mut s));
            manage::set_asset_borrow_fee_rate(&borrow_fee_cap, &mut incentive_v3, ASSET_ID_SUI, 200, ts::ctx(&mut s));
            manage::set_user_borrow_fee_rate(&borrow_fee_cap, &mut incentive_v3, USER_1, ASSET_ID_SUI, 50, ts::ctx(&mut s));

            ts::return_shared(incentive_v3);
            ts::return_to_sender(&s, borrow_fee_cap);
        };

        // Test: user-specific rate should override asset-specific rate
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);

            let amount = 100_000_000; // 100 units

            // For USER_1, should use user-specific rate (0.5%)
            let fee_user1 = incentive_v3::get_borrow_fee_v2_for_testing(&mut incentive_v3, USER_1, ASSET_ID_SUI, amount);
            assert!(fee_user1 == 500_000, 0); // 0.5% of 100 = 0.5

            // For USER_2, should use asset-specific rate (2%)
            let fee_user2 = incentive_v3::get_borrow_fee_v2_for_testing(&mut incentive_v3, USER_2, ASSET_ID_SUI, amount);
            assert!(fee_user2 == 2_000_000, 0); // 2% of 100 = 2

            ts::return_shared(incentive_v3);
        };

        ts::end(s);
    }

    // Should work correctly when default rate is 0 (zero fee)
    #[test]
    public fun test_zero_borrow_fee() {
        let s = ts::begin(ADMIN);

        // Init storage
        ts::next_tx(&mut s, ADMIN);
        {
            storage::init_for_testing(ts::ctx(&mut s));
        };

        // Create IncentiveOwnerCap
        ts::next_tx(&mut s, ADMIN);
        {
            let storage_owner_cap = ts::take_from_sender<StorageOwnerCap>(&s);
            incentive_v2::create_and_transfer_owner(&storage_owner_cap, ts::ctx(&mut s));
            ts::return_to_sender(&s, storage_owner_cap);
        };

        // Create IncentiveV2 and V3
        create_incentive(&mut s);

        // Test: when borrow_fee_rate is 0 (default), fee should be 0
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);

            let amount = 100_000_000;
            let fee = incentive_v3::get_borrow_fee_for_testing(&incentive_v3, amount);
            assert!(fee == 0, 0);

            ts::return_shared(incentive_v3);
        };

        ts::end(s);
    }

    // Should calculate fee as borrow_amount × (rate / 10000)
    #[test]
    public fun test_fee_calculation_formula() {
        let s = ts::begin(ADMIN);

        // Init storage
        ts::next_tx(&mut s, ADMIN);
        {
            storage::init_for_testing(ts::ctx(&mut s));
        };

        // Create IncentiveOwnerCap
        ts::next_tx(&mut s, ADMIN);
        {
            let storage_owner_cap = ts::take_from_sender<StorageOwnerCap>(&s);
            incentive_v2::create_and_transfer_owner(&storage_owner_cap, ts::ctx(&mut s));
            ts::return_to_sender(&s, storage_owner_cap);
        };

        // Create IncentiveV2 and V3
        create_incentive(&mut s);

        // Set default borrow fee rate to 2.5% (250 out of 10000)
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let admin_cap = ts::take_from_sender<StorageAdminCap>(&s);

            manage::set_incentive_v3_borrow_fee_rate(&admin_cap, &mut incentive_v3, 250, ts::ctx(&mut s));

            // Test various amounts to verify formula: fee = amount * (rate / 10000)
            let amount1 = 1000_000_000; // 1000 units
            let fee1 = incentive_v3::get_borrow_fee_for_testing(&incentive_v3, amount1);
            assert!(fee1 == 25_000_000, 0); // 1000 * 0.025 = 25

            let amount2 = 500_000_000; // 500 units
            let fee2 = incentive_v3::get_borrow_fee_for_testing(&incentive_v3, amount2);
            assert!(fee2 == 12_500_000, 0); // 500 * 0.025 = 12.5

            let amount3 = 1_000_000; // 1 unit
            let fee3 = incentive_v3::get_borrow_fee_for_testing(&incentive_v3, amount3);
            assert!(fee3 == 25_000, 0); // 1 * 0.025 = 0.025

            ts::return_shared(incentive_v3);
            ts::return_to_sender(&s, admin_cap);
        };

        ts::end(s);
    }

    // Should support different rates for different assets simultaneously
    #[test]
    public fun test_multiple_assets_different_rates() {
        let s = ts::begin(ADMIN);

        // Init storage
        ts::next_tx(&mut s, ADMIN);
        {
            storage::init_for_testing(ts::ctx(&mut s));
        };

        // Create IncentiveOwnerCap
        ts::next_tx(&mut s, ADMIN);
        {
            let storage_owner_cap = ts::take_from_sender<StorageOwnerCap>(&s);
            incentive_v2::create_and_transfer_owner(&storage_owner_cap, ts::ctx(&mut s));
            ts::return_to_sender(&s, storage_owner_cap);
        };

        // Create IncentiveV2 and V3
        create_incentive(&mut s);

        // Mint BorrowFeeCap
        ts::next_tx(&mut s, ADMIN);
        {
            let admin_cap = ts::take_from_sender<StorageAdminCap>(&s);
            manage::mint_borrow_fee_cap(&admin_cap, ADMIN, ts::ctx(&mut s));
            ts::return_to_sender(&s, admin_cap);
        };

        // Set different rates for different assets: SUI 1%, USDT 2%, USDC 3%
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let borrow_fee_cap = ts::take_from_sender<BorrowFeeCap>(&s);

            manage::set_asset_borrow_fee_rate(&borrow_fee_cap, &mut incentive_v3, ASSET_ID_SUI, 100, ts::ctx(&mut s));
            manage::set_asset_borrow_fee_rate(&borrow_fee_cap, &mut incentive_v3, ASSET_ID_USDT, 200, ts::ctx(&mut s));
            manage::set_asset_borrow_fee_rate(&borrow_fee_cap, &mut incentive_v3, ASSET_ID_USDC, 300, ts::ctx(&mut s));

            ts::return_shared(incentive_v3);
            ts::return_to_sender(&s, borrow_fee_cap);
        };

        // Test: each asset should use its own rate
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let amount = 100_000_000; // 100 units

            let fee_sui = incentive_v3::get_borrow_fee_v2_for_testing(&mut incentive_v3, USER_1, ASSET_ID_SUI, amount);
            assert!(fee_sui == 1_000_000, 0); // 1% of 100 = 1

            let fee_usdt = incentive_v3::get_borrow_fee_v2_for_testing(&mut incentive_v3, USER_1, ASSET_ID_USDT, amount);
            assert!(fee_usdt == 2_000_000, 0); // 2% of 100 = 2

            let fee_usdc = incentive_v3::get_borrow_fee_v2_for_testing(&mut incentive_v3, USER_1, ASSET_ID_USDC, amount);
            assert!(fee_usdc == 3_000_000, 0); // 3% of 100 = 3

            ts::return_shared(incentive_v3);
        };

        ts::end(s);
    }

    // Should support different rates for different users on the same asset
    #[test]
    public fun test_multiple_users_different_rates() {
        let s = ts::begin(ADMIN);

        // Init storage
        ts::next_tx(&mut s, ADMIN);
        {
            storage::init_for_testing(ts::ctx(&mut s));
        };

        // Create IncentiveOwnerCap
        ts::next_tx(&mut s, ADMIN);
        {
            let storage_owner_cap = ts::take_from_sender<StorageOwnerCap>(&s);
            incentive_v2::create_and_transfer_owner(&storage_owner_cap, ts::ctx(&mut s));
            ts::return_to_sender(&s, storage_owner_cap);
        };

        // Create IncentiveV2 and V3
        create_incentive(&mut s);

        // Mint BorrowFeeCap
        ts::next_tx(&mut s, ADMIN);
        {
            let admin_cap = ts::take_from_sender<StorageAdminCap>(&s);
            manage::mint_borrow_fee_cap(&admin_cap, ADMIN, ts::ctx(&mut s));
            ts::return_to_sender(&s, admin_cap);
        };

        // Set user-specific rates: USER_1 0.5%, USER_2 1.5%
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let borrow_fee_cap = ts::take_from_sender<BorrowFeeCap>(&s);

            manage::set_user_borrow_fee_rate(&borrow_fee_cap, &mut incentive_v3, USER_1, ASSET_ID_SUI, 50, ts::ctx(&mut s));
            manage::set_user_borrow_fee_rate(&borrow_fee_cap, &mut incentive_v3, USER_2, ASSET_ID_SUI, 150, ts::ctx(&mut s));

            ts::return_shared(incentive_v3);
            ts::return_to_sender(&s, borrow_fee_cap);
        };

        // Test: each user should use their own rate for the same asset
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let amount = 100_000_000; // 100 units

            let fee_user1 = incentive_v3::get_borrow_fee_v2_for_testing(&mut incentive_v3, USER_1, ASSET_ID_SUI, amount);
            assert!(fee_user1 == 500_000, 0); // 0.5% of 100 = 0.5

            let fee_user2 = incentive_v3::get_borrow_fee_v2_for_testing(&mut incentive_v3, USER_2, ASSET_ID_SUI, amount);
            assert!(fee_user2 == 1_500_000, 0); // 1.5% of 100 = 1.5

            ts::return_shared(incentive_v3);
        };

        ts::end(s);
    }

    // Should prioritize user-specific rate over asset-specific rate
    #[test]
    public fun test_priority_user_over_asset() {
        let s = ts::begin(ADMIN);

        // Init storage
        ts::next_tx(&mut s, ADMIN);
        {
            storage::init_for_testing(ts::ctx(&mut s));
        };

        // Create IncentiveOwnerCap
        ts::next_tx(&mut s, ADMIN);
        {
            let storage_owner_cap = ts::take_from_sender<StorageOwnerCap>(&s);
            incentive_v2::create_and_transfer_owner(&storage_owner_cap, ts::ctx(&mut s));
            ts::return_to_sender(&s, storage_owner_cap);
        };

        // Create IncentiveV2 and V3
        create_incentive(&mut s);

        // Mint BorrowFeeCap
        ts::next_tx(&mut s, ADMIN);
        {
            let admin_cap = ts::take_from_sender<StorageAdminCap>(&s);
            manage::mint_borrow_fee_cap(&admin_cap, ADMIN, ts::ctx(&mut s));
            ts::return_to_sender(&s, admin_cap);
        };

        // Set asset-specific 2% and user-specific 0.5%
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let borrow_fee_cap = ts::take_from_sender<BorrowFeeCap>(&s);

            manage::set_asset_borrow_fee_rate(&borrow_fee_cap, &mut incentive_v3, ASSET_ID_SUI, 200, ts::ctx(&mut s));
            manage::set_user_borrow_fee_rate(&borrow_fee_cap, &mut incentive_v3, USER_1, ASSET_ID_SUI, 50, ts::ctx(&mut s));

            ts::return_shared(incentive_v3);
            ts::return_to_sender(&s, borrow_fee_cap);
        };

        // Test: user-specific rate should have priority
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let amount = 100_000_000;

            let fee = incentive_v3::get_borrow_fee_v2_for_testing(&mut incentive_v3, USER_1, ASSET_ID_SUI, amount);
            assert!(fee == 500_000, 0); // Should use 0.5% not 2%

            ts::return_shared(incentive_v3);
        };

        ts::end(s);
    }

    // Should prioritize asset-specific rate over default rate
    #[test]
    public fun test_priority_asset_over_default() {
        let s = ts::begin(ADMIN);

        // Init storage
        ts::next_tx(&mut s, ADMIN);
        {
            storage::init_for_testing(ts::ctx(&mut s));
        };

        // Create IncentiveOwnerCap
        ts::next_tx(&mut s, ADMIN);
        {
            let storage_owner_cap = ts::take_from_sender<StorageOwnerCap>(&s);
            incentive_v2::create_and_transfer_owner(&storage_owner_cap, ts::ctx(&mut s));
            ts::return_to_sender(&s, storage_owner_cap);
        };

        // Create IncentiveV2 and V3
        create_incentive(&mut s);

        // Mint BorrowFeeCap
        ts::next_tx(&mut s, ADMIN);
        {
            let admin_cap = ts::take_from_sender<StorageAdminCap>(&s);
            manage::mint_borrow_fee_cap(&admin_cap, ADMIN, ts::ctx(&mut s));
            ts::return_to_sender(&s, admin_cap);
        };

        // Set default 1% and asset-specific 3%
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let borrow_fee_cap = ts::take_from_sender<BorrowFeeCap>(&s);

            manage::set_borrow_fee_rate(&borrow_fee_cap, &mut incentive_v3, 100, ts::ctx(&mut s));
            manage::set_asset_borrow_fee_rate(&borrow_fee_cap, &mut incentive_v3, ASSET_ID_SUI, 300, ts::ctx(&mut s));

            ts::return_shared(incentive_v3);
            ts::return_to_sender(&s, borrow_fee_cap);
        };

        // Test: asset-specific rate should have priority over default
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let amount = 100_000_000;

            let fee = incentive_v3::get_borrow_fee_v2_for_testing(&mut incentive_v3, USER_1, ASSET_ID_SUI, amount);
            assert!(fee == 3_000_000, 0); // Should use 3% not 1%

            ts::return_shared(incentive_v3);
        };

        ts::end(s);
    }

    // Should use default rate as final fallback when no overrides exist
    #[test]
    public fun test_default_as_final_fallback() {
        let s = ts::begin(ADMIN);

        // Init storage
        ts::next_tx(&mut s, ADMIN);
        {
            storage::init_for_testing(ts::ctx(&mut s));
        };

        // Create IncentiveOwnerCap
        ts::next_tx(&mut s, ADMIN);
        {
            let storage_owner_cap = ts::take_from_sender<StorageOwnerCap>(&s);
            incentive_v2::create_and_transfer_owner(&storage_owner_cap, ts::ctx(&mut s));
            ts::return_to_sender(&s, storage_owner_cap);
        };

        // Create IncentiveV2 and V3
        create_incentive(&mut s);

        // Mint BorrowFeeCap
        ts::next_tx(&mut s, ADMIN);
        {
            let admin_cap = ts::take_from_sender<StorageAdminCap>(&s);
            manage::mint_borrow_fee_cap(&admin_cap, ADMIN, ts::ctx(&mut s));
            ts::return_to_sender(&s, admin_cap);
        };

        // Set only default rate (1.5%), no asset or user overrides
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let borrow_fee_cap = ts::take_from_sender<BorrowFeeCap>(&s);

            manage::set_borrow_fee_rate(&borrow_fee_cap, &mut incentive_v3, 150, ts::ctx(&mut s));

            ts::return_shared(incentive_v3);
            ts::return_to_sender(&s, borrow_fee_cap);
        };

        // Test: should use default rate when no user/asset overrides
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let amount = 100_000_000;

            let fee = incentive_v3::get_borrow_fee_v2_for_testing(&mut incentive_v3, USER_1, ASSET_ID_SUI, amount);
            assert!(fee == 1_500_000, 0); // Should use default 1.5%

            ts::return_shared(incentive_v3);
        };

        ts::end(s);
    }

    // Should mint owner cap and send to recipient
    #[test]
    public fun test_mint_borrow_fee_cap() {
        let s = ts::begin(ADMIN);

        // Init storage
        ts::next_tx(&mut s, ADMIN);
        {
            storage::init_for_testing(ts::ctx(&mut s));
        };

        // Mint BorrowFeeCap for USER_1
        ts::next_tx(&mut s, ADMIN);
        {
            let admin_cap = ts::take_from_sender<StorageAdminCap>(&s);
            manage::mint_borrow_fee_cap(&admin_cap, USER_1, ts::ctx(&mut s));
            ts::return_to_sender(&s, admin_cap);
        };

        // Test: USER_1 should receive BorrowFeeCap
        ts::next_tx(&mut s, USER_1);
        {
            let borrow_fee_cap = ts::take_from_sender<BorrowFeeCap>(&s);
            ts::return_to_sender(&s, borrow_fee_cap);
        };

        ts::end(s);
    }

    // Should apply borrow fee in all borrow entry functions (entry_borrow, entry_borrow_v2, borrow, borrow_v2, borrow_with_account_cap, borrow_with_account_cap_v2)
    #[test]
    public fun test_borrow_fee_applied_in_all_entry_functions() {
        let userA = USER_1;
        let scenarioA = ts::begin(userA);

        let scenario = ts::begin(@0x0);

        // Create SuiSystemState for v2 functions
        ts::next_tx(&mut scenario, @0x0);
        {
            let ctx = ts::ctx(&mut scenario);
            let validators = vector[
                create_validator_for_testing(@0x1, 100, ctx),
            ];
            create_sui_system_state_for_testing(validators, 0, 0, ctx);
        };
        advance_epoch(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);

        let _clock = clock::create_for_testing(ts::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };

        // Create IncentiveOwnerCap
        ts::next_tx(&mut scenario, ADMIN);
        {
            let storage_owner_cap = ts::take_from_sender<StorageOwnerCap>(&scenario);
            incentive_v2::create_and_transfer_owner(&storage_owner_cap, ts::ctx(&mut scenario));
            ts::return_to_sender(&scenario, storage_owner_cap);
        };

        // Create IncentiveV2 and V3
        create_incentive(&mut scenario);

        // Set default borrow fee rate to 1% (100 out of 10000)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&scenario);
            let admin_cap = ts::take_from_sender<StorageAdminCap>(&scenario);

            manage::set_incentive_v3_borrow_fee_rate(&admin_cap, &mut incentive_v3, 100, ts::ctx(&mut scenario));

            ts::return_shared(incentive_v3);
            ts::return_to_sender(&scenario, admin_cap);
        };

        // userA deposit SUI 10000
        ts::next_tx(&mut scenarioA, userA);
        {
            let pool = ts::take_shared<Pool<SUI_TEST>>(&scenario);
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            let coin = coin::mint_for_testing<SUI_TEST>(10000_000000000, ts::ctx(&mut scenarioA));

            base_lending_tests::base_deposit_for_testing(&mut scenarioA, &clock, &mut pool, coin, 0, 10000_000000000);

            clock::destroy_for_testing(clock);
            ts::return_shared(pool);
        };

        // Test 1: entry_borrow should apply 1% fee
        ts::next_tx(&mut scenarioA, userA);
        {
            let pool = ts::take_shared<Pool<SUI_TEST>>(&scenario);
            let storage = ts::take_shared<storage::Storage>(&scenario);
            let price_oracle = ts::take_shared<PriceOracle>(&scenario);
            let incentive = ts::take_shared<Incentive>(&scenario);
            let incentive_v3 = ts::take_shared<IncentiveV3>(&scenario);
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));

            let (pool_balance_before, _, _) = pool::get_pool_info(&pool);

            // Borrow 10 SUI via entry_borrow
            incentive_v3::entry_borrow(
                &clock,
                &price_oracle,
                &mut storage,
                &mut pool,
                0,
                10_000000000, // 10 SUI
                &mut incentive,
                &mut incentive_v3,
                ts::ctx(&mut scenarioA)
            );

            let (pool_balance_after, _, _) = pool::get_pool_info(&pool);

            // Pool should decrease by 10.1 SUI (10 borrowed + 0.1 fee)
            assert!(pool_balance_before - pool_balance_after == 10_100000000, 0);

            clock::destroy_for_testing(clock);
            ts::return_shared(pool);
            ts::return_shared(storage);
            ts::return_shared(price_oracle);
            ts::return_shared(incentive);
            ts::return_shared(incentive_v3);
        };

        // userA deposit USDT 10000 for more tests
        ts::next_tx(&mut scenarioA, userA);
        {
            let pool = ts::take_shared<Pool<USDT_TEST>>(&scenario);
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            let coin = coin::mint_for_testing<USDT_TEST>(10000_000000, ts::ctx(&mut scenarioA));

            base_lending_tests::base_deposit_for_testing(&mut scenarioA, &clock, &mut pool, coin, 2, 10000_000000);

            clock::destroy_for_testing(clock);
            ts::return_shared(pool);
        };

        // Test 2: entry_borrow_v2 should apply 1% fee
        ts::next_tx(&mut scenarioA, userA);
        {
            let pool = ts::take_shared<Pool<USDT_TEST>>(&scenario);
            let storage = ts::take_shared<storage::Storage>(&scenario);
            let price_oracle = ts::take_shared<PriceOracle>(&scenario);
            let incentive = ts::take_shared<Incentive>(&scenario);
            let incentive_v3 = ts::take_shared<IncentiveV3>(&scenario);
            let system_state = ts::take_shared<SuiSystemState>(&scenario);
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));

            let (pool_balance_before, _, _) = pool::get_pool_info(&pool);

            // Borrow 10 USDT via entry_borrow_v2
            incentive_v3::entry_borrow_v2(
                &clock,
                &price_oracle,
                &mut storage,
                &mut pool,
                2,
                10_000000, // 10 USDT
                &mut incentive,
                &mut incentive_v3,
                &mut system_state,
                ts::ctx(&mut scenarioA)
            );

            let (pool_balance_after, _, _) = pool::get_pool_info(&pool);

            // Pool should decrease by 10.1 USDT (10 borrowed + 0.1 fee)
            assert!(pool_balance_before - pool_balance_after == 10_100000, 0);

            clock::destroy_for_testing(clock);
            ts::return_shared(pool);
            ts::return_shared(storage);
            ts::return_shared(price_oracle);
            ts::return_shared(system_state);
            ts::return_shared(incentive);
            ts::return_shared(incentive_v3);
        };

        // Create AccountCap for USER_1
        ts::next_tx(&mut scenarioA, userA);
        {
            base_lending_tests::create_account_cap_for_testing(&mut scenarioA);
        };

        // userA deposit SUI 1000 with account_cap for more tests
        ts::next_tx(&mut scenarioA, userA);
        {
            let pool = ts::take_shared<Pool<SUI_TEST>>(&scenario);
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            let coin = coin::mint_for_testing<SUI_TEST>(1000_000000000, ts::ctx(&mut scenarioA));
            let account_cap = ts::take_from_sender<AccountCap>(&scenarioA);

            base_lending_tests::base_deposit_with_account_for_testing(&mut scenarioA, &clock, &mut pool, coin, 0, &account_cap);

            clock::destroy_for_testing(clock);
            ts::return_shared(pool);
            ts::return_to_sender(&scenarioA, account_cap);
        };

        // Test 5: borrow_with_account_cap should apply 1% fee
        ts::next_tx(&mut scenarioA, userA);
        {
            let pool = ts::take_shared<Pool<SUI_TEST>>(&scenario);
            let storage = ts::take_shared<storage::Storage>(&scenario);
            let price_oracle = ts::take_shared<PriceOracle>(&scenario);
            let incentive = ts::take_shared<Incentive>(&scenario);
            let incentive_v3 = ts::take_shared<IncentiveV3>(&scenario);
            let account_cap = ts::take_from_sender<AccountCap>(&scenarioA);
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));

            let (pool_balance_before, _, _) = pool::get_pool_info(&pool);

            // Borrow 5 SUI via borrow_with_account_cap
            let balance = incentive_v3::borrow_with_account_cap(
                &clock,
                &price_oracle,
                &mut storage,
                &mut pool,
                0,
                5_000000000, // 5 SUI
                &mut incentive,
                &mut incentive_v3,
                &account_cap
            );

            let (pool_balance_after, _, _) = pool::get_pool_info(&pool);

            // Pool should decrease by 5.05 SUI (5 borrowed + 0.05 fee)
            assert!(pool_balance_before - pool_balance_after == 5_050000000, 0);

            sui::test_utils::destroy(balance);
            clock::destroy_for_testing(clock);
            ts::return_shared(pool);
            ts::return_shared(storage);
            ts::return_shared(price_oracle);
            ts::return_shared(incentive);
            ts::return_shared(incentive_v3);
            ts::return_to_sender(&scenarioA, account_cap);
        };

        // userA deposit USDT 1000 with account_cap for v2 test
        ts::next_tx(&mut scenarioA, userA);
        {
            let pool = ts::take_shared<Pool<USDT_TEST>>(&scenario);
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            let coin = coin::mint_for_testing<USDT_TEST>(1000_000000, ts::ctx(&mut scenarioA));
            let account_cap = ts::take_from_sender<AccountCap>(&scenarioA);

            base_lending_tests::base_deposit_with_account_for_testing(&mut scenarioA, &clock, &mut pool, coin, 2, &account_cap);

            clock::destroy_for_testing(clock);
            ts::return_shared(pool);
            ts::return_to_sender(&scenarioA, account_cap);
        };

        // Test 6: borrow_with_account_cap_v2 should apply 1% fee
        ts::next_tx(&mut scenarioA, userA);
        {
            let pool = ts::take_shared<Pool<USDT_TEST>>(&scenario);
            let storage = ts::take_shared<storage::Storage>(&scenario);
            let price_oracle = ts::take_shared<PriceOracle>(&scenario);
            let incentive = ts::take_shared<Incentive>(&scenario);
            let incentive_v3 = ts::take_shared<IncentiveV3>(&scenario);
            let system_state = ts::take_shared<SuiSystemState>(&scenario);
            let account_cap = ts::take_from_sender<AccountCap>(&scenarioA);
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));

            let (pool_balance_before, _, _) = pool::get_pool_info(&pool);

            // Borrow 5 USDT via borrow_with_account_cap_v2
            let balance = incentive_v3::borrow_with_account_cap_v2(
                &clock,
                &price_oracle,
                &mut storage,
                &mut pool,
                2,
                5_000000, // 5 USDT
                &mut incentive,
                &mut incentive_v3,
                &account_cap,
                &mut system_state,
                ts::ctx(&mut scenarioA)
            );

            let (pool_balance_after, _, _) = pool::get_pool_info(&pool);

            // Pool should decrease by 5.05 USDT (5 borrowed + 0.05 fee)
            assert!(pool_balance_before - pool_balance_after == 5_050000, 0);

            sui::test_utils::destroy(balance);
            clock::destroy_for_testing(clock);
            ts::return_shared(pool);
            ts::return_shared(storage);
            ts::return_shared(price_oracle);
            ts::return_shared(system_state);
            ts::return_shared(incentive);
            ts::return_shared(incentive_v3);
            ts::return_to_sender(&scenarioA, account_cap);
        };

        // Test 3: borrow should apply 1% fee
        ts::next_tx(&mut scenarioA, userA);
        {
            let pool = ts::take_shared<Pool<SUI_TEST>>(&scenario);
            let storage = ts::take_shared<storage::Storage>(&scenario);
            let price_oracle = ts::take_shared<PriceOracle>(&scenario);
            let incentive = ts::take_shared<Incentive>(&scenario);
            let incentive_v3 = ts::take_shared<IncentiveV3>(&scenario);
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));

            let (pool_balance_before, _, _) = pool::get_pool_info(&pool);

            // Borrow 5 SUI via borrow
            let balance = incentive_v3::borrow(
                &clock,
                &price_oracle,
                &mut storage,
                &mut pool,
                0,
                5_000000000, // 5 SUI
                &mut incentive,
                &mut incentive_v3,
                ts::ctx(&mut scenarioA)
            );

            let (pool_balance_after, _, _) = pool::get_pool_info(&pool);

            // Pool should decrease by 5.05 SUI (5 borrowed + 0.05 fee)
            assert!(pool_balance_before - pool_balance_after == 5_050000000, 0);

            sui::test_utils::destroy(balance);
            clock::destroy_for_testing(clock);
            ts::return_shared(pool);
            ts::return_shared(storage);
            ts::return_shared(price_oracle);
            ts::return_shared(incentive);
            ts::return_shared(incentive_v3);
        };

        // Test 4: borrow_v2 should apply 1% fee
        ts::next_tx(&mut scenarioA, userA);
        {
            let pool = ts::take_shared<Pool<USDT_TEST>>(&scenario);
            let storage = ts::take_shared<storage::Storage>(&scenario);
            let price_oracle = ts::take_shared<PriceOracle>(&scenario);
            let incentive = ts::take_shared<Incentive>(&scenario);
            let incentive_v3 = ts::take_shared<IncentiveV3>(&scenario);
            let system_state = ts::take_shared<SuiSystemState>(&scenario);
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));

            let (pool_balance_before, _, _) = pool::get_pool_info(&pool);

            // Borrow 5 USDT via borrow_v2
            let balance = incentive_v3::borrow_v2(
                &clock,
                &price_oracle,
                &mut storage,
                &mut pool,
                2,
                5_000000, // 5 USDT
                &mut incentive,
                &mut incentive_v3,
                &mut system_state,
                ts::ctx(&mut scenarioA)
            );

            let (pool_balance_after, _, _) = pool::get_pool_info(&pool);

            // Pool should decrease by 5.05 USDT (5 borrowed + 0.05 fee)
            assert!(pool_balance_before - pool_balance_after == 5_050000, 0);

            sui::test_utils::destroy(balance);
            clock::destroy_for_testing(clock);
            ts::return_shared(pool);
            ts::return_shared(storage);
            ts::return_shared(price_oracle);
            ts::return_shared(system_state);
            ts::return_shared(incentive);
            ts::return_shared(incentive_v3);
        };

        ts::end(scenario);
        ts::end(scenarioA);
        clock::destroy_for_testing(_clock);
    }

    // Integration Test: Borrow fee workflow
    // Test case:
    // 1. Check borrow fee using default fee
    // 2. Set asset borrow fee
    // 3. Check borrow fee using asset borrow fee
    // 4. Set user borrow fee
    // 5. Check borrow fee using user borrow fee
    // 6. Remove user borrow fee, check
    // 7. Remove asset borrow fee, check
    #[test]
    public fun test_integration_borrow_fee_workflow() {
        let s = ts::begin(ADMIN);

        // Init storage
        ts::next_tx(&mut s, ADMIN);
        {
            storage::init_for_testing(ts::ctx(&mut s));
        };

        // Create IncentiveOwnerCap
        ts::next_tx(&mut s, ADMIN);
        {
            let storage_owner_cap = ts::take_from_sender<StorageOwnerCap>(&s);
            incentive_v2::create_and_transfer_owner(&storage_owner_cap, ts::ctx(&mut s));
            ts::return_to_sender(&s, storage_owner_cap);
        };

        // Create IncentiveV2 and V3
        create_incentive(&mut s);

        // Mint BorrowFeeCap
        ts::next_tx(&mut s, ADMIN);
        {
            let admin_cap = ts::take_from_sender<StorageAdminCap>(&s);
            manage::mint_borrow_fee_cap(&admin_cap, ADMIN, ts::ctx(&mut s));
            ts::return_to_sender(&s, admin_cap);
        };

        // Step 1: Check borrow fee using default fee (1%)
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let borrow_fee_cap = ts::take_from_sender<BorrowFeeCap>(&s);

            // Set default rate to 1% (100 out of 10000)
            manage::set_borrow_fee_rate(&borrow_fee_cap, &mut incentive_v3, 100, ts::ctx(&mut s));

            ts::return_shared(incentive_v3);
            ts::return_to_sender(&s, borrow_fee_cap);
        };

        // Verify default fee is applied
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);

            let amount = 100_000_000; // 100 units
            let fee = incentive_v3::get_borrow_fee_v2_for_testing(&mut incentive_v3, USER_1, ASSET_ID_SUI, amount);
            assert!(fee == 1_000_000, 0); // 1% of 100 = 1

            ts::return_shared(incentive_v3);
        };

        // Step 2 & 3: Set asset borrow fee and check borrow fee using asset borrow fee
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let borrow_fee_cap = ts::take_from_sender<BorrowFeeCap>(&s);

            // Set asset-specific rate to 2% (200 out of 10000) for SUI
            manage::set_asset_borrow_fee_rate(&borrow_fee_cap, &mut incentive_v3, ASSET_ID_SUI, 200, ts::ctx(&mut s));

            ts::return_shared(incentive_v3);
            ts::return_to_sender(&s, borrow_fee_cap);
        };

        // Verify asset-specific fee is applied
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);

            let amount = 100_000_000; // 100 units
            let fee = incentive_v3::get_borrow_fee_v2_for_testing(&mut incentive_v3, USER_1, ASSET_ID_SUI, amount);
            assert!(fee == 2_000_000, 0); // 2% of 100 = 2 (asset-specific overrides default)

            ts::return_shared(incentive_v3);
        };

        // Step 4 & 5: Set user borrow fee and check borrow fee using user borrow fee
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let borrow_fee_cap = ts::take_from_sender<BorrowFeeCap>(&s);

            // Set user-specific rate to 0.5% (50 out of 10000) for USER_1 on SUI
            manage::set_user_borrow_fee_rate(&borrow_fee_cap, &mut incentive_v3, USER_1, ASSET_ID_SUI, 50, ts::ctx(&mut s));

            ts::return_shared(incentive_v3);
            ts::return_to_sender(&s, borrow_fee_cap);
        };

        // Verify user-specific fee is applied (highest priority)
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);

            let amount = 100_000_000; // 100 units

            // USER_1 should use user-specific rate (0.5%)
            let fee_user1 = incentive_v3::get_borrow_fee_v2_for_testing(&mut incentive_v3, USER_1, ASSET_ID_SUI, amount);
            assert!(fee_user1 == 500_000, 0); // 0.5% of 100 = 0.5 (user-specific overrides asset-specific)

            // USER_2 should use asset-specific rate (2%) since no user-specific rate set
            let fee_user2 = incentive_v3::get_borrow_fee_v2_for_testing(&mut incentive_v3, USER_2, ASSET_ID_SUI, amount);
            assert!(fee_user2 == 2_000_000, 0); // 2% of 100 = 2

            ts::return_shared(incentive_v3);
        };

        // Step 6: Remove user borrow fee and check
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let borrow_fee_cap = ts::take_from_sender<BorrowFeeCap>(&s);

            // Remove user-specific rate
            manage::remove_incentive_v3_user_borrow_fee_rate(&borrow_fee_cap, &mut incentive_v3, USER_1, ASSET_ID_SUI, ts::ctx(&mut s));

            ts::return_shared(incentive_v3);
            ts::return_to_sender(&s, borrow_fee_cap);
        };

        // Verify user fee is removed, should fall back to asset-specific fee
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);

            let amount = 100_000_000; // 100 units
            let fee = incentive_v3::get_borrow_fee_v2_for_testing(&mut incentive_v3, USER_1, ASSET_ID_SUI, amount);
            assert!(fee == 2_000_000, 0); // 2% of 100 = 2 (falls back to asset-specific)

            ts::return_shared(incentive_v3);
        };

        // Step 7: Remove asset borrow fee and check
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let borrow_fee_cap = ts::take_from_sender<BorrowFeeCap>(&s);

            // Remove asset-specific rate
            manage::remove_incentive_v3_asset_borrow_fee_rate(&borrow_fee_cap, &mut incentive_v3, ASSET_ID_SUI, ts::ctx(&mut s));

            ts::return_shared(incentive_v3);
            ts::return_to_sender(&s, borrow_fee_cap);
        };

        // Verify asset fee is removed, should fall back to default fee
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);

            let amount = 100_000_000; // 100 units
            let fee = incentive_v3::get_borrow_fee_v2_for_testing(&mut incentive_v3, USER_1, ASSET_ID_SUI, amount);
            assert!(fee == 1_000_000, 0); // 1% of 100 = 1 (falls back to default)

            ts::return_shared(incentive_v3);
        };

        ts::end(s);
    }

    // Should remove asset-specific borrow fee rate and fall back to default rate
    #[test]
    public fun test_remove_asset_borrow_fee_rate() {
        let s = ts::begin(ADMIN);

        // Init storage
        ts::next_tx(&mut s, ADMIN);
        {
            storage::init_for_testing(ts::ctx(&mut s));
        };

        // Create IncentiveOwnerCap
        ts::next_tx(&mut s, ADMIN);
        {
            let storage_owner_cap = ts::take_from_sender<StorageOwnerCap>(&s);
            incentive_v2::create_and_transfer_owner(&storage_owner_cap, ts::ctx(&mut s));
            ts::return_to_sender(&s, storage_owner_cap);
        };

        // Create IncentiveV2 and V3
        create_incentive(&mut s);

        // Mint BorrowFeeCap
        ts::next_tx(&mut s, ADMIN);
        {
            let admin_cap = ts::take_from_sender<StorageAdminCap>(&s);
            manage::mint_borrow_fee_cap(&admin_cap, ADMIN, ts::ctx(&mut s));
            ts::return_to_sender(&s, admin_cap);
        };

        // Set default rate to 1% and asset-specific rate to 3%
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let borrow_fee_cap = ts::take_from_sender<BorrowFeeCap>(&s);

            manage::set_borrow_fee_rate(&borrow_fee_cap, &mut incentive_v3, 100, ts::ctx(&mut s)); // 1%
            manage::set_asset_borrow_fee_rate(&borrow_fee_cap, &mut incentive_v3, ASSET_ID_SUI, 300, ts::ctx(&mut s)); // 3%

            ts::return_shared(incentive_v3);
            ts::return_to_sender(&s, borrow_fee_cap);
        };

        // Verify asset-specific rate is applied (3%)
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let amount = 100_000_000; // 100 units

            let fee = incentive_v3::get_borrow_fee_v2_for_testing(&mut incentive_v3, USER_1, ASSET_ID_SUI, amount);
            assert!(fee == 3_000_000, 0); // 3% of 100 = 3

            ts::return_shared(incentive_v3);
        };

        // Remove asset-specific rate
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let borrow_fee_cap = ts::take_from_sender<BorrowFeeCap>(&s);

            manage::remove_incentive_v3_asset_borrow_fee_rate(&borrow_fee_cap, &mut incentive_v3, ASSET_ID_SUI, ts::ctx(&mut s));

            ts::return_shared(incentive_v3);
            ts::return_to_sender(&s, borrow_fee_cap);
        };

        // Verify it falls back to default rate (1%)
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let amount = 100_000_000; // 100 units

            let fee = incentive_v3::get_borrow_fee_v2_for_testing(&mut incentive_v3, USER_1, ASSET_ID_SUI, amount);
            assert!(fee == 1_000_000, 0); // Should fall back to 1%

            ts::return_shared(incentive_v3);
        };

        ts::end(s);
    }

    // Should remove user-specific borrow fee rate and fall back to asset or default rate
    #[test]
    public fun test_remove_user_borrow_fee_rate() {
        let s = ts::begin(ADMIN);

        // Init storage
        ts::next_tx(&mut s, ADMIN);
        {
            storage::init_for_testing(ts::ctx(&mut s));
        };

        // Create IncentiveOwnerCap
        ts::next_tx(&mut s, ADMIN);
        {
            let storage_owner_cap = ts::take_from_sender<StorageOwnerCap>(&s);
            incentive_v2::create_and_transfer_owner(&storage_owner_cap, ts::ctx(&mut s));
            ts::return_to_sender(&s, storage_owner_cap);
        };

        // Create IncentiveV2 and V3
        create_incentive(&mut s);

        // Mint BorrowFeeCap
        ts::next_tx(&mut s, ADMIN);
        {
            let admin_cap = ts::take_from_sender<StorageAdminCap>(&s);
            manage::mint_borrow_fee_cap(&admin_cap, ADMIN, ts::ctx(&mut s));
            ts::return_to_sender(&s, admin_cap);
        };

        // Set default 1%, asset-specific 2%, and user-specific 0.5%
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let borrow_fee_cap = ts::take_from_sender<BorrowFeeCap>(&s);

            manage::set_borrow_fee_rate(&borrow_fee_cap, &mut incentive_v3, 100, ts::ctx(&mut s)); // 1%
            manage::set_asset_borrow_fee_rate(&borrow_fee_cap, &mut incentive_v3, ASSET_ID_SUI, 200, ts::ctx(&mut s)); // 2%
            manage::set_user_borrow_fee_rate(&borrow_fee_cap, &mut incentive_v3, USER_1, ASSET_ID_SUI, 50, ts::ctx(&mut s)); // 0.5%

            ts::return_shared(incentive_v3);
            ts::return_to_sender(&s, borrow_fee_cap);
        };

        // Verify user-specific rate is applied (0.5%)
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let amount = 100_000_000; // 100 units

            let fee = incentive_v3::get_borrow_fee_v2_for_testing(&mut incentive_v3, USER_1, ASSET_ID_SUI, amount);
            assert!(fee == 500_000, 0); // 0.5% of 100 = 0.5

            ts::return_shared(incentive_v3);
        };

        // Remove user-specific rate
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let borrow_fee_cap = ts::take_from_sender<BorrowFeeCap>(&s);

            manage::remove_incentive_v3_user_borrow_fee_rate(&borrow_fee_cap, &mut incentive_v3, USER_1, ASSET_ID_SUI, ts::ctx(&mut s));

            ts::return_shared(incentive_v3);
            ts::return_to_sender(&s, borrow_fee_cap);
        };

        // Verify it falls back to asset-specific rate (2%)
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let amount = 100_000_000; // 100 units

            let fee = incentive_v3::get_borrow_fee_v2_for_testing(&mut incentive_v3, USER_1, ASSET_ID_SUI, amount);
            assert!(fee == 2_000_000, 0); // Should fall back to 2% (asset-specific)

            ts::return_shared(incentive_v3);
        };

        ts::end(s);
    }

    // Should update asset-specific fee rate when set twice for the same asset
    #[test]
    public fun test_set_asset_borrow_fee_rate_twice() {
        let s = ts::begin(ADMIN);

        // Init storage
        ts::next_tx(&mut s, ADMIN);
        {
            storage::init_for_testing(ts::ctx(&mut s));
        };

        // Create IncentiveOwnerCap
        ts::next_tx(&mut s, ADMIN);
        {
            let storage_owner_cap = ts::take_from_sender<StorageOwnerCap>(&s);
            incentive_v2::create_and_transfer_owner(&storage_owner_cap, ts::ctx(&mut s));
            ts::return_to_sender(&s, storage_owner_cap);
        };

        // Create IncentiveV2 and V3
        create_incentive(&mut s);

        // Mint BorrowFeeCap
        ts::next_tx(&mut s, ADMIN);
        {
            let admin_cap = ts::take_from_sender<StorageAdminCap>(&s);
            manage::mint_borrow_fee_cap(&admin_cap, ADMIN, ts::ctx(&mut s));
            ts::return_to_sender(&s, admin_cap);
        };

        // First set: Set asset-specific rate to 2% for SUI
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let borrow_fee_cap = ts::take_from_sender<BorrowFeeCap>(&s);

            manage::set_asset_borrow_fee_rate(&borrow_fee_cap, &mut incentive_v3, ASSET_ID_SUI, 200, ts::ctx(&mut s)); // 2%

            ts::return_shared(incentive_v3);
            ts::return_to_sender(&s, borrow_fee_cap);
        };

        // Verify first rate is applied (2%)
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let amount = 100_000_000; // 100 units

            let fee = incentive_v3::get_borrow_fee_v2_for_testing(&mut incentive_v3, USER_1, ASSET_ID_SUI, amount);
            assert!(fee == 2_000_000, 0); // 2% of 100 = 2

            ts::return_shared(incentive_v3);
        };

        // Second set: Update asset-specific rate to 5% for the same asset
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let borrow_fee_cap = ts::take_from_sender<BorrowFeeCap>(&s);

            manage::set_asset_borrow_fee_rate(&borrow_fee_cap, &mut incentive_v3, ASSET_ID_SUI, 500, ts::ctx(&mut s)); // 5%

            ts::return_shared(incentive_v3);
            ts::return_to_sender(&s, borrow_fee_cap);
        };

        // Verify the rate is updated to the new value (5%)
        ts::next_tx(&mut s, ADMIN);
        {
            let incentive_v3 = ts::take_shared<IncentiveV3>(&s);
            let amount = 100_000_000; // 100 units

            let fee = incentive_v3::get_borrow_fee_v2_for_testing(&mut incentive_v3, USER_1, ASSET_ID_SUI, amount);
            assert!(fee == 5_000_000, 0); // Should use updated 5%, not old 2%

            ts::return_shared(incentive_v3);
        };

        ts::end(s);
    }
}
