#[test_only]
module utils::utils_test {
    use std::option;
    use utils::utils;
    use sui::transfer;
    use sui::test_scenario;
    use sui::balance::{Self};
    use sui::coin::{Self, Coin};
    use sui::tx_context::{Self, TxContext};

    struct UTILS_TEST has drop {}

    #[test_only]
    fun test_coin_mint(ctx: &mut TxContext): Coin<UTILS_TEST> {
        let witness = UTILS_TEST{};
        let (treasury, metadata) = coin::create_currency(
            witness,
            6,
            b"COIN_TESTS",
            b"coin_name",
            b"description",
            option::none(),
            ctx,
        );

        let c = coin::mint(&mut treasury, 100000000, ctx);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx));
        c
    }

    #[test]
    fun test_split_coin() {
        let tester = @0xA;
        let scenario = test_scenario::begin(tester);

        {
            let split_value = 2000000;

            let mint_coin = test_coin_mint(test_scenario::ctx(&mut scenario));
            let split_coin = utils::split_coin(mint_coin, split_value, test_scenario::ctx(&mut scenario));

            assert!(coin::value(&split_coin) == split_value, 0);
            transfer::public_transfer(split_coin, tester)
        };

        test_scenario::end(scenario);
    }

    #[test]
    fun test_split_coin_to_balance() {
        let tester = @0xA;
        let scenario = test_scenario::begin(tester);

        {
            let split_value = 2000000;

            let mint_coin = test_coin_mint(test_scenario::ctx(&mut scenario));
            let split_balance = utils::split_coin_to_balance(mint_coin, split_value, test_scenario::ctx(&mut scenario));

            assert!(balance::value(&split_balance) == split_value, 0);

            let split_coin = coin::from_balance(split_balance, test_scenario::ctx(&mut scenario));
            transfer::public_transfer(split_coin, tester)
        };

        test_scenario::end(scenario);
    }
}
