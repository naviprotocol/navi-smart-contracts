#[test_only]
module dvault::sui_test {
    use sui::coin;

    public struct SUI_TEST has drop {}

    fun init(witness: SUI_TEST, ctx: &mut TxContext) {
        let decimals = 9;
        let name = b"Sui";
        let symbol = b"SUI";
        
        let (vault_cap, metadata) = coin::create_currency<SUI_TEST>(
            witness,         // witness
            decimals,        // decimals
            symbol,          // symbol
            name,            // name
            b"",             // description
            option::none(),  // icon_url
            ctx
        );

        transfer::public_freeze_object(metadata);
        transfer::public_transfer(vault_cap, tx_context::sender(ctx))
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(SUI_TEST {}, ctx)
    }
}

#[test_only]
module dvault::usdc_test {
    use sui::coin;

    public struct USDC_TEST has drop {}

    fun init(witness: USDC_TEST, ctx: &mut TxContext) {
        let decimals = 9;
        let name = b"USDC";
        let symbol = b"USDC";
        
        let (vault_cap, metadata) = coin::create_currency<USDC_TEST>(
            witness,         // witness
            decimals,        // decimals
            symbol,          // symbol
            name,            // name
            b"",             // description
            option::none(),  // icon_url
            ctx
        );

        transfer::public_freeze_object(metadata);
        transfer::public_transfer(vault_cap, tx_context::sender(ctx))
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(USDC_TEST {}, ctx)
    }
}