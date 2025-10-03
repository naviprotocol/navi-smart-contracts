#[test_only]
module oracle::oracle_sui_test {
    use sui::coin;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct ORACLE_SUI_TEST has drop {}

    fun init(witness: ORACLE_SUI_TEST, ctx: &mut TxContext) {
        let decimals = 9;
        let name = b"Sui";
        let symbol = b"ORACLE_SUI_TEST";
        
        let (treasury_cap, metadata) = coin::create_currency<ORACLE_SUI_TEST>(
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
        init(ORACLE_SUI_TEST {}, ctx)
    }
}

#[test_only]
module oracle::test_coin1 {
    use sui::coin;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct TEST_COIN1 has drop {}

    fun init(witness: TEST_COIN1, ctx: &mut TxContext) {
        let decimals = 9;
        let name = b"TEST_COIN1";
        let symbol = b"TEST_COIN1";
        
        let (treasury_cap, metadata) = coin::create_currency<TEST_COIN1>(
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
        init(TEST_COIN1 {}, ctx)
    }
}

#[test_only]
module oracle::test_coin2 {
    use sui::coin;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct TEST_COIN2 has drop {}

    fun init(witness: TEST_COIN2, ctx: &mut TxContext) {
        let decimals = 9;
        let name = b"TEST_COIN2";
        let symbol = b"TEST_COIN2";
        
        let (treasury_cap, metadata) = coin::create_currency<TEST_COIN2>(
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
        init(TEST_COIN2 {}, ctx)
    }
}

#[test_only]
module oracle::test_coin3 {
    use sui::coin;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct TEST_COIN3 has drop {}

    fun init(witness: TEST_COIN3, ctx: &mut TxContext) {
        let decimals = 9;
        let name = b"TEST_COIN3";
        let symbol = b"TEST_COIN3";
        
        let (treasury_cap, metadata) = coin::create_currency<TEST_COIN3>(
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
        init(TEST_COIN3 {}, ctx)
    }
}

#[test_only]
module oracle::test_coin4 {
    use sui::coin;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct TEST_COIN4 has drop {}

    fun init(witness: TEST_COIN4, ctx: &mut TxContext) {
        let decimals = 9;
        let name = b"TEST_COIN4";
        let symbol = b"TEST_COIN4";
        
        let (treasury_cap, metadata) = coin::create_currency<TEST_COIN4>(
            witness,
            decimals,
            symbol,
            name,
            b"",
            option::none(),
            ctx
        );

        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(TEST_COIN4 {}, ctx);
    }
}

#[test_only]
module oracle::test_coin5 {
    use sui::coin;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct TEST_COIN5 has drop {}

    fun init(witness: TEST_COIN5, ctx: &mut TxContext) {
        let decimals = 9;
        let name = b"TEST_COIN5";
        let symbol = b"TEST_COIN5";
        
        let (treasury_cap, metadata) = coin::create_currency<TEST_COIN5>(
            witness,
            decimals,
            symbol,
            name,
            b"",
            option::none(),
            ctx
        );

        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(TEST_COIN5 {}, ctx);
    }
}

#[test_only]
module oracle::test_coin6 {
    use sui::coin;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct TEST_COIN6 has drop {}

    fun init(witness: TEST_COIN6, ctx: &mut TxContext) {
        let decimals = 9;
        let name = b"TEST_COIN6";
        let symbol = b"TEST_COIN6";
        
        let (treasury_cap, metadata) = coin::create_currency<TEST_COIN6>(
            witness,
            decimals,
            symbol,
            name,
            b"",
            option::none(),
            ctx
        );

        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(TEST_COIN6 {}, ctx);
    }
}

#[test_only]
module oracle::test_coin7 {
    use sui::coin;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct TEST_COIN7 has drop {}

    fun init(witness: TEST_COIN7, ctx: &mut TxContext) {
        let decimals = 9;
        let name = b"TEST_COIN7";
        let symbol = b"TEST_COIN7";
        
        let (treasury_cap, metadata) = coin::create_currency<TEST_COIN7>(
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
        init(TEST_COIN7 {}, ctx)
    }
}

#[test_only]
module oracle::test_coin8 {
    use sui::coin;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct TEST_COIN8 has drop {}

    fun init(witness: TEST_COIN8, ctx: &mut TxContext) {
        let decimals = 9;
        let name = b"TEST_COIN8";
        let symbol = b"TEST_COIN8";
        
        let (treasury_cap, metadata) = coin::create_currency<TEST_COIN8>(
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
        init(TEST_COIN8 {}, ctx)
    }
}