#[test_only]
module lending_core::base_lending_tests {
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::test_scenario::{Self, Scenario};

    use oracle::oracle::{PriceOracle};
    use lending_core::lending::{Self};
    use lending_core::pool::{Pool};
    use lending_core::storage::{Storage};
    use lending_core::incentive::{Incentive};
    use lending_core::account::{AccountCap};

    #[test_only]
    public fun base_deprecated_deposit_for_testing<T>(scenario: &mut Scenario, pool: &mut Pool<T>, deposit_coin: Coin<T>) {
        let storage = test_scenario::take_shared<Storage>(scenario);
        let incentive = test_scenario::take_shared<Incentive>(scenario);
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        let value = coin::value(&deposit_coin);
        lending::deposit<T>(
            &clock,
            &mut storage,
            pool,
            0,
            deposit_coin,
            value,
            &mut incentive,
            test_scenario::ctx(scenario)
        );

        clock::destroy_for_testing(clock);
        test_scenario::return_shared(storage);
        test_scenario::return_shared(incentive);
    }

    #[test_only]
    public fun base_deprecated_withdraw_for_testing<T>(scenario: &mut Scenario, pool: &mut Pool<T>) {
        let storage = test_scenario::take_shared<Storage>(scenario);
        let incentive = test_scenario::take_shared<Incentive>(scenario);
        let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        // withdraw
        lending::withdraw<T>(
            &clock,
            &price_oracle,
            &mut storage,
            pool,
            1,
            1,
            test_scenario::sender(scenario),
            &mut incentive,
            test_scenario::ctx(scenario)
        );

        clock::destroy_for_testing(clock);
        test_scenario::return_shared(storage);
        test_scenario::return_shared(incentive);
        test_scenario::return_shared(price_oracle);
    }

    #[test_only]
    public fun base_deprecated_borrow_for_testing<T>(scenario: &mut Scenario, pool: &mut Pool<T>) {
        let storage = test_scenario::take_shared<Storage>(scenario);
        let incentive = test_scenario::take_shared<Incentive>(scenario);
        let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        // borrow
        lending::borrow<T>(
            &clock,
            &price_oracle,
            &mut storage,
            pool,
            1,
            1,
            test_scenario::ctx(scenario)
        );

        clock::destroy_for_testing(clock);
        test_scenario::return_shared(storage);
        test_scenario::return_shared(incentive);
        test_scenario::return_shared(price_oracle);
    }

    #[test_only]
    public fun base_deprecated_repay_for_testing<T>(scenario: &mut Scenario, pool: &mut Pool<T>, repay_coin: Coin<T>) {
        let storage = test_scenario::take_shared<Storage>(scenario);
        let incentive = test_scenario::take_shared<Incentive>(scenario);
        let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        lending::repay<T>(
            &clock,
            &price_oracle,
            &mut storage,
            pool,
            1,
            repay_coin,
            1,
            test_scenario::ctx(scenario)
        );

        clock::destroy_for_testing(clock);
        test_scenario::return_shared(storage);
        test_scenario::return_shared(incentive);
        test_scenario::return_shared(price_oracle);
    }

    #[test_only]
    public fun base_deposit_for_testing<T>(scenario: &mut Scenario, clock: &Clock, pool: &mut Pool<T>, deposit_coin: Coin<T>, asset: u8, amount: u64) {
        let storage = test_scenario::take_shared<Storage>(scenario);

        // deposit
        lending::deposit_coin<T>(
            clock,
            &mut storage, // Storage object
            pool,         // Pool object
            asset,        // asset id
            deposit_coin, // coin
            amount,       // amount
            test_scenario::ctx(scenario)
        );

        test_scenario::return_shared(storage);
    }

    #[test_only]
    public fun base_borrow_for_testing<T>(scenario: &mut Scenario, clock: &Clock, pool: &mut Pool<T>, asset: u8, amount: u64) {
        let storage = test_scenario::take_shared<Storage>(scenario);
        let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);

        let _balance = lending::borrow_coin<T>(
            clock,
            &price_oracle, // PriceOracle object
            &mut storage,  // Storage object
            pool, // Pool object
            asset,             // asset id
            amount,  // amount
            test_scenario::ctx(scenario)
        );

        let _coin = coin::from_balance(_balance, test_scenario::ctx(scenario));
        transfer::public_transfer(_coin, test_scenario::sender(scenario));

        test_scenario::return_shared(storage);
        test_scenario::return_shared(price_oracle);
    }

    #[test_only]
    public fun base_withdraw_for_testing<T>(scenario: &mut Scenario, clock: &Clock, pool: &mut Pool<T>, asset: u8, amount: u64) {
        let storage = test_scenario::take_shared<Storage>(scenario);
        let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);

        // withdraw ETH
        let _balance = lending::withdraw_coin<T>(
            clock,
            &price_oracle,  // PriceOracle object
            &mut storage,   // Storage object
            pool,  // Pool object
            asset,              // asset id
            amount,   // amount
            test_scenario::ctx(scenario)
        );
        
        let _coin = coin::from_balance(_balance, test_scenario::ctx(scenario));
        transfer::public_transfer(_coin, test_scenario::sender(scenario));

        test_scenario::return_shared(storage);
        test_scenario::return_shared(price_oracle);
    }

    #[test_only]
    public fun base_repay_for_testing<T>(scenario: &mut Scenario, clock: &Clock, pool: &mut Pool<T>, repay_coin: Coin<T>, asset: u8, amount: u64) {
        let storage = test_scenario::take_shared<Storage>(scenario);
        let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);

        let _balance = lending::repay_coin<T>(
            clock,
            &price_oracle, // PriceOracle object
            &mut storage,  // Storage object
            pool, // Pool object
            asset,             // asset id
            repay_coin,    // Coin: ETH
            amount,   // amount
            test_scenario::ctx(scenario)
        );

        if (sui::balance::value(&_balance) > 0) {
            let _coin = coin::from_balance(_balance, test_scenario::ctx(scenario));
            transfer::public_transfer(_coin, test_scenario::sender(scenario));
        } else {
            sui::balance::destroy_zero(_balance)
        };

        test_scenario::return_shared(storage);
        test_scenario::return_shared(price_oracle);
    }

    #[test_only]
    public fun base_liquidation_for_testing<DebtCoinType, CollateralCoinType>(
        scenario: &mut Scenario,
        debt_asset: u8,
        debt_pool: &mut Pool<DebtCoinType>,
        debt_coin: Coin<DebtCoinType>,
        collateral_asset: u8,
        collateral_pool: &mut Pool<CollateralCoinType>,
        liquidate_user: address,
        liquidate_amount: u64,
    ) {
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));
        let storage = test_scenario::take_shared<Storage>(scenario);
        let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);
        let (excess, bonus) = lending::liquidation(&clock, &price_oracle, &mut storage, debt_asset, debt_pool, debt_coin, collateral_asset, collateral_pool, liquidate_user, liquidate_amount, test_scenario::ctx(scenario));

        let _coin1 = coin::from_balance(excess, test_scenario::ctx(scenario));
        transfer::public_transfer(_coin1, test_scenario::sender(scenario));

        let _coin2 = coin::from_balance(bonus, test_scenario::ctx(scenario));
        transfer::public_transfer(_coin2, test_scenario::sender(scenario));

        clock::destroy_for_testing(clock);
        test_scenario::return_shared(storage);
        test_scenario::return_shared(price_oracle);
    }

    #[test_only]
    public fun base_deposit_with_account_for_testing<T>(scenario: &mut Scenario, clock: &Clock, pool: &mut Pool<T>, deposit_coin: Coin<T>, asset: u8, account_cap: &AccountCap) {
        let storage = test_scenario::take_shared<Storage>(scenario);

        // deposit
        lending::deposit_with_account_cap<T>(
            clock,
            &mut storage, // Storage object
            pool,         // Pool object
            asset,        // asset id
            deposit_coin, // coin
            account_cap,
        );

        test_scenario::return_shared(storage);
    }

    #[test_only]
    public fun base_withdraw_with_account_for_testing<T>(scenario: &mut Scenario, clock: &Clock, pool: &mut Pool<T>, asset: u8, amount: u64, account_cap: &AccountCap) {
        let storage = test_scenario::take_shared<Storage>(scenario);
        let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);

        let _balance = lending::withdraw_with_account_cap<T>(
            clock,
            &price_oracle, // PriceOracle object
            &mut storage,  // Storage object
            pool, // Pool object
            asset,             // asset id
            amount,  // amount
            account_cap
        );

        let _coin = coin::from_balance(_balance, test_scenario::ctx(scenario));
        transfer::public_transfer(_coin, test_scenario::sender(scenario));

        test_scenario::return_shared(storage);
        test_scenario::return_shared(price_oracle);
    }

    #[test_only]
    public fun base_borrow_with_account_for_testing<T>(scenario: &mut Scenario, clock: &Clock, pool: &mut Pool<T>, asset: u8, amount: u64, account_cap: &AccountCap) {
        let storage = test_scenario::take_shared<Storage>(scenario);
        let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);

        let _balance = lending::borrow_with_account_cap<T>(
            clock,
            &price_oracle, // PriceOracle object
            &mut storage,  // Storage object
            pool, // Pool object
            asset,             // asset id
            amount,  // amount
            account_cap
        );

        let _coin = coin::from_balance(_balance, test_scenario::ctx(scenario));
        transfer::public_transfer(_coin, test_scenario::sender(scenario));

        test_scenario::return_shared(storage);
        test_scenario::return_shared(price_oracle);
    }

    #[test_only]
    public fun base_repay_with_account_for_testing<T>(scenario: &mut Scenario, clock: &Clock, pool: &mut Pool<T>, repay_coin: Coin<T>, asset: u8, account_cap: &AccountCap) {
        let storage = test_scenario::take_shared<Storage>(scenario);
        let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);

        let _balance = lending::repay_with_account_cap<T>(
            clock,
            &price_oracle, // PriceOracle object
            &mut storage,  // Storage object
            pool, // Pool object
            asset,             // asset id
            repay_coin,    // Coin: ETH
            account_cap
        );

        let _coin = coin::from_balance(_balance, test_scenario::ctx(scenario));
        transfer::public_transfer(_coin, test_scenario::sender(scenario));

        test_scenario::return_shared(storage);
        test_scenario::return_shared(price_oracle);
    }

    #[test_only]
    public fun create_account_cap_for_testing(scenario: &mut Scenario) {
        let cap = lending::create_account(test_scenario::ctx(scenario));
        transfer::public_transfer(cap, test_scenario::sender(scenario))
    }

    #[test_only]
    public fun base_deposit_on_behalf_of_user_for_testing<T>(scenario: &mut Scenario, clock: &Clock, pool: &mut Pool<T>, deposit_coin: Coin<T>, asset: u8, user: address, amount: u64) {
        let storage = test_scenario::take_shared<Storage>(scenario);

        lending::deposit_on_behalf_of_user<T>(
            clock,
            &mut storage, // Storage object
            pool,         // Pool object
            asset,        // asset id
            user,         // user
            deposit_coin, // coin
            amount,       // amount
            test_scenario::ctx(scenario)
        );

        test_scenario::return_shared(storage);
    }

    #[test_only]
    public fun base_repay_on_behalf_of_user_for_testing<T>(scenario: &mut Scenario, clock: &Clock, pool: &mut Pool<T>, repay_coin: Coin<T>, asset: u8, user: address, amount: u64) {
        let storage = test_scenario::take_shared<Storage>(scenario);
        let price_oracle = test_scenario::take_shared<PriceOracle>(scenario);

        let _balance = lending::repay_on_behalf_of_user<T>(
            clock,
            &price_oracle, // PriceOracle object
            &mut storage,  // Storage object
            pool,          // Pool object
            asset,         // asset id
            user,          // user
            repay_coin,    // Coin: ETH
            amount,        // amount
            test_scenario::ctx(scenario)
        );

        let _coin = coin::from_balance(_balance, test_scenario::ctx(scenario));
        transfer::public_transfer(_coin, test_scenario::sender(scenario));

        test_scenario::return_shared(storage);
        test_scenario::return_shared(price_oracle);
    }
}