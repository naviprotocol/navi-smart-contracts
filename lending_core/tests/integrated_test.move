#[test_only]
#[allow(unused_mut_ref)]
#[lint_allow(self_transfer)]
module lending_core::integrated_tests {
    use std::option;
    use sui::transfer;
    use sui::tx_context;
    use sui::coin::{Self};
    use sui::coin::{CoinMetadata};
    use sui::clock::{Self, Clock};
    use sui::test_scenario::{Self, Scenario};

    use oracle::oracle::{Self, OracleAdminCap, OracleFeederCap, PriceOracle};
    use lending_core::logic;
    use lending_core::lending;
    use lending_core::base_lending_tests::{Self};
    use lending_core::btc_test::{Self, BTC_TEST};
    use lending_core::incentive::{Self, Incentive};
    use lending_core::pool::{Self, Pool, PoolAdminCap};
    use lending_core::storage::{Self, Storage, StorageAdminCap};

    public fun print(str: vector<u8>) {
        std::debug::print(&std::ascii::string(str))
    }

    public fun init_modules(scenario: &mut Scenario) {
        pool::init_for_testing(test_scenario::ctx(scenario));
        storage::init_for_testing(test_scenario::ctx(scenario));
        oracle::init_for_testing(test_scenario::ctx(scenario));
        incentive::init_for_testing(test_scenario::ctx(scenario));
        btc_test::init_for_testing(test_scenario::ctx(scenario));
    }

    public fun mock_coin<CoinType: drop>(
        scenario: &mut Scenario,
        witness: CoinType,
        name: vector<u8>,
        symbol: vector<u8>,
        decimal: u8
        ) {
        let (treasury, metadata) = coin::create_currency(
            witness, 
            decimal, 
            symbol, 
            name, 
            b"description", 
            option::none(), 
            test_scenario::ctx(scenario));

        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(test_scenario::ctx(scenario)));    
    }

    public fun create_pool<CoinType>(
        scenario: &mut Scenario,
        decimal: u8
    ) {
        let pool_admin_cap = test_scenario::take_from_sender<PoolAdminCap>(scenario);

        let ctx = test_scenario::ctx(scenario);
        pool::create_pool_for_testing<CoinType>(&pool_admin_cap, decimal, ctx);
        
        test_scenario::return_to_sender(scenario, pool_admin_cap);
    }

    public fun init_oracle(
        scenario: &mut Scenario,
        pool_id: u8,
        token_decimal: u8,
        initial_token_price: u256
        ) {
            let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(scenario));
            let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);

            oracle::register_token_price(
                &oracle_admin_cap,
                &clock,
                &mut price_oracle,
                pool_id,
                initial_token_price,
                token_decimal,
            );

            clock::destroy_for_testing(clock);
            test_scenario::return_shared(price_oracle);
            test_scenario::return_to_sender(scenario, oracle_admin_cap);
    }

    public fun set_price(
        clock: &Clock,
        scenario: &mut Scenario,
        pool_id: u8,
        token_price: u256
    ) {
        let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
        let oracle_feeder_cap = test_scenario::take_from_sender<OracleFeederCap>(scenario);

        oracle::update_token_price(
            &oracle_feeder_cap,
            clock, 
            &mut price_oracle,
            pool_id,
            token_price,
        );

        test_scenario::return_shared(price_oracle);
        test_scenario::return_to_sender(scenario, oracle_feeder_cap);
    }

    public fun init_reserve<CoinType>(
        scenario: &mut Scenario,
        clock: &Clock,
    ) {
            let storage = test_scenario::take_shared<Storage>(scenario);
            let metadata = test_scenario::take_immutable<CoinMetadata<CoinType>>(scenario);
            let pool_admin_cap = test_scenario::take_from_sender<PoolAdminCap>(scenario);
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(scenario);

            {
            storage::init_reserve<CoinType>(
                &storage_admin_cap,
                &pool_admin_cap,
                clock,
                &mut storage,
                0,
                false,
                100000000000000000000000000000000000000000,
                900000000000000000000000000,
                50000000000000000000000000,
                800000000000000000000000000,
                300000000000000000000000000,
                1200000000000000000000000000,
                200000000000000000000000000,
                700000000000000000000000000,
                100000000000000000000000000,
                200000000000000000000000000,
                50000000000000000000000000,
                650000000000000000000000000,
                &metadata,
                test_scenario::ctx(scenario)
            );};

            test_scenario::return_shared(storage);
            test_scenario::return_immutable(metadata);
            test_scenario::return_to_sender(scenario, pool_admin_cap);
            test_scenario::return_to_sender(scenario, storage_admin_cap);
    }

    public fun deposit<CoinType>(
        scenario: &mut Scenario,
        clock: &Clock,
        mint_amount: u64,
        asset: u8,
        deposit_amount: u64
    ) {
        let pool = test_scenario::take_shared<Pool<CoinType>>(scenario);
        let incentive = test_scenario::take_shared<Incentive>(scenario);
        let coin = coin::mint_for_testing<CoinType>(mint_amount, test_scenario::ctx(scenario));

        base_lending_tests::base_deposit_for_testing(scenario, clock, &mut pool, coin, asset, deposit_amount);
        
        test_scenario::return_shared(pool);
        test_scenario::return_shared(incentive);
    }

    public fun withdraw<CoinType>(
        scenario: &mut Scenario,
        clock: &Clock,
        asset: u8,
        amount: u64
    ) {
        let pool = test_scenario::take_shared<Pool<CoinType>>(scenario);

        base_lending_tests::base_withdraw_for_testing(scenario, clock, &mut pool, asset, amount);

        test_scenario::return_shared(pool);  
    }

    public fun borrow<CoinType>(
        scenario: &mut Scenario,
        clock: &Clock,
        asset: u8,
        amount: u64
    ) {
        let pool = test_scenario::take_shared<Pool<CoinType>>(scenario);

        base_lending_tests::base_borrow_for_testing(scenario, clock, &mut pool, asset, amount);

        test_scenario::return_shared(pool);      
    }

    public fun repay<CoinType>(
        scenario: &mut Scenario,
        clock: &Clock,
        asset: u8,
        amount: u64
    ) {
        let pool = test_scenario::take_shared<Pool<CoinType>>(scenario);

        let repay_coin = coin::mint_for_testing<CoinType>(amount, test_scenario::ctx(scenario));

        base_lending_tests::base_repay_for_testing(scenario, clock, &mut pool, repay_coin, asset, amount);

        test_scenario::return_shared(pool);  
    }

    public fun liquidation<CoinType, CollateralCoinType>(
        scenario: &mut Scenario,
        clock: &Clock,
        asset: u8,
        liquidate_user: address,
        liquidate_amount: u64,
        liquidate_pool: u8
    ) {
        let pool = test_scenario::take_shared<Pool<CoinType>>(scenario);
        let collateral_pool = test_scenario::take_shared<Pool<CollateralCoinType>>(scenario);
        let storage = test_scenario::take_shared<Storage>(scenario);
        let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);  
        let incentive = test_scenario::take_shared<Incentive>(scenario);  

        let ctx = test_scenario::ctx(scenario); 
        let debt_coin = coin::mint_for_testing<CoinType>(liquidate_amount, ctx);

        lending::liquidation_call<CoinType, CollateralCoinType>(
                clock,
                &price_oracle,
                &mut storage,
                liquidate_pool,
                &mut pool,
                asset,
                &mut collateral_pool,
                debt_coin,
                liquidate_user,
                liquidate_amount,
                &mut incentive,
                ctx
                );        

        test_scenario::return_shared(price_oracle);
        test_scenario::return_shared(storage);
        test_scenario::return_shared(collateral_pool);
        test_scenario::return_shared(pool);      
        test_scenario::return_shared(incentive);      
    }

    public fun get_health_factor(
        scenario: &mut Scenario,
        user: address
    ) : u256 {
        let storage = test_scenario::take_shared<Storage>(scenario);
        let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        let hf = logic::user_health_factor(
            &clock,
            &mut storage,
            &price_oracle,
            user
        );

        clock::destroy_for_testing(clock);
        test_scenario::return_shared(price_oracle);
        test_scenario::return_shared(storage);
        hf
    }

    // from borrow_test.move
    // deposit - borrow test
    #[test]
    public fun test_integrated_supply_and_borrow() {
        let owner = @0x0b;
        let scenario = test_scenario::begin(owner);
        init_modules(&mut scenario);

        test_scenario::next_tx(&mut scenario, owner);
        create_pool<BTC_TEST>(&mut scenario, 9);
        
        let clock = {
            let ctx = test_scenario::ctx(&mut scenario);
            clock::create_for_testing(ctx)
        };

        test_scenario::next_tx(&mut scenario, owner);
        init_oracle(
            &mut scenario, 
            0, 
            9, 
            1100000000
        );

        test_scenario::next_tx(&mut scenario, owner);
        init_reserve<BTC_TEST>(&mut scenario, &clock,);

        test_scenario::next_tx(&mut scenario, owner);
        deposit<BTC_TEST>(
                &mut scenario, 
                &clock, 
                1000000000000, 
                0,
                100000000000
                );

        test_scenario::next_tx(&mut scenario, owner);
        clock::increment_for_testing(&mut clock, 1000 * 600000);
       
        test_scenario::next_tx(&mut scenario, owner);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let (supply_balance, borrow_balance) = storage::get_user_balance(&mut storage, 0, owner);
                 
            test_scenario::return_shared(storage);
            assert!(supply_balance == 100000000000, 0);
            assert!(borrow_balance == 0, 0);
        };

        set_price(&clock, &mut scenario, 0, 1100000000); // update price

        test_scenario::next_tx(&mut scenario, owner);
        borrow<BTC_TEST>(
                &mut scenario,
                &clock,
                0,
                10000000000
            );

        test_scenario::next_tx(&mut scenario, owner);
        clock::increment_for_testing(&mut clock, 1000 * 600000);

        test_scenario::next_tx(&mut scenario, owner);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let collateral_balance = logic::user_collateral_balance(&mut storage, 0, owner);
            let loan_balance = logic::user_loan_balance(&mut storage, 0, owner);

            test_scenario::return_shared(storage);
            assert!(collateral_balance == 100000000000, 0);
            assert!(loan_balance == 10000000000, 0);
        };
        

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // from deposit_test.move
    // deposit - withdraw test
    #[test]
    public fun test_integrated_supply_withdraw() {
        let owner = @0x0b;

        let scenario = test_scenario::begin(owner);
        init_modules(&mut scenario);

        test_scenario::next_tx(&mut scenario, owner);
        create_pool<BTC_TEST>(&mut scenario, 9);
        
        let clock = {
            let ctx = test_scenario::ctx(&mut scenario);
            clock::create_for_testing(ctx)
        };

        test_scenario::next_tx(&mut scenario, owner);
        init_oracle(
            &mut scenario, 
            0, 
            9, 
            1100000000
        );

        test_scenario::next_tx(&mut scenario, owner);
        init_reserve<BTC_TEST>(&mut scenario, &clock);

        test_scenario::next_tx(&mut scenario, owner);
        deposit<BTC_TEST>(
                &mut scenario, 
                &clock, 
                1000000000000, 
                0,
                100000000000
                );
       
        test_scenario::next_tx(&mut scenario, owner);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let (supply_balance, borrow_balance) = storage::get_user_balance(&mut storage, 0, owner);
            test_scenario::return_shared(storage);
            assert!(supply_balance == 100000000000, 0);
            assert!(borrow_balance == 0, 0);
        };

        test_scenario::next_tx(&mut scenario, owner);
        withdraw<BTC_TEST>(
            &mut scenario,
            &clock,
            0,
            10000000000
        );

        test_scenario::next_tx(&mut scenario, owner);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let (supply_balance, borrow_balance) = storage::get_user_balance(&mut storage, 0, owner);
            test_scenario::return_shared(storage);
            assert!(supply_balance == 90000000000, 0);
            assert!(borrow_balance == 0, 0);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);

    }

    // from interest_test.move
    // deposit - borrow - interest test
    #[test]
    public fun test_integrated_interest_supply_borrow() {
        let owner = @0x0b;
        let scenario = test_scenario::begin(owner);
        init_modules(&mut scenario);

        test_scenario::next_tx(&mut scenario, owner);
        create_pool<BTC_TEST>(&mut scenario, 9);
        
        let clock = {
            let ctx = test_scenario::ctx(&mut scenario);
            clock::create_for_testing(ctx)
        };

        test_scenario::next_tx(&mut scenario, owner);
        init_oracle(
                &mut scenario, 
                0, 
                9, 
                1100000000
                );

        test_scenario::next_tx(&mut scenario, owner);
        init_reserve<BTC_TEST>(&mut scenario, &clock);

        test_scenario::next_tx(&mut scenario, owner);
        deposit<BTC_TEST>(
                &mut scenario, 
                &clock, 
                100000000000000, 
                0,
                10000000000000
                );

        test_scenario::next_tx(&mut scenario, owner);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let collateral_balance = logic::user_collateral_balance(&mut storage, 0, owner);
            let loan_balance = logic::user_loan_balance(&mut storage, 0, owner);
            test_scenario::return_shared(storage);

            std::debug::print(&collateral_balance);
            std::debug::print(&loan_balance);
        };

        test_scenario::next_tx(&mut scenario, owner);
        borrow<BTC_TEST>(
                &mut scenario,
                &clock,
                0,
                1000000000000
            );

        test_scenario::next_tx(&mut scenario, owner);
        clock::increment_for_testing(&mut clock, 1000 * 100000);

        set_price(&clock, &mut scenario, 0, 1100000000); // update price

        test_scenario::next_tx(&mut scenario, owner);
        borrow<BTC_TEST>(
                &mut scenario,
                &clock,
                0,
                1000000000000
            );

        test_scenario::next_tx(&mut scenario, owner);
        clock::increment_for_testing(&mut clock, 1000 * 1000000000);

        test_scenario::next_tx(&mut scenario, owner);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let collateral_balance = logic::user_collateral_balance(&mut storage, 0, owner);
            let loan_balance = logic::user_loan_balance(&mut storage, 0, owner);
            test_scenario::return_shared(storage);

            std::debug::print(&collateral_balance);
            std::debug::print(&loan_balance);
        };
        

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // from repay_test.move
    // deposit - borrow - repay test
    #[test]
    public fun test_integrated_supply_borrow_repay() {
        let owner = @0x0b;
        let scenario = test_scenario::begin(owner);
        init_modules(&mut scenario);

        test_scenario::next_tx(&mut scenario, owner);
        create_pool<BTC_TEST>(&mut scenario, 9);
        
        let clock = {
            let ctx = test_scenario::ctx(&mut scenario);
            clock::create_for_testing(ctx)
        };

        test_scenario::next_tx(&mut scenario, owner);
        init_oracle(&mut scenario, 0, 9, 1100000000);

        test_scenario::next_tx(&mut scenario, owner);
        init_reserve<BTC_TEST>(&mut scenario, &clock);

        test_scenario::next_tx(&mut scenario, owner);
        deposit<BTC_TEST>(
                &mut scenario, 
                &clock, 
                1000000000000, 
                0,
                100000000000
                );

        test_scenario::next_tx(&mut scenario, owner);
        clock::increment_for_testing(&mut clock, 1000);
       
        test_scenario::next_tx(&mut scenario, owner);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let (supply_balance, borrow_balance) = storage::get_user_balance(&mut storage, 0, owner);
                 
            test_scenario::return_shared(storage);
            assert!(supply_balance == 100000000000, 0);
            assert!(borrow_balance == 0, 0);
        };

        test_scenario::next_tx(&mut scenario, owner);
        borrow<BTC_TEST>(&mut scenario, &clock, 0, 10000000000);

        test_scenario::next_tx(&mut scenario, owner);
        clock::increment_for_testing(&mut clock, 1000);

        test_scenario::next_tx(&mut scenario, owner);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let collateral_balance = logic::user_collateral_balance(&mut storage, 0, owner);
            let loan_balance = logic::user_loan_balance(&mut storage, 0, owner);
   
            test_scenario::return_shared(storage);
            assert!(collateral_balance == 100000000000, 0);
            assert!(loan_balance == 10000000000, 0);
        };

        test_scenario::next_tx(&mut scenario, owner);
        repay<BTC_TEST>(&mut scenario, &clock, 0, 1000000000);

        test_scenario::next_tx(&mut scenario, owner);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let collateral_balance = logic::user_collateral_balance(&mut storage, 0, owner);
            let loan_balance = logic::user_loan_balance(&mut storage, 0, owner);
            
            test_scenario::return_shared(storage);
            assert!(collateral_balance > 100000000000, 0);
            assert!(loan_balance == 9000000025, 0);
        };

        test_scenario::next_tx(&mut scenario, owner);
        repay<BTC_TEST>(&mut scenario, &clock, 0, 9000000025);

        test_scenario::next_tx(&mut scenario, owner);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let collateral_balance = logic::user_collateral_balance(&mut storage, 0, owner);
            let loan_balance = logic::user_loan_balance(&mut storage, 0, owner);

            test_scenario::return_shared(storage);
            assert!(collateral_balance > 100000000000, 0);
            assert!(loan_balance == 0, 0);
        };

        test_scenario::next_tx(&mut scenario, owner);
        clock::increment_for_testing(&mut clock, 86400 * 30);

        set_price(&clock, &mut scenario, 0, 1100000000); // update price

        test_scenario::next_tx(&mut scenario, owner);
        withdraw<BTC_TEST>(&mut scenario, &clock, 0, 9000000000);

        test_scenario::next_tx(&mut scenario, owner);
        clock::increment_for_testing(&mut clock, 86400 * 30);

        test_scenario::next_tx(&mut scenario, owner);
        {
            let storage = test_scenario::take_shared<Storage>(&scenario);
            let collateral_balance = logic::user_collateral_balance(&mut storage, 0, owner);
            let loan_balance = logic::user_loan_balance(&mut storage, 0, owner);

            test_scenario::return_shared(storage);
            assert!(collateral_balance > 91000000000, 0);
            assert!(loan_balance == 0, 0);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // TODO
    // from liquidation_test.move
    // deposit - borrow - price change - liquidation
    #[test]
    public fun test_integrated_supply_borrow_liquidation() {
        // let owner = @0x0b;
        // let bob = @0x0c;
        // let alice = @0x0d;

        // let scenario = test_scenario::begin(owner);
        // init_modules(&mut scenario);
        
        // test_scenario::next_tx(&mut scenario, owner);
        // {
        //     let ctx = test_scenario::ctx(&mut scenario);
        //     weth::init_for_testing(ctx);
        // };  

        // test_scenario::next_tx(&mut scenario, owner);
        // create_pool<SUI>(&mut scenario, 9);

        // test_scenario::next_tx(&mut scenario, owner);
        // create_pool<weth::WETH>(&mut scenario, 9);
        
        // let clock = {
        //     let ctx = test_scenario::ctx(&mut scenario);
        //     clock::create_for_testing(ctx)
        // };

        // test_scenario::next_tx(&mut scenario, owner);
        // init_oracle(
        //         &mut scenario, 
        //         0, 
        //         9, 
        //         1100000000
        //         );    

        // test_scenario::next_tx(&mut scenario, owner);
        // init_oracle(
        //         &mut scenario, 
        //         1, 
        //         9, 
        //         1800000000000
        //         );    

        // test_scenario::next_tx(&mut scenario, owner);
        // set_feeder(
        //         &mut scenario,
        //         owner,
        //         true
        //     );

        // test_scenario::next_tx(&mut scenario, owner);
        // init_reserve<SUI>(
        //         &mut scenario, 
        //         &clock,
        //         9
        //         );

        // test_scenario::next_tx(&mut scenario, owner);
        // init_reserve<weth::WETH>(
        //         &mut scenario, 
        //         &clock,
        //         9
        //         );   

        // test_scenario::next_tx(&mut scenario, owner);
        // deposit<SUI>(
        //         &mut scenario, 
        //         &clock, 
        //         1000000000000, 
        //         0,
        //         1000000000000
        //         );   

        // test_scenario::next_tx(&mut scenario, bob);
        // deposit<weth::WETH>(
        //         &mut scenario, 
        //         &clock, 
        //         10000000000, 
        //         1,
        //         1000000000
        //         ); 

        // test_scenario::next_tx(&mut scenario, owner);
        // clock::increment_for_testing(&mut clock, 1000 * 1000);
       
        // test_scenario::next_tx(&mut scenario, owner);
        // {
        //     let storage = test_scenario::take_shared<Storage>(&scenario);
        //     let (supply_balance, borrow_balance) = storage::get_user_balance(&mut storage, 0, owner);
                 
        //     test_scenario::return_shared(storage);
        //     assert!(supply_balance == 1000000000000, 0);
        //     assert!(borrow_balance == 0, 0);
        // };

        // test_scenario::next_tx(&mut scenario, owner);
        // borrow<weth::WETH>(
        //         &mut scenario,
        //         &clock,
        //         1,
        //         200000000
        //     );

        // test_scenario::next_tx(&mut scenario, owner);
        // clock::increment_for_testing(&mut clock, 1000 * 600);

        // test_scenario::next_tx(&mut scenario, owner);
        // set_price(
        //         &mut scenario,
        //         1,
        //         2600000000000
        //     );

        // test_scenario::next_tx(&mut scenario, owner);
        // {
        //     let health_factor = get_health_factor(&mut scenario, owner);
        //     std::debug::print(&health_factor);
        //     assert!(health_factor < 1000000000000000000000000000, 0);
        // };

        // test_scenario::next_tx(&mut scenario, alice);
        // liquidation<SUI, weth::WETH>(
        //     &mut scenario,
        //     &clock,
        //     0,
        //     owner,
        //     200000000,
        //     1
        // );


        // clock::destroy_for_testing(clock);
        // test_scenario::end(scenario);

    }
}