#[test_only]
module lending_core::account_test {
    use sui::clock;
    use sui::coin::{Self};
    use sui::test_scenario::{Self};

    use lending_core::base;
    use lending_core::storage::{Self, Storage};
    use lending_core::pool::{Self, Pool};
    use lending_core::sui_test::{SUI_TEST};
    use lending_core::base_lending_tests::{Self};
    use lending_core::account::{Self, AccountCap};
    
    const OWNER: address = @0xA;
    const OWNER2: address = @0xA;

    #[test]
    public fun test_deposit_with_account() {
        let scenario = test_scenario::begin(OWNER);
        let scenario2 = test_scenario::begin(OWNER2);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            base_lending_tests::create_account_cap_for_testing(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let account_cap = test_scenario::take_from_sender<AccountCap>(&scenario);
            let account_owner = account::account_owner(&account_cap);
            assert!(account_owner != OWNER, 0);

            {
                let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
                let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
                let coin = coin::mint_for_testing<SUI_TEST>(100_000000000, test_scenario::ctx(&mut scenario));

                base_lending_tests::base_deposit_with_account_for_testing(&mut scenario, &clock, &mut pool, coin, 0, &account_cap);

                let (total_supply, _, _) = pool::get_pool_info(&pool);
                assert!(total_supply == 100_000000000, 0);

                clock::destroy_for_testing(clock);
                test_scenario::return_shared(pool);
                
            };
            test_scenario::return_to_sender(&scenario, account_cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let account_cap = test_scenario::take_from_sender<AccountCap>(&scenario);
            let account_owner = account::account_owner(&account_cap);
            let storage = test_scenario::take_shared<Storage>(&scenario);

            let (owner_supply_balance, owner_borrow_balance) = storage::get_user_balance(&mut storage, 0, OWNER);
            assert!(owner_supply_balance == 0, 0);
            assert!(owner_borrow_balance == 0, 0);

            let (account_supply_balance, account_borrow_balance) = storage::get_user_balance(&mut storage, 0, account_owner);
            assert!(account_supply_balance == 100_000000000, 0);
            assert!(account_borrow_balance == 0, 0);

            test_scenario::return_shared(storage);
            test_scenario::return_to_sender(&scenario, account_cap);
        };

        // Unable to verify everyone
        // The RPC Will Got: {"code":-32002,"message":"Transaction execution failed due to issues with transaction inputs, please review the errors and try again: Transaction was not signed by the correct sender: Object ${account_cap} is owned by account address ${OWNER}, but given owner/signer address is ${OWNER2}."}
        test_scenario::next_tx(&mut scenario2, OWNER2);
        {
            let account_cap = test_scenario::take_from_sender<AccountCap>(&scenario);
            let account_owner = account::account_owner(&account_cap);
            assert!(account_owner != OWNER, 0);
            {
                let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario2);
                let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario2));
                let coin = coin::mint_for_testing<SUI_TEST>(100_000000000, test_scenario::ctx(&mut scenario2));

                base_lending_tests::base_deposit_with_account_for_testing(&mut scenario2, &clock, &mut pool, coin, 0, &account_cap);

                let (total_supply, _, _) = pool::get_pool_info(&pool);
                assert!(total_supply == 200_000000000, 0);

                clock::destroy_for_testing(clock);
                test_scenario::return_shared(pool);
                
            };
            test_scenario::return_to_sender(&scenario, account_cap);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
        test_scenario::end(scenario2);
    }

    #[test]
    public fun test_borrow_with_account() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };
        
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            base_lending_tests::create_account_cap_for_testing(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let account_cap = test_scenario::take_from_sender<AccountCap>(&scenario);
            let account_owner = account::account_owner(&account_cap);
            assert!(account_owner != OWNER, 0);

            {
                let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
                let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
                let coin = coin::mint_for_testing<SUI_TEST>(100_000000000, test_scenario::ctx(&mut scenario));

                base_lending_tests::base_deposit_with_account_for_testing(&mut scenario, &clock, &mut pool, coin, 0, &account_cap);

                let (total_supply, _, _) = pool::get_pool_info(&pool);
                assert!(total_supply == 100_000000000, 0);

                clock::destroy_for_testing(clock);
                test_scenario::return_shared(pool);
                
            };
            test_scenario::return_to_sender(&scenario, account_cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let account_cap = test_scenario::take_from_sender<AccountCap>(&scenario);
            let account_owner = account::account_owner(&account_cap);
            assert!(account_owner != OWNER, 0);

            {
                let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
                let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

                base_lending_tests::base_borrow_with_account_for_testing(&mut scenario, &clock, &mut pool, 0, 10_000000000, &account_cap);
                let (total_supply, _, _) = pool::get_pool_info(&pool);
                assert!(total_supply == 90_000000000, 0);

                clock::destroy_for_testing(clock);
                test_scenario::return_shared(pool);
            };
            test_scenario::return_to_sender(&scenario, account_cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let account_cap = test_scenario::take_from_sender<AccountCap>(&scenario);
            let account_owner = account::account_owner(&account_cap);
            let storage = test_scenario::take_shared<Storage>(&scenario);

            let (owner_supply_balance, owner_borrow_balance) = storage::get_user_balance(&mut storage, 0, OWNER);
            assert!(owner_supply_balance == 0, 0);
            assert!(owner_borrow_balance == 0, 0);

            let (account_supply_balance, account_borrow_balance) = storage::get_user_balance(&mut storage, 0, account_owner);
            assert!(account_supply_balance == 100_000000000, 0);
            assert!(account_borrow_balance == 10_000000000, 0);
            test_scenario::return_shared(storage);
            test_scenario::return_to_sender(&scenario, account_cap);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }


    #[test] // deposit -> withdraw
    public fun test_withdraw_with_account() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            base_lending_tests::create_account_cap_for_testing(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let account_cap = test_scenario::take_from_sender<AccountCap>(&scenario);
            let account_owner = account::account_owner(&account_cap);
            assert!(account_owner != OWNER, 0);

            {
                let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
                let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
                let coin = coin::mint_for_testing<SUI_TEST>(100_000000000, test_scenario::ctx(&mut scenario));

                base_lending_tests::base_deposit_with_account_for_testing(&mut scenario, &clock, &mut pool, coin, 0, &account_cap);

                let (total_supply, _, _) = pool::get_pool_info(&pool);
                assert!(total_supply == 100_000000000, 0);

                clock::destroy_for_testing(clock);
                test_scenario::return_shared(pool);
                
            };
            test_scenario::return_to_sender(&scenario, account_cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let account_cap = test_scenario::take_from_sender<AccountCap>(&scenario);
            let account_owner = account::account_owner(&account_cap);
            assert!(account_owner != OWNER, 0);

            {
                let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
                let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
                base_lending_tests::base_withdraw_with_account_for_testing(&mut scenario, &clock, &mut pool, 0, 100_000000000, &account_cap);

                // validation
                let (total_supply, _, _) = pool::get_pool_info<SUI_TEST>(&pool);
                assert!(total_supply == 0, 0);

                clock::destroy_for_testing(clock);
                test_scenario::return_shared(pool);
            };
            test_scenario::return_to_sender(&scenario, account_cap);
        };
        
        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_repay_with_account() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            base_lending_tests::create_account_cap_for_testing(&mut scenario);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let account_cap = test_scenario::take_from_sender<AccountCap>(&scenario);
            let account_owner = account::account_owner(&account_cap);
            assert!(account_owner != OWNER, 0);

            {
                let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
                let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
                let coin = coin::mint_for_testing<SUI_TEST>(100_000000000, test_scenario::ctx(&mut scenario));

                base_lending_tests::base_deposit_with_account_for_testing(&mut scenario, &clock, &mut pool, coin, 0, &account_cap);

                let (total_supply, _, _) = pool::get_pool_info(&pool);
                assert!(total_supply == 100_000000000, 0);

                clock::destroy_for_testing(clock);
                test_scenario::return_shared(pool);
                
            };
            test_scenario::return_to_sender(&scenario, account_cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let account_cap = test_scenario::take_from_sender<AccountCap>(&scenario);
            let account_owner = account::account_owner(&account_cap);
            assert!(account_owner != OWNER, 0);

            {
                let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
                let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

                base_lending_tests::base_borrow_with_account_for_testing(&mut scenario, &clock, &mut pool, 0, 10_000000000, &account_cap);
                let (total_supply, _, _) = pool::get_pool_info(&pool);
                assert!(total_supply == 90_000000000, 0);

                clock::destroy_for_testing(clock);
                test_scenario::return_shared(pool);
            };
            test_scenario::return_to_sender(&scenario, account_cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let account_cap = test_scenario::take_from_sender<AccountCap>(&scenario);
            let account_owner = account::account_owner(&account_cap);
            assert!(account_owner != OWNER, 0);

            {
                let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
                let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
                let coin = coin::mint_for_testing<SUI_TEST>(1_000000000, test_scenario::ctx(&mut scenario));

                base_lending_tests::base_repay_with_account_for_testing(&mut scenario, &clock, &mut pool, coin, 0, &account_cap);

                clock::destroy_for_testing(clock);
                test_scenario::return_shared(pool);
            };
            test_scenario::return_to_sender(&scenario, account_cap);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }
}
