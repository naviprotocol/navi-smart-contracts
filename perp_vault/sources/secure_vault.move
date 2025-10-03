/// The SecureVault module manages a secure vault for the DVault(DualVault).
/// It is separated from the active vault to prevent users from directly accessing the vault.
/// It provides an extra layer of security for the active vault.
module dvault::secure_vault;

use sui::balance::{Self, Balance};
use sui::event::emit;
use sui::table::{Self, Table};

const VERSION: u64 = 0;

const EWITHDRAW_AMOUNT_TOO_HIGH: u64 = 20007;
const EWITHDRAW_AMOUNT_TOO_HIGH_IN_EPOCH: u64 = 20008;
const EOPERATOR_DISABLED: u64 = 20009;
const EVERSION_MISMATCH: u64 = 20010;

public struct SecureVault<phantom T> has key, store {
    id: UID,
    version: u64,
    balance: Balance<T>,
    disabled_operators: Table<address, bool>,
    current_epoch: u64,
    epoch_max_amount: u64, // epoch max amount, 0 -> no limit
    epoch_current_amount: u64, // epoch current amount
}

public struct SecureOwnerCap has key, store {
    id: UID,
}

public struct SecureOperatorCap has key, store {
    id: UID,
}

public struct SecureVaultCreated has copy, drop {
    vault_id: address,
}

public struct SecureOperatorCapCreated has copy, drop {
    cap_id: address,
    recipient: address,
}

public struct WithdrawnFromSecureVault has copy, drop {
    vault_id: address,
    amount: u64,
}

public struct AdminWithdrawnFromSecureVault has copy, drop {
    vault_id: address,
    amount: u64,
}

public struct OperatorEpochMaxAmountSet has copy, drop {
    vault_id: address,
    amount: u64,
}

public struct OperatorDisableSet has copy, drop {
    vault_id: address,
    operator: address,
    disable: bool,
}

public struct SecureVaultDeposited has copy, drop {
    vault_id: address,
    amount: u64,
}

fun init(ctx: &mut TxContext) {
    transfer::public_transfer(
        SecureOwnerCap { id: object::new(ctx) },
        tx_context::sender(ctx),
    );

    transfer::public_transfer(
        SecureOperatorCap { id: object::new(ctx) },
        tx_context::sender(ctx),
    );
}

// --------Functions managed by dual_vault_manage--------
public(package) fun create_vault<T>(ctx: &mut TxContext) {
    let vault = SecureVault<T> {
        id: object::new(ctx),
        version: VERSION,
        disabled_operators: table::new<address, bool>(ctx),
        balance: balance::zero(),
        current_epoch: 0,
        epoch_max_amount: 0,
        epoch_current_amount: 0,
    };
    emit(SecureVaultCreated { vault_id: vault.id.to_address() });
    transfer::public_share_object(vault);
}

public(package) fun withdraw_secure_vault<T>(
    vault: &mut SecureVault<T>,
    amount: u64,
    ctx: &TxContext,
): Balance<T> {
    vault.secure_vault_version_verification();

    assert!(amount <= vault.balance.value(), EWITHDRAW_AMOUNT_TOO_HIGH);
    if (ctx.epoch() > vault.current_epoch) {
        vault.current_epoch = ctx.epoch();
        vault.epoch_current_amount = 0;
    };
    vault.epoch_current_amount = vault.epoch_current_amount + amount;
    assert!(
        vault.epoch_max_amount == 0 || vault.epoch_current_amount <= vault.epoch_max_amount,
        EWITHDRAW_AMOUNT_TOO_HIGH_IN_EPOCH,
    );
    emit(WithdrawnFromSecureVault { vault_id: vault.id.to_address(), amount: amount });
    vault.balance.split(amount)
}

public(package) fun deposit_secure_vault<T>(vault: &mut SecureVault<T>, balance: Balance<T>) {
    vault.secure_vault_version_verification();

    let amount = balance.value();
    vault.balance.join(balance);
    emit(SecureVaultDeposited { vault_id: vault.id.to_address(), amount: amount });
}

public fun assert_operator_enabled<T>(vault: &SecureVault<T>, cap: &SecureOperatorCap) {
    assert!(
        !vault.disabled_operators.contains(cap.id.to_address()) || !*vault.disabled_operators.borrow(cap.id.to_address()),
        EOPERATOR_DISABLED,
    );
}

// -----------Owner------------
public entry fun create_operator_cap(_: &SecureOwnerCap, recipient: address, ctx: &mut TxContext) {
    let cap = SecureOperatorCap { id: object::new(ctx) };
    emit(SecureOperatorCapCreated { cap_id: cap.id.to_address(), recipient: recipient });
    transfer::public_transfer(cap, recipient);
}

public fun admin_withdraw_secure_vault<T>(
    vault: &mut SecureVault<T>,
    _: &SecureOwnerCap,
    amount: u64,
): Balance<T> {
    vault.secure_vault_version_verification();

    assert!(amount <= vault.balance.value(), EWITHDRAW_AMOUNT_TOO_HIGH);
    emit(AdminWithdrawnFromSecureVault { vault_id: vault.id.to_address(), amount: amount });
    vault.balance.split(amount)
}

public fun set_operator_epoch_max_amount<T>(
    vault: &mut SecureVault<T>,
    _: &SecureOwnerCap,
    amount: u64,
) {
    vault.secure_vault_version_verification();

    vault.epoch_max_amount = amount;
    emit(OperatorEpochMaxAmountSet { vault_id: vault.id.to_address(), amount: amount });
}

public fun set_disable_operator<T>(
    vault: &mut SecureVault<T>,
    _: &SecureOwnerCap,
    operator: address,
    disable: bool,
) {
    vault.secure_vault_version_verification();

    if (vault.disabled_operators.contains(operator)) {
        *vault.disabled_operators.borrow_mut(operator) = disable;
    } else {
        vault.disabled_operators.add(operator, disable);
    };
    emit(OperatorDisableSet {
        vault_id: vault.id.to_address(),
        operator: operator,
        disable: disable,
    });
}

public(package) fun secure_vault_version_verification<T>(vault: &SecureVault<T>) {
    assert!(vault.version == VERSION, EVERSION_MISMATCH);
}

public(package) fun secure_vault_version_migrate<T>(vault: &mut SecureVault<T>) {
    assert!(vault.version < VERSION, EVERSION_MISMATCH);
    vault.version = VERSION;
}

// --------Public--------
public fun balance_value<T>(vault: &SecureVault<T>): u64 {
    vault.balance.value()
}

public fun to_address<T>(vault: &SecureVault<T>): address {
    vault.id.to_address()
}

// --------Test--------
#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx)
}

#[test_only]
public fun cap_to_address(cap: &SecureOperatorCap): address {
    cap.id.to_address()
}

#[test_only]
public fun get_current_epoch<T>(vault: &SecureVault<T>): u64 {
    vault.current_epoch
}

#[test_only]
public fun get_current_epoch_amount<T>(vault: &SecureVault<T>): u64 {
    vault.epoch_current_amount
}

#[test_only]
public fun get_disabled_operator<T>(vault: &SecureVault<T>, operator: address): bool {
    let is_disabled = vault.disabled_operators.borrow(operator);
    return *is_disabled
}
