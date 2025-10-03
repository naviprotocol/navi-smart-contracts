/// The DvaultManage module manages the DVault(DualVault).
/// It is a role-based access control module that allows cap owners to operate the DVault.
module dvault::dvault_manage;

use dvault::active_vault::{Self, OwnerCap as ActiveOwnerCap, PauseCap, ActiveVault, Config};
use dvault::secure_vault::{Self, SecureVault, SecureOwnerCap, SecureOperatorCap};
use sui::balance::Balance;
use sui::coin::CoinMetadata;

// --------ActiveOwnerCap--------
public fun create_owner_cap(
    _: &ActiveOwnerCap,
    config: &Config,
    recipient: address,
    ctx: &mut TxContext,
) {
    config.version_verification();
    let cap = active_vault::create_owner_cap(ctx); 
    transfer::public_transfer(cap, recipient)
}

public fun create_pause_cap(
    _: &ActiveOwnerCap,
    config: &Config,
    recipient: address,
    ctx: &mut TxContext,
) {
    config.version_verification();
    let cap = active_vault::create_pause_cap(ctx);
    transfer::public_transfer(cap, recipient)
}

public fun add_signer(_: &ActiveOwnerCap, config: &mut Config, signer: vector<u8>, threshold: u64) {
    config.add_signer(signer, threshold)
}

public fun remove_signer(
    _: &ActiveOwnerCap,
    config: &mut Config,
    signer: vector<u8>,
    threshold: u64,
) {
    config.remove_signer(signer, threshold)
}

public fun reset_signers(
    _: &ActiveOwnerCap,
    config: &mut Config,
    signers: vector<vector<u8>>,
    threshold: u64,
) {
    config.reset_signers(signers, threshold)
}

public fun set_pause(_: &ActiveOwnerCap, config: &mut Config, paused: bool) {
    config.set_pause(paused)
}

public fun version_migrate(_: &ActiveOwnerCap, config: &mut Config) {
    config.version_migrate()
}

public fun active_vault_version_migrate<T>(_: &ActiveOwnerCap, vault: &mut ActiveVault<T>) {
    vault.active_vault_version_migrate()
}

public fun secure_vault_version_migrate<T>(_: &SecureOwnerCap, vault: &mut SecureVault<T>) {
    vault.secure_vault_version_migrate()
}

#[allow(lint(share_owned))]
public fun create_vault<T>(
    _: &ActiveOwnerCap,
    config: &mut Config,
    metadata: &CoinMetadata<T>,
    minimum_deposit: u64,
    minimum_withdraw: u64,
    ctx: &mut TxContext,
) {
    // create vault
    let vault = active_vault::create_vault<T>( 
        metadata,
        config,
        minimum_deposit,
        minimum_withdraw,
        ctx,
    );
    transfer::public_share_object(vault);

    // create secure vault
    secure_vault::create_vault<T>(ctx);
}

public fun set_deposit_enable<T>(
    _: &ActiveOwnerCap,
    vault: &mut ActiveVault<T>,
    config: &Config,
    enable: bool,
) {
    config.version_verification();
    vault.set_deposit_enable<T>(enable)
}

public fun set_withdraw_enable<T>(
    _: &ActiveOwnerCap,
    vault: &mut ActiveVault<T>,
    config: &Config,
    enable: bool,
) {
    config.version_verification();
    vault.set_withdraw_enable<T>(enable)
}

public fun set_minimum_deposit<T>(
    _: &ActiveOwnerCap,
    vault: &mut ActiveVault<T>,
    config: &Config,
    minimum_deposit: u64,
) {
    config.version_verification();
    vault.set_minimum_deposit<T>(minimum_deposit)
}

public fun set_minimum_withdraw<T>(
    _: &ActiveOwnerCap,
    vault: &mut ActiveVault<T>,
    config: &Config,
    minimum_withdraw: u64,
) {
    config.version_verification();
    vault.set_minimum_withdraw<T>(minimum_withdraw)
}

public fun add_security_period<T>(
    _: &ActiveOwnerCap,
    vault: &mut ActiveVault<T>,
    config: &Config,
    duration: u64,
    limit: u64,
    ctx: &mut TxContext,
) {
    config.version_verification();
    vault.add_security_period<T>(duration, limit, ctx)
}

public fun set_enable_security_period<T>(
    _: &ActiveOwnerCap,
    vault: &mut ActiveVault<T>,
    config: &Config,
    period_id: address,
    enable: bool,
) {
    config.version_verification();
    vault.set_enable_security_period<T>(period_id, enable)
}

public fun update_security_period<T>(
    _: &ActiveOwnerCap,
    vault: &mut ActiveVault<T>,
    config: &Config,
    period_id: address,
    duration: u64,
    limit: u64,
) {
    config.version_verification();
    vault.update_security_period<T>(period_id, duration, limit)
}

public fun set_max_vault_balance<T>(
    _: &ActiveOwnerCap,
    vault: &mut ActiveVault<T>,
    config: &Config,
    max_vault_balance: u64,
) {
    config.version_verification();
    vault.set_max_vault_balance<T>(max_vault_balance)
}

public fun direct_withdraw<T>(
    _: &ActiveOwnerCap,
    config: &Config,
    vault: &mut ActiveVault<T>,
    amount: u64,
    ctx: &TxContext,
): Balance<T> {
    config.version_verification();
    vault.direct_withdraw(amount, ctx)
}

public fun freeze_pause_cap(
    _: &ActiveOwnerCap,
    config: &mut Config,
    cap_id: address,
    disable: bool,
) {
    config.version_verification();
    config.freeze_pause_cap(cap_id, disable)
}

// --------PauseCap--------
public fun set_pause_by_pause_cap(cap: &PauseCap, config: &mut Config, paused: bool) {
    config.when_not_freezed_cap(cap);
    config.set_pause(paused)
}







// --------SecureOperatorCap--------
public fun operator_withdraw_secure_vault<T>(
    cap: &SecureOperatorCap,
    config: &Config,
    vault: &mut ActiveVault<T>,
    secure_vault: &mut SecureVault<T>,
    amount: u64,
    ctx: &mut TxContext,
) {
    config.version_verification(); 
    config.when_not_paused();
    secure_vault::assert_operator_enabled<T>(secure_vault, cap);
    let _balance = secure_vault.withdraw_secure_vault<T>(amount, ctx);
    vault.direct_deposit(_balance, ctx)
}

// ---------------Public--------------
public fun direct_deposit<T>(
    vault: &mut ActiveVault<T>,
    config: &Config,
    balance: Balance<T>,
    ctx: &TxContext,
) {
    config.version_verification();
    config.when_not_paused();
    vault.direct_deposit(balance, ctx)
}

public fun deposit_secure_vault<T>(
    vault: &mut SecureVault<T>,
    config: &Config,
    balance: Balance<T>,
) {
    config.version_verification();
    config.when_not_paused();
    secure_vault::deposit_secure_vault<T>(vault, balance)
}
