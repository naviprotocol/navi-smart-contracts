#[test_only]
module lending_core::base {
    use sui::clock::{Clock};
    use sui::coin::{CoinMetadata};
    use sui::test_scenario::{Self, Scenario};

    use oracle::oracle::{Self, OracleAdminCap, PriceOracle};
    use lending_core::incentive;
    use lending_core::pool::{Self, Pool, PoolAdminCap};
    use lending_core::manage::{Self};
    use lending_core::sui_test::{Self, SUI_TEST};
    use lending_core::eth_test::{Self, ETH_TEST};
    use lending_core::usdt_test::{Self, USDT_TEST};
    use lending_core::usdc_test::{Self, USDC_TEST};
    use lending_core::test_coin::{Self, TEST_COIN};
    use lending_core::storage::{Self, Storage, StorageAdminCap};
    use lending_core::flash_loan::{Config as FlashLoanConfig};

    #[test_only]
    public fun initial_protocol(scenario: &mut Scenario, clock: &Clock) {
        let owner = test_scenario::sender(scenario);

        test_scenario::next_tx(scenario, owner);
        {
            pool::init_for_testing(test_scenario::ctx(scenario));      // Initialization of pool
            storage::init_for_testing(test_scenario::ctx(scenario));   // Initialization of storage
            oracle::init_for_testing(test_scenario::ctx(scenario));    // Initialization of oracel
            eth_test::init_for_testing(test_scenario::ctx(scenario));  // Initialization of ETH coin
            usdt_test::init_for_testing(test_scenario::ctx(scenario)); // Initialization of USDT coin
            usdc_test::init_for_testing(test_scenario::ctx(scenario)); // Initialization of USDC coin
            sui_test::init_for_testing(test_scenario::ctx(scenario)); // Initialization of USDC coin
            incentive::init_for_testing(test_scenario::ctx(scenario)); // Initialization of incentive
        };

        test_scenario::next_tx(scenario, owner);
        {
            create_pool_from_sui(scenario, clock)
        };

        test_scenario::next_tx(scenario, owner);
        {
            create_pool_from_usdc(scenario, clock)
        };

        test_scenario::next_tx(scenario, owner);
        {
            create_pool_from_usdt(scenario, clock)
        };

        test_scenario::next_tx(scenario, owner);
        {
            create_pool_from_weth(scenario, clock)
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

            manage::create_flash_loan_config(&storage_admin_cap, test_scenario::ctx(scenario));

            test_scenario::return_to_sender(scenario, storage_admin_cap);
        };

        test_scenario::next_tx(scenario, owner);
        {
            let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(scenario);
            let flash_loan_config = test_scenario::take_shared<FlashLoanConfig>(scenario);
            let storage = test_scenario::take_shared<Storage>(scenario);
            let pool = test_scenario::take_shared<Pool<SUI_TEST>>(scenario);

            manage::create_flash_loan_asset<SUI_TEST>(
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
    public fun initial_test_coin(scenario: &mut Scenario, clock: &Clock) {
        let owner = test_scenario::sender(scenario);

        test_scenario::next_tx(scenario, owner);
        {
            test_coin::init_for_testing(test_scenario::ctx(scenario)); // Initialization of TEST coin
        };

        test_scenario::next_tx(scenario, owner);
        {
            create_pool_from_test_coin(scenario, clock)
        };

    }

    #[test_only]
    public fun create_pool_from_sui(scenario: &mut Scenario, clock: &Clock) {
        let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
        let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);
        let storage = test_scenario::take_shared<Storage>(scenario);
        let pool_admin_cap = test_scenario::take_from_sender<PoolAdminCap>(scenario);
        let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(scenario);
        let metadata = test_scenario::take_immutable<CoinMetadata<SUI_TEST>>(scenario);

        oracle::register_token_price(
            &oracle_admin_cap,
            clock,
            &mut price_oracle,
            0, // oracle_id
            500000000, // token_price
            9, // decimals
        );

        storage::init_reserve<SUI_TEST>(
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
            1000000, // token_price
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

    #[test_only]
    public fun create_pool_from_usdt(scenario: &mut Scenario, clock: &Clock) {
        let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
        let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);
        let storage = test_scenario::take_shared<Storage>(scenario);
        let pool_admin_cap = test_scenario::take_from_sender<PoolAdminCap>(scenario);
        let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(scenario);
        let metadata = test_scenario::take_immutable<CoinMetadata<USDT_TEST>>(scenario);

        oracle::register_token_price(
            &oracle_admin_cap,
            clock,
            &mut price_oracle,
            2, // oracle_id
            999900, // token_price
            6, // decimals
        );

        storage::init_reserve<USDT_TEST>(
            &storage_admin_cap,
            &pool_admin_cap,
            clock,
            &mut storage,
            2, // oracle id
            false, // is_isolated
            3000000000000000000000000000000000000000000, // supply_cap_ceiling: 20000000
            900000000000000000000000000, // borrow_cap_ceiling: 90%
            0, // base_rate: 0%
            500000000000000000000000000, // optimal_utilization: 80%
            128000000000000000000000000, // multiplier: 5%
            3200000000000000000000000000, // jump_rate_multiplier: 109%
            100000000000000000000000000, // reserve_factor: 7%
            700000000000000000000000000, // ltv: 70%
            100000000000000000000000000, // treasury_factor: 10%
            350000000000000000000000000, // liquidation_ratio: 35%
            50000000000000000000000000, // liquidation_bonus: 5%
            750000000000000000000000000, // liquidation_threshold: 75%
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

    #[test_only]
    public fun create_pool_from_weth(scenario: &mut Scenario, clock: &Clock) {
        let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
        let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);
        let storage = test_scenario::take_shared<Storage>(scenario);
        let pool_admin_cap = test_scenario::take_from_sender<PoolAdminCap>(scenario);
        let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(scenario);
        let metadata = test_scenario::take_immutable<CoinMetadata<ETH_TEST>>(scenario);

        oracle::register_token_price(
            &oracle_admin_cap,
            clock,
            &mut price_oracle,
            3, // oracle_id
            2048000000000, // token_price
            9, // decimals
        );

        storage::init_reserve<ETH_TEST>(
            &storage_admin_cap,
            &pool_admin_cap,
            clock,
            &mut storage,
            3, // oracle id
            false, // is_isolated
            175000000000000000000000000000000000000, // supply_cap_ceiling: 20000000
            900000000000000000000000000, // borrow_cap_ceiling: 90%
            0, // base_rate: 0%
            750000000000000000000000000, // optimal_utilization: 80%
            86000000000000000000000000, // multiplier: 5%
            3200000000000000000000000000, // jump_rate_multiplier: 109%
            200000000000000000000000000, // reserve_factor: 7%
            750000000000000000000000000, // ltv: 75%
            100000000000000000000000000, // treasury_factor: 10%
            350000000000000000000000000, // liquidation_ratio: 35%
            50000000000000000000000000, // liquidation_bonus: 5%
            800000000000000000000000000, // liquidation_threshold: 80%
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

    #[test_only]
    public fun create_pool_from_test_coin(scenario: &mut Scenario, clock: &Clock) {
        let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
        let oracle_admin_cap = test_scenario::take_from_sender<OracleAdminCap>(scenario);
        let storage = test_scenario::take_shared<Storage>(scenario);
        let pool_admin_cap = test_scenario::take_from_sender<PoolAdminCap>(scenario);
        let storage_admin_cap = test_scenario::take_from_sender<StorageAdminCap>(scenario);
        let metadata = test_scenario::take_immutable<CoinMetadata<TEST_COIN>>(scenario);

        oracle::register_token_price(
            &oracle_admin_cap,
            clock,
            &mut price_oracle,
            4, // oracle_id
            1_0000, // token_price
            6, // decimals
        );

        storage::init_reserve<TEST_COIN>(
            &storage_admin_cap,
            &pool_admin_cap,
            clock,
            &mut storage,
            4, // oracle id
            false, // is_isolated
            20000000_000000000_000000000000000000000000000, // supply_cap_ceiling: 20000000
            900000000000000000000000000, // borrow_cap_ceiling: 90%
            0, // base_rate: 0%
            800000000000000000000000000, // optimal_utilization: 80%
            80000000000000000000000000, // multiplier: 5%
            3000000000000000000000000000, // jump_rate_multiplier: 109%
            100000000000000000000000000, // reserve_factor: 7%
            0, // ltv: 80%
            100000000000000000000000000, // treasury_factor: 10%
            350000000000000000000000000, // liquidation_ratio: 35%
            50000000000000000000000000, // liquidation_bonus: 5%
            0, // liquidation_threshold: 85%
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

#[test_only]
module lending_core::sui_test {
    use sui::coin;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct SUI_TEST has drop {}

    fun init(witness: SUI_TEST, ctx: &mut TxContext) {
        let decimals = 9;
        let name = b"Sui";
        let symbol = b"SUI";
        
        let (treasury_cap, metadata) = coin::create_currency<SUI_TEST>(
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
        init(SUI_TEST {}, ctx)
    }
}

#[test_only]
module lending_core::usdc_test {
    use sui::coin;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct USDC_TEST has drop {}

    fun init(witness: USDC_TEST, ctx: &mut TxContext) {
        let decimals = 6;
        let name = b"Wrapped USDC";
        let symbol = b"USDC_TEST";
        
        let (treasury_cap, metadata) = coin::create_currency<USDC_TEST>(
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
        init(USDC_TEST {}, ctx)
    }
}

#[test_only]
module lending_core::usdt_test {
    use sui::coin;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct USDT_TEST has drop {}

    fun init(witness: USDT_TEST, ctx: &mut TxContext) {
        let decimals = 6;
        let name = b"Wrapped USDT";
        let symbol = b"USDT_TEST";
        
        let (treasury_cap, metadata) = coin::create_currency<USDT_TEST>(
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
        init(USDT_TEST {}, ctx)
    }
}

#[test_only]
module lending_core::eth_test {
    use sui::coin;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct ETH_TEST has drop {}

    fun init(witness: ETH_TEST, ctx: &mut TxContext) {
        let decimals = 9;
        let name = b"Wrapped ETH";
        let symbol = b"ETH_TEST";
        
        let (treasury_cap, metadata) = coin::create_currency<ETH_TEST>(
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
        init(ETH_TEST {}, ctx)
    }
}

#[test_only]
module lending_core::eth2_test {
    use sui::coin;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct ETH2_TEST has drop {}

    fun init(witness: ETH2_TEST, ctx: &mut TxContext) {
        let decimals = 9;
        let name = b"Wrapped ETH";
        let symbol = b"ETH2_TEST";
        
        let (treasury_cap, metadata) = coin::create_currency<ETH2_TEST>(
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
        init(ETH2_TEST {}, ctx)
    }
}

#[test_only]
module lending_core::btc_test {
    use sui::coin;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct BTC_TEST has drop {}

    fun init(witness: BTC_TEST, ctx: &mut TxContext) {
        let decimals = 9;
        let name = b"Wrapped BTC";
        let symbol = b"BTC_TEST";
        
        let (treasury_cap, metadata) = coin::create_currency<BTC_TEST>(
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
        init(BTC_TEST {}, ctx)
    }
}

#[test_only]
module lending_core::test_coin {
    use sui::coin;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct TEST_COIN has drop {}

    fun init(witness: TEST_COIN, ctx: &mut TxContext) {
        let decimals = 6;
        let name = b"Test Coin";
        let symbol = b"TEST_COIN";
        
        let (treasury_cap, metadata) = coin::create_currency<TEST_COIN>(
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
        init(TEST_COIN {}, ctx)
    }
}

#[test_only]
module lending_core::lib {

    use lending_core::storage::{Self, Storage};

    #[test_only]
    public fun printf(str: vector<u8>) {
        std::debug::print(&std::ascii::string(str))
    }

    #[test_only]
    public fun print<T>(x: &T) {
        std::debug::print(x)
    }

    #[test_only]
    public fun print_u256(str: vector<u8>, value: u256) {
        std::vector::append(&mut str, b": ");
        let c = sui::hex::encode(sui::address::to_bytes(sui::address::from_u256(value)));
        std::vector::append(&mut str, c);
        std::debug::print(&std::ascii::string(str));
    }

    #[test_only]
    public fun print_rate(stg: &mut Storage, asset: u8) {
        let (s,b) = storage::get_current_rate(stg, asset);
        printf(b"supply and borrow rate:");
        print(&s);
        print(&b);
    }

    #[test_only]
    public fun print_index(stg: &mut Storage, asset: u8) {
        let (s,b) = storage::get_index(stg, asset);
        printf(b"supply and borrow index:");
        print(&s);
        print(&b);
    }

    #[test_only]
    public fun print_balance(stg: &mut Storage, asset: u8) {
        let (s,b) = storage::get_total_supply(stg, asset);
        printf(b"supply and borrow balance:");
        print(&s);
        print(&b);
    }

    #[test_only]
    #[allow(unused_assignment)]
    public fun close_to(v1: u256, v2:u256, diff: u256) {
        if (diff == 0) {
            diff = pow(10, 9);
        };

        let n_diff = 0;
        if (v1 > v2) {
            n_diff = v1 - v2
        } else {
            n_diff = v2 - v1;
        };
        assert!(n_diff <= diff, 0);
    }

    #[test_only]
    #[allow(unused_assignment)]
    // percentage diff
    public fun close_to_p(v1: u256, v2:u256, diff: u256) {
        if (diff == 0) {
            // default 1% tolerance
            diff = 100;
        };

        let n_diff = 0;
        let max = 0;
        if (v1 > v2) {
            max = v1 / diff;
            n_diff = v1 - v2
        } else {
            max = v2 / diff;
            n_diff = v2 - v1;
        };
        assert!(max >= n_diff, 0);
    }

    public fun pow(n: u256, p: u256): u256 {
        if (p == 0) {
            return 1
        };
        let res = 1;
        while (p > 0) {
            res = res * n;
            p = p - 1;
        };
        res
    }
}