#[test_only, allow(unused_const, unused_use, unused_variable)]
module dvault::integration_test;

use dvault::active_vault::{Self, ActiveVault, Config, OwnerCap as DvaultOwnerCap};
use dvault::dvault_manage;
use dvault::secure_vault::{Self, SecureVault, SecureOperatorCap, SecureOwnerCap};
use dvault::sui_test::{Self, SUI_TEST};
use dvault::usdc_test::{Self, USDC_TEST};
use dvault::user_entry;
use sui::clock::{Self, Clock};
use sui::coin::{Self, CoinMetadata, Coin};
use sui::ed25519;
use sui::test_scenario::{Self, Scenario};

const OWNER: address = @0xa;
const ALICE: address = @0xa;
const BOB: address = @0xb;
const PAUSE_CAP: address = @0xc;
const OPERATOR_CAP: address = @0xd;

// public key and secret key for testing
const PK1: vector<u8> = x"b9c6ee1630ef3e711144a648db06bbb2284f7274cfbee53ffcee503cc1a49200";
const SK1: vector<u8> = x"9bf49a6a0755f953811fce125f2683d50429c3bb49e074147e0089a52eae155f";

const PK2: vector<u8> = x"f1a756ceb2955f680ab622c9c271aa437a22aa978c34ae456f24400d6ea7ccdd";
const SK2: vector<u8> = x"c5e26f9b31288c268c31217de8d2a783eec7647c2b8de48286f0a25a2dd6594b";

const PK3: vector<u8> = x"848a7e4e12f0b56c79c30ff7d0a2187552b839ee90ccd7d1ae15c7f8396e083f";
const SK3: vector<u8> = x"39e6aeb1b81de0a6d15a72194585557b2c2afd27f33b575ea007d57a6733ba51";

#[test_only]
public fun init_dvault(scenario_mut: &mut Scenario) {
    let owner = test_scenario::sender(scenario_mut);

    test_scenario::next_tx(scenario_mut, owner);
    {
        sui_test::init_for_testing(scenario_mut.ctx());
        usdc_test::init_for_testing(scenario_mut.ctx());
        active_vault::init_for_testing(scenario_mut.ctx());
        secure_vault::init_for_testing(scenario_mut.ctx());
    };

    // create SUI vault
    test_scenario::next_tx(scenario_mut, owner);
    {
        let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
        let mut config = test_scenario::take_shared<Config>(scenario_mut);
        let metadata = test_scenario::take_immutable<CoinMetadata<SUI_TEST>>(scenario_mut);
        dvault_manage::create_vault<SUI_TEST>(
            &cap,
            &mut config,
            &metadata,
            2_000000000,
            1_000000000,
            scenario_mut.ctx(),
        );
        scenario_mut.return_to_sender(cap);
        test_scenario::return_shared(config);
        test_scenario::return_immutable(metadata);
    };

    // create USDC vault
    test_scenario::next_tx(scenario_mut, owner);
    {
        let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
        let mut config = test_scenario::take_shared<Config>(scenario_mut);
        let metadata = test_scenario::take_immutable<CoinMetadata<USDC_TEST>>(scenario_mut);
        dvault_manage::create_vault<USDC_TEST>(
            &cap,
            &mut config,
            &metadata,
            2_000000,
            1_000000,
            scenario_mut.ctx(),
        );
        scenario_mut.return_to_sender(cap);
        test_scenario::return_shared(config);
        test_scenario::return_immutable(metadata);
    };

    // add signer pk1 and pk2
    test_scenario::next_tx(scenario_mut, owner);
    {
        let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
        let mut config = test_scenario::take_shared<Config>(scenario_mut);
        dvault_manage::add_signer(&cap, &mut config, PK1, 1);
        dvault_manage::add_signer(&cap, &mut config, PK2, 2);
        assert!(active_vault::signer_length(&config) == 2);
        let signers = active_vault::signers(&config);
        let p1 = PK1;
        let p2 = PK2;
        assert!(signers.borrow(0) == p1);
        assert!(signers.borrow(1) == p2);
        scenario_mut.return_to_sender(cap);
        test_scenario::return_shared(config);
    };

    // create pause cap and operator cap
    test_scenario::next_tx(scenario_mut, OWNER);
    {
        let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
        let config = test_scenario::take_shared<Config>(scenario_mut);

        dvault_manage::create_pause_cap(&owner_cap, &config, PAUSE_CAP, scenario_mut.ctx());

        let secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);
        let secure_owner_cap = test_scenario::take_from_sender<SecureOwnerCap>(scenario_mut);
        secure_vault::create_operator_cap(&secure_owner_cap, OPERATOR_CAP, scenario_mut.ctx());

        scenario_mut.return_to_sender(owner_cap);
        scenario_mut.return_to_sender(secure_owner_cap);
        test_scenario::return_shared(secure_vault);
        test_scenario::return_shared(config);
    };
}

#[test]
// mock the scenario:
// deposit to active vault
// deposit to secure vault (exceeds max active vault balance)
// deposit to active vault (not exceeds)
// operator withdraw from secure vault to active vault
public fun test_complex_deposit_withdraw() {
    let mut scenario = test_scenario::begin(OWNER);
    let scenario_mut = &mut scenario;
    init_dvault(scenario_mut);

    // set max vault balance to 100 SUI
    test_scenario::next_tx(scenario_mut, OWNER);
    {
        let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
        let config = test_scenario::take_shared<Config>(scenario_mut);
        let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
        dvault_manage::set_max_vault_balance(&owner_cap, &mut vault, &config, 100_000000000);

        scenario_mut.return_to_sender(owner_cap);
        test_scenario::return_shared(vault);
        test_scenario::return_shared(config);
    };

    // ALICE mint 100 SUI and deposit 50 SUI to vault
    // Entity   | OWNER | ALICE | BOB |   AVAULT   | SVAULT |
    //          -----------------------------------------
    // Balance  |   0   |   50  |  0  |   50/100   |    0   |
    test_scenario::next_tx(scenario_mut, ALICE);
    {
        let config = test_scenario::take_shared<Config>(scenario_mut);
        let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
        let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);
        let coin = coin::mint_for_testing<SUI_TEST>(
            100_000000000,
            test_scenario::ctx(scenario_mut),
        );

        user_entry::deposit<SUI_TEST>(
            &config,
            &mut vault,
            &mut secure_vault,
            coin,
            50_000000000,
            scenario_mut.ctx(),
        );

        test_scenario::return_shared(vault);
        test_scenario::return_shared(secure_vault);
        test_scenario::return_shared(config);
    };

    // BOB mint 200 SUI and deposit 20 SUI to vault
    // Entity   | OWNER | ALICE | BOB |   AVAULT   | SVAULT |
    //          -----------------------------------------
    // Balance  |   0   |   50  | 180 |   70/100   |    0   |
    test_scenario::next_tx(scenario_mut, BOB);
    {
        let config = test_scenario::take_shared<Config>(scenario_mut);
        let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
        let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);
        let coin = coin::mint_for_testing<SUI_TEST>(
            200_000000000,
            test_scenario::ctx(scenario_mut),
        );

        user_entry::deposit<SUI_TEST>(
            &config,
            &mut vault,
            &mut secure_vault,
            coin,
            20_000000000,
            scenario_mut.ctx(),
        );

        test_scenario::return_shared(vault);
        test_scenario::return_shared(secure_vault);
        test_scenario::return_shared(config);
    };

    // BOB deposit 50 SUI to vault
    // Entity   | OWNER | ALICE | BOB |   AVAULT   | SVAULT |
    //          -----------------------------------------
    // Balance  |   0   |   50  | 130 |   70/100   |   50   |
    test_scenario::next_tx(scenario_mut, BOB);
    {
        let config = test_scenario::take_shared<Config>(scenario_mut);
        let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
        let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);
        let coin = test_scenario::take_from_sender<Coin<SUI_TEST>>(scenario_mut);

        user_entry::deposit<SUI_TEST>(
            &config,
            &mut vault,
            &mut secure_vault,
            coin,
            50_000000000,
            scenario_mut.ctx(),
        );

        test_scenario::return_shared(vault);
        test_scenario::return_shared(secure_vault);
        test_scenario::return_shared(config);
    };

    // BOB deposit 10 SUI to vault
    // Entity   | OWNER | ALICE | BOB |   AVAULT   | SVAULT |
    //          -----------------------------------------
    // Balance  |   0   |   50  | 120 |   80/100   |   50   |
    test_scenario::next_tx(scenario_mut, BOB);
    {
        let config = test_scenario::take_shared<Config>(scenario_mut);
        let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
        let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);
        let coin = test_scenario::take_from_sender<Coin<SUI_TEST>>(scenario_mut);

        user_entry::deposit<SUI_TEST>(
            &config,
            &mut vault,
            &mut secure_vault,
            coin,
            10_000000000,
            scenario_mut.ctx(),
        );

        test_scenario::return_shared(vault);
        test_scenario::return_shared(secure_vault);
        test_scenario::return_shared(config);
    };

    // OPERATOR withdraw 10 SUI from secure wallet
    // Entity   | OWNER | ALICE | BOB |   AVAULT   | SVAULT |
    //          -----------------------------------------
    // Balance  |   0   |   50  | 120 |   90/100  |   40   |
    test_scenario::next_tx(scenario_mut, OPERATOR_CAP);
    {
        let config = test_scenario::take_shared<Config>(scenario_mut);
        let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
        let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);

        let operator_cap = test_scenario::take_from_sender<SecureOperatorCap>(scenario_mut);
        dvault_manage::operator_withdraw_secure_vault(
            &operator_cap,
            &config,
            &mut vault,
            &mut secure_vault,
            10_000000000,
            scenario_mut.ctx(),
        );
        scenario_mut.return_to_sender(operator_cap);
        test_scenario::return_shared(vault);
        test_scenario::return_shared(secure_vault);
        test_scenario::return_shared(config);
    };

    // BOB deposit 10 SUI to vault
    // Entity   | OWNER | ALICE | BOB |   AVAULT   | SVAULT |
    //          -----------------------------------------
    // Balance  |   0   |   50  | 110 |   100/100   |   40   |
    test_scenario::next_tx(scenario_mut, BOB);
    {
        let config = test_scenario::take_shared<Config>(scenario_mut);
        let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
        let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);
        let coin = test_scenario::take_from_sender<Coin<SUI_TEST>>(scenario_mut);

        user_entry::deposit<SUI_TEST>(
            &config,
            &mut vault,
            &mut secure_vault,
            coin,
            10_000000000,
            scenario_mut.ctx(),
        );

        test_scenario::return_shared(vault);
        test_scenario::return_shared(secure_vault);
        test_scenario::return_shared(config);
    };

    // OPERATOR withdraw 30 SUI from secure wallet
    // Entity   | OWNER | ALICE | BOB |   AVAULT   | SVAULT |
    //          -----------------------------------------
    // Balance  |   0   |   50  | 110 |   130/100  |   10   |
    test_scenario::next_tx(scenario_mut, OPERATOR_CAP);
    {
        let config = test_scenario::take_shared<Config>(scenario_mut);
        let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
        let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);

        let operator_cap = test_scenario::take_from_sender<SecureOperatorCap>(scenario_mut);
        dvault_manage::operator_withdraw_secure_vault(
            &operator_cap,
            &config,
            &mut vault,
            &mut secure_vault,
            30_000000000,
            scenario_mut.ctx(),
        );
        scenario_mut.return_to_sender(operator_cap);
        test_scenario::return_shared(vault);
        test_scenario::return_shared(secure_vault);
        test_scenario::return_shared(config);
    };

    // BOB deposit 10 SUI to vault (will goes to Secure Vault)
    // Entity   | OWNER | ALICE | BOB |   AVAULT   | SVAULT |
    //          -----------------------------------------
    // Balance  |   0   |   50  |  100 |   130/100  |   20   |
    test_scenario::next_tx(scenario_mut, BOB);
    {
        let config = test_scenario::take_shared<Config>(scenario_mut);
        let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
        let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);
        let coin = test_scenario::take_from_sender<Coin<SUI_TEST>>(scenario_mut);

        user_entry::deposit<SUI_TEST>(
            &config,
            &mut vault,
            &mut secure_vault,
            coin,
            10_000000000,
            scenario_mut.ctx(),
        );

        test_scenario::return_shared(vault);
        test_scenario::return_shared(secure_vault);
        test_scenario::return_shared(config);
    };

    // BOB direct_deposit 10 SUI to vault (will goes to Active Vault)
    // Entity   | OWNER | ALICE | BOB |   AVAULT   | SVAULT |
    //          -----------------------------------------
    // Balance  |   0   |   50  |  90 |   140/100  |   20   |
    test_scenario::next_tx(scenario_mut, BOB);
    {
        let config = test_scenario::take_shared<Config>(scenario_mut);
        let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);

        let coin = test_scenario::take_from_sender<Coin<SUI_TEST>>(scenario_mut);
        let mut coin_balance = coin::into_balance(coin);
        let deposit_coin_balance = coin_balance.split(10_000000000);

        dvault_manage::direct_deposit(
            &mut vault,
            &config,
            deposit_coin_balance,
            scenario_mut.ctx(),
        );

        transfer::public_transfer(coin_balance.into_coin(scenario_mut.ctx()), BOB);
        test_scenario::return_shared(vault);
        test_scenario::return_shared(config);
    };

    // BOB deposit_secure_vault 10 SUI to vault (will goes to Secure Vault)
    // Entity   | OWNER | ALICE | BOB |   AVAULT   | SVAULT |
    //          -----------------------------------------
    // Balance  |   0   |   50  |  80 |   140/100  |   30   |
    test_scenario::next_tx(scenario_mut, BOB);
    {
        let config = test_scenario::take_shared<Config>(scenario_mut);
        let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);

        let coin = test_scenario::take_from_sender<Coin<SUI_TEST>>(scenario_mut);
        let mut coin_balance = coin::into_balance(coin);
        let deposit_coin_balance = coin_balance.split(10_000000000);

        dvault_manage::deposit_secure_vault(
            &mut secure_vault,
            &config,
            deposit_coin_balance,
        );

        transfer::public_transfer(coin_balance.into_coin(scenario_mut.ctx()), BOB);
        test_scenario::return_shared(secure_vault);
        test_scenario::return_shared(config);
    };

    // ALICE withdraw 50 SUI from vault to BOB
    // Entity   | OWNER | ALICE | BOB |   AVAULT   | SVAULT |
    //          -----------------------------------------
    // Balance  |   0   |   50  |  130 |   90/100  |   30   |
    test_scenario::next_tx(scenario_mut, ALICE);
    {
        let config = test_scenario::take_shared<Config>(scenario_mut);
        let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
        let clock = clock::create_for_testing(scenario_mut.ctx());

        let msg1 = active_vault::keccak_message<SUI_TEST>(
            1,
            1,
            ALICE,
            50_000000000,
            BOB,
            b"aaaa",
        );
        // std::debug::print(&msg1);
        // 0xe32fa5e13c8665710912d22f14e8120f8ea1773c2382ab4d835cf3ad76006f9e

        let mut signatures = vector::empty<vector<u8>>();

        let sig1 =
            x"1dc73378ef0ebae275fc13ded4bed694c663b7a905df01419db9419fd82c08077bf8d124902e3e2836e575d5f3dada3ab6cb455a2312344aa7b44b3d31fdf30e";
        let sig2 =
            x"f2897c4120744b15491f3dd22c7724648db1a8fb10f047d1ef00aa2958edd037f6a13214b77330a9c72c8bf80fcd0ec16c05fcb56ff563fd91f2f42d1d386901";
        signatures.push_back(sig1);
        signatures.push_back(sig2);
        user_entry::withdraw(
            &clock,
            &config,
            &mut vault,
            1,
            1,
            50_000000000,
            BOB,
            signatures,
            b"aaaa",
            scenario_mut.ctx(),
        );

        test_scenario::return_shared(vault);
        test_scenario::return_shared(config);
        clock::destroy_for_testing(clock);
    };

    // OWNER direct withdraw 20 SUI from (active)vault and destroy
    // Entity   | OWNER | ALICE | BOB |   AVAULT   | SVAULT |
    //          -----------------------------------------
    // Balance  |   0   |   50  |  130 |   70/100  |   30   |
    test_scenario::next_tx(scenario_mut, OWNER);
    {
        let config = test_scenario::take_shared<Config>(scenario_mut);
        let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
        let active_owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);

        let withdraw_balance = dvault_manage::direct_withdraw<SUI_TEST>(
            &active_owner_cap,
            &config,
            &mut vault,
            20_000000000,
            scenario_mut.ctx(),
        );
        assert!(withdraw_balance.value() == 20_000000000);

        scenario_mut.return_to_sender(active_owner_cap);
        test_scenario::return_shared(vault);
        test_scenario::return_shared(config);
        withdraw_balance.destroy_for_testing();
    };

    // OWNER withdraw 20 SUI from secure wallet and destroy
    // Entity   | OWNER | ALICE | BOB |   AVAULT   | SVAULT |
    //          -----------------------------------------
    // Balance  |   0   |   50  | 130 |   70/100  |   10   |
    test_scenario::next_tx(scenario_mut, OWNER);
    {
        let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);
        let secure_owner_cap = test_scenario::take_from_sender<SecureOwnerCap>(scenario_mut);
        let withdraw_balance = secure_vault::admin_withdraw_secure_vault(
            &mut secure_vault,
            &secure_owner_cap,
            20_000000000,
        );
        scenario_mut.return_to_sender(secure_owner_cap);
        test_scenario::return_shared(secure_vault);
        withdraw_balance.destroy_for_testing();
    };

    // BOB direct deposit 1 SUI into vault (<minimum deposit amount but ignored)
    // OWNER withdraw 20 SUI from secure wallet and destroy
    // Entity   | OWNER | ALICE | BOB |   AVAULT   | SVAULT |
    //          -----------------------------------------
    // Balance  |   0   |   50  | 129 |   71/100  |   10   |
    test_scenario::next_tx(scenario_mut, BOB);
    {
        let config = test_scenario::take_shared<Config>(scenario_mut);
        let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);

        let coin = test_scenario::take_from_sender<Coin<SUI_TEST>>(scenario_mut);
        let mut coin_balance = coin::into_balance(coin);
        let deposit_coin_balance = coin_balance.split(1_000000000);

        dvault_manage::direct_deposit(
            &mut vault,
            &config,
            deposit_coin_balance,
            scenario_mut.ctx(),
        );

        transfer::public_transfer(coin_balance.into_coin(scenario_mut.ctx()), BOB);
        test_scenario::return_shared(vault);
        test_scenario::return_shared(config);
    };

    // OWNER direct withdraw 0.5 SUI (<minimum withdraw amount but ignored) from (active)vault and destroy
    // Entity   | OWNER | ALICE | BOB |   AVAULT   | SVAULT |
    //          -----------------------------------------
    // Balance  |   0   |   50  |  129 |   70.5/100  |   10   |
    test_scenario::next_tx(scenario_mut, OWNER);
    {
        let config = test_scenario::take_shared<Config>(scenario_mut);
        let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
        let active_owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);

        let withdraw_balance = dvault_manage::direct_withdraw<SUI_TEST>(
            &active_owner_cap,
            &config,
            &mut vault,
            500000000,
            scenario_mut.ctx(),
        );
        assert!(withdraw_balance.value() == 500000000);

        scenario_mut.return_to_sender(active_owner_cap);
        test_scenario::return_shared(vault);
        test_scenario::return_shared(config);
        withdraw_balance.destroy_for_testing();
    };

    // check state
    test_scenario::next_tx(scenario_mut, BOB);
    {
        let alice_coin = test_scenario::take_from_address<Coin<SUI_TEST>>(scenario_mut, ALICE);
        let alice_balance = coin::balance(&alice_coin).value() ;
        std::debug::print(&alice_balance);
        test_scenario::return_to_address(ALICE, alice_coin);

        let bob_coin = test_scenario::take_from_sender<Coin<SUI_TEST>>(scenario_mut);
        let bob_balance = coin::balance(&bob_coin).value();
        // std::debug::print(&bob_balance);

        let bob_coin2_id_opt = test_scenario::most_recent_id_for_address<Coin<SUI_TEST>>(BOB);
        let bob_coin_2 = test_scenario::take_from_sender_by_id<Coin<SUI_TEST>>(
            scenario_mut,
            bob_coin2_id_opt.destroy_some(),
        );
        let bob_balance_2 = coin::balance(&bob_coin_2).value();
        std::debug::print(&(bob_balance + bob_balance_2));

        scenario_mut.return_to_sender(bob_coin_2);
        scenario_mut.return_to_sender(bob_coin);

        let active_vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
        let active_vault_balance = active_vault::balance_value(&active_vault);
        std::debug::print(&active_vault_balance);
        test_scenario::return_shared(active_vault);

        let secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);
        let secure_vault_balance = secure_vault::balance_value(&secure_vault);
        std::debug::print(&secure_vault_balance);
        test_scenario::return_shared(secure_vault);
    };

    test_scenario::end(scenario);
}
