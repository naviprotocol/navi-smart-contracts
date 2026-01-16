#[test_only]
module lending_core::manage_test {
    use std::string;
    use std::debug::print;
    use sui::coin;
    use sui::balance;
    use sui::clock::{Self, Clock};
    use sui::test_scenario::{Self, Scenario};
    use sui::object::{ID};

    use lending_core::lib;
    use lending_core::logic;
    use lending_core::base;
    use lending_core::lending;
    use lending_core::manage;
    use lending_core::base_lending_tests;
    use lending_core::pool::{Self, Pool};
    use lending_core::sui_test::{Self, SUI_TEST};
    use lending_core::eth_test::{Self, ETH_TEST};
    use lending_core::usdt_test::{Self, USDT_TEST};
    use lending_core::usdc_test::{Self, USDC_TEST};
    use lending_core::test_coin::{Self, TEST_COIN};
    use lending_core::storage::{Self, StorageAdminCap, Storage};
    use lending_core::flash_loan::{Self, Config as FlashLoanConfig, get_asset};

    use oracle::oracle::{Self, PriceOracle, OracleFeederCap};

    const OWNER: address = @0xA;

    const USER_A: address = @0xB;
    const USER_B: address = @0xC;

    const SUI_ASSET_ID: u8 = 0;
    const USDC_ASSET_ID: u8 = 1;
    const USDT_ASSET_ID: u8 = 2;

    // Should set rate for different assets
    #[test]
    public fun test_set_asset_rate_to_supplier() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };  

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(&scenario);

            manage::set_flash_loan_asset_rate_to_supplier<SUI_TEST>(&storage_admin_cap, &mut config, 100);
            manage::set_flash_loan_asset_rate_to_supplier<USDC_TEST>(&storage_admin_cap, &mut config, 200);

            test_scenario::return_shared(config);
            test_scenario::return_to_sender(&scenario, storage_admin_cap);
        };

        //check after set rate
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let config = test_scenario::take_shared<FlashLoanConfig>(&scenario);

            let (_, _, _, _, rate_to_supplier1, _, _, _) = get_asset<SUI_TEST>(&config);
            let (_, _, _, _, rate_to_supplier2, _, _, _) = get_asset<USDC_TEST>(&config);

            assert!(rate_to_supplier1 == 100, 0);
            assert!(rate_to_supplier2 == 200, 0);

            test_scenario::return_shared(config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    // Should fail if _coin_type is invalid
    #[test]
    #[expected_failure(abort_code = 2000, location = lending_core::flash_loan)]
    public fun test_set_asset_rate_to_supplier_fail_if_coin_type_invalid() {
         let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };  

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(&scenario);

            manage::set_flash_loan_asset_rate_to_supplier<TEST_COIN>(&storage_admin_cap, &mut config, 200);

            test_scenario::return_shared(config);
            test_scenario::return_to_sender(&scenario, storage_admin_cap);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    // Should fail if rate_to_supplier + rate_to_treasury > 10000
    #[test]
    #[expected_failure(abort_code = 1503, location = lending_core::flash_loan)]
    public fun test_set_rate_fail_if_too_much() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };  

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(&scenario);

            manage::set_flash_loan_asset_rate_to_supplier<SUI_TEST>(&storage_admin_cap, &mut config, 10000);
            manage::set_flash_loan_asset_rate_to_treasury<SUI_TEST>(&storage_admin_cap, &mut config, 10000);

            test_scenario::return_shared(config);
            test_scenario::return_to_sender(&scenario, storage_admin_cap);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    // Should set rate for different assets
    #[test]
    public fun test_set_asset_rate_to_treasury() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };  

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(&scenario);

            manage::set_flash_loan_asset_rate_to_treasury<SUI_TEST>(&storage_admin_cap, &mut config, 100);
            manage::set_flash_loan_asset_rate_to_treasury<USDC_TEST>(&storage_admin_cap, &mut config, 200);

            test_scenario::return_shared(config);
            test_scenario::return_to_sender(&scenario, storage_admin_cap);
        };

        //check after set rate
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let config = test_scenario::take_shared<FlashLoanConfig>(&scenario);

            let (_, _, _, _, _, rate_to_treasury1, _, _) = get_asset<SUI_TEST>(&config);
            let (_, _, _, _, _, rate_to_treasury2, _, _) = get_asset<USDC_TEST>(&config);

            assert!(rate_to_treasury1 == 100, 0);
            assert!(rate_to_treasury2 == 200, 0);

            test_scenario::return_shared(config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1503, location = lending_core::flash_loan)]
    public fun test_set_min_and_set_max() 
    {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };  
        // Should set min max for different assets
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(&scenario);

            manage::set_flash_loan_asset_min<SUI_TEST>(&storage_admin_cap, &mut config, 1000000);
            manage::set_flash_loan_asset_max<SUI_TEST>(&storage_admin_cap, &mut config, 1000_000000);

            manage::set_flash_loan_asset_min<USDC_TEST>(&storage_admin_cap, &mut config, 2000000);
            manage::set_flash_loan_asset_max<USDC_TEST>(&storage_admin_cap, &mut config, 2000_000000);

        
            test_scenario::return_shared(config);
            test_scenario::return_to_sender(&scenario, storage_admin_cap);
        };

        //check after set min and set max
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let config = test_scenario::take_shared<FlashLoanConfig>(&scenario);

            let (_, _, _, _, _, _, max1, min1) = get_asset<SUI_TEST>(&config);
            let (_, _, _, _, _, _, max2, min2) = get_asset<USDC_TEST>(&config);

            // Should set min max for different assets
            assert!(min1 == 1000000, 0);
            assert!(max1 == 1000_000000, 0);
            assert!(min2 == 2000000, 0);
            assert!(max2 == 2000_000000, 0);

            test_scenario::return_shared(config);
        };

        // should flash loan fail if amount do not between min and max
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

            let loan_amount = 1;
            let (loan_balance, receipt) = lending::flash_loan_with_ctx<SUI_TEST>(&flash_loan_config, &mut sui_pool, loan_amount, test_scenario::ctx(&mut scenario));

            let (user, _, amount, pool, fee_to_supplier, fee_to_treasury) = flash_loan::parsed_receipt<SUI_TEST>(&receipt);
            let coin = coin::mint_for_testing<SUI_TEST>(fee_to_supplier + fee_to_treasury , test_scenario::ctx(&mut scenario));
            let total_fee = coin::into_balance(coin);
            balance::join(&mut loan_balance, total_fee);
            let excess_balance = lending::flash_repay_with_ctx<SUI_TEST>(&_clock, &mut storage, &mut sui_pool, receipt, loan_balance, test_scenario::ctx(&mut scenario));

            balance::destroy_for_testing(excess_balance);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(sui_pool);
            test_scenario::return_shared(flash_loan_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }
    // should fail if max < min
     #[test]
    #[expected_failure(abort_code = 1503, location = lending_core::flash_loan)]
    public fun test_set_max_fail_if_min_greater_than_max() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };  

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(&scenario);

            manage::set_flash_loan_asset_min<SUI_TEST>(&storage_admin_cap, &mut config, 1000000);
            manage::set_flash_loan_asset_max<SUI_TEST>(&storage_admin_cap, &mut config, 10);

            test_scenario::return_shared(config);
            test_scenario::return_to_sender(&scenario, storage_admin_cap);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }
    // should fail if max < min
    #[test]
    #[expected_failure(abort_code = 1503, location = lending_core::flash_loan)]
    public fun test_set_min_fail_if_min_greater_than_max() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };  

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(&scenario);

            manage::set_flash_loan_asset_max<SUI_TEST>(&storage_admin_cap, &mut config, 10);
            manage::set_flash_loan_asset_min<SUI_TEST>(&storage_admin_cap, &mut config, 10000000);

            test_scenario::return_shared(config);
            test_scenario::return_to_sender(&scenario, storage_admin_cap);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }
    // should flash loan fail if amount do not between min and max
    #[test]
    #[expected_failure(abort_code = 1503, location = lending_core::flash_loan)]
    public fun test_flash_loan_fail_if_amount_greater_than_max() 
    {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        };  

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(&scenario);

            manage::set_flash_loan_asset_min<USDC_TEST>(&storage_admin_cap, &mut config, 2000000);
            manage::set_flash_loan_asset_max<USDC_TEST>(&storage_admin_cap, &mut config, 2000_000000);

        
            test_scenario::return_shared(config);
            test_scenario::return_to_sender(&scenario, storage_admin_cap);
        };

        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let sui_pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);

            let loan_amount = 3000_000000;
            let (loan_balance, receipt) = lending::flash_loan_with_ctx<USDC_TEST>(&flash_loan_config, &mut sui_pool, loan_amount, test_scenario::ctx(&mut scenario));

            let (user, _, amount, pool, fee_to_supplier, fee_to_treasury) = flash_loan::parsed_receipt<USDC_TEST>(&receipt);
            let coin = coin::mint_for_testing<USDC_TEST>(fee_to_supplier + fee_to_treasury , test_scenario::ctx(&mut scenario));
            let total_fee = coin::into_balance(coin);
            balance::join(&mut loan_balance, total_fee);
            let excess_balance = lending::flash_repay_with_ctx<USDC_TEST>(&_clock, &mut storage, &mut sui_pool, receipt, loan_balance, test_scenario::ctx(&mut scenario));

            balance::destroy_for_testing(excess_balance);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(sui_pool);
            test_scenario::return_shared(flash_loan_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    // perform flashloan with default fee rate then change fee to a larger rate, perform flashloan
    #[test]
    public fun test_flash_loan_should_correctly_with_larger_rate()
    {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        }; 

        // deposit 1m Sui
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            deposit_in_empty_pool_for_testing<SUI_TEST>(&mut scenario, &_clock, SUI_ASSET_ID, 1000000_000000000);
        };
        // flash loan 3000 Sui with default fee rate
        let supply_index_diff_in_first_time_flash_loan = 0;
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let (total_supple, _) = storage::get_total_supply(&mut storage, SUI_ASSET_ID);

            let (_before_supply_index, _) = storage::get_index(&mut storage, SUI_ASSET_ID);

            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

            let loan_amount = 3000_000000000;
            let (loan_balance, receipt) = lending::flash_loan_with_ctx<SUI_TEST>(&flash_loan_config, &mut sui_pool, loan_amount, test_scenario::ctx(&mut scenario));

            let (user, _, amount, pool, fee_to_supplier, fee_to_treasury) = flash_loan::parsed_receipt<SUI_TEST>(&receipt);
 
            assert!(fee_to_supplier == 4_800000000, 0);
            assert!(fee_to_treasury == 1_200000000, 0);

            let coin = coin::mint_for_testing<SUI_TEST>(fee_to_supplier + fee_to_treasury , test_scenario::ctx(&mut scenario));
            let total_fee = coin::into_balance(coin);
            balance::join(&mut loan_balance, total_fee);
            let excess_balance = lending::flash_repay_with_ctx<SUI_TEST>(&_clock, &mut storage, &mut sui_pool, receipt, loan_balance, test_scenario::ctx(&mut scenario));

            assert!(balance::value(&excess_balance) == 0, 0);

            let (supply_index, _) = storage::get_index(&mut storage, SUI_ASSET_ID);
            let supply_diff_on_first_flash_loan = supply_index - _before_supply_index;

            balance::destroy_for_testing(excess_balance);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(sui_pool);
            test_scenario::return_shared(flash_loan_config);
        };
        // set rate_to_supplier and rate_to_treasury
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(&scenario);

            manage::set_flash_loan_asset_rate_to_treasury<SUI_TEST>(&storage_admin_cap, &mut config, 0);
            manage::set_flash_loan_asset_rate_to_supplier<SUI_TEST>(&storage_admin_cap, &mut config, 9999);

            test_scenario::return_shared(config);
            test_scenario::return_to_sender(&scenario, storage_admin_cap);
        };

        // flash loan 3000 Sui with largest rate_to_supplier and zero rate_to_treasury
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);
            let (_before_supply_index, _before_borrow_index) = storage::get_index(&mut storage, SUI_ASSET_ID);
            let (_before_pool_balance, _before_pool_tresaury_balance, _) = pool::get_pool_info(&sui_pool);

            let loan_amount = 3000_000000000;
            let (loan_balance, receipt) = lending::flash_loan_with_ctx<SUI_TEST>(&flash_loan_config, &mut sui_pool, loan_amount, test_scenario::ctx(&mut scenario));

            // check fee 
            let (user, _, amount, pool, fee_to_supplier, fee_to_treasury) = flash_loan::parsed_receipt<SUI_TEST>(&receipt);
            let expect_supply_fee = 2999_700000000;
            assert!(fee_to_supplier == expect_supply_fee, 0);
            assert!(fee_to_treasury == 0, 0);
            assert!(amount == 3000_000000000, 0);

            let coin = coin::mint_for_testing<SUI_TEST>(fee_to_supplier + fee_to_treasury , test_scenario::ctx(&mut scenario));
            let total_fee = coin::into_balance(coin);
            balance::join(&mut loan_balance, total_fee);

            let excess_balance = lending::flash_repay_with_ctx<SUI_TEST>(&_clock, &mut storage, &mut sui_pool, receipt, loan_balance, test_scenario::ctx(&mut scenario));

            assert!(balance::value(&excess_balance) == 0, 0);

            // check index
            let (supply_index, borrow_index) = storage::get_index(&mut storage, SUI_ASSET_ID);
            let actual_supply_index_diff = supply_index - _before_supply_index;

            assert!(_before_borrow_index == borrow_index, 0);
            assert!(_before_supply_index < supply_index, 0);
            assert!(supply_index_diff_in_first_time_flash_loan < actual_supply_index_diff, 0);

            let d = std::string::utf8(b"test_flash_loan_should_correctly_with_larger_rate");
            std::debug::print(&d);
            let (total_supply, _) = storage::get_total_supply(&mut storage, SUI_ASSET_ID);
            let actual_amount = math::ray_math::ray_div((expect_supply_fee as u256), _before_supply_index);// 2999700000000 / 1000004800000000000000000000 = 2999685601509
            print(&actual_amount);
            print(&total_supply);//1e15
            print(&_before_supply_index);// 1000004800000000000000000000
            let expect_supply_index_diff = math::ray_math::ray_mul(math::ray_math::ray_div(actual_amount, total_supply), _before_supply_index);//2999.7 * 1e21
            print(&expect_supply_index_diff);// 2999699999999887243200000

            assert!(expect_supply_index_diff == actual_supply_index_diff, 0);

            //check balance in pool
            let (pool_balance, pool_tresaury_balance, _) = pool::get_pool_info(&sui_pool);
            assert!(pool_balance == _before_pool_balance + expect_supply_fee, 0);
            assert!(pool_tresaury_balance == _before_pool_tresaury_balance, 0);


            balance::destroy_for_testing(excess_balance);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(sui_pool);
            test_scenario::return_shared(flash_loan_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    // perform flashloan with default fee rate then change fee to 0, perform flashloan
    #[test]
    public fun test_flash_loan_should_correctly_with_zero_rate()
    {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        }; 

        // deposit 1m Sui
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            deposit_in_empty_pool_for_testing<SUI_TEST>(&mut scenario, &_clock, SUI_ASSET_ID, 1000000_000000000);
        };
        // flash loan 1000 Sui with default fee rate
        let supply_index_diff_in_first_time_flash_loan = 0;
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let (total_supple, _) = storage::get_total_supply(&mut storage, SUI_ASSET_ID);

            let (_before_supply_index, _) = storage::get_index(&mut storage, SUI_ASSET_ID);

            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

            let loan_amount = 1000_000000000;
            let (loan_balance, receipt) = lending::flash_loan_with_ctx<SUI_TEST>(&flash_loan_config, &mut sui_pool, loan_amount, test_scenario::ctx(&mut scenario));

            let (user, _, amount, pool, fee_to_supplier, fee_to_treasury) = flash_loan::parsed_receipt<SUI_TEST>(&receipt);

            assert!(fee_to_supplier == 1_600000000, 0);
            assert!(fee_to_treasury == 400000000, 0);

            let coin = coin::mint_for_testing<SUI_TEST>(fee_to_supplier + fee_to_treasury , test_scenario::ctx(&mut scenario));
            let total_fee = coin::into_balance(coin);
            balance::join(&mut loan_balance, total_fee);
            let excess_balance = lending::flash_repay_with_ctx<SUI_TEST>(&_clock, &mut storage, &mut sui_pool, receipt, loan_balance, test_scenario::ctx(&mut scenario));

            assert!(balance::value(&excess_balance) == 0, 0);

            let (supply_index, _) = storage::get_index(&mut storage, SUI_ASSET_ID);
            let supply_diff_on_first_flash_loan = supply_index - _before_supply_index;

            balance::destroy_for_testing(excess_balance);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(sui_pool);
            test_scenario::return_shared(flash_loan_config);
        };
        // set rate_to_supplier and rate_to_treasury
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(&scenario);

            manage::set_flash_loan_asset_rate_to_supplier<SUI_TEST>(&storage_admin_cap, &mut config, 0);
            manage::set_flash_loan_asset_rate_to_treasury<SUI_TEST>(&storage_admin_cap, &mut config, 9999);

            test_scenario::return_shared(config);
            test_scenario::return_to_sender(&scenario, storage_admin_cap);
        };

        // flash loan 1000 Sui  with zero rate_to_supplier and largest rate_to_treasury
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

            let (_before_supply_index, _before_borrow_index) = storage::get_index(&mut storage, SUI_ASSET_ID);
            let (_before_pool_balance, _before_pool_tresaury_balance, _) = pool::get_pool_info(&sui_pool);

            let loan_amount = 1000000000000;
            let (loan_balance, receipt) = lending::flash_loan_with_ctx<SUI_TEST>(&flash_loan_config, &mut sui_pool, loan_amount, test_scenario::ctx(&mut scenario));

            // check fee 
            let expect_treasury_fee = 999_900000000;
            let (user, _, amount, pool, fee_to_supplier, fee_to_treasury) = flash_loan::parsed_receipt<SUI_TEST>(&receipt);
            assert!(fee_to_supplier == 0, 0);
            assert!(fee_to_treasury == expect_treasury_fee, 0);

            let coin = coin::mint_for_testing<SUI_TEST>(fee_to_supplier + fee_to_treasury , test_scenario::ctx(&mut scenario));
            let total_fee = coin::into_balance(coin);
            balance::join(&mut loan_balance, total_fee);

            let excess_balance = lending::flash_repay_with_ctx<SUI_TEST>(&_clock, &mut storage, &mut sui_pool, receipt, loan_balance, test_scenario::ctx(&mut scenario));

            assert!(balance::value(&excess_balance) == 0, 0);

            // check index
            let (supply_index, borrow_index) = storage::get_index(&mut storage, SUI_ASSET_ID);
            assert!(_before_borrow_index == borrow_index, 0);
            assert!(_before_supply_index == supply_index, 0);

            //check balance in pool
            let (pool_balance, pool_tresaury_balance, _) = pool::get_pool_info(&sui_pool);
            assert!(pool_balance == _before_pool_balance, 0);
            assert!(pool_tresaury_balance == _before_pool_tresaury_balance + expect_treasury_fee, 0);


            balance::destroy_for_testing(excess_balance);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(sui_pool);
            test_scenario::return_shared(flash_loan_config);
        };
        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }

    /*
        1.flash loan for more than 2 assets, check fee 
        2.set supplier rate、treasury rate for one asset
        3.flash loan for all assets, check fee, check index
    */
    #[test]
    public fun test_flash_loan_after_set_rate_integration() {
        let scenario = test_scenario::begin(OWNER);
        let _clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        {
            base::initial_protocol(&mut scenario, &_clock);
        }; 

        //create USDT_TEST flash loan asset
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(&scenario);
            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let pool = test_scenario::take_shared<Pool<USDT_TEST>>(&scenario);

            manage::create_flash_loan_asset<USDT_TEST>(
                &storage_admin_cap,
                &mut flash_loan_config,
                &storage,
                &pool,
                USDT_ASSET_ID, // asset id
                15, //rate to supplier
                5, //rate to reasury
                100000_000000000, // max: 100k
                0, // min: 1
                test_scenario::ctx(&mut scenario)
            );
            test_scenario::return_shared(pool);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(flash_loan_config);
            test_scenario::return_to_sender(&scenario, storage_admin_cap);
        };

        // deposit 1m Sui
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            deposit_in_empty_pool_for_testing<SUI_TEST>(&mut scenario, &_clock, SUI_ASSET_ID, 10000000_000000000);
        };
       // deposit 100k USDC
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            deposit_in_empty_pool_for_testing<USDC_TEST>(&mut scenario, &_clock, USDC_ASSET_ID, 1000000_000000);
        };
       // deposit 10k USDT
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            deposit_in_empty_pool_for_testing<USDT_TEST>(&mut scenario, &_clock, USDT_ASSET_ID, 100000_000000);
        };

        let fee_to_supplier_on_first_flash_loan_sui = 0;
        let fee_to_treasury_on_first_flash_loan_sui = 0;
        let supply_diff_on_first_flash_loan_sui = 0;
        //First flash loan: 200 Sui
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let (total_supple, _) = storage::get_total_supply(&mut storage, SUI_ASSET_ID);

            let (_before_supply_index, _) = storage::get_index(&mut storage, SUI_ASSET_ID);

            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

            let loan_amount = 200_000000000;
            let (loan_balance, receipt) = lending::flash_loan_with_ctx<SUI_TEST>(&flash_loan_config, &mut sui_pool, loan_amount, test_scenario::ctx(&mut scenario));

            let (user, _, amount, _, fee_to_supplier, fee_to_treasury) = flash_loan::parsed_receipt<SUI_TEST>(&receipt);

            fee_to_supplier_on_first_flash_loan_sui = fee_to_supplier;
            fee_to_treasury_on_first_flash_loan_sui = fee_to_treasury;
            
            assert!(fee_to_supplier_on_first_flash_loan_sui == 320000000, 0);
            assert!(fee_to_treasury_on_first_flash_loan_sui == 80000000, 0);

            let coin = coin::mint_for_testing<SUI_TEST>(fee_to_supplier_on_first_flash_loan_sui + fee_to_treasury_on_first_flash_loan_sui , test_scenario::ctx(&mut scenario));
            let total_fee = coin::into_balance(coin);
            balance::join(&mut loan_balance, total_fee);
            let excess_balance = lending::flash_repay_with_ctx<SUI_TEST>(&_clock, &mut storage, &mut sui_pool, receipt, loan_balance, test_scenario::ctx(&mut scenario));

            assert!(balance::value(&excess_balance) == 0, 0);

            let (supply_index, _) = storage::get_index(&mut storage, SUI_ASSET_ID);
            supply_diff_on_first_flash_loan_sui = supply_index - _before_supply_index;

            balance::destroy_for_testing(excess_balance);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(sui_pool);
            test_scenario::return_shared(flash_loan_config);
        };

        let fee_to_supplier_on_first_flash_loan_usdc = 0;
        let fee_to_treasury_on_first_flash_loan_usdc = 0;
        let supply_diff_on_first_flash_loan_usdc = 0;
        //Frist flash loan: 80 USDC
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let (total_supple, _) = storage::get_total_supply(&mut storage, USDC_ASSET_ID);

            let (_before_supply_index, _) = storage::get_index(&mut storage, USDC_ASSET_ID);

            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);

            let loan_amount = 80_000000;
            let (loan_balance, receipt) = lending::flash_loan_with_ctx<USDC_TEST>(&flash_loan_config, &mut pool, loan_amount, test_scenario::ctx(&mut scenario));

            let (user, _, amount, _, fee_to_supplier, fee_to_treasury) = flash_loan::parsed_receipt<USDC_TEST>(&receipt);
            fee_to_supplier_on_first_flash_loan_usdc = fee_to_supplier;
            fee_to_treasury_on_first_flash_loan_usdc = fee_to_treasury;


            assert!(fee_to_supplier_on_first_flash_loan_usdc == 128000, 0);
            assert!(fee_to_treasury_on_first_flash_loan_usdc == 32000, 0);

            let coin = coin::mint_for_testing<USDC_TEST>(fee_to_supplier_on_first_flash_loan_usdc + fee_to_treasury_on_first_flash_loan_usdc , test_scenario::ctx(&mut scenario));
            let total_fee = coin::into_balance(coin);
            balance::join(&mut loan_balance, total_fee);
            let excess_balance = lending::flash_repay_with_ctx<USDC_TEST>(&_clock, &mut storage, &mut pool, receipt, loan_balance, test_scenario::ctx(&mut scenario));

            assert!(balance::value(&excess_balance) == 0, 0);

            let (supply_index, _) = storage::get_index(&mut storage, USDC_ASSET_ID);
            supply_diff_on_first_flash_loan_usdc = supply_index - _before_supply_index;

            balance::destroy_for_testing(excess_balance);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(flash_loan_config);
        };

        let fee_to_supplier_on_first_flash_loan_usdt = 0;
        let fee_to_treasury_on_first_flash_loan_usdt = 0;
        let supply_diff_on_first_flash_loan_usdt = 0;
        //First flash loan: 30 USDT
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let (total_supple, _) = storage::get_total_supply(&mut storage, USDT_ASSET_ID);

            let (_before_supply_index, _) = storage::get_index(&mut storage, USDT_ASSET_ID);

            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let pool = test_scenario::take_shared<Pool<USDT_TEST>>(&scenario);

            let loan_amount = 30_000000;
            let (loan_balance, receipt) = lending::flash_loan_with_ctx<USDT_TEST>(&flash_loan_config, &mut pool, loan_amount, test_scenario::ctx(&mut scenario));

            let (user, _, amount, _, fee_to_supplier, fee_to_treasury) = flash_loan::parsed_receipt<USDT_TEST>(&receipt);
            fee_to_supplier_on_first_flash_loan_usdt = fee_to_supplier;
            fee_to_treasury_on_first_flash_loan_usdt = fee_to_treasury;

            assert!(fee_to_supplier_on_first_flash_loan_usdt == 45000, 0);
            assert!(fee_to_treasury_on_first_flash_loan_usdt == 15000, 0);

            let coin = coin::mint_for_testing<USDT_TEST>(fee_to_supplier_on_first_flash_loan_usdt + fee_to_treasury_on_first_flash_loan_usdt , test_scenario::ctx(&mut scenario));
            let total_fee = coin::into_balance(coin);
            balance::join(&mut loan_balance, total_fee);
            let excess_balance = lending::flash_repay_with_ctx<USDT_TEST>(&_clock, &mut storage, &mut pool, receipt, loan_balance, test_scenario::ctx(&mut scenario));

            assert!(balance::value(&excess_balance) == 0, 0);

            let (supply_index, _) = storage::get_index(&mut storage, USDT_ASSET_ID);
            supply_diff_on_first_flash_loan_usdt = supply_index - _before_supply_index;

            balance::destroy_for_testing(excess_balance);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(flash_loan_config);
        };

        // set rate_to_supplier=300 and rate_to_tresury=1 for USDT asset
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(&scenario);

            manage::set_flash_loan_asset_rate_to_supplier<USDT_TEST>(&storage_admin_cap, &mut config, 300);
            manage::set_flash_loan_asset_rate_to_treasury<USDT_TEST>(&storage_admin_cap, &mut config, 1);

            test_scenario::return_shared(config);
            test_scenario::return_to_sender(&scenario, storage_admin_cap);
        };

        //Second flash loan: 200 Sui
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let (total_supple, _) = storage::get_total_supply(&mut storage, SUI_ASSET_ID);

            let (_before_supply_index, _before_borrow_index) = storage::get_index(&mut storage, SUI_ASSET_ID);

            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&scenario);

            let loan_amount = 200_000000000;
            let (loan_balance, receipt) = lending::flash_loan_with_ctx<SUI_TEST>(&flash_loan_config, &mut sui_pool, loan_amount, test_scenario::ctx(&mut scenario));

            let (user, _, amount, _, fee_to_supplier, fee_to_treasury) = flash_loan::parsed_receipt<SUI_TEST>(&receipt);

            //check fee
            assert!(fee_to_supplier == fee_to_supplier_on_first_flash_loan_sui, 0);
            assert!(fee_to_treasury == fee_to_treasury_on_first_flash_loan_sui, 0);

            let coin = coin::mint_for_testing<SUI_TEST>(fee_to_supplier + fee_to_treasury , test_scenario::ctx(&mut scenario));
            let total_fee = coin::into_balance(coin);
            balance::join(&mut loan_balance, total_fee);
            let excess_balance = lending::flash_repay_with_ctx<SUI_TEST>(&_clock, &mut storage, &mut sui_pool, receipt, loan_balance, test_scenario::ctx(&mut scenario));

            assert!(balance::value(&excess_balance) == 0, 0);

            let (supply_index, borrow_index) = storage::get_index(&mut storage, SUI_ASSET_ID);
            let supply_diff_on_second_flash_loan = supply_index - _before_supply_index;

            //check index
            assert!(_before_borrow_index == borrow_index, 0);
            assert!(_before_supply_index < supply_index, 0);
            // Difference caused by rounding
            lib::close_to(supply_diff_on_first_flash_loan_sui, supply_diff_on_second_flash_loan, 60000000000);

            balance::destroy_for_testing(excess_balance);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(sui_pool);
            test_scenario::return_shared(flash_loan_config);
        };

        // Sencond flash loan: 80 USDC
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let (total_supple, _) = storage::get_total_supply(&mut storage, USDC_ASSET_ID);

            let (_before_supply_index, _before_borrow_index) = storage::get_index(&mut storage, USDC_ASSET_ID);

            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let pool = test_scenario::take_shared<Pool<USDC_TEST>>(&scenario);

            let loan_amount = 80_000000;
            let (loan_balance, receipt) = lending::flash_loan_with_ctx<USDC_TEST>(&flash_loan_config, &mut pool, loan_amount, test_scenario::ctx(&mut scenario));

            let (user, _, amount, _, fee_to_supplier, fee_to_treasury) = flash_loan::parsed_receipt<USDC_TEST>(&receipt);
            // check fee
            assert!(fee_to_supplier == fee_to_supplier_on_first_flash_loan_usdc, 0);
            assert!(fee_to_treasury == fee_to_treasury_on_first_flash_loan_usdc, 0);

            let coin = coin::mint_for_testing<USDC_TEST>(fee_to_supplier + fee_to_treasury , test_scenario::ctx(&mut scenario));
            let total_fee = coin::into_balance(coin);
            balance::join(&mut loan_balance, total_fee);
            let excess_balance = lending::flash_repay_with_ctx<USDC_TEST>(&_clock, &mut storage, &mut pool, receipt, loan_balance, test_scenario::ctx(&mut scenario));

            assert!(balance::value(&excess_balance) == 0, 0);

            let (supply_index, borrow_index) = storage::get_index(&mut storage, USDC_ASSET_ID);
            let supply_diff_on_sencond_flash_loan_usdc = supply_index - _before_supply_index;

            // check index 
            assert!(_before_borrow_index == borrow_index, 0);
            assert!(_before_supply_index < supply_index, 0);
            lib::close_to(supply_diff_on_sencond_flash_loan_usdc, supply_diff_on_first_flash_loan_usdc, 600000000000);

            balance::destroy_for_testing(excess_balance);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(flash_loan_config);
        };

        //Sencond flash loan: 30 USDT, The rate has been modified.  
        test_scenario::next_tx(&mut scenario, OWNER);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let (total_supple, _) = storage::get_total_supply(&mut storage, USDT_ASSET_ID);

            let (_before_supply_index, _before_borrow_index) = storage::get_index(&mut storage, USDT_ASSET_ID);

            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&scenario);
            let pool = test_scenario::take_shared<Pool<USDT_TEST>>(&scenario);

            let loan_amount = 30_000000;
            let (loan_balance, receipt) = lending::flash_loan_with_ctx<USDT_TEST>(&flash_loan_config, &mut pool, loan_amount, test_scenario::ctx(&mut scenario));

            let (user, _, amount, _, fee_to_supplier, fee_to_treasury) = flash_loan::parsed_receipt<USDT_TEST>(&receipt);

            // check fee
            assert!(fee_to_supplier_on_first_flash_loan_usdt < fee_to_supplier, 0); 
            assert!(fee_to_treasury_on_first_flash_loan_usdt > fee_to_treasury, 0); 
            assert!(fee_to_supplier == 900000, 0);// rate 300 
            assert!(fee_to_treasury == 3000, 0);// rate 1

            let coin = coin::mint_for_testing<USDT_TEST>(fee_to_supplier + fee_to_treasury , test_scenario::ctx(&mut scenario));
            let total_fee = coin::into_balance(coin);
            balance::join(&mut loan_balance, total_fee);
            let excess_balance = lending::flash_repay_with_ctx<USDT_TEST>(&_clock, &mut storage, &mut pool, receipt, loan_balance, test_scenario::ctx(&mut scenario));

            assert!(balance::value(&excess_balance) == 0, 0);

            let (supply_index, borrow_index) = storage::get_index(&mut storage, USDT_ASSET_ID);
            let supply_diff_on_second_flash_loan_usdt = supply_index - _before_supply_index;

            // check index
            assert!(_before_borrow_index == borrow_index, 0);
            assert!(_before_supply_index < supply_index, 0);
            assert!(supply_diff_on_second_flash_loan_usdt > supply_diff_on_first_flash_loan_usdt, 0);


            let d = std::string::utf8(b"test_flash_loan_after_set_rate_integration");
            std::debug::print(&d);
            print(&supply_index); // 1000009449999999998177500000
            let (total_supply, _) = storage::get_total_supply(&mut storage, USDT_ASSET_ID);
            let actual_amount = math::ray_math::ray_div((900000000 as u256), _before_supply_index);
            print(&actual_amount); // 899999595
            print(&total_supply); // 1e14
            print(&_before_supply_index); // 1000000450000000000000000000
            print(&supply_diff_on_first_flash_loan_usdt); // 450000000000000000000
            let expect_supply_index_diff = math::ray_math::ray_mul(math::ray_math::ray_div(actual_amount, total_supply), _before_supply_index);
            print(&expect_supply_index_diff);// 8999999999998177500000

            assert!(supply_diff_on_second_flash_loan_usdt == expect_supply_index_diff, 0);


            balance::destroy_for_testing(excess_balance);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(flash_loan_config);
        };

        clock::destroy_for_testing(_clock);
        test_scenario::end(scenario);
    }
    /* 
        This integration test is divided into three methods, namely test_borrow_without_flash_loan、test_borrow_with_empty_flash_loan_rate and test_borrow_with_non_empty_flash_loan_rate
        The above three methods should result the same user balance.

        1.UserA deposit 100k
        2.UserA borrow 50 Sui
        3.1 year passed
        4.UserA borrow 100 Sui
    */
    #[test]
    public fun test_borrow_without_flash_loan() {
        let user_a_scenario = test_scenario::begin(USER_A);
        let user_a_test_clock = clock::create_for_testing(test_scenario::ctx(&mut user_a_scenario));
        clock::set_for_testing(&mut user_a_test_clock, 1704038400000);
        {
            base::initial_protocol(&mut user_a_scenario, &user_a_test_clock);
        };

        // UserA deposit 100k 
        test_scenario::next_tx(&mut user_a_scenario, USER_A);
        {
            deposit_in_empty_pool_for_testing<SUI_TEST>(&mut user_a_scenario, &user_a_test_clock, SUI_ASSET_ID, 100000_000000000);
        };

        // UserA borrow 50 Sui
        test_scenario::next_tx(&mut user_a_scenario, USER_A);
        {
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&user_a_scenario);

            base_lending_tests::base_borrow_for_testing(&mut user_a_scenario, &user_a_test_clock, &mut sui_pool, SUI_ASSET_ID, 50_000000000);

            test_scenario::return_shared(sui_pool);
        };

        // 1 year passed
        test_scenario::next_tx(&mut user_a_scenario, USER_A);
        {
            let stg = test_scenario::take_shared<Storage>(&user_a_scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&user_a_scenario);
            let oracle_feeder_cap = test_scenario::take_from_sender<OracleFeederCap>(&user_a_scenario);

            clock::increment_for_testing(&mut user_a_test_clock, 86400 * 1000 * 365);
            oracle::update_token_price(
                &oracle_feeder_cap,
                &user_a_test_clock,
                &mut price_oracle,
                0,
                500000000,
            );

            test_scenario::return_shared(stg);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_to_sender(&user_a_scenario, oracle_feeder_cap);

        };

        // UserA borrow 100 Sui
        test_scenario::next_tx(&mut user_a_scenario, USER_A);
        {
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&user_a_scenario);

            base_lending_tests::base_borrow_for_testing(&mut user_a_scenario, &user_a_test_clock, &mut sui_pool, SUI_ASSET_ID, 100_000000000);

            test_scenario::return_shared(sui_pool);
        };
        
        // check user balance and check pool balance
        test_scenario::next_tx(&mut user_a_scenario, USER_A);
        {
            let storage = test_scenario::take_shared<Storage>(&user_a_scenario);
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&user_a_scenario);

            let (user_a_sui_supply, user_a_sui_borrow) = storage::get_user_balance(&mut storage, SUI_ASSET_ID, USER_A);
            lib::close_to(user_a_sui_supply, 100000_000000000, 1);
            lib::close_to(user_a_sui_borrow, 149994182169, 1);

            let (sui_balance, treasury_balance, _) = pool::get_pool_info(&sui_pool);
            assert!(sui_balance == 99850_000000000, 0);
            assert!(treasury_balance == 0, 0);

            let d = std::string::utf8(b"974 test_borrow_without_flash_loan");
            std::debug::print(&d);
            std::debug::print(&user_a_sui_supply);
            std::debug::print(&user_a_sui_borrow);

            test_scenario::return_shared(storage);
            test_scenario::return_shared(sui_pool);
        };
        clock::destroy_for_testing(user_a_test_clock);
        test_scenario::end(user_a_scenario);
    }  
    
    /* 
        1.UserA deposit 100k
        2.UserA borrow 50 Sui
        3.1 year passed
        4.set rate_to_supplier=0 and rate_to_treasury=0
        5.UserA flash loan 10 Sui
        6.UserA borrow 100 Sui
    */
    #[test]
    public fun test_borrow_with_empty_flash_loan_rate() {
        let user_a_scenario = test_scenario::begin(USER_A);
        let user_a_test_clock = clock::create_for_testing(test_scenario::ctx(&mut user_a_scenario));
        clock::set_for_testing(&mut user_a_test_clock, 1704038400000);
        {
            base::initial_protocol(&mut user_a_scenario, &user_a_test_clock);
        };

        // UserA deposit 100k 
        test_scenario::next_tx(&mut user_a_scenario, USER_A);
        {
            deposit_in_empty_pool_for_testing<SUI_TEST>(&mut user_a_scenario, &user_a_test_clock, SUI_ASSET_ID, 100000_000000000);
        };

        // UserA borrow 50 Sui
        test_scenario::next_tx(&mut user_a_scenario, USER_A);
        {
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&user_a_scenario);

            base_lending_tests::base_borrow_for_testing(&mut user_a_scenario, &user_a_test_clock, &mut sui_pool, SUI_ASSET_ID, 50_000000000);

            test_scenario::return_shared(sui_pool);
        };

        // 1 year passed
        test_scenario::next_tx(&mut user_a_scenario, USER_A);
        {
            let stg = test_scenario::take_shared<Storage>(&user_a_scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&user_a_scenario);
            let oracle_feeder_cap = test_scenario::take_from_sender<OracleFeederCap>(&user_a_scenario);

            clock::increment_for_testing(&mut user_a_test_clock, 86400 * 1000 * 365);
            oracle::update_token_price(
                &oracle_feeder_cap,
                &user_a_test_clock,
                &mut price_oracle,
                0,
                500000000,
            );

            test_scenario::return_shared(stg);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_to_sender(&user_a_scenario, oracle_feeder_cap);

        };
        // set rate_to_supplier=0 and rate_to_tresury=0 for Sui asset
        test_scenario::next_tx(&mut user_a_scenario, USER_A);
        {
            let config = test_scenario::take_shared<FlashLoanConfig>(&user_a_scenario);
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(&user_a_scenario);

            manage::set_flash_loan_asset_rate_to_supplier<SUI_TEST>(&storage_admin_cap, &mut config, 0);
            manage::set_flash_loan_asset_rate_to_treasury<SUI_TEST>(&storage_admin_cap, &mut config, 0);

            test_scenario::return_shared(config);
            test_scenario::return_to_sender(&user_a_scenario, storage_admin_cap);
        };
        // update states before flash loan
        test_scenario::next_tx(&mut user_a_scenario, USER_A);
        {
            let storage = test_scenario::take_shared<Storage>(&user_a_scenario);

            logic::update_state_of_all_for_testing(&user_a_test_clock, &mut storage);

            test_scenario::return_shared(storage);

        };

        // flash loan 10 Sui
        test_scenario::next_tx(&mut user_a_scenario, USER_A);
        {
            let storage = test_scenario::take_shared<Storage>(&user_a_scenario);

            let (user_a_sui_supply, user_a_sui_borrow) = storage::get_user_balance(&mut storage, SUI_ASSET_ID, USER_A);

            let (total_supple, _) = storage::get_total_supply(&mut storage, SUI_ASSET_ID);

            let (_before_supply_index, _before_borrow_index) = storage::get_index(&mut storage, SUI_ASSET_ID);

            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&user_a_scenario);
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&user_a_scenario);

            let loan_amount = 10_000000000;
            let (loan_balance, receipt) = lending::flash_loan_with_ctx<SUI_TEST>(&flash_loan_config, &mut sui_pool, loan_amount, test_scenario::ctx(&mut user_a_scenario));

            let (user, _, amount, _, fee_to_supplier, fee_to_treasury) = flash_loan::parsed_receipt<SUI_TEST>(&receipt);

            assert!(fee_to_supplier == 0, 0);
            assert!(fee_to_treasury == 0, 0);

            let excess_balance = lending::flash_repay_with_ctx<SUI_TEST>(&user_a_test_clock, &mut storage, &mut sui_pool, receipt, loan_balance, test_scenario::ctx(&mut user_a_scenario));

            assert!(balance::value(&excess_balance) == 0, 0);

            let (supply_index, borrow_index) = storage::get_index(&mut storage, SUI_ASSET_ID);

            assert!(supply_index == _before_supply_index, 0);
            assert!(borrow_index == _before_borrow_index, 0);

            balance::destroy_for_testing(excess_balance);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(sui_pool);
            test_scenario::return_shared(flash_loan_config);
        };

        // UserA borrow 100 Sui
        test_scenario::next_tx(&mut user_a_scenario, USER_A);
        {
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&user_a_scenario);

            base_lending_tests::base_borrow_for_testing(&mut user_a_scenario, &user_a_test_clock, &mut sui_pool, SUI_ASSET_ID, 100_000000000);

            test_scenario::return_shared(sui_pool);
        };
        
        // check user balance and check pool balance
        test_scenario::next_tx(&mut user_a_scenario, USER_A);
        {
            let storage = test_scenario::take_shared<Storage>(&user_a_scenario);
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&user_a_scenario);

            let (user_a_sui_supply, user_a_sui_borrow) = storage::get_user_balance(&mut storage, SUI_ASSET_ID, USER_A);
            lib::close_to(user_a_sui_supply, 100000_000000000, 1);
            lib::close_to(user_a_sui_borrow, 149994182169, 1);

            let (sui_balance, treasury_balance, _) = pool::get_pool_info(&sui_pool);
            assert!(sui_balance == 99850_000000000, 0);
            assert!(treasury_balance == 0, 0);

            let d = std::string::utf8(b"1034 test_borrow_with_empty_flash_loan_rate");
            std::debug::print(&d);
            std::debug::print(&user_a_sui_supply);
            std::debug::print(&user_a_sui_borrow);

            test_scenario::return_shared(storage);
            test_scenario::return_shared(sui_pool);
        };
        clock::destroy_for_testing(user_a_test_clock);
        test_scenario::end(user_a_scenario);
    }
    /* 
        1.UserA deposit 100k
        2.UserA borrow 50 Sui
        3.1 year passed
        4.set rate_to_supplier=50 and rate_to_treasury=10
        5.UserA flash loan 10 Sui
        6.UserA borrow 100 Sui
    */
    #[test]
    public fun test_borrow_with_non_empty_flash_loan_rate() {
        let user_a_scenario = test_scenario::begin(USER_A);
        let user_a_test_clock = clock::create_for_testing(test_scenario::ctx(&mut user_a_scenario));
        clock::set_for_testing(&mut user_a_test_clock, 1704038400000);
        {
            base::initial_protocol(&mut user_a_scenario, &user_a_test_clock);
        };

        // UserA deposit 100k 
        test_scenario::next_tx(&mut user_a_scenario, USER_A);
        {
            deposit_in_empty_pool_for_testing<SUI_TEST>(&mut user_a_scenario, &user_a_test_clock, SUI_ASSET_ID, 100000_000000000);
        };

        // UserA borrow 50 Sui
        test_scenario::next_tx(&mut user_a_scenario, USER_A);
        {
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&user_a_scenario);

            base_lending_tests::base_borrow_for_testing(&mut user_a_scenario, &user_a_test_clock, &mut sui_pool, SUI_ASSET_ID, 50_000000000);

            test_scenario::return_shared(sui_pool);
        };

        // 1 year passed
        test_scenario::next_tx(&mut user_a_scenario, USER_A);
        {
            let stg = test_scenario::take_shared<Storage>(&user_a_scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&user_a_scenario);
            let oracle_feeder_cap = test_scenario::take_from_sender<OracleFeederCap>(&user_a_scenario);

            clock::increment_for_testing(&mut user_a_test_clock, 86400 * 1000 * 365);
            oracle::update_token_price(
                &oracle_feeder_cap,
                &user_a_test_clock,
                &mut price_oracle,
                0,
                500000000,
            );

            test_scenario::return_shared(stg);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_to_sender(&user_a_scenario, oracle_feeder_cap);

        };
        // set rate_to_supplier=50 and rate_to_tresury=10 for Sui asset
        test_scenario::next_tx(&mut user_a_scenario, USER_A);
        {
            let config = test_scenario::take_shared<FlashLoanConfig>(&user_a_scenario);
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(&user_a_scenario);

            manage::set_flash_loan_asset_rate_to_supplier<SUI_TEST>(&storage_admin_cap, &mut config, 50);
            manage::set_flash_loan_asset_rate_to_treasury<SUI_TEST>(&storage_admin_cap, &mut config, 10);

            test_scenario::return_shared(config);
            test_scenario::return_to_sender(&user_a_scenario, storage_admin_cap);
        };
        // update states before flash loan
        test_scenario::next_tx(&mut user_a_scenario, USER_A);
        {
            let storage = test_scenario::take_shared<Storage>(&user_a_scenario);

            logic::update_state_of_all_for_testing(&user_a_test_clock, &mut storage);

            test_scenario::return_shared(storage);

        };

        // flash loan 10 Sui
        test_scenario::next_tx(&mut user_a_scenario, USER_A);
        {
            let storage = test_scenario::take_shared<Storage>(&user_a_scenario);

            let (user_a_sui_supply, user_a_sui_borrow) = storage::get_user_balance(&mut storage, SUI_ASSET_ID, USER_A);

            let (total_supple, _) = storage::get_total_supply(&mut storage, SUI_ASSET_ID);

            let (_before_supply_index, _before_borrow_index) = storage::get_index(&mut storage, SUI_ASSET_ID);

            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(&user_a_scenario);
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&user_a_scenario);

            let loan_amount = 10_000000000;
            let (loan_balance, receipt) = lending::flash_loan_with_ctx<SUI_TEST>(&flash_loan_config, &mut sui_pool, loan_amount, test_scenario::ctx(&mut user_a_scenario));

            let (user, _, amount, _, fee_to_supplier, fee_to_treasury) = flash_loan::parsed_receipt<SUI_TEST>(&receipt);
            let coin = coin::mint_for_testing<SUI_TEST>(fee_to_supplier + fee_to_treasury , test_scenario::ctx(&mut user_a_scenario));
            let total_fee = coin::into_balance(coin);
            balance::join(&mut loan_balance, total_fee);
            
            assert!(fee_to_supplier == 50000000, 0);
            assert!(fee_to_treasury == 10000000, 0);

            let excess_balance = lending::flash_repay_with_ctx<SUI_TEST>(&user_a_test_clock, &mut storage, &mut sui_pool, receipt, loan_balance, test_scenario::ctx(&mut user_a_scenario));
            
            assert!(balance::value(&excess_balance) == 0, 0);

            let (supply_index, borrow_index) = storage::get_index(&mut storage, SUI_ASSET_ID);

            assert!(supply_index > _before_supply_index, 0);
            assert!(borrow_index == _before_borrow_index, 0);

            balance::destroy_for_testing(excess_balance);
            test_scenario::return_shared(storage);
            test_scenario::return_shared(sui_pool);
            test_scenario::return_shared(flash_loan_config);
        };

        // UserA borrow 100 Sui
        test_scenario::next_tx(&mut user_a_scenario, USER_A);
        {
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&user_a_scenario);

            base_lending_tests::base_borrow_for_testing(&mut user_a_scenario, &user_a_test_clock, &mut sui_pool, SUI_ASSET_ID, 100_000000000);

            test_scenario::return_shared(sui_pool);
        };

        // check user balance and check pool balance
        test_scenario::next_tx(&mut user_a_scenario, USER_A);
        {
            let storage = test_scenario::take_shared<Storage>(&user_a_scenario);
            let sui_pool = test_scenario::take_shared<Pool<SUI_TEST>>(&user_a_scenario);

            let (user_a_sui_supply, user_a_sui_borrow) = storage::get_user_balance(&mut storage, SUI_ASSET_ID, USER_A);
            lib::close_to(user_a_sui_supply, 100000_000000000, 1);
            lib::close_to(user_a_sui_borrow, 149994182169, 1);

            let (sui_balance, treasury_balance, _) = pool::get_pool_info(&sui_pool);
            assert!(sui_balance == 99850_000000000 + 50000000, 0);
            assert!(treasury_balance == 10000000, 0);

            let d = std::string::utf8(b"1183 test_borrow_with_non_empty_flash_loan_rate");
            std::debug::print(&d);
            std::debug::print(&user_a_sui_supply);
            std::debug::print(&user_a_sui_borrow);
            std::debug::print(&sui_balance);
            std::debug::print(&treasury_balance);

            test_scenario::return_shared(storage);
            test_scenario::return_shared(sui_pool);
        };
        clock::destroy_for_testing(user_a_test_clock);
        test_scenario::end(user_a_scenario);
    }
    #[test_only]
    public fun deposit_in_empty_pool_for_testing<T>(scenario: &mut Scenario, clock: &Clock, asset_id: u8, amount: u64) {
        let pool = test_scenario::take_shared<Pool<T>>(scenario);
        let coin = coin::mint_for_testing<T>(amount, test_scenario::ctx(scenario));

        base_lending_tests::base_deposit_for_testing(scenario, clock, &mut pool, coin, asset_id, amount);

        let (total_supply, _, _) = pool::get_pool_info(&pool);
        assert!(total_supply == amount, 0);

        test_scenario::return_shared(pool);
    }
}