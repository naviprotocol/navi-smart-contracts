/// The ActiveVault module manages the active vault for the DVault(DualVault).
/// It provides deposit and withdraw functions to the active vault for users.
module dvault::active_vault;

use dvault::secure_vault::{Self, SecureVault};
use std::ascii::into_bytes;
use std::type_name::{get, into_string};
use sui::address::from_u256;
use sui::balance::{Self, Balance};
use sui::clock::Clock;
use sui::coin::CoinMetadata;
use sui::ed25519;
use sui::event::emit;
use sui::hash::keccak256;
use sui::table::{Self, Table};

const VERSION: u64 = 0;

const ESIGNER_ALREADY_EXISTS: u64 = 10000;
const ESIGNER_NOT_FOUND: u64 = 10001;
const ETHRESHOLD_OVERFLOW: u64 = 10002;
const EPAUSED: u64 = 10003;
const EDISABLED: u64 = 10004;
const EVERSION_MISMATCH: u64 = 10005;
const EDEPOSIT_AMOUNT_TOO_LOW: u64 = 10006;
const EWITHDRAW_AMOUNT_TOO_LOW: u64 = 10007;
const EINVALID_SIGNATURES: u64 = 10008;
const ETRANSACTION_HASH_ALREADY_USED: u64 = 10009;
const ETHRESHOLD_TOO_LOW: u64 = 10010;
const EWITHDRAWAL_AMOUNT_OVERFLOW: u64 = 10011;
const EEXPIRED: u64 = 10012;
const ESECURITY_PERIOD_NOT_FOUND: u64 = 10013;
const EORDER_ID_ALREADY_USED: u64 = 10014;

public struct OwnerCap has key, store {
    id: UID,
}

public struct PauseCap has key, store {
    id: UID,
}

public struct Config has key, store {
    id: UID,
    version: u64,
    paused: bool,
    signers: vector<vector<u8>>,
    threshold: u64,
    treasuries: vector<address>,
    freezed_caps: Table<address, bool>, // freezed pause cap
}

public struct ActiveVault<phantom T> has key, store {
    id: UID,
    version: u64,
    balance: Balance<T>,
    config: ActiveVaultConfig,
}

public struct ActiveVaultConfig has store {
    deposit_enable: bool,
    withdraw_enable: bool,
    max_vault_balance: u64, // 0 -> no limit
    deposit_minimum_balance: u64,
    withdraw_minimum_balance: u64,
    order_id_counter: u64,
    used_hashes: Table<vector<u8>, bool>,
    deposit_order_ids: Table<u256, u64>,
    withdrawal_order_ids: Table<u256, u64>,
    withdraw_security_period: vector<SecurityPeriod>,
}

public struct SecurityPeriod has key, store {
    id: UID,
    enable: bool,
    duration: u64,
    limit: u64,
    period_amount: Table<u64, u64>,
}

public struct ActiveVaultCreated has copy, drop {
    sender: address,
    vault: address,
}

public struct OwnerCapCreated has copy, drop {
    sender: address,
    owner_cap: address,
}

public struct PauseCapCreated has copy, drop {
    sender: address,
    pause_cap: address,
}

public struct Deposited has copy, drop {
    user: address,
    amount: u64,
    vault_id: address,
    order_id: u64,
}

public struct DirectDeposited has copy, drop {
    user: address,
    amount: u64,
    vault_id: address,
}

public struct Withdrawn has copy, drop {
    order_id: u256,
    order_time: u64,
    caller: address,
    recipient: address,
    amount: u64,
    vault_id: address,
}

public struct DirectWithdrawn has copy, drop {
    user: address,
    amount: u64,
    vault_id: address,
}

public struct SignerAdded has copy, drop {
    signer: vector<u8>,
    threshold: u64,
}

public struct SignerRemoved has copy, drop {
    signer: vector<u8>,
    threshold: u64,
}

public struct SignerReset has copy, drop {
    signers: vector<vector<u8>>,
    threshold: u64,
}

public struct ConfigUpdatedU64 has copy, drop {
    config_field: vector<u8>,
    value: u64,
}

public struct ConfigUpdatedBool has copy, drop {
    config_field: vector<u8>,
    value: bool,
}

public struct SecurityPeriodUpdated has copy, drop {
    period_id: address,
    duration: u64,
    limit: u64,
    enable: bool,
}

public struct PauseCapFreezeSet has copy, drop {
    cap_id: address,
    disable: bool,
}

// Init function
fun init(ctx: &mut TxContext) {
    transfer::public_transfer(
        OwnerCap { id: object::new(ctx) },
        tx_context::sender(ctx),
    );

    transfer::public_share_object(Config {
        id: object::new(ctx),
        version: VERSION,
        paused: false,
        signers: vector::empty<vector<u8>>(),
        threshold: 0,
        treasuries: vector::empty<address>(),
        freezed_caps: table::new<address, bool>(ctx),
    });
}

// -----Entry functions-----
public(package) fun deposit<T>(
    vault: &mut ActiveVault<T>,
    config: &Config,
    secure_vault: &mut SecureVault<T>,
    user: address,
    _balance: Balance<T>,
) {
    when_not_paused(config);
    when_deposit_not_disabled(vault);

    config.version_verification();
    vault.active_vault_version_verification();
    secure_vault.secure_vault_version_verification();

    let value = _balance.value();
    assert!(value >= vault.config.deposit_minimum_balance, EDEPOSIT_AMOUNT_TOO_LOW);

    let mut vault_id = vault.id.to_address();
    if (
        vault.config.max_vault_balance != 0 && vault.balance.value() + value > vault.config.max_vault_balance
    ) {
        secure_vault.deposit_secure_vault(_balance);
        vault_id = secure_vault.to_address();
    } else {
        vault.balance.join(_balance);
    };

    let order_id = vault.config.order_id_counter;
    vault.config.deposit_order_ids.add(order_id as u256, value);
    vault.config.order_id_counter = vault.config.order_id_counter + 1;

    emit(Deposited { user: user, amount: value, vault_id: vault_id, order_id: order_id });
}

public(package) fun withdraw<T>(
    vault: &mut ActiveVault<T>,
    clock: &Clock,
    config: &Config,
    order_id: u256,
    order_time: u64,
    caller: address,
    amount: u64,
    recipient: address,
    signatures: vector<vector<u8>>,
    message: vector<u8>,
): Balance<T> {
    when_not_paused(config);
    when_withdraw_not_disabled(vault);
    when_not_expired(clock, order_time);

    config.version_verification();
    vault.active_vault_version_verification();

    vault.security_update(clock, amount);

    assert!(signatures.length() >= config.threshold, EINVALID_SIGNATURES);
    assert!(signatures.length() <= config.signers.length(), EINVALID_SIGNATURES);

    assert!(amount >= vault.config.withdraw_minimum_balance, EWITHDRAW_AMOUNT_TOO_LOW);

    let kmessage = keccak_message<T>(order_id, order_time, caller, amount, recipient, message);

    // Ensure signatures are not used & order id is not used (and update them)
    assert!(!vault.config.used_hashes.contains(kmessage), ETRANSACTION_HASH_ALREADY_USED);
    vault.config.used_hashes.add(kmessage, true);
    assert!(!vault.config.withdrawal_order_ids.contains(order_id), EORDER_ID_ALREADY_USED);
    vault.config.withdrawal_order_ids.add(order_id, amount);

    // Check signatures
    // It's composed of multiple signatures, so we need to check the number reached the threshold
    let mut i = 0;
    let mut threshold = 0;
    let signature_length = signatures.length();
    let signer_length = config.signers.length();
    while (i < signer_length) {
        let _signer = config.signers.borrow(i);

        let mut j = 0;
        while (j < signature_length) {
            let _signature = signatures.borrow(j);
            assert!(_signature.length() == 64, EINVALID_SIGNATURES);

            if (ed25519::ed25519_verify(_signature, _signer, &kmessage)) {
                threshold = threshold + 1;
                break
            };
            j = j + 1;
        };
        i = i + 1;
    };
    assert!(threshold >= config.threshold, ETHRESHOLD_TOO_LOW);

    emit(Withdrawn {
        order_id: order_id,
        order_time: order_time,
        caller: caller,
        recipient: recipient,
        amount: amount,
        vault_id: vault.id.to_address(),
    });
    return vault.balance.split(amount)
}

// -----Manage functions(Config)-----
public(package) fun create_owner_cap(ctx: &mut TxContext): OwnerCap {
    let cap = OwnerCap {
        id: object::new(ctx),
    };

    emit(OwnerCapCreated { sender: ctx.sender(), owner_cap: cap.id.to_address() });
    return cap
}

public(package) fun create_pause_cap(ctx: &mut TxContext): PauseCap {
    let cap = PauseCap {
        id: object::new(ctx),
    };
    emit(PauseCapCreated { sender: ctx.sender(), pause_cap: cap.id.to_address() });
    return cap
}

public(package) fun add_signer(config: &mut Config, signer: vector<u8>, threshold: u64) {
    config.version_verification();

    assert!(!config.signers.contains(&signer), ESIGNER_ALREADY_EXISTS);
    assert!(threshold > 0 && threshold <= config.signers.length() + 1, ETHRESHOLD_OVERFLOW);

    config.signers.push_back(signer);
    config.threshold = threshold;
    emit(SignerAdded { signer: signer, threshold: threshold });
}

public(package) fun remove_signer(config: &mut Config, signer: vector<u8>, threshold: u64) {
    config.version_verification();
    
    let (ok, idx) = config.signers.index_of(&signer);
    assert!(ok, ESIGNER_NOT_FOUND);
    assert!(threshold > 0 && threshold <= config.signers.length()-1, ETHRESHOLD_OVERFLOW);

    config.signers.remove(idx);
    config.threshold = threshold;
    emit(SignerRemoved { signer: signer, threshold: threshold });
}

public(package) fun reset_signers(
    config: &mut Config,
    signers: vector<vector<u8>>,
    threshold: u64,
) {
    config.version_verification();

    assert!(threshold > 0 && threshold <= signers.length(), ETHRESHOLD_OVERFLOW);

    config.signers = signers;
    config.threshold = threshold;
    emit(SignerReset { signers: signers, threshold: threshold });
}

public(package) fun set_pause(config: &mut Config, paused: bool) {
    config.version_verification();

    config.paused = paused;
}

public(package) fun freeze_pause_cap(config: &mut Config, cap_id: address, disable: bool) {
    config.version_verification();

    if (config.freezed_caps.contains(cap_id)) {
        *config.freezed_caps.borrow_mut(cap_id) = disable;
    } else {
        config.freezed_caps.add(cap_id, disable);
    };
    emit(PauseCapFreezeSet { cap_id: cap_id, disable: disable });
}

public(package) fun version_migrate(config: &mut Config) {
    assert!(config.version < VERSION, EVERSION_MISMATCH);
    config.version = VERSION;
}

public(package) fun active_vault_version_migrate<T>(vault: &mut ActiveVault<T>) {
    assert!(vault.version < VERSION, EVERSION_MISMATCH);
    vault.version = VERSION;
}

// -----Manage functions(Vault)-----
public(package) fun create_vault<T>(
    _: &CoinMetadata<T>,
    config: &mut Config,
    minimum_deposit: u64,
    minimum_withdraw: u64,
    ctx: &mut TxContext,
): ActiveVault<T> {
    config.version_verification();
    config.when_not_paused();

    let vault = ActiveVault {
        id: object::new(ctx),
        version: VERSION,
        balance: balance::zero<T>(),
        config: ActiveVaultConfig {
            deposit_enable: true,
            withdraw_enable: true,
            max_vault_balance: 0,
            deposit_minimum_balance: minimum_deposit,
            withdraw_minimum_balance: minimum_withdraw,
            order_id_counter: 0,
            used_hashes: table::new<vector<u8>, bool>(ctx),
            deposit_order_ids: table::new<u256, u64>(ctx),
            withdrawal_order_ids: table::new<u256, u64>(ctx),
            withdraw_security_period: vector::empty<SecurityPeriod>(),
        },
    };
    config.treasuries.push_back(vault.id.to_address());

    emit(ActiveVaultCreated { sender: ctx.sender(), vault: vault.id.to_address() });
    return vault
}

public(package) fun set_deposit_enable<T>(vault: &mut ActiveVault<T>, enable: bool) {
    vault.active_vault_version_verification();

    vault.config.deposit_enable = enable;
    emit(ConfigUpdatedBool { config_field: b"deposit_enable", value: enable });
}

public(package) fun set_withdraw_enable<T>(vault: &mut ActiveVault<T>, enable: bool) {
    vault.active_vault_version_verification();

    vault.config.withdraw_enable = enable;
    emit(ConfigUpdatedBool { config_field: b"withdraw_enable", value: enable });
}

public(package) fun set_minimum_deposit<T>(vault: &mut ActiveVault<T>, v: u64) {
    vault.active_vault_version_verification();

    vault.config.deposit_minimum_balance = v;
    emit(ConfigUpdatedU64 { config_field: b"deposit_minimum_balance", value: v });
}

public(package) fun set_minimum_withdraw<T>(vault: &mut ActiveVault<T>, v: u64) {
    vault.active_vault_version_verification();

    vault.config.withdraw_minimum_balance = v;
    emit(ConfigUpdatedU64 { config_field: b"withdraw_minimum_balance", value: v });
}

public(package) fun set_max_vault_balance<T>(vault: &mut ActiveVault<T>, v: u64) {
    vault.active_vault_version_verification();

    vault.config.max_vault_balance = v;
    emit(ConfigUpdatedU64 { config_field: b"max_vault_balance", value: v });
}

public(package) fun add_security_period<T>(
    vault: &mut ActiveVault<T>,
    duration: u64,
    limit: u64,
    ctx: &mut TxContext,
) {
    vault.active_vault_version_verification();

    let period = SecurityPeriod {
        id: object::new(ctx),
        enable: true,
        duration: duration,
        limit: limit,
        period_amount: table::new<u64, u64>(ctx),
    };
    emit(SecurityPeriodUpdated {
        period_id: period.id.to_address(),
        duration: period.duration,
        limit: period.limit,
        enable: period.enable,
    });
    vault.config.withdraw_security_period.push_back(period);
}

public(package) fun set_enable_security_period<T>(
    vault: &mut ActiveVault<T>,
    period_id: address,
    enable: bool,
) {
    vault.active_vault_version_verification();

    let period = find_security_period(vault, period_id);
    period.enable = enable;
    emit(SecurityPeriodUpdated {
        period_id: period_id,
        duration: period.duration,
        limit: period.limit,
        enable: period.enable,
    });
}

public(package) fun update_security_period<T>(
    vault: &mut ActiveVault<T>,
    period_id: address,
    duration: u64,
    limit: u64,
) {
    vault.active_vault_version_verification();

    let period = find_security_period(vault, period_id);
    period.duration = duration;
    period.limit = limit;
    emit(SecurityPeriodUpdated {
        period_id: period_id,
        duration: period.duration,
        limit: period.limit,
        enable: period.enable,
    });
}

fun find_security_period<T>(vault: &mut ActiveVault<T>, period_id: address): &mut SecurityPeriod {
    vault.active_vault_version_verification();

    let mut i = 0;
    while (i < vault.config.withdraw_security_period.length()) {
        let period = vault.config.withdraw_security_period.borrow(i);
        if (period.id.to_address() == period_id) {
            return vault.config.withdraw_security_period.borrow_mut(i)
        };
        i = i + 1;
    };
    abort ESECURITY_PERIOD_NOT_FOUND
}

public(package) fun direct_deposit<T>(
    vault: &mut ActiveVault<T>,
    _balance: Balance<T>,
    ctx: &TxContext,
) {
    vault.active_vault_version_verification();

    let amount = _balance.value();
    vault.balance.join(_balance);
    emit(DirectDeposited { user: ctx.sender(), amount: amount, vault_id: vault.id.to_address() });
}

public(package) fun direct_withdraw<T>(
    vault: &mut ActiveVault<T>,
    amount: u64,
    ctx: &TxContext,
): Balance<T> {
    vault.active_vault_version_verification();

    let _balance = vault.balance.split(amount);
    emit(DirectWithdrawn { user: ctx.sender(), amount: amount, vault_id: vault.id.to_address() });
    _balance
}

// Internal functions
fun security_update<T>(vault: &mut ActiveVault<T>, clock: &Clock, amount: u64) {
    vault.active_vault_version_verification();

    let mut i = 0;
    while (i < vault.config.withdraw_security_period.length()) {
        let period = vault.config.withdraw_security_period.borrow_mut(i);
        if (period.enable) {
            let epoch = clock.timestamp_ms() / period.duration;

            let mut amount_used = 0;
            if (period.period_amount.contains(epoch)) {
                amount_used = period.period_amount.remove(epoch)
            };

            let limit = amount + amount_used;
            assert!(limit <= period.limit, EWITHDRAWAL_AMOUNT_OVERFLOW);

            period.period_amount.add(epoch, limit);
        };
        i = i + 1;
    };
}

// Public functions
public fun when_not_paused(config: &Config) {
    assert!(!config.paused, EPAUSED);
}

public fun when_not_freezed_cap(config: &Config, cap: &PauseCap) {
    assert!(
        !config.freezed_caps.contains(cap.id.to_address()) || !*config.freezed_caps.borrow(cap.id.to_address()),
        EPAUSED,
    );
}

public fun when_deposit_not_disabled<T>(vault: &ActiveVault<T>) {
    assert!(vault.config.deposit_enable, EDISABLED);
}

public fun when_withdraw_not_disabled<T>(vault: &ActiveVault<T>) {
    assert!(vault.config.withdraw_enable, EDISABLED);
}

public fun when_not_expired(clock: &Clock, deadline: u64) {
    assert!(deadline >= clock.timestamp_ms(), EEXPIRED);
}

public fun version_verification(config: &Config) {
    assert!(config.version == VERSION, EVERSION_MISMATCH);
}

public fun active_vault_version_verification<T>(vault: &ActiveVault<T>) {
    assert!(vault.version == VERSION, EVERSION_MISMATCH);
}

public fun paused(config: &Config): bool {
    config.paused
}

public fun threshold(config: &Config): u64 {
    config.threshold
}

public fun signers(config: &Config): &vector<vector<u8>> {
    &config.signers
}

public fun signer_length(config: &Config): u64 {
    config.signers.length()
}

public fun balance_value<T>(vault: &ActiveVault<T>): u64 {
    vault.balance.value()
}

// Handler Functions
public fun keccak_message<T>(
    order_id: u256,
    order_time: u64,
    caller: address,
    amount: u64,
    recipient: address,
    msg: vector<u8>,
): vector<u8> {
    let mut message = vector::empty<u8>();
    message.append(b"mainnet"); // network flag: mainnet, testnet, devnet
    message.append(msg); // message
    message.append(into_bytes(into_string(get<T>()))); // coin type such as 0x2::sui::SUI
    message.append(caller.to_bytes()); // caller address
    message.append(recipient.to_bytes()); // recipient address
    message.append(from_u256((amount as u256)).to_bytes()); // withdraw amount
    message.append(from_u256(order_id).to_bytes()); // order id
    message.append(from_u256((order_time as u256)).to_bytes());

    keccak256(&message)
}

//---------------Test-------------------
#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx)
}

#[test_only]
public fun get_vault_config<T>(
    vault: &ActiveVault<T>,
): (
    bool,
    bool,
    u64,
    u64,
    u64,
    u64,
    &Table<vector<u8>, bool>,
    &Table<u256, u64>,
    &Table<u256, u64>,
    &vector<SecurityPeriod>,
) {
    return (
        vault.config.deposit_enable,
        vault.config.withdraw_enable,
        vault.config.max_vault_balance,
        vault.config.deposit_minimum_balance,
        vault.config.withdraw_minimum_balance,
        vault.config.order_id_counter,
        &vault.config.used_hashes,
        &vault.config.deposit_order_ids,
        &vault.config.withdrawal_order_ids,
        &vault.config.withdraw_security_period,
    )
}

#[test_only]
public fun get_security_period<T>(
    vault: &ActiveVault<T>,
    idx: u64,
): (bool, u64, u64, &Table<u64, u64>) {
    let period = vault.config.withdraw_security_period.borrow(idx);
    return (period.enable, period.duration, period.limit, &period.period_amount)
}

#[test_only]
public fun get_security_period_id<T>(vault: &ActiveVault<T>, idx: u64): address {
    vault.config.withdraw_security_period.borrow(idx).id.to_address()
}

#[test_only]
public fun get_freezed_caps(config: &Config): &Table<address, bool> {
    &config.freezed_caps
}

#[test_only]
public fun pause_cap_to_address(cap: &PauseCap): address {
    cap.id.to_address()
}

#[test_only]
public fun owner_cap_to_address(cap: &OwnerCap): address {
    cap.id.to_address()
}

#[test_only]
public fun mock_version_migrate(config: &mut Config, upgrade: bool) {
    // assert!(config.version <= VERSION, EVERSION_MISMATCH);
    if (upgrade) {
        config.version = config.version + 1;
    } else config.version = config.version - 1;
}
