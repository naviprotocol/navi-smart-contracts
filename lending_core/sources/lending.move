#[allow(unused_mut_parameter, unused_function)]
module lending_core::lending {
    use sui::balance::{Self, Balance};
    use sui::event::emit;
    use sui::clock::{Clock};
    use sui::coin::{Self, Coin};
    use sui::tx_context::{Self, TxContext};
    use utils::utils;
    use oracle::oracle::{Self, PriceOracle};

    use lending_core::logic::{Self};
    use lending_core::pool::{Self, Pool};
    use lending_core::storage::{Self, Storage};
    use lending_core::incentive::{Incentive};
    use lending_core::account::{Self, AccountCap};
    use lending_core::error::{Self};
    use lending_core::flash_loan::{Self, Config as FlashLoanConfig, Receipt as FlashLoanReceipt};

    friend lending_core::incentive_v2;
    friend lending_core::incentive_v3;

    #[test_only]
    friend lending_core::base_lending_tests;

    // Event
    struct DepositEvent has copy, drop {
        reserve: u8,
        sender: address,
        amount: u64,
    }

    struct DepositOnBehalfOfEvent has copy, drop {
        reserve: u8,
        sender: address,
        user: address,
        amount: u64,
    }

    struct WithdrawEvent has copy, drop {
        reserve: u8,
        sender: address,
        to: address,
        amount: u64,
    }

    struct BorrowEvent has copy, drop {
        reserve: u8,
        sender: address,
        amount: u64,
    }

    struct RepayEvent has copy, drop {
        reserve: u8,
        sender: address,
        amount: u64,
    }
    
    struct RepayOnBehalfOfEvent has copy, drop {
        reserve: u8,
        sender: address,
        user: address,
        amount: u64,
    }

    #[allow(unused_field)]
    struct LiquidationCallEvent has copy, drop {
        reserve: u8,
        sender: address,
        liquidate_user: address,
        liquidate_amount: u64,
    }

    struct LiquidationEvent has copy, drop {
        sender: address,
        user: address,
        collateral_asset: u8,
        collateral_price: u256,
        collateral_amount: u64,
        treasury: u64,
        debt_asset: u8,
        debt_price: u256,
        debt_amount: u64,
    }

    fun when_not_paused(storage: &Storage) {
        assert!(!storage::pause(storage), error::paused())
    }

    public entry fun deposit<CoinType>(
        _clock: &Clock,
        _storage: &mut Storage,
        _pool: &mut Pool<CoinType>,
        _asset: u8,
        _deposit_coin: Coin<CoinType>,
        _amount: u64,
        _incentive: &mut Incentive,
        _ctx: &mut TxContext
    ) {
        abort 0
    }

    public entry fun withdraw<CoinType>(
        _clock: &Clock,
        _oracle: &PriceOracle,
        _storage: &mut Storage,
        _pool: &mut Pool<CoinType>,
        _asset: u8,
        _amount: u64,
        _to: address,
        _incentive: &mut Incentive,
        _ctx: &mut TxContext
    ) {
        abort 0
    }

    public entry fun borrow<CoinType>(
        _clock: &Clock,
        _oracle: &PriceOracle,
        _storage: &mut Storage,
        _pool: &mut Pool<CoinType>,
        _asset: u8,
        _amount: u64,
        _ctx: &mut TxContext
    ) {
        abort 0
    }

    public entry fun repay<CoinType>(
        _clock: &Clock,
        _oracle: &PriceOracle,
        _storage: &mut Storage,
        _pool: &mut Pool<CoinType>,
        _asset: u8,
        _repay_coin: Coin<CoinType>,
        _amount: u64,
        _ctx: &mut TxContext
    ) {
        abort 0
    }

    public entry fun liquidation_call<CoinType, CollateralCoinType>(
        _clock: &Clock,
        _oracle: &PriceOracle,
        _storage: &mut Storage,
        _debt_asset: u8, // Which pool to liquidate
        _debt_pool: &mut Pool<CoinType>,
        _collateral_asset: u8,
        _collateral_pool: &mut Pool<CollateralCoinType>,
        _debt_coin: Coin<CoinType>, // Repayment coin
        _liquidate_user: address, // Liquidated users
        _liquidate_amount: u64, // Liquidated amount
        _incentive: &mut Incentive,
        _ctx: &mut TxContext
    ) {
        abort 0
    }

    // Non-Entry, Base Functions

    // Non-Entry: Deposit Function
    public(friend) fun deposit_coin<CoinType>(
        clock: &Clock,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        deposit_coin: Coin<CoinType>,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let deposit_balance = utils::split_coin_to_balance(deposit_coin, amount, ctx);
        base_deposit(clock, storage, pool, asset, sender, deposit_balance)
    }

    // Base: Deposit Function
    fun base_deposit<CoinType>(
        clock: &Clock,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        user: address,
        deposit_balance: Balance<CoinType>,
    ) {
        storage::when_not_paused(storage);
        storage::version_verification(storage);

        let deposit_amount = balance::value(&deposit_balance);
        pool::deposit_balance(pool, deposit_balance, user);

        let normal_deposit_amount = pool::normal_amount(pool, deposit_amount);
        logic::execute_deposit<CoinType>(clock, storage, asset, user, (normal_deposit_amount as u256));

        emit(DepositEvent {
            reserve: asset,
            sender: user,
            amount: deposit_amount,
        })
    }

    // Non-Entry: Withdraw Function
    public(friend) fun withdraw_coin<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        amount: u64,
        ctx: &mut TxContext
    ): Balance<CoinType> {
        let sender = tx_context::sender(ctx);
        let _balance = base_withdraw(clock, oracle, storage, pool, asset, amount, sender);
        return _balance
    }

    // Base: Withdraw Function
    fun base_withdraw<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        amount: u64,
        user: address
    ): Balance<CoinType> {
        storage::when_not_paused(storage);
        storage::version_verification(storage);

        let normal_withdraw_amount = pool::normal_amount(pool, amount);
        let normal_withdrawable_amount = logic::execute_withdraw<CoinType>(
            clock,
            oracle,
            storage,
            asset,
            user,
            (normal_withdraw_amount as u256)
        );

        let withdrawable_amount = pool::unnormal_amount(pool, normal_withdrawable_amount);
        let _balance = pool::withdraw_balance(pool, withdrawable_amount, user);
        emit(WithdrawEvent {
            reserve: asset,
            sender: user,
            to: user,
            amount: withdrawable_amount,
        });

        return _balance
    }

    // Non-Entry: Borrow Function
    public(friend) fun borrow_coin<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        amount: u64,
        ctx: &mut TxContext
    ): Balance<CoinType> {
        let sender = tx_context::sender(ctx);
        let _balance = base_borrow(clock, oracle, storage, pool, asset, amount, sender);
        return _balance
    }

    // Base: Borrow Function
    fun base_borrow<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        amount: u64,
        user: address,
    ): Balance<CoinType> {
        storage::when_not_paused(storage);
        storage::version_verification(storage);

        let normal_borrow_amount = pool::normal_amount(pool, amount);
        logic::execute_borrow<CoinType>(clock, oracle, storage, asset, user, (normal_borrow_amount as u256));

        let _balance = pool::withdraw_balance(pool, amount, user);
        emit(BorrowEvent {
            reserve: asset,
            sender: user,
            amount: amount
        });

        return _balance
    }

    // Non-Entry: Repay Function
    public(friend) fun repay_coin<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        repay_coin: Coin<CoinType>,
        amount: u64,
        ctx: &mut TxContext
    ): Balance<CoinType> {
        let sender = tx_context::sender(ctx);
        let repay_balance = utils::split_coin_to_balance(repay_coin, amount, ctx);
        let _balance = base_repay(clock, oracle, storage, pool, asset, repay_balance, sender);

        return _balance
    }

    // Base: Repay Function
    fun base_repay<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        repay_balance: Balance<CoinType>,
        user: address,
    ): Balance<CoinType> {
        storage::when_not_paused(storage);
        storage::version_verification(storage);

        let repay_amount = balance::value(&repay_balance);
        pool::deposit_balance(pool, repay_balance, user);

        let normal_repay_amount = pool::normal_amount(pool, repay_amount);

        let normal_excess_amount = logic::execute_repay<CoinType>(clock, oracle, storage, asset, user, (normal_repay_amount as u256));
        let excess_amount = pool::unnormal_amount(pool, (normal_excess_amount as u64));

        emit(RepayEvent {
            reserve: asset,
            sender: user,
            amount: repay_amount - excess_amount
        });

        if (excess_amount > 0) {
            let _balance = pool::withdraw_balance(pool, excess_amount, user);
            return _balance
        } else {
            let _balance = balance::zero<CoinType>();
            return _balance
        }
    }

    public(friend) fun liquidation<DebtCoinType, CollateralCoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        debt_asset: u8,
        debt_pool: &mut Pool<DebtCoinType>,
        debt_coin: Coin<DebtCoinType>,
        collateral_asset: u8,
        collateral_pool: &mut Pool<CollateralCoinType>,
        liquidate_user: address,
        liquidate_amount: u64,
        ctx: &mut TxContext
    ): (Balance<CollateralCoinType>, Balance<DebtCoinType>) {
        let sender = tx_context::sender(ctx);
        let debt_balance = utils::split_coin_to_balance(debt_coin, liquidate_amount, ctx);

        let (_excess_balance, _bonus_balance) = base_liquidation_call(
            clock,
            oracle,
            storage,
            debt_asset,
            debt_pool,
            debt_balance,
            collateral_asset,
            collateral_pool,
            sender,
            liquidate_user
        );

        (_bonus_balance, _excess_balance)
    }

    public(friend) fun liquidation_non_entry<DebtCoinType, CollateralCoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        debt_asset: u8,
        debt_pool: &mut Pool<DebtCoinType>,
        debt_balance: Balance<DebtCoinType>,
        collateral_asset: u8,
        collateral_pool: &mut Pool<CollateralCoinType>,
        liquidate_user: address,
        ctx: &mut TxContext
    ): (Balance<CollateralCoinType>, Balance<DebtCoinType>) {
        let sender = tx_context::sender(ctx);

        let (_excess_balance, _bonus_balance) = base_liquidation_call(
            clock,
            oracle,
            storage,
            debt_asset,
            debt_pool,
            debt_balance,
            collateral_asset,
            collateral_pool,
            sender,
            liquidate_user
        );

        (_bonus_balance, _excess_balance)
    }

    // Base: Liquidation Function
    fun base_liquidation_call<DebtCoinType, CollateralCoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        debt_asset: u8,
        debt_pool: &mut Pool<DebtCoinType>,
        debt_balance: Balance<DebtCoinType>,
        collateral_asset: u8,
        collateral_pool: &mut Pool<CollateralCoinType>,
        executor: address,
        liquidate_user: address
    ): (Balance<DebtCoinType>, Balance<CollateralCoinType>) {
        storage::when_not_paused(storage);
        storage::version_verification(storage);

        let debt_amount = balance::value(&debt_balance);
        pool::deposit_balance(debt_pool, debt_balance, executor);

        let normal_debt_amount = pool::normal_amount(debt_pool, debt_amount);
        let (
            normal_obtainable_amount,
            normal_excess_amount,
            normal_treasury_amount
        ) = logic::execute_liquidate<DebtCoinType, CollateralCoinType>(
            clock,
            oracle,
            storage,
            liquidate_user,
            collateral_asset,
            debt_asset,
            (normal_debt_amount as u256)
        );

        // The treasury balance
        let treasury_amount = pool::unnormal_amount(collateral_pool, (normal_treasury_amount as u64));
        pool::deposit_treasury(collateral_pool, treasury_amount);

        // The total collateral balance = collateral + bonus
        let obtainable_amount = pool::unnormal_amount(collateral_pool, (normal_obtainable_amount as u64));
        let obtainable_balance = pool::withdraw_balance(collateral_pool, obtainable_amount, executor);

        // The excess balance
        let excess_amount = pool::unnormal_amount(debt_pool, (normal_excess_amount as u64));
        let excess_balance = pool::withdraw_balance(debt_pool, excess_amount, executor);

        let collateral_oracle_id = storage::get_oracle_id(storage, collateral_asset);
        let debt_oracle_id = storage::get_oracle_id(storage, debt_asset);

        let (_, collateral_price, _) = oracle::get_token_price(clock, oracle, collateral_oracle_id);
        let (_, debt_price, _) = oracle::get_token_price(clock, oracle, debt_oracle_id);

        emit(LiquidationEvent {
            sender: executor,
            user: liquidate_user,
            collateral_asset: collateral_asset,
            collateral_price: collateral_price,
            collateral_amount: obtainable_amount + treasury_amount,
            treasury: treasury_amount,
            debt_asset: debt_asset,
            debt_price: debt_price,
            debt_amount: debt_amount - excess_amount,
        });

        return (excess_balance, obtainable_balance)
    }

    // Account Cap
    public fun create_account(ctx: &mut TxContext): AccountCap {
        account::create_account_cap(ctx)
    }

    public fun delete_account(_cap: AccountCap) {
        abort 0
    }

    public(friend) fun deposit_with_account_cap<CoinType>(
        clock: &Clock,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        deposit_coin: Coin<CoinType>,
        account_cap: &AccountCap
    ) {
        base_deposit(clock, storage, pool, asset, account::account_owner(account_cap), coin::into_balance(deposit_coin))
    }

    public(friend) fun withdraw_with_account_cap<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        amount: u64,
        account_cap: &AccountCap
    ): Balance<CoinType> {
        base_withdraw(clock, oracle, storage, pool, asset, amount, account::account_owner(account_cap))
    }

    public(friend) fun borrow_with_account_cap<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        amount: u64,
        account_cap: &AccountCap
    ): Balance<CoinType> {
        base_borrow(clock, oracle, storage, pool, asset, amount, account::account_owner(account_cap))
    }

    public(friend) fun repay_with_account_cap<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        repay_coin: Coin<CoinType>,
        account_cap: &AccountCap
    ): Balance<CoinType> {
        base_repay(clock, oracle, storage, pool, asset, coin::into_balance(repay_coin), account::account_owner(account_cap))
    }

    // Flash Loan
    fun base_flash_loan<CoinType>(config: &FlashLoanConfig, pool: &mut Pool<CoinType>, user: address, amount: u64): (Balance<CoinType>, FlashLoanReceipt<CoinType>) {
        flash_loan::loan<CoinType>(config, pool, user, amount)
    }

    fun base_flash_repay<CoinType>(clock: &Clock, storage: &mut Storage, pool: &mut Pool<CoinType>, receipt: FlashLoanReceipt<CoinType>, user: address, repay_balance: Balance<CoinType>): Balance<CoinType> {
        flash_loan::repay<CoinType>(clock, storage, pool, receipt, user, repay_balance)
    }

    public fun flash_loan_with_ctx<CoinType>(config: &FlashLoanConfig, pool: &mut Pool<CoinType>, amount: u64, ctx: &mut TxContext): (Balance<CoinType>, FlashLoanReceipt<CoinType>) {
        base_flash_loan<CoinType>(config, pool, tx_context::sender(ctx), amount)
    }

    public fun flash_loan_with_account_cap<CoinType>(config: &FlashLoanConfig, pool: &mut Pool<CoinType>, amount: u64, account_cap: &AccountCap): (Balance<CoinType>, FlashLoanReceipt<CoinType>) {
        base_flash_loan<CoinType>(config, pool, account::account_owner(account_cap), amount)
    }

    public fun flash_repay_with_ctx<CoinType>(clock: &Clock, storage: &mut Storage, pool: &mut Pool<CoinType>, receipt: FlashLoanReceipt<CoinType>, repay_balance: Balance<CoinType>, ctx: &mut TxContext): Balance<CoinType> {
        base_flash_repay<CoinType>(clock, storage, pool, receipt, tx_context::sender(ctx), repay_balance)
    }

    public fun flash_repay_with_account_cap<CoinType>(clock: &Clock, storage: &mut Storage, pool: &mut Pool<CoinType>, receipt: FlashLoanReceipt<CoinType>, repay_balance: Balance<CoinType>, account_cap: &AccountCap): Balance<CoinType> {
        base_flash_repay<CoinType>(clock, storage, pool, receipt, account::account_owner(account_cap), repay_balance)
    }

    public(friend) fun deposit_on_behalf_of_user<CoinType>(clock: &Clock, storage: &mut Storage, pool: &mut Pool<CoinType>, asset: u8, user: address, deposit_coin: Coin<CoinType>, value: u64, ctx: &mut TxContext) {
        let deposit_balance = utils::split_coin_to_balance(deposit_coin, value, ctx);
        base_deposit(clock, storage, pool, asset, user, deposit_balance);

        emit(DepositOnBehalfOfEvent{
            reserve: asset,
            sender: tx_context::sender(ctx),
            user: user,
            amount: value,
        })
    }

    public(friend) fun repay_on_behalf_of_user<CoinType>(clock: &Clock, oracle: &PriceOracle, storage: &mut Storage, pool: &mut Pool<CoinType>, asset: u8, user: address, repay_coin: Coin<CoinType>, value: u64, ctx: &mut TxContext): Balance<CoinType> {
        let repay_balance = utils::split_coin_to_balance(repay_coin, value, ctx);
        let _balance = base_repay(clock, oracle, storage, pool, asset, repay_balance, user);

        let balance_value = balance::value(&_balance);
        emit(RepayOnBehalfOfEvent{
            reserve: asset,
            sender: tx_context::sender(ctx),
            user: user,
            amount: value - balance_value,
        });

        _balance
    }
}