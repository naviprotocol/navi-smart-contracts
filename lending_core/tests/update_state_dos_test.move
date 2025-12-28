module lending_core::update_state_dos_test {
    use sui::tx_context::{Self, TxContext};
    use sui::clock::{Self, Clock};
    use sui::object::UID;

    use lending_core::storage::{Self, Storage};
    use lending_core::storage::{Self};
    use lending_core::pool::{Self, Pool};
    use lending_core::lending::{Self};

    #[test_only]
    fun setup_storage(ctx: &mut TxContext): Storage {
        let storage = storage::init_for_testing(ctx);
        storage
    }

    /// This test demonstrates two things:
    /// 1) `update_state_of_all` is invoked as part of deposit/borrow/withdraw/repay via the `execute_*` family
    /// 2) `update_state_of_all` loops through ALL reserves (no early break), so its cost grows linearly with number of reserves
    fun prove_update_state_iterations_for_n(clock: &mut Clock, ctx: &mut TxContext, n: u8) {
        let mut storage = setup_storage(ctx);

        // create many reserves
        let pool_admin_cap = lending_core::pool::init_for_testing(ctx); // placeholder: pool creation is side-effecty in tests

        // initialize n reserves for the test; we use the test-only init_reserve without metadata
        let mut i: u8 = 0;
        while (i < n) {
            storage::init_reserve_without_metadata_for_testing(&mut storage, &pool_admin_cap, clock, i, false, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9, ctx);
            i = i + 1;
        };

        // Set each reserve's last_update_timestamp to an old value (0)
        let mut j: u8 = 0;
        while (j < n) {
            // update index so that last_update_timestamp becomes old
            storage::update_state_for_testing(&mut storage, j, 0, 0, 1u64, 0);
            j = j + 1;
        };

        // call execute_deposit_for_testing on a specific asset (0) which will call update_state_of_all
        logic::execute_deposit_for_testing<u8>(clock, &mut storage, 0u8, @0x1, 1);

        // After execute_deposit_for_testing, every reserve's last_update_timestamp should be updated to now (> 1)
        let mut k: u8 = 0;
        while (k < n) {
            let ts = storage::get_last_update_timestamp(&storage, k);
            assert!(ts > 1, 100u64);
            k = k + 1;
        };
    }

    #[test_only]
    fun prove_update_state_iterations_10(clock: &mut Clock, ctx: &mut TxContext) {
        prove_update_state_iterations_for_n(clock, ctx, 10u8);
    }

    #[test_only]
    fun prove_update_state_iterations_100(clock: &mut Clock, ctx: &mut TxContext) {
        prove_update_state_iterations_for_n(clock, ctx, 100u8);
    }

    #[test_only]
    fun prove_update_state_iterations_255(clock: &mut Clock, ctx: &mut TxContext) {
        prove_update_state_iterations_for_n(clock, ctx, 255u8);
    }
}