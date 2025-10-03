module dvault::user_entry;

use dvault::active_vault::{ActiveVault, Config};
use dvault::secure_vault::SecureVault;
use sui::clock::Clock;
use sui::coin::Coin;

const EINFUFFICIENT_BALANCE: u64 = 20000;

#[allow(lint(self_transfer))]
public fun deposit<T>(
    config: &Config,
    vault: &mut ActiveVault<T>,
    secure_vault: &mut SecureVault<T>,
    _coin: Coin<T>,
    amount: u64,
    ctx: &mut TxContext,
) {
    assert!(_coin.value() >= amount, EINFUFFICIENT_BALANCE);

    let mut _balance = _coin.into_balance();
    let _split = _balance.split(amount);

    vault.deposit(config, secure_vault, ctx.sender(), _split);

    if (_balance.value() > 0) {
        transfer::public_transfer(_balance.into_coin(ctx), ctx.sender());
    } else {
        _balance.destroy_zero()
    }
}

public fun withdraw<T>(
    clock: &Clock,
    config: &Config,
    vault: &mut ActiveVault<T>,
    order_id: u256,
    order_time: u64,
    amount: u64,
    recipient: address,
    signatures: vector<vector<u8>>,
    message: vector<u8>,
    ctx: &mut TxContext,
) {
    let _balance = vault.withdraw(
        clock,
        config,
        order_id,
        order_time,
        ctx.sender(),
        amount,
        recipient,
        signatures,
        message,
    );
    transfer::public_transfer(_balance.into_coin(ctx), recipient);
}
