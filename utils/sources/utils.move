module utils::utils {
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::balance::{Balance};
    use sui::tx_context::{Self, TxContext};
    
    const UTILS_AMOUNT_ZERO: u64 = 46000;
    const UTILS_INSUFFICIENT_FUNDS: u64 = 46001;

    public fun split_coin<CoinType>(split_coin: Coin<CoinType>, amount: u64, ctx: &mut TxContext): Coin<CoinType> {
        // get total value of coin
        let coin_value = coin::value(&split_coin);
        assert!(amount > 0, UTILS_AMOUNT_ZERO);
        assert!(coin_value >= amount, UTILS_INSUFFICIENT_FUNDS);

        // Split the specified amount of coin
        let split_ = coin::split(&mut split_coin, amount, ctx);
        if (coin::value(&split_coin) == 0) {
            coin::destroy_zero(split_coin);
            return split_
        };

        // Transferring the unsegmented portion back to the user
        transfer::public_transfer(split_coin, tx_context::sender(ctx));
        split_
    }

    public fun split_coin_to_balance<CoinType>(split_coin: Coin<CoinType>, amount: u64, ctx: &mut TxContext): Balance<CoinType> {
        // Split coin
        let split = split_coin(split_coin, amount, ctx);

        // put in balance
        let balance = coin::into_balance(split);
        balance
    }
}
