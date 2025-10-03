#[allow(unused_field, unused_mut_parameter)]
module lending_core::pool {
    use std::type_name;
    use std::ascii::{String};

    use sui::transfer;
    use sui::event::emit;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};

    use lending_core::error::{Self};

    friend lending_core::lending;
    friend lending_core::storage;
    friend lending_core::flash_loan;

    // The treasury pool, which is used to hold all the funds
    struct Pool<phantom CoinType> has key, store {
        id: UID,
        balance: Balance<CoinType>, // BTC. ETH
        treasury_balance: Balance<CoinType>,
        decimal: u8,
    }

    struct PoolAdminCap has key, store {
        id: UID,
        creator: address,
    }

    // Event
    struct PoolCreate has copy, drop {
        creator: address,
    }

    struct PoolBalanceRegister has copy, drop {
        sender: address,
        amount: u64,
        new_amount: u64,
        pool: String,
    }

    struct PoolDeposit has copy, drop {
        sender: address,
        amount: u64,
        pool: String,
    }

    struct PoolWithdraw has copy, drop {
        sender: address,
        recipient: address,
        amount: u64,
        pool: String,
    }

    struct PoolWithdrawReserve has copy, drop {
        sender: address,
        recipient: address,
        amount: u64,
        before: u64,
        after: u64,
        pool: String,
        poolId: address,
    }

    // Entry
    fun init(ctx: &mut TxContext) {
        transfer::public_transfer(PoolAdminCap {
            id: object::new(ctx),
            creator: tx_context::sender(ctx),
        }, tx_context::sender(ctx))
    }

    public(friend) fun create_pool<CoinType>(_: &PoolAdminCap, decimal: u8, ctx: &mut TxContext) {
        let pool = Pool<CoinType> {
            id: object::new(ctx),
            balance: balance::zero<CoinType>(),
            treasury_balance: balance::zero<CoinType>(),
            decimal: decimal,
        };
        transfer::share_object(pool);

        emit(PoolCreate {creator: tx_context::sender(ctx)})
    }

    // Putting coin into the pool
    public(friend) fun deposit<CoinType>(pool: &mut Pool<CoinType>, mint_coin: Coin<CoinType>, ctx: &mut TxContext) {
        let mint_value = coin::value(&mint_coin);
        let mint_balance = coin::into_balance(mint_coin);
        balance::join(&mut pool.balance, mint_balance);

        emit(PoolDeposit {
            sender: tx_context::sender(ctx),
            amount: mint_value,
            pool: type_name::into_string(type_name::get<CoinType>())
        })
    }

    public(friend) fun deposit_balance<CoinType>(pool: &mut Pool<CoinType>, deposit_balance: Balance<CoinType>, user: address) {
        let balance_value = balance::value(&deposit_balance);
        balance::join(&mut pool.balance, deposit_balance);

        emit(PoolDeposit {
            sender: user,
            amount: balance_value,
            pool: type_name::into_string(type_name::get<CoinType>())
        })
    }

    // Transferrung part of coin to the user
    public(friend) fun withdraw<CoinType>(pool: &mut Pool<CoinType>, amount: u64, recipient: address, ctx: &mut TxContext) {
        let withdraw_balance = balance::split(&mut pool.balance, amount);
        let withdraw_coin = coin::from_balance(withdraw_balance, ctx);
        emit(PoolWithdraw {
            sender: tx_context::sender(ctx),
            recipient: recipient,
            amount: amount,
            pool: type_name::into_string(type_name::get<CoinType>()),
        });

        transfer::public_transfer(withdraw_coin, recipient)
    }

    public(friend) fun withdraw_balance<CoinType>(pool: &mut Pool<CoinType>, amount: u64, user: address): Balance<CoinType> {
        if (amount == 0) {
            let _zero = balance::zero<CoinType>();
            return _zero
        };

        let _balance = balance::split(&mut pool.balance, amount);
        emit(PoolWithdraw {
            sender: user,
            recipient: user,
            amount: amount,
            pool: type_name::into_string(type_name::get<CoinType>()),
        });

        return _balance
    }

    public(friend) fun deposit_treasury<CoinType>(pool: &mut Pool<CoinType>, deposit_amount: u64) {
        let total_supply = balance::value(&pool.balance);
        assert!(total_supply >= deposit_amount, error::insufficient_balance());

        let decrease_balance = balance::split(&mut pool.balance, deposit_amount);
        balance::join(&mut pool.treasury_balance, decrease_balance);
    }

    public fun withdraw_treasury<CoinType>(_cap: &mut PoolAdminCap, pool: &mut Pool<CoinType>, amount: u64, recipient: address, ctx: &mut TxContext) {
        let total_supply = balance::value(&pool.treasury_balance);
        assert!(total_supply >= amount, error::insufficient_balance());

        let withdraw_balance = balance::split(&mut pool.treasury_balance, amount);
        let withdraw_coin = coin::from_balance(withdraw_balance, ctx);
        transfer::public_transfer(withdraw_coin, recipient)
    }

    public(friend) fun withdraw_reserve_balance<CoinType>(
        _: &PoolAdminCap,
        pool: &mut Pool<CoinType>,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let total_supply = balance::value(&pool.balance);
        assert!(total_supply >= amount, error::insufficient_balance());

        let withdraw_balance = balance::split(&mut pool.balance, amount);
        let withdraw_coin = coin::from_balance(withdraw_balance, ctx);

        let total_supply_after_withdraw = balance::value(&pool.balance);
        emit(PoolWithdrawReserve {
            sender: tx_context::sender(ctx),
            recipient: recipient,
            amount: amount,
            before: total_supply,
            after: total_supply_after_withdraw,
            pool: type_name::into_string(type_name::get<CoinType>()),
            poolId: object::uid_to_address(&pool.id),
        });

        transfer::public_transfer(withdraw_coin, recipient)
    }

    /// Get coin decimal
    public fun get_coin_decimal<CoinType>(pool: &Pool<CoinType>): u8 {
        pool.decimal
    }

    /// Convert amount from current decimal to target decimal
    public fun convert_amount(amount: u64, cur_decimal: u8, target_decimal: u8): u64 {
        while (cur_decimal != target_decimal) {
            if (cur_decimal < target_decimal) {
                amount = amount * 10;
                cur_decimal = cur_decimal + 1;
            }else {
                amount = amount / 10;
                cur_decimal = cur_decimal - 1;
            };
        };
        amount
    }

    /// Normal coin amount in dola protocol
    public fun normal_amount<CoinType>(pool: &Pool<CoinType>, amount: u64): u64 {
        let cur_decimal = get_coin_decimal<CoinType>(pool);
        let target_decimal = 9;
        convert_amount(amount, cur_decimal, target_decimal)
    }

    /// Unnormal coin amount in dola protocol
    public fun unnormal_amount<CoinType>(pool: &Pool<CoinType>, amount: u64): u64 {
        let cur_decimal = 9;
        let target_decimal = get_coin_decimal<CoinType>(pool);
        convert_amount(amount, cur_decimal, target_decimal)
    }

    public fun uid<T>(pool: &Pool<T>): &UID {
        &pool.id
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx)
    }

    #[test_only]
    public fun create_pool_for_testing<T>(cap: &PoolAdminCap, decimal: u8, ctx: &mut TxContext) {
        create_pool<T>(cap, decimal, ctx);
    }

    #[test_only]
    public fun get_pool_info<T>(pool: &Pool<T>): (u64, u64, u8) {
        (
            balance::value(&pool.balance),
            balance::value(&pool.treasury_balance),
            pool.decimal,
        )
    }

    #[test_only]
    public fun deposit_for_testing<T>(pool: &mut Pool<T>, mint_coin: Coin<T>, ctx: &mut TxContext) {
        deposit(pool, mint_coin, ctx);
    }

    #[test_only]
    public fun withdraw_for_testing<T>(pool: &mut Pool<T>, amount: u64, recipient: address, ctx: &mut TxContext) {
        withdraw(pool, amount, recipient, ctx)
    }

    #[test_only]
    public fun deposit_treasury_for_testing<T>(pool: &mut Pool<T>, deposit_amount: u64) {
        deposit_treasury(pool, deposit_amount)
    }

    #[test_only]
    public fun deposit_balance_for_testing<T>(pool: &mut Pool<T>, deposit_balance: Balance<T>, user: address) {
        deposit_balance(pool, deposit_balance, user)
    }

    #[test_only]
    public fun withdraw_balance_for_testing<T>(pool: &mut Pool<T>, amount: u64, user: address): Balance<T> {
        withdraw_balance(pool, amount, user)
    }

}