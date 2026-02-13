#[test_only]
module lending_core::flash_loan_test {
    use sui::clock::{Self, Clock};
    use sui::object;
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::balance::{Self};
    use sui::test_scenario::{Self, Scenario};
    use oracle::oracle::{Self, PriceOracle, OracleFeederCap};

    use lending_core::base;
    use lending_core::storage::{Self, Storage, StorageAdminCap};
    use lending_core::pool::{Self, Pool};
    use lending_core::sui_test::{SUI_TEST};
    use lending_core::usdc_test::{USDC_TEST};
    use lending_core::base_lending_tests::{Self};
    use lending_core::account::{Self, AccountCap};
    use lending_core::lending::{Self};
    use lending_core::manage::{Self};
    use lending_core::flash_loan::{Self, Config as FlashLoanConfig};

    use lending_core::ray_math;
    use lending_core::calculator;
    use lending_core::logic::{Self};

    const OWNER: address = @0xA;
    const OWNER2: address = @0xB;
    const UserA: address = @0xA;
    const UserB: address = @0xB;
    const UserC: address = @0xC;

    #[test]
    #[expected_failure(abort_code = 1503, location = lending_core::flash_loan)]
    public fun test_flash_loan_with_account_cap() {
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
                let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
                let sui_coin = coin::mint_for_testing<SUI_TEST>(10000_000000000, test_scenario::ctx(&mut scenario));

                base_lending_tests::base_deposit_with_account_for_testing(&mut scenario, &_clock, &mut sui_pool, sui_coin, 0, &account_cap);

                let (total_supply, _, _) = pool::get_pool_info(&sui_pool);
                assert!(total_supply == 10000_000000000, 0);

                test_scenario::return_shared(sui_pool);
            };
            test_scenario::return_to_sender(&scenario, account_cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let account_cap = test_scenario::take_from_sender<AccountCap>(&scenario);
            let account_owner = account::account_owner(&account_cap);
            assert!(account_owner != OWNER, 0);

            {
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);
                let usdc_coin = coin::mint_for_testing<USDC_TEST>(10000_000000, test_scenario::ctx(&mut scenario));

                base_lending_tests::base_deposit_with_account_for_testing(&mut scenario, &_clock, &mut usdc_pool, usdc_coin, 1, &account_cap);

                let (total_supply, _, _) = pool::get_pool_info(&usdc_pool);
                assert!(total_supply == 10000_000000, 0);

                test_scenario::return_shared(usdc_pool);
            };
            test_scenario::return_to_sender(&scenario, account_cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let account_cap = test_scenario::take_from_sender<AccountCap>(&scenario);
            let account_owner = account::account_owner(&account_cap);
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);


            let loan_amount = 100_000000000;
            let (loan_balance, receipt) = lending::flash_loan_with_account_cap<SUI_TEST>(&flash_loan_config, &mut sui_pool, loan_amount, &account_cap);
            assert!(balance::value(&loan_balance) == loan_amount, 0);
            
            let (user, _, amount, pool, fee_to_supplier, fee_to_treasury) = flash_loan::parsed_receipt<SUI_TEST>(&receipt);
            assert!(user == account_owner, 0);
            assert!(amount == loan_amount, 0);
            assert!(pool == object::uid_to_address(pool::uid(&sui_pool)), 0);

            {
                // When you borrow money, you can do whatever you want!!!
                // call another module::function()...

                // When you pay back the money, you should add interest!!!
                let coin = coin::mint_for_testing<SUI_TEST>(fee_to_supplier + fee_to_treasury, test_scenario::ctx(&mut scenario));
                let total_fee = coin::into_balance(coin);
                balance::join(&mut loan_balance, total_fee);
            };

            let _excess_balance = lending::flash_repay_with_account_cap<SUI_TEST>(&_clock, &mut storage, &mut sui_pool, receipt, loan_balance, &account_cap);

            if (balance::value(&_excess_balance) == 0) {
                balance::destroy_zero(_excess_balance)
            } else {
                let _coin = coin::from_balance(_excess_balance, test_scenario::ctx(&mut scenario));
                transfer::public_transfer(_coin, test_scenario::sender(&scenario));
            };

            test_scenario::return_shared(storage);
            test_scenario::return_to_sender(&scenario, account_cap);
            test_scenario::return_shared(sui_pool);
            test_scenario::return_shared(flash_loan_config);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let account_cap = test_scenario::take_from_sender<AccountCap>(&scenario);
            let account_owner = account::account_owner(&account_cap);
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);

            let loan_amount_sui = 100_000000000;
            let (loan_balance_sui, receipt_sui) = lending::flash_loan_with_account_cap<SUI_TEST>(&flash_loan_config, &mut sui_pool, loan_amount_sui, &account_cap);
            assert!(balance::value(&loan_balance_sui) == loan_amount_sui, 0);
            let (user1, _, amount_sui, sui_pool_address, fee_to_supplier_sui, fee_to_treasury_sui) = flash_loan::parsed_receipt<SUI_TEST>(&receipt_sui);
            assert!(user1 == account_owner, 0);
            assert!(amount_sui == loan_amount_sui, 0);
            assert!(sui_pool_address == object::uid_to_address(pool::uid(&sui_pool)), 0);

            let loan_amount_usdc = 100_000000;
            let (loan_balance_usdc, receipt_usdc) = lending::flash_loan_with_account_cap<USDC_TEST>(&flash_loan_config, &mut usdc_pool, loan_amount_usdc, &account_cap);
            assert!(balance::value(&loan_balance_usdc) == loan_amount_usdc, 0);
            let (user2, _, amount_usdc, usdc_pool_address, fee_to_supplier_usdc, fee_to_treasury_usdc) = flash_loan::parsed_receipt<USDC_TEST>(&receipt_usdc);
            assert!(user2 == account_owner, 0);
            assert!(amount_usdc == loan_amount_usdc, 0);
            assert!(usdc_pool_address == object::uid_to_address(pool::uid(&usdc_pool)), 0);

            {
                let coin = coin::mint_for_testing<SUI_TEST>(fee_to_supplier_sui + fee_to_treasury_sui, test_scenario::ctx(&mut scenario));
                let total_fee = coin::into_balance(coin);
                balance::join(&mut loan_balance_sui, total_fee);
                assert!(balance::value(&loan_balance_sui)==amount_sui + fee_to_supplier_sui + fee_to_treasury_sui, 0);
            };

            {
                let coin = coin::mint_for_testing<USDC_TEST>(fee_to_supplier_usdc + fee_to_treasury_usdc, test_scenario::ctx(&mut scenario));
                let total_fee = coin::into_balance(coin);
                balance::join(&mut loan_balance_usdc, total_fee);
                assert!(balance::value(&loan_balance_usdc)==amount_usdc + fee_to_supplier_usdc + fee_to_treasury_usdc, 0);
            };

            let _excess_balance1 = lending::flash_repay_with_account_cap<SUI_TEST>(&_clock, &mut storage, &mut sui_pool, receipt_sui, loan_balance_sui, &account_cap);
            if (balance::value(&_excess_balance1) == 0) {
                balance::destroy_zero(_excess_balance1)
            } else {
                let _coin = coin::from_balance(_excess_balance1, test_scenario::ctx(&mut scenario));
                transfer::public_transfer(_coin, test_scenario::sender(&scenario));
            };

            let _excess_balance2 = lending::flash_repay_with_account_cap<USDC_TEST>(&_clock, &mut storage, &mut usdc_pool, receipt_usdc, loan_balance_usdc, &account_cap);
            if (balance::value(&_excess_balance2) == 0) {
                balance::destroy_zero(_excess_balance2)
            } else {
                let _coin = coin::from_balance(_excess_balance2, test_scenario::ctx(&mut scenario));
                transfer::public_transfer(_coin, test_scenario::sender(&scenario));
            };

            test_scenario::return_shared(storage);
            test_scenario::return_to_sender(&scenario, account_cap);
            test_scenario::return_shared(sui_pool);
            test_scenario::return_shared(usdc_pool);
            test_scenario::return_shared(flash_loan_config);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let account_cap = test_scenario::take_from_sender<AccountCap>(&scenario);
            let account_owner = account::account_owner(&account_cap);
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

            let loan_amount_sui = 100_000000000;
            let (loan_balance_sui, receipt_sui) = lending::flash_loan_with_account_cap<SUI_TEST>(&flash_loan_config, &mut sui_pool, loan_amount_sui, &account_cap);
            assert!(balance::value(&loan_balance_sui) == loan_amount_sui, 0);
            let (user1, _, amount_sui, sui_pool_address, fee_to_supplier_sui, fee_to_treasury_sui) = flash_loan::parsed_receipt<SUI_TEST>(&receipt_sui);
            assert!(user1 == account_owner, 0);
            assert!(amount_sui == loan_amount_sui, 0);
            assert!(sui_pool_address == object::uid_to_address(pool::uid(&sui_pool)), 0);

            let loan_amount_sui2 = 1000_000000000;
            let (loan_balance_sui2, receipt_sui2) = lending::flash_loan_with_account_cap<SUI_TEST>(&flash_loan_config, &mut sui_pool, loan_amount_sui2, &account_cap);
            assert!(balance::value(&loan_balance_sui2) == loan_amount_sui2, 0);
            let (user2, _, amount_sui2, sui_pool_address2, fee_to_supplier_sui2, fee_to_treasury_sui2) = flash_loan::parsed_receipt<SUI_TEST>(&receipt_sui2);
            assert!(user2 == account_owner, 0);
            assert!(amount_sui == loan_amount_sui, 0);
            assert!(sui_pool_address2 == object::uid_to_address(pool::uid(&sui_pool)), 0);

            {
                let coin = coin::mint_for_testing<SUI_TEST>(fee_to_supplier_sui + fee_to_treasury_sui, test_scenario::ctx(&mut scenario));
                let total_fee = coin::into_balance(coin);
                balance::join(&mut loan_balance_sui, total_fee);
                assert!(balance::value(&loan_balance_sui)==amount_sui + fee_to_supplier_sui + fee_to_treasury_sui, 0);
            };

            {
                let coin = coin::mint_for_testing<SUI_TEST>(fee_to_supplier_sui2 + fee_to_treasury_sui2, test_scenario::ctx(&mut scenario));
                let total_fee = coin::into_balance(coin);
                balance::join(&mut loan_balance_sui2, total_fee);
                assert!(balance::value(&loan_balance_sui2)==amount_sui2 + fee_to_supplier_sui2 + fee_to_treasury_sui2, 0);
            };

            let _excess_balance1 = lending::flash_repay_with_account_cap<SUI_TEST>(&_clock, &mut storage, &mut sui_pool, receipt_sui, loan_balance_sui, &account_cap);
            if (balance::value(&_excess_balance1) == 0) {
                balance::destroy_zero(_excess_balance1)
            } else {
                let _coin = coin::from_balance(_excess_balance1, test_scenario::ctx(&mut scenario));
                transfer::public_transfer(_coin, test_scenario::sender(&scenario));
            };

            let _excess_balance2 = lending::flash_repay_with_account_cap<SUI_TEST>(&_clock, &mut storage, &mut sui_pool, receipt_sui2, loan_balance_sui2, &account_cap);
            if (balance::value(&_excess_balance2) == 0) {
                balance::destroy_zero(_excess_balance2)
            } else {
                let _coin = coin::from_balance(_excess_balance2, test_scenario::ctx(&mut scenario));
                transfer::public_transfer(_coin, test_scenario::sender(&scenario));
            };

            test_scenario::return_shared(storage);
            test_scenario::return_to_sender(&scenario, account_cap);
            test_scenario::return_shared(sui_pool);
            test_scenario::return_shared(flash_loan_config);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let account_cap = test_scenario::take_from_sender<AccountCap>(&scenario);
            let account_owner = account::account_owner(&account_cap);
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

            let loan_amount = 100_000000000;
            let (loan_balance, receipt) = lending::flash_loan_with_account_cap<SUI_TEST>(&flash_loan_config, &mut sui_pool, loan_amount, &account_cap);
            assert!(balance::value(&loan_balance) == loan_amount, 0);
            
            let (user, _, amount, pool, _, _) = flash_loan::parsed_receipt<SUI_TEST>(&receipt);
            assert!(user == account_owner, 0);
            assert!(amount == loan_amount, 0);
            assert!(pool == object::uid_to_address(pool::uid(&sui_pool)), 0);

            let _excess_balance = lending::flash_repay_with_account_cap<SUI_TEST>(&_clock, &mut storage, &mut sui_pool, receipt, loan_balance, &account_cap);

            if (balance::value(&_excess_balance) == 0) {
                balance::destroy_zero(_excess_balance)
            } else {
                let _coin = coin::from_balance(_excess_balance, test_scenario::ctx(&mut scenario));
                transfer::public_transfer(_coin, test_scenario::sender(&scenario));
            };

            test_scenario::return_shared(storage);
            test_scenario::return_to_sender(&scenario, account_cap);
            test_scenario::return_shared(sui_pool);
            test_scenario::return_shared(flash_loan_config);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
        test_scenario::end(scenario2);
    }

    #[test]
    #[expected_failure(abort_code = 1503, location = lending_core::flash_loan)]
    public fun test_flash_loan_with_ctx() {
        let scenario = test_scenario::begin(OWNER);
        let scenario2 = test_scenario::begin(OWNER2);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            let sui_coin = coin::mint_for_testing<SUI_TEST>(1000000_000000000, test_scenario::ctx(&mut scenario));

            base_lending_tests::base_deposit_for_testing(&mut scenario, &clock, &mut sui_pool, sui_coin, 0, 1000000_000000000);

            let (total_supply, _, _) = pool::get_pool_info(&sui_pool);
            assert!(total_supply == 1000000_000000000, 0);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(sui_pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            let usdc_coin = coin::mint_for_testing<USDC_TEST>(10000_000000, test_scenario::ctx(&mut scenario));

            base_lending_tests::base_deposit_for_testing(&mut scenario, &clock, &mut usdc_pool, usdc_coin, 1, 10000_000000);

            let (total_supply, _, _) = pool::get_pool_info(&usdc_pool);
            assert!(total_supply == 10000_000000, 0);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(usdc_pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

            let loan_amount = 100_000000000;
            let (loan_balance, receipt) = lending::flash_loan_with_ctx<SUI_TEST>(&flash_loan_config, &mut sui_pool, loan_amount, test_scenario::ctx(&mut scenario));
            assert!(balance::value(&loan_balance) == loan_amount, 0);
            
            let (user, _, amount, pool, fee_to_supplier, fee_to_treasury) = flash_loan::parsed_receipt<SUI_TEST>(&receipt);
            assert!(user == test_scenario::sender(&scenario), 0);
            assert!(amount == loan_amount, 0);
            assert!(pool == object::uid_to_address(pool::uid(&sui_pool)), 0);

            {
                // When you borrow money, you can do whatever you want!!!
                // call another module::function()...

                // When you pay back the money, you should add interest!!!
                let coin = coin::mint_for_testing<SUI_TEST>(fee_to_supplier + fee_to_treasury, test_scenario::ctx(&mut scenario));
                let total_fee = coin::into_balance(coin);
                balance::join(&mut loan_balance, total_fee);
            };

            let _excess_balance = lending::flash_repay_with_ctx<SUI_TEST>(&_clock, &mut storage, &mut sui_pool, receipt, loan_balance, test_scenario::ctx(&mut scenario));

            if (balance::value(&_excess_balance) == 0) {
                balance::destroy_zero(_excess_balance)
            } else {
                let _coin = coin::from_balance(_excess_balance, test_scenario::ctx(&mut scenario));
                transfer::public_transfer(_coin, test_scenario::sender(&scenario));
            };

            test_scenario::return_shared(storage);
            test_scenario::return_shared(sui_pool);
            test_scenario::return_shared(flash_loan_config);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);

            let loan_amount_sui = 100_000000000;
            let (loan_balance_sui, receipt_sui) = lending::flash_loan_with_ctx<SUI_TEST>(&flash_loan_config, &mut sui_pool, loan_amount_sui, test_scenario::ctx(&mut scenario));
            assert!(balance::value(&loan_balance_sui) == loan_amount_sui, 0);
            let (user1, _, amount_sui, sui_pool_address, fee_to_supplier_sui, fee_to_treasury_sui) = flash_loan::parsed_receipt<SUI_TEST>(&receipt_sui);
            assert!(user1 == test_scenario::sender(&scenario), 0);
            assert!(amount_sui == loan_amount_sui, 0);
            assert!(sui_pool_address == object::uid_to_address(pool::uid(&sui_pool)), 0);

            let loan_amount_usdc = 100_000000;
            let (loan_balance_usdc, receipt_usdc) = lending::flash_loan_with_ctx<USDC_TEST>(&flash_loan_config, &mut usdc_pool, loan_amount_usdc, test_scenario::ctx(&mut scenario));
            assert!(balance::value(&loan_balance_usdc) == loan_amount_usdc, 0);
            let (user2, _, amount_usdc, usdc_pool_address, fee_to_supplier_usdc, fee_to_treasury_usdc) = flash_loan::parsed_receipt<USDC_TEST>(&receipt_usdc);
            assert!(user2 == test_scenario::sender(&scenario), 0);
            assert!(amount_usdc == loan_amount_usdc, 0);
            assert!(usdc_pool_address == object::uid_to_address(pool::uid(&usdc_pool)), 0);

            {
                let coin = coin::mint_for_testing<SUI_TEST>(fee_to_supplier_sui + fee_to_treasury_sui, test_scenario::ctx(&mut scenario));
                let total_fee = coin::into_balance(coin);
                balance::join(&mut loan_balance_sui, total_fee);
                assert!(balance::value(&loan_balance_sui)==amount_sui + fee_to_supplier_sui + fee_to_treasury_sui, 0);
            };

            {
                let coin = coin::mint_for_testing<USDC_TEST>(fee_to_supplier_usdc + fee_to_treasury_usdc, test_scenario::ctx(&mut scenario));
                let total_fee = coin::into_balance(coin);
                balance::join(&mut loan_balance_usdc, total_fee);
                assert!(balance::value(&loan_balance_usdc)==amount_usdc + fee_to_supplier_usdc + fee_to_treasury_usdc, 0);
            };

            let _excess_balance1 = lending::flash_repay_with_ctx<SUI_TEST>(&_clock, &mut storage, &mut sui_pool, receipt_sui, loan_balance_sui, test_scenario::ctx(&mut scenario));
            if (balance::value(&_excess_balance1) == 0) {
                balance::destroy_zero(_excess_balance1)
            } else {
                let _coin = coin::from_balance(_excess_balance1, test_scenario::ctx(&mut scenario));
                transfer::public_transfer(_coin, test_scenario::sender(&scenario));
            };

            let _excess_balance2 = lending::flash_repay_with_ctx<USDC_TEST>(&_clock, &mut storage, &mut usdc_pool, receipt_usdc, loan_balance_usdc, test_scenario::ctx(&mut scenario));
            if (balance::value(&_excess_balance2) == 0) {
                balance::destroy_zero(_excess_balance2)
            } else {
                let _coin = coin::from_balance(_excess_balance2, test_scenario::ctx(&mut scenario));
                transfer::public_transfer(_coin, test_scenario::sender(&scenario));
            };

            test_scenario::return_shared(storage);
            test_scenario::return_shared(sui_pool);
            test_scenario::return_shared(usdc_pool);
            test_scenario::return_shared(flash_loan_config);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

            let loan_amount_sui = 100_000000000;
            let (loan_balance_sui, receipt_sui) = lending::flash_loan_with_ctx<SUI_TEST>(&flash_loan_config, &mut sui_pool, loan_amount_sui, test_scenario::ctx(&mut scenario));
            assert!(balance::value(&loan_balance_sui) == loan_amount_sui, 0);
            let (user1, _, amount_sui, sui_pool_address, fee_to_supplier_sui, fee_to_treasury_sui) = flash_loan::parsed_receipt<SUI_TEST>(&receipt_sui);
            assert!(user1 == test_scenario::sender(&scenario), 0);
            assert!(amount_sui == loan_amount_sui, 0);
            assert!(sui_pool_address == object::uid_to_address(pool::uid(&sui_pool)), 0);

            let loan_amount_sui2 = 1000_000000000;
            let (loan_balance_sui2, receipt_sui2) = lending::flash_loan_with_ctx<SUI_TEST>(&flash_loan_config, &mut sui_pool, loan_amount_sui2, test_scenario::ctx(&mut scenario));
            assert!(balance::value(&loan_balance_sui2) == loan_amount_sui2, 0);
            let (user2, _, amount_sui2, sui_pool_address2, fee_to_supplier_sui2, fee_to_treasury_sui2) = flash_loan::parsed_receipt<SUI_TEST>(&receipt_sui2);
            assert!(user2 == test_scenario::sender(&scenario), 0);
            assert!(amount_sui == loan_amount_sui, 0);
            assert!(sui_pool_address2 == object::uid_to_address(pool::uid(&sui_pool)), 0);

            {
                let coin = coin::mint_for_testing<SUI_TEST>(fee_to_supplier_sui + fee_to_treasury_sui, test_scenario::ctx(&mut scenario));
                let total_fee = coin::into_balance(coin);
                balance::join(&mut loan_balance_sui, total_fee);
                assert!(balance::value(&loan_balance_sui)==amount_sui + fee_to_supplier_sui + fee_to_treasury_sui, 0);
            };

            {
                let coin = coin::mint_for_testing<SUI_TEST>(fee_to_supplier_sui2 + fee_to_treasury_sui2, test_scenario::ctx(&mut scenario));
                let total_fee = coin::into_balance(coin);
                balance::join(&mut loan_balance_sui2, total_fee);
                assert!(balance::value(&loan_balance_sui2)==amount_sui2 + fee_to_supplier_sui2 + fee_to_treasury_sui2, 0);
            };

            let _excess_balance1 = lending::flash_repay_with_ctx<SUI_TEST>(&_clock, &mut storage, &mut sui_pool, receipt_sui, loan_balance_sui, test_scenario::ctx(&mut scenario));
            if (balance::value(&_excess_balance1) == 0) {
                balance::destroy_zero(_excess_balance1)
            } else {
                let _coin = coin::from_balance(_excess_balance1, test_scenario::ctx(&mut scenario));
                transfer::public_transfer(_coin, test_scenario::sender(&scenario));
            };

            let _excess_balance2 = lending::flash_repay_with_ctx<SUI_TEST>(&_clock, &mut storage, &mut sui_pool, receipt_sui2, loan_balance_sui2, test_scenario::ctx(&mut scenario));
            if (balance::value(&_excess_balance2) == 0) {
                balance::destroy_zero(_excess_balance2)
            } else {
                let _coin = coin::from_balance(_excess_balance2, test_scenario::ctx(&mut scenario));
                transfer::public_transfer(_coin, test_scenario::sender(&scenario));
            };

            test_scenario::return_shared(storage);
            test_scenario::return_shared(sui_pool);
            test_scenario::return_shared(flash_loan_config);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

            let loan_amount = 100_000000000;
            let (loan_balance, receipt) = lending::flash_loan_with_ctx<SUI_TEST>(&flash_loan_config, &mut sui_pool, loan_amount, test_scenario::ctx(&mut scenario));
            assert!(balance::value(&loan_balance) == loan_amount, 0);
            
            let (user, _, amount, pool, fee_to_supplier, fee_to_treasury) = flash_loan::parsed_receipt<SUI_TEST>(&receipt);
            assert!(user == test_scenario::sender(&scenario), 0);
            assert!(amount == loan_amount, 0);
            assert!(pool == object::uid_to_address(pool::uid(&sui_pool)), 0);

            let excess_amount = 9_000000000;
            {
                let coin = coin::mint_for_testing<SUI_TEST>(fee_to_supplier + fee_to_treasury + excess_amount, test_scenario::ctx(&mut scenario));
                let total_fee = coin::into_balance(coin);
                balance::join(&mut loan_balance, total_fee);
                assert!(balance::value(&loan_balance)==amount + fee_to_supplier + fee_to_treasury + excess_amount, 0);
            };

            let _excess_balance = lending::flash_repay_with_ctx<SUI_TEST>(&_clock, &mut storage, &mut sui_pool, receipt, loan_balance, test_scenario::ctx(&mut scenario));
            assert!(balance::value(&_excess_balance) == excess_amount, 0);
            if (balance::value(&_excess_balance) == 0) {
                balance::destroy_zero(_excess_balance)
            } else {
                let _coin = coin::from_balance(_excess_balance, test_scenario::ctx(&mut scenario));
                transfer::public_transfer(_coin, test_scenario::sender(&scenario));
            };

            test_scenario::return_shared(storage);
            test_scenario::return_shared(sui_pool);
            test_scenario::return_shared(flash_loan_config);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

            let (_,_,_,_,_,_,max,_) = flash_loan::get_asset<SUI_TEST>(&flash_loan_config);
            let loan_amount = max + 1;
            let (loan_balance, receipt) = lending::flash_loan_with_ctx<SUI_TEST>(&flash_loan_config, &mut sui_pool, loan_amount, test_scenario::ctx(&mut scenario));

            let _excess_balance = lending::flash_repay_with_ctx<SUI_TEST>(&_clock, &mut storage, &mut sui_pool, receipt, loan_balance, test_scenario::ctx(&mut scenario));
            let _coin = coin::from_balance(_excess_balance, test_scenario::ctx(&mut scenario));
            transfer::public_transfer(_coin, test_scenario::sender(&scenario));

            test_scenario::return_shared(storage);
            test_scenario::return_shared(sui_pool);
            test_scenario::return_shared(flash_loan_config);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
        test_scenario::end(scenario2);
    }

    #[test]
    public fun test_supplier_earns_fee() {
        let scenario = test_scenario::begin(OWNER);
        let scenario2 = test_scenario::begin(OWNER2);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };

        // deposit sui
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            let sui_coin = coin::mint_for_testing<SUI_TEST>(1000000_000000000, test_scenario::ctx(&mut scenario));

            base_lending_tests::base_deposit_for_testing(&mut scenario, &clock, &mut sui_pool, sui_coin, 0, 1000000_000000000);

            let (total_supply, _, _) = pool::get_pool_info(&sui_pool);
            assert!(total_supply == 1000000_000000000, 0);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(sui_pool);
        };

        // sui flash loan
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

            let loan_amount = 100_000000000;
            let (loan_balance, receipt) = lending::flash_loan_with_ctx<SUI_TEST>(&flash_loan_config, &mut sui_pool, loan_amount, test_scenario::ctx(&mut scenario));
            assert!(balance::value(&loan_balance) == loan_amount, 0);
            
            let (user, _, amount, pool, fee_to_supplier, fee_to_treasury) = flash_loan::parsed_receipt<SUI_TEST>(&receipt);
            assert!(user == test_scenario::sender(&scenario), 0);
            assert!(amount == loan_amount, 0);
            assert!(pool == object::uid_to_address(pool::uid(&sui_pool)), 0);
            std::debug::print(&fee_to_supplier);

            {
                let coin = coin::mint_for_testing<SUI_TEST>(fee_to_supplier + fee_to_treasury , test_scenario::ctx(&mut scenario));
                let total_fee = coin::into_balance(coin);
                balance::join(&mut loan_balance, total_fee);
                assert!(balance::value(&loan_balance)==amount + fee_to_supplier + fee_to_treasury, 0);
            };
            let _excess_balance = lending::flash_repay_with_ctx<SUI_TEST>(&_clock, &mut storage, &mut sui_pool, receipt, loan_balance, test_scenario::ctx(&mut scenario));
            assert!(balance::value(&_excess_balance) == 0, 0);
            balance::destroy_zero(_excess_balance);

            let (s, b) = storage::get_user_balance(&mut storage, 0, OWNER);
            std::debug::print(&s);
            std::debug::print(&b);
            assert!(s == 1000000_000000000, 1);
            assert!(b == 0, 1);

            let (s, b) = storage::get_index(&mut storage, 0);
            std::debug::print(&s);
            std::debug::print(&b);
            assert!(s == 1_000000160000000000000000000, 1);
            assert!(b == 1_000000000000000000000000000, 1);

            test_scenario::return_shared(storage);
            test_scenario::return_shared(sui_pool);
            test_scenario::return_shared(flash_loan_config);
        };

        // verify user withdrawal
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            // excess withdraw
            base_lending_tests::base_withdraw_for_testing(&mut scenario, &clock, &mut pool, 0, 1000000_160000000);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let sui_balance = test_scenario::take_from_sender<Coin<SUI_TEST>>(&scenario);
            assert!(coin::value(&sui_balance)  == 1000000_160000000, 2);
            test_scenario::return_to_sender(&scenario, sui_balance);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
        test_scenario::end(scenario2);
    }

    #[test]
    #[expected_failure(abort_code = 0, location=lending_core::flash_loan_test)]
    public fun test_error_flash_loan_index() {
        let scenario = test_scenario::begin(OWNER);
        let user_a_scenario = test_scenario::begin(UserA);
        let user_b_scenario = test_scenario::begin(UserB);
        let test_clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        clock::set_for_testing(&mut test_clock, 1704038400000);

        {
            test_scenario::next_tx(&mut scenario, OWNER);
            {
                base::initial_protocol(&mut scenario, &test_clock);
            };

            test_scenario::next_tx(&mut scenario, OWNER);
            {
                // Update The Sui Coin Price To 800000000(0.8)
                let storage = test_scenario::take_shared<Storage>(&scenario);
                let oracle_feeder_cap = test_scenario::take_from_sender<OracleFeederCap>(&scenario);
                let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);

                oracle::update_token_price(
                    &oracle_feeder_cap, // feeder cap
                    &test_clock,
                    &mut price_oracle, // PriceOracle
                    0,                 // Oracle id
                    800000000,    // price
                );

                test_scenario::return_shared(storage);
                test_scenario::return_shared(price_oracle);
                test_scenario::return_to_sender(&scenario, oracle_feeder_cap);
            };
        };

        { // UserA and UserB Perform Supply And Borrow Operations
            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                // UserA Supply 1000000 USDC
                clock::increment_for_testing(&mut test_clock, 60 * 1000); // 1 minute, 1 minute After Initial Time
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);

                let coin = coin::mint_for_testing<USDC_TEST>(1000000_000000, test_scenario::ctx(&mut user_a_scenario));
                base_lending_tests::base_deposit_for_testing(&mut user_a_scenario, &test_clock, &mut usdc_pool, coin, 1, 1000000_000000);

                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut user_b_scenario, UserB);
            {
                // UserB Supply 10000 SUI
                clock::increment_for_testing(&mut test_clock, 60 * 1000); // 1 minute, 2 minute After Initial Time
                let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&user_b_scenario);

                let coin = coin::mint_for_testing<SUI_TEST>(10000_000000000, test_scenario::ctx(&mut user_b_scenario));
                base_lending_tests::base_deposit_for_testing(&mut user_b_scenario, &test_clock, &mut sui_pool, coin, 0, 10000_000000000);

                test_scenario::return_shared(sui_pool);
            };

            let _max_borrow_in_usdc = 0;
            test_scenario::next_tx(&mut user_b_scenario, UserB);
            {
                // Calculate The Maximum USDC Amount For UserB Can Borrow
                clock::increment_for_testing(&mut test_clock, 60 * 1000); // 1 minute, 3 minute After Initial Time
                _max_borrow_in_usdc = calculate_max_borrow_in_asset_amount(&user_b_scenario, &test_clock, UserB, 1) -1;
            };
            test_scenario::next_tx(&mut user_b_scenario, UserB);
            {
                // UserB Borrow Maximum USDC
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_b_scenario);
                let amount = pool::unnormal_amount(&usdc_pool, (_max_borrow_in_usdc as u64));
                std::debug::print(&amount);
                base_lending_tests::base_borrow_for_testing(&mut user_b_scenario, &test_clock, &mut usdc_pool, 1, amount);
                test_scenario::return_shared(usdc_pool);
            };
        };

        {
            test_scenario::next_tx(&mut user_b_scenario, UserB);
            {
                // UserB Borrow Maximum USDC
                clock::increment_for_testing(&mut test_clock, 60 *60 * 24 * 10 * 1000); // 10 days
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_b_scenario);

                let usdc_coin = coin::mint_for_testing<USDC_TEST>(10000_000000000, test_scenario::ctx(&mut user_b_scenario));
                base_lending_tests::base_repay_for_testing(&mut user_b_scenario, &test_clock, &mut usdc_pool, usdc_coin, 1, 1); // just for update index...

                test_scenario::return_shared(usdc_pool);
            };

            let _before_supply_index = 0;
            let _before_borrow_index = 0;
            test_scenario::next_tx(&mut user_b_scenario, UserB); // flash loan first
            {
                let storage = test_scenario::take_shared<Storage>(&scenario);
                let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);
                (_before_supply_index, _before_borrow_index) = storage::get_index(&mut storage, 1);
                std::debug::print(&_before_supply_index);
                std::debug::print(&_before_borrow_index);

                let (loan_balance, receipt) = lending::flash_loan_with_ctx<USDC_TEST>(&flash_loan_config, &mut usdc_pool, 0, test_scenario::ctx(&mut user_b_scenario));
                let this_balance = loan_balance;
                let _excess_balance = lending::flash_repay_with_ctx<USDC_TEST>(&test_clock, &mut storage, &mut usdc_pool, receipt, this_balance, test_scenario::ctx(&mut user_b_scenario));
                if (balance::value(&_excess_balance) == 0) {
                    balance::destroy_zero(_excess_balance)
                } else {
                    let _coin = coin::from_balance(_excess_balance, test_scenario::ctx(&mut scenario));
                    transfer::public_transfer(_coin, test_scenario::sender(&scenario));
                };

                let (after_supply_index, after_borrow_index) = storage::get_index(&mut storage, 1);
                assert!(_before_supply_index == after_borrow_index, 0); // ERROR
                assert!(_before_borrow_index == after_supply_index, 0); // ERROR

                test_scenario::return_shared(storage);
                test_scenario::return_shared(usdc_pool);
                test_scenario::return_shared(flash_loan_config);
            };

            test_scenario::next_tx(&mut user_b_scenario, UserB); // flash loan again
            {
                let storage = test_scenario::take_shared<Storage>(&scenario);
                let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);

                let (loan_balance, receipt) = lending::flash_loan_with_ctx<USDC_TEST>(&flash_loan_config, &mut usdc_pool, 0, test_scenario::ctx(&mut user_b_scenario));
                let this_balance = loan_balance;
                let _excess_balance = lending::flash_repay_with_ctx<USDC_TEST>(&test_clock, &mut storage, &mut usdc_pool, receipt, this_balance, test_scenario::ctx(&mut user_b_scenario));
                if (balance::value(&_excess_balance) == 0) {
                    balance::destroy_zero(_excess_balance)
                } else {
                    let _coin = coin::from_balance(_excess_balance, test_scenario::ctx(&mut scenario));
                    transfer::public_transfer(_coin, test_scenario::sender(&scenario));
                };

                let (this_supply_index, this_borrow_index) = storage::get_index(&mut storage, 1);
                assert!(_before_supply_index == this_supply_index, 0);
                assert!(_before_borrow_index == this_borrow_index, 0);

                test_scenario::return_shared(storage);
                test_scenario::return_shared(usdc_pool);
                test_scenario::return_shared(flash_loan_config);
            }
        };

        test_scenario::end(scenario);
        test_scenario::end(user_a_scenario);
        test_scenario::end(user_b_scenario);
        clock::destroy_for_testing(test_clock);
    }

    #[test]
    public fun test_flash_loan_index_should_be_correct() {
        let scenario = test_scenario::begin(OWNER);
        let user_a_scenario = test_scenario::begin(UserA);
        let user_b_scenario = test_scenario::begin(UserB);
        let test_clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        clock::set_for_testing(&mut test_clock, 1704038400000);

        {
            test_scenario::next_tx(&mut scenario, OWNER);
            {
                base::initial_protocol(&mut scenario, &test_clock);
            };

            test_scenario::next_tx(&mut scenario, OWNER);
            {
                // Update The Sui Coin Price To 800000000(0.8)
                let storage = test_scenario::take_shared<Storage>(&scenario);
                let oracle_feeder_cap = test_scenario::take_from_sender<OracleFeederCap>(&scenario);
                let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);

                oracle::update_token_price(
                    &oracle_feeder_cap, // feeder cap
                    &test_clock,
                    &mut price_oracle, // PriceOracle
                    0,                 // Oracle id
                    800000000,    // price
                );

                test_scenario::return_shared(storage);
                test_scenario::return_shared(price_oracle);
                test_scenario::return_to_sender(&scenario, oracle_feeder_cap);
            };
        };

        { // UserA and UserB Perform Supply And Borrow Operations
            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                // UserA Supply 1000000 USDC
                clock::increment_for_testing(&mut test_clock, 60 * 1000); // 1 minute, 1 minute After Initial Time
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);

                let coin = coin::mint_for_testing<USDC_TEST>(1000000_000000, test_scenario::ctx(&mut user_a_scenario));
                base_lending_tests::base_deposit_for_testing(&mut user_a_scenario, &test_clock, &mut usdc_pool, coin, 1, 1000000_000000);

                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut user_b_scenario, UserB);
            {
                // UserB Supply 10000 SUI
                clock::increment_for_testing(&mut test_clock, 60 * 1000); // 1 minute, 2 minute After Initial Time
                let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&user_b_scenario);

                let coin = coin::mint_for_testing<SUI_TEST>(10000_000000000, test_scenario::ctx(&mut user_b_scenario));
                base_lending_tests::base_deposit_for_testing(&mut user_b_scenario, &test_clock, &mut sui_pool, coin, 0, 10000_000000000);

                test_scenario::return_shared(sui_pool);
            };

            let _max_borrow_in_usdc = 0;
            test_scenario::next_tx(&mut user_b_scenario, UserB);
            {
                // Calculate The Maximum USDC Amount For UserB Can Borrow
                clock::increment_for_testing(&mut test_clock, 60 * 1000); // 1 minute, 3 minute After Initial Time
                _max_borrow_in_usdc = calculate_max_borrow_in_asset_amount(&user_b_scenario, &test_clock, UserB, 1) -1;
            };
            test_scenario::next_tx(&mut user_b_scenario, UserB);
            {
                // UserB Borrow Maximum USDC
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_b_scenario);
                let amount = pool::unnormal_amount(&usdc_pool, (_max_borrow_in_usdc as u64));
                std::debug::print(&amount);
                base_lending_tests::base_borrow_for_testing(&mut user_b_scenario, &test_clock, &mut usdc_pool, 1, amount);
                test_scenario::return_shared(usdc_pool);
            };
        };

        {
            test_scenario::next_tx(&mut user_b_scenario, UserB);
            {
                // UserB Borrow Maximum USDC
                clock::increment_for_testing(&mut test_clock, 60 *60 * 24 * 10 * 1000); // 10 days
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_b_scenario);

                let usdc_coin = coin::mint_for_testing<USDC_TEST>(10000_000000000, test_scenario::ctx(&mut user_b_scenario));
                base_lending_tests::base_repay_for_testing(&mut user_b_scenario, &test_clock, &mut usdc_pool, usdc_coin, 1, 1); // just for update index...

                test_scenario::return_shared(usdc_pool);
            };

            let _before_supply_index = 0;
            let _before_borrow_index = 0;
            test_scenario::next_tx(&mut user_b_scenario, UserB); // flash loan first
            {
                let storage = test_scenario::take_shared<Storage>(&scenario);
                let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);
                (_before_supply_index, _before_borrow_index) = storage::get_index(&mut storage, 1);

                let (loan_balance, receipt) = lending::flash_loan_with_ctx<USDC_TEST>(&flash_loan_config, &mut usdc_pool, 0, test_scenario::ctx(&mut user_b_scenario));
                let this_balance = loan_balance;
                let _excess_balance = lending::flash_repay_with_ctx<USDC_TEST>(&test_clock, &mut storage, &mut usdc_pool, receipt, this_balance, test_scenario::ctx(&mut user_b_scenario));
                if (balance::value(&_excess_balance) == 0) {
                    balance::destroy_zero(_excess_balance)
                } else {
                    let _coin = coin::from_balance(_excess_balance, test_scenario::ctx(&mut scenario));
                    transfer::public_transfer(_coin, test_scenario::sender(&scenario));
                };

                let (after_supply_index, after_borrow_index) = storage::get_index(&mut storage, 1);
                assert!(_before_supply_index == after_supply_index, 0); // ERROR
                assert!(_before_borrow_index == after_borrow_index, 0); // ERROR

                test_scenario::return_shared(storage);
                test_scenario::return_shared(usdc_pool);
                test_scenario::return_shared(flash_loan_config);
            };

            test_scenario::next_tx(&mut user_b_scenario, UserB); // flash loan again
            {
                let storage = test_scenario::take_shared<Storage>(&scenario);
                let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);

                let (loan_balance, receipt) = lending::flash_loan_with_ctx<USDC_TEST>(&flash_loan_config, &mut usdc_pool, 0, test_scenario::ctx(&mut user_b_scenario));
                let this_balance = loan_balance;
                let _excess_balance = lending::flash_repay_with_ctx<USDC_TEST>(&test_clock, &mut storage, &mut usdc_pool, receipt, this_balance, test_scenario::ctx(&mut user_b_scenario));
                if (balance::value(&_excess_balance) == 0) {
                    balance::destroy_zero(_excess_balance)
                } else {
                    let _coin = coin::from_balance(_excess_balance, test_scenario::ctx(&mut scenario));
                    transfer::public_transfer(_coin, test_scenario::sender(&scenario));
                };

                let (this_supply_index, this_borrow_index) = storage::get_index(&mut storage, 1);
                assert!(_before_supply_index == this_supply_index, 0);
                assert!(_before_borrow_index == this_borrow_index, 0);

                test_scenario::return_shared(storage);
                test_scenario::return_shared(usdc_pool);
                test_scenario::return_shared(flash_loan_config);
            }
        };

        test_scenario::end(scenario);
        test_scenario::end(user_a_scenario);
        test_scenario::end(user_b_scenario);
        clock::destroy_for_testing(test_clock);
    }

    #[test_only]
    public fun calculate_max_borrow_in_asset_amount(scenario: &Scenario, clock: &Clock, user: address, asset_id: u8): u256 {
        let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
        let storage = test_scenario::take_shared<Storage>(scenario);

        let avg_ltv = logic::calculate_avg_ltv(clock, &price_oracle, &mut storage, user);
        let avg_threshold = logic::calculate_avg_threshold(clock, &price_oracle, &mut storage, user);
        let health_factor_in_borrow = ray_math::ray_div(avg_threshold, avg_ltv);
        let health_collateral_value = logic::user_health_collateral_value(clock, &price_oracle, &mut storage, user);
        let dynamic_liquidation_threshold = logic::dynamic_liquidation_threshold(clock, &mut storage, &price_oracle, user);
        let max_borrow_in_usd = ray_math::ray_div(
            health_collateral_value,
            ray_math::ray_div(health_factor_in_borrow, dynamic_liquidation_threshold),
        );

        let oracle_id = storage::get_oracle_id(&storage, asset_id);
        let amount = calculator::calculate_amount(clock, &price_oracle, max_borrow_in_usd, oracle_id);

        test_scenario::return_shared(price_oracle);
        test_scenario::return_shared(storage);

        amount
    }

    #[test]
    #[allow(unused_assignment, unused_variable)]
    // Should flash_loan correctly after update_state 
    public fun test_flash_loan_index_should_be_correct_after_update_state() {
        let scenario = test_scenario::begin(OWNER);
        let user_a_scenario = test_scenario::begin(UserA);
        let user_b_scenario = test_scenario::begin(UserB);
        let test_clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        clock::set_for_testing(&mut test_clock, 1704038400000);

        {
            test_scenario::next_tx(&mut scenario, OWNER);
            {
                base::initial_protocol(&mut scenario, &test_clock);
            };

            test_scenario::next_tx(&mut scenario, OWNER);
            {
                // Update The Sui Coin Price To 800000000(0.8)
                let storage = test_scenario::take_shared<Storage>(&scenario);
                let oracle_feeder_cap = test_scenario::take_from_sender<OracleFeederCap>(&scenario);
                let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
                clock::increment_for_testing(&mut test_clock, 86400 * 365 * 1000);
                oracle::update_token_price(
                    &oracle_feeder_cap, // feeder cap
                    &test_clock,
                    &mut price_oracle, // PriceOracle
                    0,                 // Oracle id
                    800000000,    // price
                );

                oracle::update_token_price(
                    &oracle_feeder_cap, // feeder cap
                    &test_clock,
                    &mut price_oracle, // PriceOracle
                    1,                 // Oracle id
                    1_000000000,    // price
                );

                test_scenario::return_shared(storage);
                test_scenario::return_shared(price_oracle);
                test_scenario::return_to_sender(&scenario, oracle_feeder_cap);
            };
        };

        { // UserA and UserB Perform Supply And Borrow Operations
            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                // UserA Supply 1000000 USDC
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);

                let coin = coin::mint_for_testing<USDC_TEST>(1000000_000000, test_scenario::ctx(&mut user_a_scenario));
                base_lending_tests::base_deposit_for_testing(&mut user_a_scenario, &test_clock, &mut usdc_pool, coin, 1, 1000000_000000);

                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut user_a_scenario, UserA);
            {
                // UserA Supply 1000000 USDC
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_a_scenario);
                
                base_lending_tests::base_borrow_for_testing(&mut user_a_scenario, &test_clock, &mut usdc_pool, 1, 500000_000000);

                test_scenario::return_shared(usdc_pool);
            };

            test_scenario::next_tx(&mut user_b_scenario, UserB);
            {
                // UserB Supply 10000 SUI
                clock::increment_for_testing(&mut test_clock, 60 * 1000); // 1 minute, 2 minute After Initial Time
                let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&user_b_scenario);

                let coin = coin::mint_for_testing<SUI_TEST>(10000_000000000, test_scenario::ctx(&mut user_b_scenario));
                base_lending_tests::base_deposit_for_testing(&mut user_b_scenario, &test_clock, &mut sui_pool, coin, 0, 10000_000000000);

                test_scenario::return_shared(sui_pool);
            };

            let _max_borrow_in_usdc = 0;
            test_scenario::next_tx(&mut user_b_scenario, UserB);
            {
                // Calculate The Maximum USDC Amount For UserB Can Borrow
                clock::increment_for_testing(&mut test_clock, 60 * 1000); // 1 minute, 3 minute After Initial Time
                _max_borrow_in_usdc = calculate_max_borrow_in_asset_amount(&user_b_scenario, &test_clock, UserB, 1) -1;
            };
            test_scenario::next_tx(&mut user_b_scenario, UserB);
            {
                // UserB Borrow Maximum USDC
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_b_scenario);
                let amount = pool::unnormal_amount(&usdc_pool, (_max_borrow_in_usdc as u64));
                std::debug::print(&amount);
                base_lending_tests::base_borrow_for_testing(&mut user_b_scenario, &test_clock, &mut usdc_pool, 1, amount);
                test_scenario::return_shared(usdc_pool);
            };
        };

        {
            test_scenario::next_tx(&mut user_b_scenario, UserB);
            {
                // UserB Borrow Maximum USDC
                clock::increment_for_testing(&mut test_clock, 60 *60 * 24 * 10 * 1000); // 10 days
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&user_b_scenario);

                let usdc_coin = coin::mint_for_testing<USDC_TEST>(10000_000000000, test_scenario::ctx(&mut user_b_scenario));
                base_lending_tests::base_repay_for_testing(&mut user_b_scenario, &test_clock, &mut usdc_pool, usdc_coin, 1, 1); // just for update index...

                test_scenario::return_shared(usdc_pool);
            };

            let _before_supply_index = 0;
            let _before_borrow_index = 0;
            let after_borrow_index = 0;
            let after_supply_index = 0;
            test_scenario::next_tx(&mut user_b_scenario, UserB); // flash loan first
            {
                let storage = test_scenario::take_shared<Storage>(&scenario);
                let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);
                (_before_supply_index, _before_borrow_index) = storage::get_index(&mut storage, 1);

                let (loan_balance, receipt) = lending::flash_loan_with_ctx<USDC_TEST>(&flash_loan_config, &mut usdc_pool, 100_000000, test_scenario::ctx(&mut user_b_scenario));
                {
                    let (user, _, amount, pool, fee_to_supplier, fee_to_treasury) = flash_loan::parsed_receipt<USDC_TEST>(&receipt);
                    let coin = coin::mint_for_testing<USDC_TEST>(fee_to_supplier + fee_to_treasury , test_scenario::ctx(&mut scenario));
                    let total_fee = coin::into_balance(coin);
                    balance::join(&mut loan_balance, total_fee);
                    assert!(balance::value(&loan_balance)==amount + fee_to_supplier + fee_to_treasury, 0);
                };                
                let _excess_balance = lending::flash_repay_with_ctx<USDC_TEST>(&test_clock, &mut storage, &mut usdc_pool, receipt, loan_balance, test_scenario::ctx(&mut user_b_scenario));
                if (balance::value(&_excess_balance) == 0) {
                    balance::destroy_zero(_excess_balance)
                } else {
                    let _coin = coin::from_balance(_excess_balance, test_scenario::ctx(&mut scenario));
                    transfer::public_transfer(_coin, test_scenario::sender(&scenario));
                };

                (after_supply_index, after_borrow_index) = storage::get_index(&mut storage, 1);
                std::debug::print(&(after_supply_index - _before_supply_index));
                assert!(_before_supply_index < after_supply_index, 0); 
                assert!(_before_borrow_index == after_borrow_index, 0); 

                test_scenario::return_shared(storage);
                test_scenario::return_shared(usdc_pool);
                test_scenario::return_shared(flash_loan_config);
            };

            test_scenario::next_tx(&mut user_b_scenario, UserB); // flash loan again
            {
                let storage = test_scenario::take_shared<Storage>(&scenario);
                let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
                let usdc_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);

                let (loan_balance, receipt) = lending::flash_loan_with_ctx<USDC_TEST>(&flash_loan_config, &mut usdc_pool, 100_000000, test_scenario::ctx(&mut user_b_scenario));
                {
                    let (user, _, amount, pool, fee_to_supplier, fee_to_treasury) = flash_loan::parsed_receipt<USDC_TEST>(&receipt);
                    let coin = coin::mint_for_testing<USDC_TEST>(fee_to_supplier + fee_to_treasury , test_scenario::ctx(&mut scenario));
                    let total_fee = coin::into_balance(coin);
                    balance::join(&mut loan_balance, total_fee);
                    assert!(balance::value(&loan_balance)==amount + fee_to_supplier + fee_to_treasury, 0);
                };           
                let _excess_balance = lending::flash_repay_with_ctx<USDC_TEST>(&test_clock, &mut storage, &mut usdc_pool, receipt, loan_balance, test_scenario::ctx(&mut user_b_scenario));
                if (balance::value(&_excess_balance) == 0) {
                    balance::destroy_zero(_excess_balance)
                } else {
                    let _coin = coin::from_balance(_excess_balance, test_scenario::ctx(&mut scenario));
                    transfer::public_transfer(_coin, test_scenario::sender(&scenario));
                };

                let (this_supply_index, this_borrow_index) = storage::get_index(&mut storage, 1);
                std::debug::print(&(this_supply_index - after_supply_index)); // 0_000000159971934717255645958
                assert!(_before_supply_index < this_supply_index, 0);
                assert!(_before_borrow_index == this_borrow_index, 0);

                test_scenario::return_shared(storage);
                test_scenario::return_shared(usdc_pool);
                test_scenario::return_shared(flash_loan_config);
            }
        };

        test_scenario::end(scenario);
        test_scenario::end(user_a_scenario);
        test_scenario::end(user_b_scenario);
        clock::destroy_for_testing(test_clock);
    }

    #[test]
    public fun test_supplier_earns_fee_integration() {
        let scenario = test_scenario::begin(OWNER);
        let scenario2 = test_scenario::begin(OWNER2);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };

        // deposit 1m sui
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            let sui_coin = coin::mint_for_testing<SUI_TEST>(1000000_000000000, test_scenario::ctx(&mut scenario));

            base_lending_tests::base_deposit_for_testing(&mut scenario, &clock, &mut sui_pool, sui_coin, 0, 1000_000_000000000);

            let (total_supply, _, _) = pool::get_pool_info(&sui_pool);
            assert!(total_supply == 1000000_000000000, 0);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(sui_pool);
        };

        // sui flash loan
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

            let loan_amount = 100_000000000;
            let (loan_balance, receipt) = lending::flash_loan_with_ctx<SUI_TEST>(&flash_loan_config, &mut sui_pool, loan_amount, test_scenario::ctx(&mut scenario));
            assert!(balance::value(&loan_balance) == loan_amount, 0);

            let (user, _, amount, pool, fee_to_supplier, fee_to_treasury) = flash_loan::parsed_receipt<SUI_TEST>(&receipt);
            assert!(user == test_scenario::sender(&scenario), 0);
            assert!(amount == loan_amount, 0);
            assert!(pool == object::uid_to_address(pool::uid(&sui_pool)), 0);
            std::debug::print(&fee_to_supplier);

            {
                let coin = coin::mint_for_testing<SUI_TEST>(fee_to_supplier + fee_to_treasury , test_scenario::ctx(&mut scenario));
                let total_fee = coin::into_balance(coin);
                balance::join(&mut loan_balance, total_fee);
                assert!(balance::value(&loan_balance)==amount + fee_to_supplier + fee_to_treasury, 0);
            };
            let _excess_balance = lending::flash_repay_with_ctx<SUI_TEST>(&_clock, &mut storage, &mut sui_pool, receipt, loan_balance, test_scenario::ctx(&mut scenario));
            assert!(balance::value(&_excess_balance) == 0, 0);
            balance::destroy_zero(_excess_balance);

            let (s, b) = storage::get_user_balance(&mut storage, 0, OWNER);
            std::debug::print(&s);
            std::debug::print(&b);
            assert!(s == 1000000_000000000, 1);
            assert!(b == 0, 1);

            let (s, b) = storage::get_index(&mut storage, 0);
            std::debug::print(&s);
            std::debug::print(&b);
            assert!(s == 1_000000160000000000000000000, 1);
            assert!(b == 1_000000000000000000000000000, 1);

            test_scenario::return_shared(storage);
            test_scenario::return_shared(sui_pool);
            test_scenario::return_shared(flash_loan_config);
        };

        // owner2 deposit 1m sui
        test_scenario::next_tx(&mut scenario2, OWNER2);
        {
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario2);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario2));
            let sui_coin = coin::mint_for_testing<SUI_TEST>(1000000_000000000, test_scenario::ctx(&mut scenario2));

            base_lending_tests::base_deposit_for_testing(&mut scenario2, &clock, &mut sui_pool, sui_coin, 0, 1000_000_000000000);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(sui_pool);
        };

        // sui flash loan
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

            let loan_amount = 100_000000000;
            let (loan_balance, receipt) = lending::flash_loan_with_ctx<SUI_TEST>(&flash_loan_config, &mut sui_pool, loan_amount, test_scenario::ctx(&mut scenario));
            assert!(balance::value(&loan_balance) == loan_amount, 0);

            let (user, _, amount, pool, fee_to_supplier, fee_to_treasury) = flash_loan::parsed_receipt<SUI_TEST>(&receipt);
            assert!(user == test_scenario::sender(&scenario), 0);
            assert!(amount == loan_amount, 0);
            assert!(pool == object::uid_to_address(pool::uid(&sui_pool)), 0);
            std::debug::print(&fee_to_supplier);

            {
                let coin = coin::mint_for_testing<SUI_TEST>(fee_to_supplier + fee_to_treasury , test_scenario::ctx(&mut scenario));
                let total_fee = coin::into_balance(coin);
                balance::join(&mut loan_balance, total_fee);
                assert!(balance::value(&loan_balance)==amount + fee_to_supplier + fee_to_treasury, 0);
            };
            let _excess_balance = lending::flash_repay_with_ctx<SUI_TEST>(&_clock, &mut storage, &mut sui_pool, receipt, loan_balance, test_scenario::ctx(&mut scenario));
            assert!(balance::value(&_excess_balance) == 0, 0);
            balance::destroy_zero(_excess_balance);

            let (s, b) = storage::get_user_balance(&mut storage, 0, OWNER);
            std::debug::print(&s);
            std::debug::print(&b);
            assert!(s == 1000000000000000, 1);
            assert!(b == 0, 1);

            let (s, b) = storage::get_user_balance(&mut storage, 0, OWNER2);
            std::debug::print(&s);
            std::debug::print(&b);
            assert!(s == 999999840000026, 1);
            assert!(b == 0, 1);

            let (s, b) = storage::get_index(&mut storage, 0);
            std::debug::print(&s);
            std::debug::print(&b);
            assert!(s == 1_000000240000006199997376000, 1);
            assert!(b == 1_000000000000000000000000000, 1);

            test_scenario::return_shared(storage);
            test_scenario::return_shared(sui_pool);
            test_scenario::return_shared(flash_loan_config);
        };

        // verify owner1 withdrawal 
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            base_lending_tests::base_withdraw_for_testing(&mut scenario, &_clock, &mut pool, 0, 1000000_240000000);

            test_scenario::return_shared(pool);
        };

        // verify owner2 withdrawal 
        test_scenario::next_tx(&mut scenario, OWNER2);
        {
            let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            // excess withdraw
            base_lending_tests::base_withdraw_for_testing(&mut scenario, &_clock, &mut pool, 0, 1000000_080000000);

            test_scenario::return_shared(pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let sui_balance = test_scenario::take_from_sender<Coin<SUI_TEST>>(&scenario);
            std::debug::print(&coin::value(&sui_balance));
            assert!(coin::value(&sui_balance)  == 1000000_240000000, 2);
            test_scenario::return_to_sender(&scenario, sui_balance);
        };

        test_scenario::next_tx(&mut scenario, OWNER2);
        {
            let sui_balance = test_scenario::take_from_address<Coin<SUI_TEST>>(&scenario2, OWNER2);
            std::debug::print(&coin::value(&sui_balance));
            assert!(coin::value(&sui_balance)  == 1000000_079999994, 2);
            test_scenario::return_to_sender(&scenario, sui_balance);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
        test_scenario::end(scenario2);
    }


    #[test]
    public fun test_loan_min_and_max() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };

        // deposit 1m sui
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            let sui_coin = coin::mint_for_testing<SUI_TEST>(1000000_000000000, test_scenario::ctx(&mut scenario));

            base_lending_tests::base_deposit_for_testing(&mut scenario, &clock, &mut sui_pool, sui_coin, 0, 1000000_000000000);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(sui_pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER); 
        {
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(&mut scenario);
            let storage = test_scenario::take_shared<Storage>(&mut scenario);
            manage::create_flash_loan_config_with_storage(&storage_admin_cap, &storage, test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(storage);
            test_scenario::return_to_sender(&scenario, storage_admin_cap);
        };


        // init config
        test_scenario::next_tx(&mut scenario, OWNER); // flash loan again
        {
            let (storage, flash_loan_config, storage_admin_cap,pool) = borrow_all(&mut scenario);

            manage::create_flash_loan_asset<SUI_TEST>(
                &storage_admin_cap,
                &mut flash_loan_config,
                &storage,
                &pool,
                0,
                20, // 0.0020
                10, // 0.0010
                200000_000000000, // 200k
                1000_000000000, // 1000
                test_scenario::ctx(&mut scenario)
            );

            return_all(&scenario ,storage, flash_loan_config, storage_admin_cap,pool);
        };


        // flash loan and repay max
        test_scenario::next_tx(&mut scenario, OWNER); // flash loan again
        {
            let (storage, flash_loan_config, storage_admin_cap,sui_pool) = borrow_all(&mut scenario);

            let loan_amount = 200000_000000000;
            let (loan_balance, receipt) = lending::flash_loan_with_ctx<SUI_TEST>(&flash_loan_config, &mut sui_pool, loan_amount, test_scenario::ctx(&mut scenario));


            let (user, _, amount, pool, fee_to_supplier, fee_to_treasury) = flash_loan::parsed_receipt<SUI_TEST>(&receipt);


            let coin = coin::mint_for_testing<SUI_TEST>(fee_to_supplier + fee_to_treasury, test_scenario::ctx(&mut scenario));
            let total_fee = coin::into_balance(coin);
            balance::join(&mut loan_balance, total_fee);

            let _excess_balance = lending::flash_repay_with_ctx<SUI_TEST>(&_clock, &mut storage, &mut sui_pool, receipt, loan_balance, test_scenario::ctx(&mut scenario));

            assert!(balance::value(&_excess_balance) == 0, 1);
            balance::destroy_zero(_excess_balance);

            return_all(&scenario ,storage, flash_loan_config, storage_admin_cap, sui_pool);
        };

        // flash loan and repay min
        test_scenario::next_tx(&mut scenario, OWNER); // flash loan again
        {
            let (storage, flash_loan_config, storage_admin_cap,sui_pool) = borrow_all(&mut scenario);

            let loan_amount = 1000_000000000;
            let (loan_balance, receipt) = lending::flash_loan_with_ctx<SUI_TEST>(&flash_loan_config, &mut sui_pool, loan_amount, test_scenario::ctx(&mut scenario));


            let (user, _, amount, pool, fee_to_supplier, fee_to_treasury) = flash_loan::parsed_receipt<SUI_TEST>(&receipt);


            let coin = coin::mint_for_testing<SUI_TEST>(fee_to_supplier + fee_to_treasury, test_scenario::ctx(&mut scenario));
            let total_fee = coin::into_balance(coin);
            balance::join(&mut loan_balance, total_fee);

            let _excess_balance = lending::flash_repay_with_ctx<SUI_TEST>(&_clock, &mut storage, &mut sui_pool, receipt, loan_balance, test_scenario::ctx(&mut scenario));

            assert!(balance::value(&_excess_balance) == 0, 1);
            balance::destroy_zero(_excess_balance);

            return_all(&scenario ,storage, flash_loan_config, storage_admin_cap, sui_pool);
        };

        // supplier earns fee
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            // excess withdraw with fee 201000 * 0.2% = 402
            base_lending_tests::base_withdraw_for_testing(&mut scenario, &clock, &mut pool, 0, 1000402_000000000);
            let (_,t_balance,_) = pool::get_pool_info<SUI_TEST>(&pool);
            assert(t_balance == 201_000000000, 0);
            clock::destroy_for_testing(clock);
            test_scenario::return_shared(pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let sui_balance = test_scenario::take_from_sender<Coin<SUI_TEST>>(&scenario);
            std::debug::print(&coin::value(&sui_balance)) ;
            assert!(coin::value(&sui_balance)  == 1000402_000000000, 2);
            test_scenario::return_to_sender(&scenario, sui_balance);
        };


        test_scenario::end(scenario);
        clock::destroy_for_testing(_clock);
    }

    #[test]
    #[expected_failure(abort_code = 1503, location = lending_core::flash_loan)]
    public fun test_loan_under_min() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };

        // deposit 1m sui
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            let sui_coin = coin::mint_for_testing<SUI_TEST>(1000000_000000000, test_scenario::ctx(&mut scenario));

            base_lending_tests::base_deposit_for_testing(&mut scenario, &clock, &mut sui_pool, sui_coin, 0, 1000000_000000000);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(sui_pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER); 
        {
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(&mut scenario);
            let storage = test_scenario::take_shared<Storage>(&mut scenario);
            manage::create_flash_loan_config_with_storage(&storage_admin_cap, &storage, test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(storage);
            test_scenario::return_to_sender(&scenario, storage_admin_cap);
        };


        // init config
        test_scenario::next_tx(&mut scenario, OWNER); // flash loan again
        {
            let (storage, flash_loan_config, storage_admin_cap,pool) = borrow_all(&mut scenario);

            manage::create_flash_loan_asset<SUI_TEST>(
                &storage_admin_cap,
                &mut flash_loan_config,
                &storage,
                &pool,
                0,
                20, // 0.0020
                10, // 0.0010
                200000_000000000, // 200k
                1000_000000000, // 1000
                test_scenario::ctx(&mut scenario)
            );

            return_all(&scenario ,storage, flash_loan_config, storage_admin_cap,pool);
        };


        // flash loan and repay under min
        test_scenario::next_tx(&mut scenario, OWNER); // flash loan again
        {
            let (storage, flash_loan_config, storage_admin_cap,sui_pool) = borrow_all(&mut scenario);

            let loan_amount = 1000_000000000 - 1;
            let (loan_balance, receipt) = lending::flash_loan_with_ctx<SUI_TEST>(&flash_loan_config, &mut sui_pool, loan_amount, test_scenario::ctx(&mut scenario));


            let (user, _, amount, pool, fee_to_supplier, fee_to_treasury) = flash_loan::parsed_receipt<SUI_TEST>(&receipt);


            let coin = coin::mint_for_testing<SUI_TEST>(fee_to_supplier + fee_to_treasury, test_scenario::ctx(&mut scenario));
            let total_fee = coin::into_balance(coin);
            balance::join(&mut loan_balance, total_fee);

            let _excess_balance = lending::flash_repay_with_ctx<SUI_TEST>(&_clock, &mut storage, &mut sui_pool, receipt, loan_balance, test_scenario::ctx(&mut scenario));

            assert!(balance::value(&_excess_balance) == 0, 1);
            balance::destroy_zero(_excess_balance);

            return_all(&scenario ,storage, flash_loan_config, storage_admin_cap, sui_pool);
        };

        test_scenario::end(scenario);
        clock::destroy_for_testing(_clock);
    }

    #[test]
    #[expected_failure(abort_code = 1503, location = lending_core::flash_loan)]
    public fun test_loan_over_max() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };

        // deposit 1m sui
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            let sui_coin = coin::mint_for_testing<SUI_TEST>(1000000_000000000, test_scenario::ctx(&mut scenario));

            base_lending_tests::base_deposit_for_testing(&mut scenario, &clock, &mut sui_pool, sui_coin, 0, 1000000_000000000);

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(sui_pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER); 
        {
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(&mut scenario);
            let storage = test_scenario::take_shared<Storage>(&mut scenario);
            manage::create_flash_loan_config_with_storage(&storage_admin_cap, &storage, test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(storage);
            test_scenario::return_to_sender(&scenario, storage_admin_cap);
        };


        // init config
        test_scenario::next_tx(&mut scenario, OWNER); // flash loan again
        {
            let (storage, flash_loan_config, storage_admin_cap,pool) = borrow_all(&mut scenario);

            manage::create_flash_loan_asset<SUI_TEST>(
                &storage_admin_cap,
                &mut flash_loan_config,
                &storage,
                &pool,
                0,
                20, // 0.0020
                10, // 0.0010
                200000_000000000, // 200k
                1000_000000000, // 1000
                test_scenario::ctx(&mut scenario)
            );

            return_all(&scenario ,storage, flash_loan_config, storage_admin_cap,pool);
        };


        // flash loan and repay under min
        test_scenario::next_tx(&mut scenario, OWNER); // flash loan again
        {
            let (storage, flash_loan_config, storage_admin_cap,sui_pool) = borrow_all(&mut scenario);

            let loan_amount = 200000_000000000 + 1;
            let (loan_balance, receipt) = lending::flash_loan_with_ctx<SUI_TEST>(&flash_loan_config, &mut sui_pool, loan_amount, test_scenario::ctx(&mut scenario));


            let (user, _, amount, pool, fee_to_supplier, fee_to_treasury) = flash_loan::parsed_receipt<SUI_TEST>(&receipt);


            let coin = coin::mint_for_testing<SUI_TEST>(fee_to_supplier + fee_to_treasury, test_scenario::ctx(&mut scenario));
            let total_fee = coin::into_balance(coin);
            balance::join(&mut loan_balance, total_fee);

            let _excess_balance = lending::flash_repay_with_ctx<SUI_TEST>(&_clock, &mut storage, &mut sui_pool, receipt, loan_balance, test_scenario::ctx(&mut scenario));

            assert!(balance::value(&_excess_balance) == 0, 1);
            balance::destroy_zero(_excess_balance);

            return_all(&scenario ,storage, flash_loan_config, storage_admin_cap, sui_pool);
        };

        test_scenario::end(scenario);
        clock::destroy_for_testing(_clock);
    }

    #[test]
    public fun test_integration_loan_base() {
        let scenario = test_scenario::begin(OWNER);
        let user_a_scenario = test_scenario::begin(UserA);
        let user_b_scenario = test_scenario::begin(UserB);
        let test_clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        clock::set_for_testing(&mut test_clock, 1704038400000);

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            base::initial_protocol(&mut scenario, &test_clock);
        };

        // A deposit 10k
        test_scenario::next_tx(&mut user_a_scenario, UserA);
        {
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&user_a_scenario);

            let coin = coin::mint_for_testing<SUI_TEST>(10000_000000000, test_scenario::ctx(&mut user_a_scenario));
            base_lending_tests::base_deposit_for_testing(&mut user_a_scenario, &test_clock, &mut sui_pool, coin, 0, 10000_000000000);

            test_scenario::return_shared(sui_pool);
        };

        // A borrow 5k  
        test_scenario::next_tx(&mut user_a_scenario, UserA);
        {
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&user_a_scenario);

            base_lending_tests::base_borrow_for_testing(&mut user_a_scenario, &test_clock, &mut sui_pool, 0, 5000_000000000);

            test_scenario::return_shared(sui_pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            pass_time_and_update_price(&mut scenario, &mut test_clock,86400 * 365 / 2,0,500000000);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            logic::update_state_of_all_for_testing(&test_clock, &mut storage);
            test_scenario::return_shared(storage);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            pass_time_and_update_price(&mut scenario, &mut test_clock,86400 * 365 / 2,0,500000000);
        };
        // A deposit 10k
        test_scenario::next_tx(&mut user_a_scenario, UserA);
        {
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&user_a_scenario);

            let coin = coin::mint_for_testing<SUI_TEST>(10000_000000000, test_scenario::ctx(&mut user_a_scenario));
            base_lending_tests::base_deposit_for_testing(&mut user_a_scenario, &test_clock, &mut sui_pool, coin, 0, 10000_000000000);

            test_scenario::return_shared(sui_pool);
        };

        // A borrow 5k  
        test_scenario::next_tx(&mut user_a_scenario, UserA);
        {
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&user_a_scenario);

            base_lending_tests::base_borrow_for_testing(&mut user_a_scenario, &test_clock, &mut sui_pool, 0, 5000_000000000);

            test_scenario::return_shared(sui_pool);
        };

        // verify status
        test_scenario::next_tx(&mut user_a_scenario, UserA);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);

            let (s, b) = storage::get_user_balance(&mut storage, 0, UserA);
            std::debug::print(&s);
            std::debug::print(&b);

            let (s_index, b_index) = storage::get_index(&mut storage, 0);
            std::debug::print(&s_index);
            std::debug::print(&b_index);
            // assert!(s == 1_000000160000000000000000000, 1);
            // assert!(b == 1_000000000000000000000000000, 1);
            s = s * s_index / (1000000000000000000000000000);
            b = b * b_index / (1000000000000000000000000000);
            std::debug::print(&s);
            std::debug::print(&b);
            assert!(s == 20000232721354, 1);
            assert!(b == 10000290908461, 1);

            test_scenario::return_shared(storage);

        };

        test_scenario::end(scenario);
        test_scenario::end(user_a_scenario);
        test_scenario::end(user_b_scenario);
        clock::destroy_for_testing(test_clock);

    }

    #[test]
    public fun test_integration_loan_compare() {
        let scenario = test_scenario::begin(OWNER);
        let test_clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        clock::set_for_testing(&mut test_clock, 1704038400000);

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            base::initial_protocol(&mut scenario, &test_clock);
        };

        // A deposit 10k
        test_scenario::next_tx(&mut scenario, UserA);
        {
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

            let coin = coin::mint_for_testing<SUI_TEST>(10000_000000000, test_scenario::ctx(&mut scenario));
            base_lending_tests::base_deposit_for_testing(&mut scenario, &test_clock, &mut sui_pool, coin, 0, 10000_000000000);

            test_scenario::return_shared(sui_pool);
        };

        // A borrow 5k  
        test_scenario::next_tx(&mut scenario, UserA);
        {
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

            base_lending_tests::base_borrow_for_testing(&mut scenario, &test_clock, &mut sui_pool, 0, 5000_000000000);

            test_scenario::return_shared(sui_pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            pass_time_and_update_price(&mut scenario, &mut test_clock,86400 * 365 / 2,0,500000000);
        };

        // Owner flash loan and repay 1000
        test_scenario::next_tx(&mut scenario, OWNER); // flash loan again
        {
            let (storage, flash_loan_config, storage_admin_cap,sui_pool) = borrow_all(&mut scenario);

            let loan_amount = 1000_000000000;
            let (loan_balance, receipt) = lending::flash_loan_with_ctx<SUI_TEST>(&flash_loan_config, &mut sui_pool, loan_amount, test_scenario::ctx(&mut scenario));


            let (user, _, amount, pool, fee_to_supplier, fee_to_treasury) = flash_loan::parsed_receipt<SUI_TEST>(&receipt);


            let coin = coin::mint_for_testing<SUI_TEST>(fee_to_supplier + fee_to_treasury, test_scenario::ctx(&mut scenario));
            let total_fee = coin::into_balance(coin);
            balance::join(&mut loan_balance, total_fee);

            let _excess_balance = lending::flash_repay_with_ctx<SUI_TEST>(&test_clock, &mut storage, &mut sui_pool, receipt, loan_balance, test_scenario::ctx(&mut scenario));

            assert!(balance::value(&_excess_balance) == 0, 1);
            balance::destroy_zero(_excess_balance);

            return_all(&scenario ,storage, flash_loan_config, storage_admin_cap, sui_pool);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            pass_time_and_update_price(&mut scenario, &mut test_clock,86400 * 365 / 2,0,500000000);
        };


        // A deposit 10k
        test_scenario::next_tx(&mut scenario, UserA);
        {
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

            let coin = coin::mint_for_testing<SUI_TEST>(10000_000000000, test_scenario::ctx(&mut scenario));
            base_lending_tests::base_deposit_for_testing(&mut scenario, &test_clock, &mut sui_pool, coin, 0, 10000_000000000);

            test_scenario::return_shared(sui_pool);
        };

        // A borrow 5k  
        test_scenario::next_tx(&mut scenario, UserA);
        {
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

            base_lending_tests::base_borrow_for_testing(&mut scenario, &test_clock, &mut sui_pool, 0, 5000_000000000);

            test_scenario::return_shared(sui_pool);
        };

        // verify status
        test_scenario::next_tx(&mut scenario, UserA);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);

            let (s, b) = storage::get_user_balance(&mut storage, 0, UserA);
            std::debug::print(&s);
            std::debug::print(&b);

            let (s_index, b_index) = storage::get_index(&mut storage, 0);
            std::debug::print(&s_index);
            std::debug::print(&b_index);
            // assert!(s == 1_000000160000000000000000000, 1);
            // assert!(b == 1_000000000000000000000000000, 1);
            s = s * s_index / (1000000000000000000000000000);
            b = b * b_index / (1000000000000000000000000000);
            std::debug::print(&s);
            std::debug::print(&b);
            // 20000_232721354 base 
            // 20001832701469 compare
            assert!(s == 20001832701469, 1);
            // 10000290908461 base
            // 10000290887308 compare
            assert!(b == 10000290887308, 1);

            test_scenario::return_shared(storage);
        };

        test_scenario::end(scenario);
        clock::destroy_for_testing(test_clock);

    }

    #[test_only]
    public fun borrow_all(scenario: &mut Scenario):(Storage, FlashLoanConfig, StorageAdminCap, Pool<SUI_TEST>) {
            let storage = test_scenario::take_shared<Storage>(scenario);
            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(scenario);
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(scenario);
            let pool = test_scenario::take_shared<Pool<SUI_TEST>>(scenario);
            (storage, flash_loan_config, storage_admin_cap,pool)
    }


    #[test_only]
    public fun return_all(scenario: &Scenario, storage:Storage, config:FlashLoanConfig, storage_admin_cap: StorageAdminCap, sui_pool:Pool<SUI_TEST>) {
        test_scenario::return_shared(storage);
        test_scenario::return_shared(config);
        test_scenario::return_shared(sui_pool);
        test_scenario::return_to_sender(scenario, storage_admin_cap);
    }

    #[test_only]
    public fun pass_time_and_update_price(scenario: &mut Scenario, _clock: &mut Clock, time: u64, asset:u8, price:u256) {
        // 1 year past, same price updated
        let stg = test_scenario::take_shared<Storage>(scenario);
        let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
        let oracle_feeder_cap = test_scenario::take_from_sender<OracleFeederCap>(scenario);

        clock::increment_for_testing( _clock, time);
        oracle::update_token_price(
            &oracle_feeder_cap,
            _clock,
            &mut price_oracle,
            asset,
            price,
        );

        test_scenario::return_shared(stg);
        test_scenario::return_shared(price_oracle);
        test_scenario::return_to_sender(scenario, oracle_feeder_cap);
    }
}