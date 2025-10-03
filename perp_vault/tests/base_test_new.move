#[test_only, allow(unused_const, unused_use, unused_variable)]
module dvault::base_test_new {
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
    // public key and secret key for testing
    const PK1: vector<u8> = x"b9c6ee1630ef3e711144a648db06bbb2284f7274cfbee53ffcee503cc1a49200";
    const SK1: vector<u8> = x"9bf49a6a0755f953811fce125f2683d50429c3bb49e074147e0089a52eae155f";

    const PK2: vector<u8> = x"f1a756ceb2955f680ab622c9c271aa437a22aa978c34ae456f24400d6ea7ccdd";
    const SK2: vector<u8> = x"c5e26f9b31288c268c31217de8d2a783eec7647c2b8de48286f0a25a2dd6594b";

    const PK3: vector<u8> = x"848a7e4e12f0b56c79c30ff7d0a2187552b839ee90ccd7d1ae15c7f8396e083f";
    const SK3: vector<u8> = x"39e6aeb1b81de0a6d15a72194585557b2c2afd27f33b575ea007d57a6733ba51";

    #[test_only]
    // initialize dvault for testing (will be called first in each test)
    public fun init_dvault(scenario_mut: &mut Scenario) {
        let owner = test_scenario::sender(scenario_mut);

        // init coins & vault modules for testing
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
            // @note try two ways to return the cap
            // scenario_mut.return_to_sender(cap);
            test_scenario::return_to_address(owner, cap);
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
    }

    #[test]
    // deposit 100 sui into dvault, no other checks
    public fun test_deposit() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);
        test_scenario::next_tx(scenario_mut, OWNER);
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
                100_000000000,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };
        test_scenario::end(scenario);
    }

    #[test]
    // deposit 100 sui (by OWNER) and withdraw 1 sui (called by ALICE but sent to BOB)
    public fun test_withdraw() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // deposit
        test_scenario::next_tx(scenario_mut, OWNER);
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
                100_000000000,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        // withdraw
        test_scenario::next_tx(scenario_mut, ALICE);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let clock = clock::create_for_testing(scenario_mut.ctx());

            let msg1 = active_vault::keccak_message<SUI_TEST>(
                1,
                1,
                ALICE,
                1_000000000,
                BOB,
                b"aaaa",
            );
            std::debug::print(&msg1);
            // 0x39fae67be485475f6ce184f43d96af402b5b3eb9c237a3b76ab6606f7fb9c256

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 =
                x"916db9ce4c38490dd0882d7918ac85f9e658c2b1ae43ab1205e9ad7dd5b260fd6ba0f5b9b3ce75013034b39813614c2e79a92fac9b1e1dac7d108f806263eb01";
            let sig2 =
                x"6e54f3c1b5369b0c3e6032d6122037c3cb472faa27e11f1804f3d5b9bb42e325aa47cd172dbb28e3ec2ead69a5b29df43fd752643cf300e7822bb725e99fd10c";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(
                &clock,
                &config,
                &mut vault,
                1,
                1,
                1_000000000,
                BOB,
                signatures,
                b"aaaa",
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };

        // check state
        test_scenario::next_tx(scenario_mut, BOB);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let coin = scenario_mut.take_from_sender<Coin<SUI_TEST>>();
            assert!(coin.value() == 1_000000000);

            let msg1 = active_vault::keccak_message<SUI_TEST>(
                1,
                1,
                ALICE,
                1_000000000,
                BOB,
                b"aaaa",
            );

            let (
                deposit_enable,
                withdraw_enable,
                max_vault_balance,
                deposit_minimum_balance,
                withdraw_minimum_balance,
                order_id_counter,
                used_hashes,
                deposit_order_ids,
                used_order_ids,
                withdraw_security_period,
            ) = active_vault::get_vault_config<SUI_TEST>(&vault);
            assert!(deposit_enable == true);
            assert!(withdraw_enable == true);
            assert!(max_vault_balance == 0);
            assert!(deposit_minimum_balance == 2_000000000);
            assert!(withdraw_minimum_balance == 1_000000000);
            assert!(order_id_counter == 1);
            assert!(used_hashes.borrow(msg1) == true);
            assert!(deposit_order_ids.borrow(0) == 100_000000000);
            assert!(used_order_ids.borrow(1) == 1_000000000);
            assert!(withdraw_security_period.length() == 0);

            assert!(active_vault::paused(&config) == false);
            assert!(active_vault::threshold(&config) == 2);
            assert!(active_vault::balance_value(&vault) == 99_000000000);

            test_scenario::return_shared(vault);
            scenario_mut.return_to_sender(coin);
            test_scenario::return_shared(config);
        };
        test_scenario::end(scenario);
    }

    #[test]
    // deposit 100 SUI (by OWNER)
    // add security period (1 SUI / day)
    // ALICE withdraw 1 SUI to BOB
    // ALICE withdraw 1 SUI to BOB after 1 day
    public fun test_withdraw_with_security_period() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // deposit
        test_scenario::next_tx(scenario_mut, OWNER);
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
                100_000000000,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        // set security period (1 SUI / day)
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let config = test_scenario::take_shared<Config>(scenario_mut);
            dvault_manage::add_security_period<SUI_TEST>(
                &cap,
                &mut vault,
                &config,
                86400 * 1000,
                1_000000000,
                scenario_mut.ctx(),
            );
            scenario_mut.return_to_sender(cap);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
        };

        // ALICE withdraw 1 SUI to BOB
        test_scenario::next_tx(scenario_mut, ALICE);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let clock = clock::create_for_testing(scenario_mut.ctx());

            let msg1 = active_vault::keccak_message<SUI_TEST>(
                1,
                1,
                ALICE,
                1_000000000,
                BOB,
                b"aaaa",
            );
            std::debug::print(&msg1);
            // 0x39fae67be485475f6ce184f43d96af402b5b3eb9c237a3b76ab6606f7fb9c256

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 =
                x"916db9ce4c38490dd0882d7918ac85f9e658c2b1ae43ab1205e9ad7dd5b260fd6ba0f5b9b3ce75013034b39813614c2e79a92fac9b1e1dac7d108f806263eb01";
            let sig2 =
                x"6e54f3c1b5369b0c3e6032d6122037c3cb472faa27e11f1804f3d5b9bb42e325aa47cd172dbb28e3ec2ead69a5b29df43fd752643cf300e7822bb725e99fd10c";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(
                &clock,
                &config,
                &mut vault,
                1,
                1,
                1_000000000,
                BOB,
                signatures,
                b"aaaa",
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };

        // check state
        test_scenario::next_tx(scenario_mut, BOB);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let coin = scenario_mut.take_from_sender<Coin<SUI_TEST>>();
            assert!(coin.value() == 1_000000000);

            let msg1 = active_vault::keccak_message<SUI_TEST>(
                1,
                1,
                ALICE,
                1_000000000,
                BOB,
                b"aaaa",
            );

            let (
                deposit_enable,
                withdraw_enable,
                max_vault_balance,
                deposit_minimum_balance,
                withdraw_minimum_balance,
                order_id_counter,
                used_hashes,
                deposit_order_ids,
                used_order_ids,
                withdraw_security_period,
            ) = active_vault::get_vault_config<SUI_TEST>(&vault);
            assert!(deposit_enable == true);
            assert!(withdraw_enable == true);
            assert!(max_vault_balance == 0);
            assert!(deposit_minimum_balance == 2_000000000);
            assert!(withdraw_minimum_balance == 1_000000000);
            assert!(order_id_counter == 1);
            assert!(used_hashes.borrow(msg1) == true);
            assert!(deposit_order_ids.borrow(0) == 100_000000000);
            assert!(used_order_ids.borrow(1) == 1_000000000);
            assert!(withdraw_security_period.length() == 1);

            assert!(active_vault::paused(&config) == false);
            assert!(active_vault::threshold(&config) == 2);
            assert!(active_vault::balance_value(&vault) == 99_000000000);

            test_scenario::return_shared(vault);
            scenario_mut.return_to_sender(coin);
            test_scenario::return_shared(config);
        };

        // ALICE withdraw 1 SUI to BOB after 1 day
        test_scenario::next_tx(scenario_mut, ALICE);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let mut clock = clock::create_for_testing(scenario_mut.ctx());
            clock.increment_for_testing(86400 * 1000);

            let msg1 = active_vault::keccak_message<SUI_TEST>(
                2,
                86400 * 1000 + 1,
                ALICE,
                1_000000000,
                BOB,
                b"aaaa",
            );
            std::debug::print(&msg1);
            // 0xdc9635e7a6a56898c3498fdf377b084b4d5870676ba3131eb26fb02c5a1a63b6

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 =
                x"933d04ecd789c582b7e1bd02d18b83b01a6b4ec030d0c250807e4babfba4170fac4f4513ffda4a4ee3e43daa5d8ceed119c1d0e8b073f626f05874cd4556d601";
            let sig2 =
                x"f0c40b9cb283f92f0d38ab1e69d946c88f104ab290afb062ef70d874ec53633ad740d6c7dfaa9f6e501a43bb5de9a7efd8fb9548cb79c95820dc3d317e2ae306";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(
                &clock,
                &config,
                &mut vault,
                2,
                86400 * 1000 + 1,
                1_000000000,
                BOB,
                signatures,
                b"aaaa",
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        test_scenario::end(scenario);
    }

    #[test]
    // deposit 100 SUI (by OWNER)
    // add security period (1 SUI / day)
    // add security period (10 SUI / 10 days)
    // ALICE withdraw 1 SUI to BOB
    // ALICE withdraw 1 SUI to BOB after 1 day
    public fun test_withdraw_with_multiple_security_period() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // deposit
        test_scenario::next_tx(scenario_mut, OWNER);
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
                100_000000000,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        // add security period (1 SUI / day)
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            dvault_manage::add_security_period<SUI_TEST>(
                &cap,
                &mut vault,
                &config,
                86400 * 1000,
                1_000000000,
                scenario_mut.ctx(),
            );
            scenario_mut.return_to_sender(cap);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
        };

        // add security period (10 SUI / 10 days)
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let config = test_scenario::take_shared<Config>(scenario_mut);
            dvault_manage::add_security_period<SUI_TEST>(
                &cap,
                &mut vault,
                &config,
                864000 * 1000,
                10_000000000,
                scenario_mut.ctx(),
            );
            scenario_mut.return_to_sender(cap);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
        };

        // withdraw
        test_scenario::next_tx(scenario_mut, ALICE);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let clock = clock::create_for_testing(scenario_mut.ctx());

            let msg1 = active_vault::keccak_message<SUI_TEST>(
                1,
                1,
                ALICE,
                1_000000000,
                BOB,
                b"aaaa",
            );
            std::debug::print(&msg1);
            // 0x39fae67be485475f6ce184f43d96af402b5b3eb9c237a3b76ab6606f7fb9c256

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 =
                x"916db9ce4c38490dd0882d7918ac85f9e658c2b1ae43ab1205e9ad7dd5b260fd6ba0f5b9b3ce75013034b39813614c2e79a92fac9b1e1dac7d108f806263eb01";
            let sig2 =
                x"6e54f3c1b5369b0c3e6032d6122037c3cb472faa27e11f1804f3d5b9bb42e325aa47cd172dbb28e3ec2ead69a5b29df43fd752643cf300e7822bb725e99fd10c";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(
                &clock,
                &config,
                &mut vault,
                1,
                1,
                1_000000000,
                BOB,
                signatures,
                b"aaaa",
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };

        // withdraw after 1 day
        test_scenario::next_tx(scenario_mut, ALICE);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let mut clock = clock::create_for_testing(scenario_mut.ctx());
            clock.increment_for_testing(86400 * 1000);

            let msg1 = active_vault::keccak_message<SUI_TEST>(
                2,
                86400 * 1000 + 1,
                ALICE,
                1_000000000,
                BOB,
                b"aaaa",
            );
            std::debug::print(&msg1);
            // 0xdc9635e7a6a56898c3498fdf377b084b4d5870676ba3131eb26fb02c5a1a63b6

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 =
                x"933d04ecd789c582b7e1bd02d18b83b01a6b4ec030d0c250807e4babfba4170fac4f4513ffda4a4ee3e43daa5d8ceed119c1d0e8b073f626f05874cd4556d601";
            let sig2 =
                x"f0c40b9cb283f92f0d38ab1e69d946c88f104ab290afb062ef70d874ec53633ad740d6c7dfaa9f6e501a43bb5de9a7efd8fb9548cb79c95820dc3d317e2ae306";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(
                &clock,
                &config,
                &mut vault,
                2,
                86400 * 1000 + 1,
                1_000000000,
                BOB,
                signatures,
                b"aaaa",
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };

        // check state
        // Security Period 1: 1 SUI / day
        // Epoch 0: 1 / 1
        // Epoch 1: 1 / 1
        // Security Period 2: 10 SUI / 10 days
        // Epoch 0: 2 / 10
        test_scenario::next_tx(scenario_mut, BOB);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);

            let (enable, duration, limit, period_amount) = active_vault::get_security_period<
                SUI_TEST,
            >(&vault, 0);
            assert!(enable == true);
            assert!(duration == 86400 * 1000);
            assert!(limit == 1_000000000);
            assert!(period_amount.borrow(0) == 1_000000000);
            assert!(period_amount.borrow(1) == 1_000000000);
            assert!(period_amount.contains(2) == false);

            let (enable, duration, limit, period_amount) = active_vault::get_security_period<
                SUI_TEST,
            >(&vault, 1);
            assert!(enable == true);
            assert!(duration == 86400 * 10000);
            assert!(limit == 10_000000000);
            assert!(period_amount.borrow(0) == 2_000000000);
            assert!(period_amount.contains(1) == false);

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
        };
        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = active_vault::EWITHDRAWAL_AMOUNT_OVERFLOW,
            location = active_vault,
        ),
    ]
    // deposit 100 SUI (by OWNER)
    // add security period (1 SUI / day)
    // add  security period (1.5 SUI / 2 days)
    // ALICE withdraw 1 SUI to BOB
    // ALICE withdraw 1 SUI to BOB after 1 day (fail, 2/1.5 overflow)
    public fun test_withdraw_fail_with_multiple_security_period() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // deposit
        test_scenario::next_tx(scenario_mut, OWNER);
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
                100_000000000,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        // set security period
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let config = test_scenario::take_shared<Config>(scenario_mut);
            dvault_manage::add_security_period<SUI_TEST>(
                &cap,
                &mut vault,
                &config,
                86400 * 1000,
                1_000000000,
                scenario_mut.ctx(),
            );
            scenario_mut.return_to_sender(cap);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
        };

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let config = test_scenario::take_shared<Config>(scenario_mut);
            dvault_manage::add_security_period<SUI_TEST>(
                &cap,
                &mut vault,
                &config,
                86400 * 2000,
                1_500000000,
                scenario_mut.ctx(),
            );
            scenario_mut.return_to_sender(cap);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
        };

        // withdraw
        test_scenario::next_tx(scenario_mut, ALICE);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let clock = clock::create_for_testing(scenario_mut.ctx());

            let msg1 = active_vault::keccak_message<SUI_TEST>(
                1,
                1,
                ALICE,
                1_000000000,
                BOB,
                b"aaaa",
            );
            std::debug::print(&msg1);
            // 0x39fae67be485475f6ce184f43d96af402b5b3eb9c237a3b76ab6606f7fb9c256

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 =
                x"916db9ce4c38490dd0882d7918ac85f9e658c2b1ae43ab1205e9ad7dd5b260fd6ba0f5b9b3ce75013034b39813614c2e79a92fac9b1e1dac7d108f806263eb01";
            let sig2 =
                x"6e54f3c1b5369b0c3e6032d6122037c3cb472faa27e11f1804f3d5b9bb42e325aa47cd172dbb28e3ec2ead69a5b29df43fd752643cf300e7822bb725e99fd10c";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(
                &clock,
                &config,
                &mut vault,
                1,
                1,
                1_000000000,
                BOB,
                signatures,
                b"aaaa",
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };

        // withdraw after 1 day
        test_scenario::next_tx(scenario_mut, ALICE);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let mut clock = clock::create_for_testing(scenario_mut.ctx());
            clock.increment_for_testing(86400 * 1000);

            let msg1 = active_vault::keccak_message<SUI_TEST>(
                2,
                86400 * 1000 + 1,
                ALICE,
                1_000000000,
                BOB,
                b"aaaa",
            );
            std::debug::print(&msg1);
            // 0xdc9635e7a6a56898c3498fdf377b084b4d5870676ba3131eb26fb02c5a1a63b6

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 =
                x"933d04ecd789c582b7e1bd02d18b83b01a6b4ec030d0c250807e4babfba4170fac4f4513ffda4a4ee3e43daa5d8ceed119c1d0e8b073f626f05874cd4556d601";
            let sig2 =
                x"f0c40b9cb283f92f0d38ab1e69d946c88f104ab290afb062ef70d874ec53633ad740d6c7dfaa9f6e501a43bb5de9a7efd8fb9548cb79c95820dc3d317e2ae306";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(
                &clock,
                &config,
                &mut vault,
                2,
                86400 * 1000 + 1,
                1_000000000,
                BOB,
                signatures,
                b"aaaa",
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = active_vault::EWITHDRAWAL_AMOUNT_OVERFLOW,
            location = active_vault,
        ),
    ]
    // deposit 100 SUI (by OWNER)
    // add security period (1 SUI / 0.1 day)
    // withdraw 1 SUI
    // withdraw 1 SUI again (fail, 2/1 overflow)
    public fun test_withdraw_fail_exceed_security_period() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // deposit
        test_scenario::next_tx(scenario_mut, OWNER);
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
                100_000000000,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        // set security period
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let config = test_scenario::take_shared<Config>(scenario_mut);
            dvault_manage::add_security_period<SUI_TEST>(
                &cap,
                &mut vault,
                &config,
                86400 * 1000,
                1_000000000,
                scenario_mut.ctx(),
            );
            scenario_mut.return_to_sender(cap);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
        };

        // withdraw
        test_scenario::next_tx(scenario_mut, ALICE);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let clock = clock::create_for_testing(scenario_mut.ctx());

            let msg1 = active_vault::keccak_message<SUI_TEST>(
                1,
                1,
                ALICE,
                1_000000000,
                BOB,
                b"aaaa",
            );
            std::debug::print(&msg1);
            // 0x39fae67be485475f6ce184f43d96af402b5b3eb9c237a3b76ab6606f7fb9c256

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 =
                x"916db9ce4c38490dd0882d7918ac85f9e658c2b1ae43ab1205e9ad7dd5b260fd6ba0f5b9b3ce75013034b39813614c2e79a92fac9b1e1dac7d108f806263eb01";
            let sig2 =
                x"6e54f3c1b5369b0c3e6032d6122037c3cb472faa27e11f1804f3d5b9bb42e325aa47cd172dbb28e3ec2ead69a5b29df43fd752643cf300e7822bb725e99fd10c";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(
                &clock,
                &config,
                &mut vault,
                1,
                1,
                1_000000000,
                BOB,
                signatures,
                b"aaaa",
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };

        // withdraw again (clock time still 0, order time set to 1 day later)
        test_scenario::next_tx(scenario_mut, ALICE);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let clock = clock::create_for_testing(scenario_mut.ctx());

            let msg1 = active_vault::keccak_message<SUI_TEST>(
                2,
                86400 * 1000 + 1,
                ALICE,
                1_000000000,
                BOB,
                b"aaaa",
            );
            std::debug::print(&msg1);
            // 0xdc9635e7a6a56898c3498fdf377b084b4d5870676ba3131eb26fb02c5a1a63b6

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 =
                x"933d04ecd789c582b7e1bd02d18b83b01a6b4ec030d0c250807e4babfba4170fac4f4513ffda4a4ee3e43daa5d8ceed119c1d0e8b073f626f05874cd4556d601";
            let sig2 =
                x"f0c40b9cb283f92f0d38ab1e69d946c88f104ab290afb062ef70d874ec53633ad740d6c7dfaa9f6e501a43bb5de9a7efd8fb9548cb79c95820dc3d317e2ae306";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(
                &clock,
                &config,
                &mut vault,
                2,
                86400 * 1000 + 1,
                1_000000000,
                BOB,
                signatures,
                b"aaaa",
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_getter() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        let clock = clock::create_for_testing(scenario_mut.ctx());
        init_dvault(scenario_mut);
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);

            active_vault::when_not_paused(&config);
            active_vault::when_deposit_not_disabled(&vault);
            active_vault::when_withdraw_not_disabled(&vault);
            active_vault::when_not_expired(&clock, 1);
            active_vault::version_verification(&config);
            assert!(active_vault::paused(&config) == false);
            assert!(active_vault::signer_length(&config) == 2);
            assert!(active_vault::balance_value(&vault) == 0);

            test_scenario::return_shared(config);
            test_scenario::return_shared(vault);
            clock::destroy_for_testing(clock);
        };
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_keccak_message() {
        let msg = active_vault::keccak_message<SUI_TEST>(1, 1, ALICE, 1_000000000, BOB, b"aaaa");

        // make sure differen param gets different msg
        let msg1 = active_vault::keccak_message<USDC_TEST>(1, 1, ALICE, 1_000000000, BOB, b"aaaa");
        let msg2 = active_vault::keccak_message<SUI_TEST>(2, 1, ALICE, 1_000000000, BOB, b"aaaa");
        let msg3 = active_vault::keccak_message<SUI_TEST>(1, 3, ALICE, 1_000000000, BOB, b"aaaa");
        let msg4 = active_vault::keccak_message<SUI_TEST>(1, 1, BOB, 1_000000000, BOB, b"aaaa");
        let msg5 = active_vault::keccak_message<SUI_TEST>(1, 1, ALICE, 10_000000000, BOB, b"aaaa");
        let msg6 = active_vault::keccak_message<SUI_TEST>(1, 1, ALICE, 1_000000000, ALICE, b"aaaa");
        let msg7 = active_vault::keccak_message<SUI_TEST>(1, 1, ALICE, 1_000000000, BOB, b"aaaaa");

        assert!(msg != msg1, 0);
        assert!(msg != msg2, 1);
        assert!(msg != msg3, 2);
        assert!(msg != msg4, 3);
        assert!(msg != msg5, 4);
        assert!(msg != msg6, 5);
        assert!(msg != msg7, 6);

        std::debug::print(&msg);
    }

    #[test]
    #[expected_failure(abort_code = active_vault::EDEPOSIT_AMOUNT_TOO_LOW, location = active_vault)]
    public fun test_set_min_deposit() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            dvault_manage::set_minimum_deposit<SUI_TEST>(&cap, &mut vault, &config, 1_000000000);

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(cap);
        };
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);
            let coin = coin::mint_for_testing<SUI_TEST>(
                1_000000000 - 1,
                test_scenario::ctx(scenario_mut),
            );

            user_entry::deposit<SUI_TEST>(
                &config,
                &mut vault,
                &mut secure_vault,
                coin,
                1_000000000 - 1,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };
        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = active_vault::EWITHDRAW_AMOUNT_TOO_LOW,
            location = active_vault,
        ),
    ]
    // set minimum withdraw to 1 SUI
    // withdraw less than 1 SUI
    public fun test_set_min_withdraw() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // set minimum withdraw amount
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);

            dvault_manage::set_minimum_withdraw<SUI_TEST>(&cap, &mut vault, &config, 1_000000000);

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(cap);
        };

        // withdraw less than 1 SUI
        test_scenario::next_tx(scenario_mut, ALICE);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let clock = clock::create_for_testing(scenario_mut.ctx());

            let msg1 = active_vault::keccak_message<SUI_TEST>(
                1,
                1,
                ALICE,
                1_000000000 - 1,
                BOB,
                b"aaaa",
            );
            std::debug::print(&msg1);
            // 0x39fae67be485475f6ce184f43d96af402b5b3eb9c237a3b76ab6606f7fb9c256

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 =
                x"916db9ce4c38490dd0882d7918ac85f9e658c2b1ae43ab1205e9ad7dd5b260fd6ba0f5b9b3ce75013034b39813614c2e79a92fac9b1e1dac7d108f806263eb01";
            let sig2 =
                x"6e54f3c1b5369b0c3e6032d6122037c3cb472faa27e11f1804f3d5b9bb42e325aa47cd172dbb28e3ec2ead69a5b29df43fd752643cf300e7822bb725e99fd10c";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(
                &clock,
                &config,
                &mut vault,
                1,
                1,
                1_000000000 - 1,
                BOB,
                signatures,
                b"aaaa",
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        test_scenario::end(scenario);
    }

    #[test]
    // set max vault balance to 4 SUI
    // deposit 2 SUI, 2 SUI and 4 SUI
    // check vault balance: 4 SUI in active vault, 4 SUI in secure vault
    public fun test_set_max_vault_balance() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            dvault_manage::set_max_vault_balance<SUI_TEST>(&cap, &mut vault, &config, 4_000000000);

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(cap);
        };

        // deposit 2sui, 2sui and 4sui
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);
            let coin = coin::mint_for_testing<SUI_TEST>(
                2_000000000,
                test_scenario::ctx(scenario_mut),
            );
            user_entry::deposit<SUI_TEST>(
                &config,
                &mut vault,
                &mut secure_vault,
                coin,
                2_000000000,
                scenario_mut.ctx(),
            );

            let coin = coin::mint_for_testing<SUI_TEST>(
                2_000000000,
                test_scenario::ctx(scenario_mut),
            );
            user_entry::deposit<SUI_TEST>(
                &config,
                &mut vault,
                &mut secure_vault,
                coin,
                2_000000000,
                scenario_mut.ctx(),
            );

            let coin = coin::mint_for_testing<SUI_TEST>(
                4_000000000,
                test_scenario::ctx(scenario_mut),
            );
            user_entry::deposit<SUI_TEST>(
                &config,
                &mut vault,
                &mut secure_vault,
                coin,
                4_000000000,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);

            let (
                deposit_enable,
                withdraw_enable,
                max_vault_balance,
                deposit_minimum_balance,
                withdraw_minimum_balance,
                order_id_counter,
                used_hashes,
                deposit_order_ids,
                used_order_ids,
                withdraw_security_period,
            ) = active_vault::get_vault_config<SUI_TEST>(&vault);
            assert!(order_id_counter == 3);
            assert!(vault.balance_value() == 4_000000000, 0);
            assert!(secure_vault.balance_value() == 4_000000000, 1);

            assert!(deposit_order_ids.borrow(0) == 2_000000000);
            assert!(deposit_order_ids.borrow(1) == 2_000000000);
            assert!(deposit_order_ids.borrow(2) == 4_000000000);

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = active_vault::EINVALID_SIGNATURES, location = active_vault)]
    // add PK3
    // deposit 100 SUI
    // use PK1 and PK2 to withdraw 1 SUI => fail
    public fun test_withdraw_fail_if_signer_not_enough() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // Add PK3 as a new signer and threshold update to 3
        // Now need PK1, PK2 and PK3 to withdraw
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut config = test_scenario::take_shared<Config>(scenario_mut);
            dvault_manage::add_signer(&cap, &mut config, PK3, 3);
            scenario_mut.return_to_sender(cap);
            test_scenario::return_shared(config);
        };

        // deposit
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
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
                100_000000000,
                scenario_mut.ctx(),
            );

            // dvault_manage::set_minimum_withdraw<SUI_TEST>(&cap, &mut vault, &config, 1_000000000);

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(cap);
            test_scenario::return_shared(secure_vault);
        };

        // withdraw
        test_scenario::next_tx(scenario_mut, ALICE);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let clock = clock::create_for_testing(scenario_mut.ctx());

            let msg1 = active_vault::keccak_message<SUI_TEST>(
                1,
                1,
                ALICE,
                1_000000000,
                BOB,
                b"aaaa",
            );
            std::debug::print(&msg1);
            // 0x39fae67be485475f6ce184f43d96af402b5b3eb9c237a3b76ab6606f7fb9c256

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 =
                x"916db9ce4c38490dd0882d7918ac85f9e658c2b1ae43ab1205e9ad7dd5b260fd6ba0f5b9b3ce75013034b39813614c2e79a92fac9b1e1dac7d108f806263eb01";
            let sig2 =
                x"6e54f3c1b5369b0c3e6032d6122037c3cb472faa27e11f1804f3d5b9bb42e325aa47cd172dbb28e3ec2ead69a5b29df43fd752643cf300e7822bb725e99fd10c";
            signatures.push_back(sig1);
            signatures.push_back(sig2);

            // fail -> assert!(signatures.length() >= config.threshold, EINVALID_SIGNATURES);
            user_entry::withdraw(
                &clock,
                &config,
                &mut vault,
                1,
                1,
                1_000000000,
                BOB,
                signatures,
                b"aaaa",
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        test_scenario::end(scenario);
    }

     #[test]
    #[expected_failure(abort_code = active_vault::EINVALID_SIGNATURES, location = active_vault)]
    // deposit 100 SUI
    // use [PK1, PK2, PK2] to withdraw 1 SUI => fail
    public fun test_withdraw_fail_if_signatures_more_than_signers() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // deposit
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
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
                100_000000000,
                scenario_mut.ctx(),
            );

            // dvault_manage::set_minimum_withdraw<SUI_TEST>(&cap, &mut vault, &config, 1_000000000);

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(cap);
            test_scenario::return_shared(secure_vault);
        };

        // withdraw
        test_scenario::next_tx(scenario_mut, ALICE);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let clock = clock::create_for_testing(scenario_mut.ctx());

            let msg1 = active_vault::keccak_message<SUI_TEST>(
                1,
                1,
                ALICE,
                1_000000000,
                BOB,
                b"aaaa",
            );
            std::debug::print(&msg1);
            // 0x39fae67be485475f6ce184f43d96af402b5b3eb9c237a3b76ab6606f7fb9c256

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 =
                x"916db9ce4c38490dd0882d7918ac85f9e658c2b1ae43ab1205e9ad7dd5b260fd6ba0f5b9b3ce75013034b39813614c2e79a92fac9b1e1dac7d108f806263eb01";
            let sig2 =
                x"6e54f3c1b5369b0c3e6032d6122037c3cb472faa27e11f1804f3d5b9bb42e325aa47cd172dbb28e3ec2ead69a5b29df43fd752643cf300e7822bb725e99fd10c";
            let sig3 =
                x"6e54f3c1b5369b0c3e6032d6122037c3cb472faa27e11f1804f3d5b9bb42e325aa47cd172dbb28e3ec2ead69a5b29df43fd752643cf300e7822bb725e99fd10c";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            signatures.push_back(sig3);

            // fail -> assert!(signatures.length() >= config.threshold, EINVALID_SIGNATURES);
            user_entry::withdraw(
                &clock,
                &config,
                &mut vault,
                1,
                1,
                1_000000000,
                BOB,
                signatures,
                b"aaaa",
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = active_vault::ETRANSACTION_HASH_ALREADY_USED,
            location = active_vault,
        ),
    ]
    // deposit 100 SUI
    // use PK1 and PK2 to withdraw 1 SUI
    // use the same message hash to withdraw 1 SUI => fail
    public fun test_withdraw_fail_double() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // deposit
        test_scenario::next_tx(scenario_mut, OWNER);
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
                100_000000000,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        // withdraw 1 SUI
        test_scenario::next_tx(scenario_mut, ALICE);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let clock = clock::create_for_testing(scenario_mut.ctx());

            let msg1 = active_vault::keccak_message<SUI_TEST>(
                1,
                1,
                ALICE,
                1_000000000,
                BOB,
                b"aaaa",
            );
            std::debug::print(&msg1);
            // 0x39fae67be485475f6ce184f43d96af402b5b3eb9c237a3b76ab6606f7fb9c256

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 =
                x"916db9ce4c38490dd0882d7918ac85f9e658c2b1ae43ab1205e9ad7dd5b260fd6ba0f5b9b3ce75013034b39813614c2e79a92fac9b1e1dac7d108f806263eb01";
            let sig2 =
                x"6e54f3c1b5369b0c3e6032d6122037c3cb472faa27e11f1804f3d5b9bb42e325aa47cd172dbb28e3ec2ead69a5b29df43fd752643cf300e7822bb725e99fd10c";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(
                &clock,
                &config,
                &mut vault,
                1,
                1,
                1_000000000,
                BOB,
                signatures,
                b"aaaa",
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };

        // withdraw 1 SUI with the same message hash
        test_scenario::next_tx(scenario_mut, ALICE);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let clock = clock::create_for_testing(scenario_mut.ctx());

            let msg1 = active_vault::keccak_message<SUI_TEST>(
                1,
                1,
                ALICE,
                1_000000000,
                BOB,
                b"aaaa",
            );
            std::debug::print(&msg1);
            // 0x39fae67be485475f6ce184f43d96af402b5b3eb9c237a3b76ab6606f7fb9c256

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 =
                x"916db9ce4c38490dd0882d7918ac85f9e658c2b1ae43ab1205e9ad7dd5b260fd6ba0f5b9b3ce75013034b39813614c2e79a92fac9b1e1dac7d108f806263eb01";
            let sig2 =
                x"6e54f3c1b5369b0c3e6032d6122037c3cb472faa27e11f1804f3d5b9bb42e325aa47cd172dbb28e3ec2ead69a5b29df43fd752643cf300e7822bb725e99fd10c";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(
                &clock,
                &config,
                &mut vault,
                1,
                1,
                1_000000000,
                BOB,
                signatures,
                b"aaaa",
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = active_vault::EORDER_ID_ALREADY_USED, location = active_vault)]
    // deposit 100 SUI
    // use PK1 and PK2 to withdraw 1 SUI
    // use the same message hash to withdraw 1 SUI => fail
    public fun test_withdraw_fail_with_same_order_id() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // deposit
        test_scenario::next_tx(scenario_mut, OWNER);
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
                100_000000000,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        // withdraw
        test_scenario::next_tx(scenario_mut, ALICE);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let clock = clock::create_for_testing(scenario_mut.ctx());

            let msg1 = active_vault::keccak_message<SUI_TEST>(
                1,
                1,
                ALICE,
                1_000000000,
                BOB,
                b"aaaa",
            );
            std::debug::print(&msg1);
            // 0x39fae67be485475f6ce184f43d96af402b5b3eb9c237a3b76ab6606f7fb9c256

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 =
                x"916db9ce4c38490dd0882d7918ac85f9e658c2b1ae43ab1205e9ad7dd5b260fd6ba0f5b9b3ce75013034b39813614c2e79a92fac9b1e1dac7d108f806263eb01";
            let sig2 =
                x"6e54f3c1b5369b0c3e6032d6122037c3cb472faa27e11f1804f3d5b9bb42e325aa47cd172dbb28e3ec2ead69a5b29df43fd752643cf300e7822bb725e99fd10c";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(
                &clock,
                &config,
                &mut vault,
                1,
                1,
                1_000000000,
                BOB,
                signatures,
                b"aaaa",
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };

        // withdraw
        test_scenario::next_tx(scenario_mut, ALICE);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let clock = clock::create_for_testing(scenario_mut.ctx());

            let msg1 = active_vault::keccak_message<SUI_TEST>(
                1,
                2,
                ALICE,
                1_000000000,
                BOB,
                b"aaaa",
            );
            std::debug::print(&msg1);

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 =
                x"916db9ce4c38490dd0882d7918ac85f9e658c2b1ae43ab1205e9ad7dd5b260fd6ba0f5b9b3ce75013034b39813614c2e79a92fac9b1e1dac7d108f806263eb01";
            let sig2 =
                x"6e54f3c1b5369b0c3e6032d6122037c3cb472faa27e11f1804f3d5b9bb42e325aa47cd172dbb28e3ec2ead69a5b29df43fd752643cf300e7822bb725e99fd10c";
            signatures.push_back(sig1);
            signatures.push_back(sig2);

            // same order_id, same order_time
            user_entry::withdraw(
                &clock,
                &config,
                &mut vault,
                1,
                2,
                1_000000000,
                BOB,
                signatures,
                b"aaaa",
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    // set max vault balance to 1 SUI
    // OWNER deposit 100 SUI (0 to active vault, 100 to secure vault)
    // operator withdraw 100 SUI (to active vault)
    public fun test_operator_withdraw_secure_vault() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            dvault_manage::set_max_vault_balance<SUI_TEST>(&cap, &mut vault, &config, 1_000000000);

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(cap);
        };

        // deposit 100 SUI
        test_scenario::next_tx(scenario_mut, OWNER);
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
                100_000000000,
                scenario_mut.ctx(),
            );
            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        // withdraw
        test_scenario::next_tx(scenario_mut, OWNER);
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
                100_000000000,
                scenario_mut.ctx(),
            );
            scenario_mut.return_to_sender(operator_cap);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        // check balance
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let (
                deposit_enable,
                withdraw_enable,
                max_vault_balance,
                deposit_minimum_balance,
                withdraw_minimum_balance,
                order_id_counter,
                used_hashes,
                deposit_order_ids,
                used_order_ids,
                withdraw_security_period,
            ) = active_vault::get_vault_config<SUI_TEST>(&vault);
            assert!(vault.balance_value() == 100_000000000, 0);
            assert!(max_vault_balance == 1_000000000, 0);
            test_scenario::return_shared(vault);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = secure_vault::EOPERATOR_DISABLED, location = secure_vault)]
    // set max vault balance to 1 SUI
    // OWNER deposit 100 SUI (0 to active vault, 100 to secure vault)
    // disable operator
    // operator withdraw 1 SUI (to active vault) failed because operator is disabled
    public fun test_disabled_operator_withdraw_secure_vault_fail() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            dvault_manage::set_max_vault_balance<SUI_TEST>(&cap, &mut vault, &config, 1_000000000);

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(cap);
        };

        // deposit 100 SUI
        test_scenario::next_tx(scenario_mut, OWNER);
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
                100_000000000,
                scenario_mut.ctx(),
            );
            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        // disable the operator
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);
            let operator_cap = test_scenario::take_from_sender<SecureOperatorCap>(scenario_mut);
            let admin_cap = test_scenario::take_from_sender<SecureOwnerCap>(scenario_mut);
            secure_vault.set_disable_operator<SUI_TEST>(
                &admin_cap,
                operator_cap.cap_to_address(),
                true,
            );
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(operator_cap);
            scenario_mut.return_to_sender(admin_cap);
        };

        // operator withdraw from secure vault
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let cap = test_scenario::take_from_sender<SecureOperatorCap>(scenario_mut);
            dvault_manage::operator_withdraw_secure_vault(
                &cap,
                &config,
                &mut vault,
                &mut secure_vault,
                1_000000000,
                scenario_mut.ctx(),
            );
            scenario_mut.return_to_sender(cap);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = secure_vault::EWITHDRAW_AMOUNT_TOO_HIGH_IN_EPOCH,
            location = secure_vault,
        ),
    ]
    public fun test_operator_withdraw_secure_vault_fail_exceed_limit() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            dvault_manage::set_max_vault_balance<SUI_TEST>(&cap, &mut vault, &config, 1_000000000);

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(cap);
        };

        // deposit 100sui
        test_scenario::next_tx(scenario_mut, OWNER);
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
                100_000000000,
                scenario_mut.ctx(),
            );
            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        // set epoch max amount to 1SUI
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);
            let operator_cap = test_scenario::take_from_sender<SecureOperatorCap>(scenario_mut);
            let admin_cap = test_scenario::take_from_sender<SecureOwnerCap>(scenario_mut);
            secure_vault.set_operator_epoch_max_amount<SUI_TEST>(&admin_cap, 1_000000000);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(operator_cap);
            scenario_mut.return_to_sender(admin_cap);
        };

        // withdraw
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);
            let cap = test_scenario::take_from_sender<SecureOperatorCap>(scenario_mut);

            dvault_manage::operator_withdraw_secure_vault(
                &cap,
                &config,
                &mut vault,
                &mut secure_vault,
                1_000000000 + 1,
                scenario_mut.ctx(),
            );

            scenario_mut.return_to_sender(cap);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
        };

        test_scenario::end(scenario);
    }

    #[test]
    // Owner should be able to withdraw funds from secure vault (admin cap)
    // No matter the "epoch_max_amount" is set to 1 SUI
    public fun test_admin_withdraw_secure_vault() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // Tx1: Set max vault balance to 1 SUI
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);

            dvault_manage::set_max_vault_balance<SUI_TEST>(&cap, &mut vault, &config, 1_000000000);

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(cap);
        };

        // Tx2: Deposit 100 SUI
        test_scenario::next_tx(scenario_mut, OWNER);
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
                100_000000000,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        // Tx3: Set max amount each epoch to 1SUI
        // (admin withdraw does not affect)
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);
            let operator_cap = test_scenario::take_from_sender<SecureOperatorCap>(scenario_mut);
            let admin_cap = test_scenario::take_from_sender<SecureOwnerCap>(scenario_mut);

            secure_vault.set_operator_epoch_max_amount<SUI_TEST>(&admin_cap, 1_000000000);

            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(operator_cap);
            scenario_mut.return_to_sender(admin_cap);
        };

        // Tx4: Withdraw 100 SUI from secure vault
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);
            let cap = test_scenario::take_from_sender<SecureOwnerCap>(scenario_mut);

            let _balance = secure_vault.admin_withdraw_secure_vault<SUI_TEST>(&cap, 100_000000000);
            // @note Why this transfer is not in the contract
            transfer::public_transfer(_balance.into_coin(scenario_mut.ctx()), OWNER);
            scenario_mut.return_to_sender(cap);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        // Tx5: Check SUI coin balance of the owner
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let coin = test_scenario::take_from_sender<Coin<SUI_TEST>>(scenario_mut);
            assert!(coin.value() == 100_000000000, 0);
            scenario_mut.return_to_sender(coin);
        };

        test_scenario::end(scenario);
    }
}

module dvault::base_test_new_2 {
    use dvault::active_vault::{Self, ActiveVault, Config, OwnerCap as DvaultOwnerCap, PauseCap};
    use dvault::dvault_manage;
    use dvault::secure_vault::{Self, SecureVault, SecureOperatorCap, SecureOwnerCap};
    use dvault::sui_test::{Self, SUI_TEST};
    use dvault::usdc_test::{Self, USDC_TEST};
    use dvault::user_entry;
    use sui::address;
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, CoinMetadata, Coin};
    use sui::ed25519;
    use sui::test_scenario::{Self, Scenario};

    const OWNER: address = @0xa;
    const ALICE: address = @0xa;
    const BOB: address = @0xb;
    // public key and secret key for testing
    const PK1: vector<u8> = x"b9c6ee1630ef3e711144a648db06bbb2284f7274cfbee53ffcee503cc1a49200";
    const SK1: vector<u8> = x"9bf49a6a0755f953811fce125f2683d50429c3bb49e074147e0089a52eae155f";

    const PK2: vector<u8> = x"f1a756ceb2955f680ab622c9c271aa437a22aa978c34ae456f24400d6ea7ccdd";
    const SK2: vector<u8> = x"c5e26f9b31288c268c31217de8d2a783eec7647c2b8de48286f0a25a2dd6594b";

    const PK3: vector<u8> = x"848a7e4e12f0b56c79c30ff7d0a2187552b839ee90ccd7d1ae15c7f8396e083f";
    const SK3: vector<u8> = x"39e6aeb1b81de0a6d15a72194585557b2c2afd27f33b575ea007d57a6733ba51";

    #[test_only]
    // initialize dvault for testing (will be called first in each test)
    public fun init_dvault(scenario_mut: &mut Scenario) {
        let owner = test_scenario::sender(scenario_mut);

        // init coins & vault modules for testing
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
                1_000000000,
                1_000000000,
                scenario_mut.ctx(),
            );
            // @note try two ways to return the cap
            // scenario_mut.return_to_sender(cap);
            test_scenario::return_to_address(owner, cap);
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
    }

    #[test]
    public fun test_set_pause() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // Set pause
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let mut config = test_scenario::take_shared<Config>(scenario_mut);
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);

            dvault_manage::set_pause(&owner_cap, &mut config, true);

            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(owner_cap);
        };

        // check state
        // OWNER should still have 100 SUI
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            assert!(active_vault::paused(&config) == true);

            test_scenario::return_shared(config);
        };

        test_scenario::end(scenario);
    }

    #[test]
    // freeze a pause cap
    public fun test_freeze_pause_cap_already_pause_cap() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // craete pause cap ALICE
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let active_vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);

            dvault_manage::create_pause_cap(&owner_cap, &config, ALICE, scenario_mut.ctx());

            test_scenario::return_shared(active_vault);
            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(owner_cap);
        };

        // freeze a pause cap (ALICE)
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let mut config = test_scenario::take_shared<Config>(scenario_mut);
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);

            dvault_manage::freeze_pause_cap(&owner_cap, &mut config, ALICE, true);

            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(owner_cap);
        };

        // freeze ALICE again
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let mut config = test_scenario::take_shared<Config>(scenario_mut);
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);

            dvault_manage::freeze_pause_cap(&owner_cap, &mut config, ALICE, true);

            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(owner_cap);
        };

        // check if freezed
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let active_vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);

            let freezed_caps = active_vault::get_freezed_caps(&config);

            assert!(freezed_caps.contains(ALICE));
            assert!(*freezed_caps.borrow(ALICE));

            test_scenario::return_shared(config);
            test_scenario::return_shared(active_vault);
        };

        test_scenario::end(scenario);
    }

    #[test]
    // freeze a pause cap
    public fun test_freeze_pause_cap_not_already_pause_cap() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // freeze a pause cap
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let mut config = test_scenario::take_shared<Config>(scenario_mut);
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);

            // get an address from pk

            let p3 = address::from_bytes(PK3);
            dvault_manage::freeze_pause_cap(&owner_cap, &mut config, p3, true);

            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(owner_cap);
        };

        // check if it is freezed
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let active_vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let p3 = address::from_bytes(PK3);

            let freezed_caps = active_vault::get_freezed_caps(&config);

            assert!(freezed_caps.contains(p3));
            assert!(*freezed_caps.borrow(p3));

            test_scenario::return_shared(config);
            test_scenario::return_shared(active_vault);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = active_vault::EPAUSED, location = active_vault)]
    // freeze a pause cap
    public fun test_set_pause_fail_freezed_pause_cap() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // craete pause cap ALICE
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let active_vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);

            dvault_manage::create_pause_cap(&owner_cap, &config, ALICE, scenario_mut.ctx());

            test_scenario::return_shared(active_vault);
            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(owner_cap);
        };

        // freeze a pause cap
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let mut config = test_scenario::take_shared<Config>(scenario_mut);
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let pause_cap = test_scenario::take_from_address<PauseCap>(scenario_mut, ALICE);

            dvault_manage::freeze_pause_cap(
                &owner_cap,
                &mut config,
                active_vault::pause_cap_to_address(&pause_cap),
                true,
            );

            test_scenario::return_shared(config);
            test_scenario::return_to_address(ALICE, pause_cap);
            scenario_mut.return_to_sender(owner_cap);
        };

        // ALICE can not set pause because it is freezed
        test_scenario::next_tx(scenario_mut, ALICE);
        {
            let mut config = test_scenario::take_shared<Config>(scenario_mut);
            let active_vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);

            let pause_cap = test_scenario::take_from_address<PauseCap>(scenario_mut, ALICE);

            dvault_manage::set_pause_by_pause_cap(&pause_cap, &mut config, true);

            test_scenario::return_shared(config);
            test_scenario::return_shared(active_vault);
            test_scenario::return_to_address(ALICE, pause_cap);
        };

        test_scenario::end(scenario);
    }

    #[test]
    // mint 200 SUI to OWNER
    // deposit 100 SUI, should have 100 SUI left
    public fun test_deposit_with_balance_check() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // Mint 200 SUI
        // OWNER deposit 100 SUI
        test_scenario::next_tx(scenario_mut, OWNER);
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
                100_000000000,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        // check state
        // OWNER should still have 100 SUI
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            // let config = test_scenario::take_shared<Config>(scenario_mut);
            // let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            // let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);

            let coin = scenario_mut.take_from_sender<Coin<SUI_TEST>>();
            assert!(coin.value() == 100_000000000);

            scenario_mut.return_to_sender(coin);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = active_vault::EPAUSED, location = active_vault)]
    public fun test_deposit_fail_when_paused() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // OWNER deposit 100 SUI
        test_scenario::next_tx(scenario_mut, OWNER);
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
                100_000000000,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let mut config = test_scenario::take_shared<Config>(scenario_mut);
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);

            dvault_manage::set_pause(&owner_cap, &mut config, true);

            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(owner_cap);
        };

        test_scenario::next_tx(scenario_mut, OWNER);
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
                100_000000000,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = active_vault::EDISABLED, location = active_vault)]
    public fun test_deposit_fail_when_deposit_disabled() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // OWNER deposit 100 SUI
        test_scenario::next_tx(scenario_mut, OWNER);
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
                100_000000000,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        // set deposit disabled
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);

            dvault_manage::set_deposit_enable(&owner_cap, &mut vault, &config, false);

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(owner_cap);
        };

        test_scenario::next_tx(scenario_mut, OWNER);
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
                100_000000000,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        test_scenario::end(scenario);
    }

    #[test]
    // direct deposit into active vault
    public fun test_direct_deposit() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);

            let coin = coin::mint_for_testing<SUI_TEST>(
                100_000000000,
                test_scenario::ctx(scenario_mut),
            );

            let balance = coin::into_balance(coin);

            dvault_manage::direct_deposit<SUI_TEST>(
                &mut vault,
                &config,
                balance,
                scenario_mut.ctx(),
            );

            assert!(active_vault::balance_value(&vault) == 100_000000000);

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
        };
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_direct_withdraw() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);

            let coin = coin::mint_for_testing<SUI_TEST>(
                100_000000000,
                test_scenario::ctx(scenario_mut),
            );

            let balance = coin::into_balance(coin);

            dvault_manage::direct_deposit<SUI_TEST>(
                &mut vault,
                &config,
                balance,
                scenario_mut.ctx(),
            );

            assert!(active_vault::balance_value(&vault) == 100_000000000);

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
        };

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let active_owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);

            let withdraw_balance = dvault_manage::direct_withdraw<SUI_TEST>(
                &active_owner_cap,
                &config,
                &mut vault,
                50_000000000,
                scenario_mut.ctx(),
            );

            assert!(active_vault::balance_value(&vault) == 50_000000000);
            assert!(withdraw_balance.value() == 50_000000000);

            scenario_mut.return_to_sender(active_owner_cap);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            withdraw_balance.destroy_for_testing();
        };
        test_scenario::end(scenario);
    }

    #[test]
    // deposit into secure vault
    public fun test_deposit_secure_vault() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);

            let coin = coin::mint_for_testing<SUI_TEST>(
                100_000000000,
                test_scenario::ctx(scenario_mut),
            );
            let balance = coin::into_balance(coin);

            dvault_manage::deposit_secure_vault<SUI_TEST>(&mut secure_vault, &config, balance);

            assert!(secure_vault::balance_value(&secure_vault) == 100_000000000);

            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_add_signer() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // Add signer PK3
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut config = test_scenario::take_shared<Config>(scenario_mut);

            dvault_manage::add_signer(&owner_cap, &mut config, PK3, 3);

            scenario_mut.return_to_sender(owner_cap);
            test_scenario::return_shared(config);
        };

        // check state: the signer is added correctly
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);

            let p3 = PK3;
            let signers = active_vault::signers(&config);
            assert!(signers.length() == 3);
            assert!(signers.borrow(2) == p3);

            let threshold = active_vault::threshold(&config);
            assert!(threshold == 3);

            test_scenario::return_shared(config);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = active_vault::ESIGNER_ALREADY_EXISTS, location = active_vault)]
    // add PK2 as signer (already a signer)
    public fun test_add_signer_fail_when_already_signer() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // Add signer PK2 (already a signer)
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut config = test_scenario::take_shared<Config>(scenario_mut);

            dvault_manage::add_signer(&owner_cap, &mut config, PK2, 2);

            scenario_mut.return_to_sender(owner_cap);
            test_scenario::return_shared(config);
        };
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = active_vault::ETHRESHOLD_OVERFLOW, location = active_vault)]
    // add PK3 as signer with threshold 4 (>3)
    public fun test_add_signer_fail_threshold_overflow() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // Add signer PK3 with threshold 4 (>3)
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut config = test_scenario::take_shared<Config>(scenario_mut);

            dvault_manage::add_signer(&owner_cap, &mut config, PK3, 4);

            scenario_mut.return_to_sender(owner_cap);
            test_scenario::return_shared(config);
        };
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = active_vault::ETHRESHOLD_OVERFLOW, location = active_vault)]
    // add PK3 as signer with threshold 0
    public fun test_add_signer_fail_zero_threshold() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // Add signer PK3 with threshold 0
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut config = test_scenario::take_shared<Config>(scenario_mut);

            dvault_manage::add_signer(&owner_cap, &mut config, PK3, 0);

            scenario_mut.return_to_sender(owner_cap);
            test_scenario::return_shared(config);
        };
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_remove_signer() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // Remove signer PK2
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut config = test_scenario::take_shared<Config>(scenario_mut);

            dvault_manage::remove_signer(&owner_cap, &mut config, PK2, 1);

            scenario_mut.return_to_sender(owner_cap);
            test_scenario::return_shared(config);
        };

        // check state: the signer is removed correctly
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);

            let p1 = PK1;
            let p2 = PK2;
            let signers = active_vault::signers(&config);
            assert!(signers.length() == 1);
            assert!(signers.borrow(0) == p1);

            // PK2 has been removed
            let (ok, _) = signers.index_of(&p2);
            assert!(!ok);

            test_scenario::return_shared(config);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = active_vault::ESIGNER_NOT_FOUND, location = active_vault)]
    public fun test_remove_signer_fail_signer_not_found() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // Remove signer PK2
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut config = test_scenario::take_shared<Config>(scenario_mut);

            dvault_manage::remove_signer(&owner_cap, &mut config, PK3, 1);

            scenario_mut.return_to_sender(owner_cap);
            test_scenario::return_shared(config);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = active_vault::ETHRESHOLD_OVERFLOW, location = active_vault)]
    public fun test_remove_signer_fail_threshold_overflow() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // Remove signer PK2 with threshold 2
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut config = test_scenario::take_shared<Config>(scenario_mut);

            dvault_manage::remove_signer(&owner_cap, &mut config, PK2, 2);

            scenario_mut.return_to_sender(owner_cap);
            test_scenario::return_shared(config);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = active_vault::ETHRESHOLD_OVERFLOW, location = active_vault)]
    public fun test_remove_signer_fail_threshold_zero() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // Remove signer PK2 with threshold 2
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut config = test_scenario::take_shared<Config>(scenario_mut);

            dvault_manage::remove_signer(&owner_cap, &mut config, PK2, 0);

            scenario_mut.return_to_sender(owner_cap);
            test_scenario::return_shared(config);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_reset_signers() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // Reset signers to [PK3]
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut config = test_scenario::take_shared<Config>(scenario_mut);

            let p3 = PK3;
            // generate a vector contains PK3
            let new_signers = vector[p3];

            dvault_manage::reset_signers(&owner_cap, &mut config, new_signers, 1);

            assert!(config.signer_length() == 1);
            assert!(config.threshold() == 1);
            assert!(config.signers().borrow(0) == p3);

            scenario_mut.return_to_sender(owner_cap);
            test_scenario::return_shared(config);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = active_vault::ETHRESHOLD_OVERFLOW, location = active_vault)]
    // The restriction is that the threshold must be less than or equal to the number of signers new added
    // Maybe it should be less than the total signers amount
    // Or we need to change this "reset_signer" function to "set_signers" function
    public fun test_reset_signers_fail_threshold_overflow() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // Reset signers to [PK3]
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut config = test_scenario::take_shared<Config>(scenario_mut);

            let p3 = PK3;
            // generate a vector contains PK3
            let new_signers = vector[p3];

            dvault_manage::reset_signers(&owner_cap, &mut config, new_signers, 2);

            scenario_mut.return_to_sender(owner_cap);
            test_scenario::return_shared(config);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = active_vault::ETHRESHOLD_OVERFLOW, location = active_vault)]
    // The restriction is that the threshold must be less than or equal to the number of signers new added
    // Maybe it should be less than the total signers amount
    // Or we need to change this "reset_signer" function to "set_signers" function
    public fun test_reset_signers_fail_threshold_zero() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // Reset signers to [PK3]
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut config = test_scenario::take_shared<Config>(scenario_mut);

            let p3 = PK3;
            // generate a vector contains PK3
            let new_signers = vector[p3];

            dvault_manage::reset_signers(&owner_cap, &mut config, new_signers, 0);

            scenario_mut.return_to_sender(owner_cap);
            test_scenario::return_shared(config);
        };

        test_scenario::end(scenario);
    }

    // #[test]
    // #[expected_failure(abort_code = active_vault::ESIGNER_ALREADY_EXISTS, location = active_vault)]
    // // one of the new signers already exists
    // public fun test_reset_signers_fail_already_signer() {
    //     let mut scenario = test_scenario::begin(OWNER);
    //     let scenario_mut = &mut scenario;
    //     init_dvault(scenario_mut);

    //     // Reset signers to [PK3]
    //     test_scenario::next_tx(scenario_mut, OWNER);
    //     {
    //         let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
    //         let mut config = test_scenario::take_shared<Config>(scenario_mut);

    //         let p2 = PK2;
    //         let p3 = PK3;
    //         // generate a vector contains PK3
    //         let new_signers = vector[p2, p3];

    //         dvault_manage::reset_signers(&owner_cap, &mut config, new_signers, 2);

    //         scenario_mut.return_to_sender(owner_cap);
    //         test_scenario::return_shared(config);
    //     };

    //     test_scenario::end(scenario);
    // }

    #[test]
    public fun test_set_enable_security_period() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // add security period, 1 SUI / day
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let config = test_scenario::take_shared<Config>(scenario_mut);
            dvault_manage::add_security_period<SUI_TEST>(
                &cap,
                &mut vault,
                &config,
                86400 * 1000,
                1_000000000,
                scenario_mut.ctx(),
            );
            scenario_mut.return_to_sender(cap);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
        };

        // deposit 1 SUI
        test_scenario::next_tx(scenario_mut, OWNER);
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
                100_000000000,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        // Set security period enable to false
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut active_vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);

            let pid = active_vault::get_security_period_id(&active_vault, 0);
            dvault_manage::set_enable_security_period(
                &owner_cap,
                &mut active_vault,
                &config,
                pid,
                false,
            );

            test_scenario::return_shared(config);
            test_scenario::return_shared(active_vault);
            scenario_mut.return_to_sender(owner_cap);
        };

        // deposit another 1 SUI and should success
        test_scenario::next_tx(scenario_mut, OWNER);
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
                1_000000000,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_update_security_period() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // add security period, 1 SUI / day
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let config = test_scenario::take_shared<Config>(scenario_mut);
            dvault_manage::add_security_period<SUI_TEST>(
                &cap,
                &mut vault,
                &config,
                86400 * 1000,
                1_000000000,
                scenario_mut.ctx(),
            );
            scenario_mut.return_to_sender(cap);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
        };

        // deposit 1 SUI
        test_scenario::next_tx(scenario_mut, OWNER);
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
                100_000000000,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        // Update security period to 2 SUI / day
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut active_vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);

            let pid = active_vault::get_security_period_id(&active_vault, 0);
            dvault_manage::update_security_period(
                &owner_cap,
                &mut active_vault,
                &config,
                pid,
                86400 * 1000,
                2_000000000,
            );

            test_scenario::return_shared(config);
            test_scenario::return_shared(active_vault);
            scenario_mut.return_to_sender(owner_cap);
        };

        // deposit another 1 SUI and should success
        test_scenario::next_tx(scenario_mut, OWNER);
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
                1_000000000,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        test_scenario::end(scenario);
    }

    #[test]
    // owner can create secure operator cap (ALICE)
    public fun test_create_operator_cap() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let secure_owner_cap = test_scenario::take_from_sender<SecureOwnerCap>(scenario_mut);
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);

            secure_vault::create_operator_cap(
                &secure_owner_cap,
                ALICE,
                scenario_mut.ctx(),
            );

            let operator_cap = test_scenario::take_from_address<SecureOperatorCap>(
                scenario_mut,
                ALICE,
            );
            // assert!(test_scenario::has_most_recent_for_address<SecureOperatorCap>(ALICE));
            std::debug::print(&operator_cap.cap_to_address());
            assert!(operator_cap.cap_to_address() != address::from_u256(0));

            test_scenario::return_shared(secure_vault);
            scenario_mut.return_to_sender(secure_owner_cap);
            test_scenario::return_shared(config);
            test_scenario::return_to_address(ALICE, operator_cap);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_create_pause_cap() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // craete pause cap ALICE
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let active_vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);

            dvault_manage::create_pause_cap(&owner_cap, &config, ALICE, scenario_mut.ctx());

            test_scenario::return_shared(active_vault);
            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(owner_cap);
        };

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let pause_cap = test_scenario::take_from_address<PauseCap>(scenario_mut, ALICE);
            std::debug::print(&pause_cap.pause_cap_to_address());
            assert!(pause_cap.pause_cap_to_address() != address::from_u256(0));
            test_scenario::return_to_address(ALICE, pause_cap);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_set_pause_by_pause_cap() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // craete pause cap ALICE
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let active_vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);

            dvault_manage::create_pause_cap(&owner_cap, &config, ALICE, scenario_mut.ctx());

            test_scenario::return_shared(active_vault);
            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(owner_cap);
        };

        // Set pause
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let mut config = test_scenario::take_shared<Config>(scenario_mut);
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let pause_cap = test_scenario::take_from_address<PauseCap>(scenario_mut, ALICE);

            dvault_manage::set_pause_by_pause_cap(&pause_cap, &mut config, true);

            test_scenario::return_to_address(ALICE, pause_cap);
            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(owner_cap);
        };

        // paused
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            assert!(active_vault::paused(&config) == true);

            test_scenario::return_shared(config);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = active_vault::EDISABLED, location = active_vault)]
    public fun test_withdraw_fail_when_withdraw_disable() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // OWNER deposit 100 SUI
        test_scenario::next_tx(scenario_mut, OWNER);
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
                100_000000000,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        // set withdraw disabled
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);

            dvault_manage::set_withdraw_enable(&owner_cap, &mut vault, &config, false);

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(owner_cap);
        };

        // withdraw will fail because withdraw is disabled
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let clock = clock::create_for_testing(scenario_mut.ctx());

            let msg1 = active_vault::keccak_message<SUI_TEST>(
                1,
                1,
                ALICE,
                1_000000000,
                BOB,
                b"aaaa",
            );
            std::debug::print(&msg1);
            // 0x39fae67be485475f6ce184f43d96af402b5b3eb9c237a3b76ab6606f7fb9c256

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 =
                x"916db9ce4c38490dd0882d7918ac85f9e658c2b1ae43ab1205e9ad7dd5b260fd6ba0f5b9b3ce75013034b39813614c2e79a92fac9b1e1dac7d108f806263eb01";
            let sig2 =
                x"6e54f3c1b5369b0c3e6032d6122037c3cb472faa27e11f1804f3d5b9bb42e325aa47cd172dbb28e3ec2ead69a5b29df43fd752643cf300e7822bb725e99fd10c";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(
                &clock,
                &config,
                &mut vault,
                1,
                1,
                1_000000000,
                BOB,
                signatures,
                b"aaaa",
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = active_vault::EEXPIRED, location = active_vault)]
    public fun test_withdraw_fail_expired() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // OWNER deposit 100 SUI
        test_scenario::next_tx(scenario_mut, OWNER);
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
                100_000000000,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        // withdraw will fail because the order time has expired
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let mut clock = clock::create_for_testing(scenario_mut.ctx());

            clock::increment_for_testing(&mut clock, 100);

            let msg1 = active_vault::keccak_message<SUI_TEST>(
                1,
                1,
                ALICE,
                1_000000000,
                BOB,
                b"aaaa",
            );
            std::debug::print(&msg1);
            // 0x39fae67be485475f6ce184f43d96af402b5b3eb9c237a3b76ab6606f7fb9c256

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 =
                x"916db9ce4c38490dd0882d7918ac85f9e658c2b1ae43ab1205e9ad7dd5b260fd6ba0f5b9b3ce75013034b39813614c2e79a92fac9b1e1dac7d108f806263eb01";
            let sig2 =
                x"6e54f3c1b5369b0c3e6032d6122037c3cb472faa27e11f1804f3d5b9bb42e325aa47cd172dbb28e3ec2ead69a5b29df43fd752643cf300e7822bb725e99fd10c";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(
                &clock,
                &config,
                &mut vault,
                1,
                1,
                1_000000000,
                BOB,
                signatures,
                b"aaaa",
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = active_vault::EVERSION_MISMATCH, location = active_vault)]
    public fun test_version_check_fail_version_mismatch() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // OWNER deposit 100 SUI
        test_scenario::next_tx(scenario_mut, OWNER);
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
                100_000000000,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        // Migrate to a new version
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut config = test_scenario::take_shared<Config>(scenario_mut);

            active_vault::mock_version_migrate(&mut config, true);

            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(owner_cap);
        };

        // deposit again, should fail
        test_scenario::next_tx(scenario_mut, OWNER);
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
                100_000000000,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = active_vault::EVERSION_MISMATCH, location = active_vault)]
    public fun test_version_migration_fail_same_version() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut config = test_scenario::take_shared<Config>(scenario_mut);

            dvault_manage::version_migrate(&owner_cap, &mut config);

            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(owner_cap);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = active_vault::EVERSION_MISMATCH, location = active_vault)]
    public fun test_version_migration_fail_version_mismatch() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // Migrate to a new version (+1)
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut config = test_scenario::take_shared<Config>(scenario_mut);

            active_vault::mock_version_migrate(&mut config, true);

            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(owner_cap);
        };

        // migrate again, should fail because it downgrades the version
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut config = test_scenario::take_shared<Config>(scenario_mut);

            dvault_manage::version_migrate(&owner_cap, &mut config);

            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(owner_cap);
        };

        test_scenario::end(scenario);
    }

    #[test]
    // deposit 100 SUI (by OWNER)
    // add security period (1 SUI / day)
    // add security period (10 SUI / 10 days)
    // add security period (0.5 SUI / day) but not enable
    // ALICE withdraw 1 SUI to BOB
    // ALICE withdraw 1 SUI to BOB after 1 day
    public fun test_withdraw_with_multiple_security_period_part_enabled() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // deposit
        test_scenario::next_tx(scenario_mut, OWNER);
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
                100_000000000,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        // add security period (1 SUI / day)
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            dvault_manage::add_security_period<SUI_TEST>(
                &cap,
                &mut vault,
                &config,
                86400 * 1000,
                1_000000000,
                scenario_mut.ctx(),
            );
            scenario_mut.return_to_sender(cap);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
        };

        // add security period (10 SUI / 10 days)
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let config = test_scenario::take_shared<Config>(scenario_mut);
            dvault_manage::add_security_period<SUI_TEST>(
                &cap,
                &mut vault,
                &config,
                864000 * 1000,
                10_000000000,
                scenario_mut.ctx(),
            );
            scenario_mut.return_to_sender(cap);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
        };

        // add security period (0.5 SUI / 1day) but not enable
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let config = test_scenario::take_shared<Config>(scenario_mut);
            dvault_manage::add_security_period<SUI_TEST>(
                &cap,
                &mut vault,
                &config,
                86400 * 1000,
                500000000,
                scenario_mut.ctx(),
            );
            scenario_mut.return_to_sender(cap);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
        };

        // Set security period enable to false
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut active_vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);

            let pid = active_vault::get_security_period_id(&active_vault, 2);
            dvault_manage::set_enable_security_period(
                &owner_cap,
                &mut active_vault,
                &config,
                pid,
                false,
            );

            test_scenario::return_shared(config);
            test_scenario::return_shared(active_vault);
            scenario_mut.return_to_sender(owner_cap);
        };

        // withdraw
        test_scenario::next_tx(scenario_mut, ALICE);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let clock = clock::create_for_testing(scenario_mut.ctx());

            let msg1 = active_vault::keccak_message<SUI_TEST>(
                1,
                1,
                ALICE,
                1_000000000,
                BOB,
                b"aaaa",
            );
            std::debug::print(&msg1);
            // 0x39fae67be485475f6ce184f43d96af402b5b3eb9c237a3b76ab6606f7fb9c256

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 =
                x"916db9ce4c38490dd0882d7918ac85f9e658c2b1ae43ab1205e9ad7dd5b260fd6ba0f5b9b3ce75013034b39813614c2e79a92fac9b1e1dac7d108f806263eb01";
            let sig2 =
                x"6e54f3c1b5369b0c3e6032d6122037c3cb472faa27e11f1804f3d5b9bb42e325aa47cd172dbb28e3ec2ead69a5b29df43fd752643cf300e7822bb725e99fd10c";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(
                &clock,
                &config,
                &mut vault,
                1,
                1,
                1_000000000,
                BOB,
                signatures,
                b"aaaa",
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };

        // withdraw after 1 day
        test_scenario::next_tx(scenario_mut, ALICE);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let mut clock = clock::create_for_testing(scenario_mut.ctx());
            clock.increment_for_testing(86400 * 1000);

            let msg1 = active_vault::keccak_message<SUI_TEST>(
                2,
                86400 * 1000 + 1,
                ALICE,
                1_000000000,
                BOB,
                b"aaaa",
            );
            std::debug::print(&msg1);
            // 0xdc9635e7a6a56898c3498fdf377b084b4d5870676ba3131eb26fb02c5a1a63b6

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 =
                x"933d04ecd789c582b7e1bd02d18b83b01a6b4ec030d0c250807e4babfba4170fac4f4513ffda4a4ee3e43daa5d8ceed119c1d0e8b073f626f05874cd4556d601";
            let sig2 =
                x"f0c40b9cb283f92f0d38ab1e69d946c88f104ab290afb062ef70d874ec53633ad740d6c7dfaa9f6e501a43bb5de9a7efd8fb9548cb79c95820dc3d317e2ae306";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(
                &clock,
                &config,
                &mut vault,
                2,
                86400 * 1000 + 1,
                1_000000000,
                BOB,
                signatures,
                b"aaaa",
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = active_vault::ESECURITY_PERIOD_NOT_FOUND,
            location = active_vault,
        ),
    ]
    public fun test_find_security_period_fail() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // add security period (1 SUI / day)
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            dvault_manage::add_security_period<SUI_TEST>(
                &owner_cap,
                &mut vault,
                &config,
                86400 * 1000,
                1_000000000,
                scenario_mut.ctx(),
            );
            scenario_mut.return_to_sender(owner_cap);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
        };

        // add security period (10 SUI / 10 days)
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let config = test_scenario::take_shared<Config>(scenario_mut);
            dvault_manage::add_security_period<SUI_TEST>(
                &owner_cap,
                &mut vault,
                &config,
                864000 * 1000,
                10_000000000,
                scenario_mut.ctx(),
            );
            scenario_mut.return_to_sender(owner_cap);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
        };

        // try to set security period enable to false (not exist)
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut active_vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);

            dvault_manage::set_enable_security_period(
                &owner_cap,
                &mut active_vault,
                &config,
                address::from_u256(123),
                false,
            );

            test_scenario::return_shared(config);
            test_scenario::return_shared(active_vault);
            scenario_mut.return_to_sender(owner_cap);
        };

        test_scenario::end(scenario);
    }

    #[test]
    // create an owner cap for ALICE and check if successful
    public fun test_create_owner_cap() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // create owner cap for ALICE
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let owner_cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let config = test_scenario::take_shared<Config>(scenario_mut);

            dvault_manage::create_owner_cap(&owner_cap, &config, ALICE, scenario_mut.ctx());

            scenario_mut.return_to_sender(owner_cap);
            test_scenario::return_shared(config);
        };

        // check ALICE has owner cap
        test_scenario::next_tx(scenario_mut, ALICE);
        {
            let owner_cap = test_scenario::take_from_address<DvaultOwnerCap>(scenario_mut, ALICE);

            let cap_id = active_vault::owner_cap_to_address(&owner_cap);
            std::debug::print(&cap_id);
            let zeroAddress = address::from_u256(0);
            std::debug::print(&zeroAddress);
            assert!(cap_id != zeroAddress);

            test_scenario::return_to_address(ALICE, owner_cap);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = active_vault::ETHRESHOLD_TOO_LOW, location = active_vault)]
    // withdraw will fail when the valid signatures are less than the threshold
    public fun test_withdraw_fail_signatures_not_enough() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // deposit
        test_scenario::next_tx(scenario_mut, OWNER);
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
                100_000000000,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        // withdraw with not enough correct signatures
        test_scenario::next_tx(scenario_mut, ALICE);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let clock = clock::create_for_testing(scenario_mut.ctx());

            let msg1 = active_vault::keccak_message<SUI_TEST>(
                1,
                1,
                ALICE,
                1_000000000,
                BOB,
                b"aaaa",
            );
            std::debug::print(&msg1);
            // 0x39fae67be485475f6ce184f43d96af402b5b3eb9c237a3b76ab6606f7fb9c256

            let mut signatures = vector::empty<vector<u8>>();

            // change the first character of the signature
            let sig1 =
                x"116db9ce4c38490dd0882d7918ac85f9e658c2b1ae43ab1205e9ad7dd5b260fd6ba0f5b9b3ce75013034b39813614c2e79a92fac9b1e1dac7d108f806263eb01";
            let sig2 =
                x"6e54f3c1b5369b0c3e6032d6122037c3cb472faa27e11f1804f3d5b9bb42e325aa47cd172dbb28e3ec2ead69a5b29df43fd752643cf300e7822bb725e99fd10c";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(
                &clock,
                &config,
                &mut vault,
                1,
                1,
                1_000000000,
                BOB,
                signatures,
                b"aaaa",
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = active_vault::EINVALID_SIGNATURES, location = active_vault)]
    // withdraw will fail when the valid signatures are less than the threshold
    public fun test_withdraw_fail_signatures_length() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // deposit
        test_scenario::next_tx(scenario_mut, OWNER);
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
                100_000000000,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        // withdraw with not enough correct signatures
        test_scenario::next_tx(scenario_mut, ALICE);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let clock = clock::create_for_testing(scenario_mut.ctx());

            let msg1 = active_vault::keccak_message<SUI_TEST>(
                1,
                1,
                ALICE,
                1_000000000,
                BOB,
                b"aaaa",
            );
            std::debug::print(&msg1);
            // 0x39fae67be485475f6ce184f43d96af402b5b3eb9c237a3b76ab6606f7fb9c256

            let mut signatures = vector::empty<vector<u8>>();

            // change length of sig1
            let sig1 =
                x"916db9ce4c38490dd0882d7918ac85f9e658c2b1ae43ab1205e9ad7dd5b260fd6ba0f5b9b3ce75013034b39813614c2e79a92fac9b1e1dac7d08";
            let sig2 =
                x"6e54f3c1b5369b0c3e6032d6122037c3cb472faa27e11f1804f3d5b9bb42e325aa47cd172dbb28e3ec2ead69a5b29df43fd752643cf300e7822bb725e99fd10c";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(
                &clock,
                &config,
                &mut vault,
                1,
                1,
                1_000000000,
                BOB,
                signatures,
                b"aaaa",
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = secure_vault::EWITHDRAW_AMOUNT_TOO_HIGH,
            location = secure_vault,
        ),
    ]
    // Owner can not withdraw more than the secure vault balance
    public fun test_admin_withdraw_secure_vault_fail_amount_too_high() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // set max vault balance to 1 SUI
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);

            dvault_manage::set_max_vault_balance<SUI_TEST>(&cap, &mut vault, &config, 1_000000000);

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(cap);
        };

        // deposit 100 SUI
        test_scenario::next_tx(scenario_mut, OWNER);
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
                100_000000000,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        // withdraw 200 SUI from secure vault
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);
            let cap = test_scenario::take_from_sender<SecureOwnerCap>(scenario_mut);

            let _balance = secure_vault.admin_withdraw_secure_vault<SUI_TEST>(&cap, 200_000000000);
            transfer::public_transfer(_balance.into_coin(scenario_mut.ctx()), OWNER);
            scenario_mut.return_to_sender(cap);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[
        expected_failure(
            abort_code = secure_vault::EWITHDRAW_AMOUNT_TOO_HIGH,
            location = secure_vault,
        ),
    ]
    public fun test_withdraw_secure_vault_fail_amount_too_high() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // set max vault balance to 1 SUI
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);

            dvault_manage::set_max_vault_balance<SUI_TEST>(&cap, &mut vault, &config, 1_000000000);

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(cap);
        };

        // deposit 100 SUI
        test_scenario::next_tx(scenario_mut, OWNER);
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
                100_000000000,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        // withdraw 200 SUI from secure vault
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);
            let cap = test_scenario::take_from_sender<SecureOperatorCap>(scenario_mut);

            dvault_manage::operator_withdraw_secure_vault(
                &cap,
                &config,
                &mut vault,
                &mut secure_vault,
                200_000000000,
                scenario_mut.ctx(),
            );

            scenario_mut.return_to_sender(cap);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
        };

        test_scenario::end(scenario);
    }

    #[test]
    // when ctx epoch not synced with vault epoch, it will sync
    public fun test_withdraw_secure_vault_epoch_sync() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // set max vault balance to 1 SUI
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);

            dvault_manage::set_max_vault_balance<SUI_TEST>(&cap, &mut vault, &config, 1_000000000);

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(cap);
        };

        // deposit 100 SUI
        test_scenario::next_tx(scenario_mut, OWNER);
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
                100_000000000,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        // withdraw 40 SUI from secure vault
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);
            let cap = test_scenario::take_from_sender<SecureOperatorCap>(scenario_mut);

            dvault_manage::operator_withdraw_secure_vault(
                &cap,
                &config,
                &mut vault,
                &mut secure_vault,
                40_000000000,
                scenario_mut.ctx(),
            );

            scenario_mut.return_to_sender(cap);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
        };

        // withdraw 60 SUI from secure vault (with advanced epoch)
        test_scenario::next_epoch(scenario_mut, OWNER);
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);
            let cap = test_scenario::take_from_sender<SecureOperatorCap>(scenario_mut);

            dvault_manage::operator_withdraw_secure_vault(
                &cap,
                &config,
                &mut vault,
                &mut secure_vault,
                60_000000000,
                scenario_mut.ctx(),
            );

            scenario_mut.return_to_sender(cap);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
        };

        // check epoch state
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);

            let current_epoch = secure_vault::get_current_epoch(&secure_vault);
            assert!(current_epoch == 1);

            let epoch_current_amount = secure_vault::get_current_epoch_amount(&secure_vault);
            assert!(epoch_current_amount == 60_000000000);

            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        test_scenario::end(scenario);
    }

    #[test]
    public fun test_set_disable_operator() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            dvault_manage::set_max_vault_balance<SUI_TEST>(&cap, &mut vault, &config, 1_000000000);

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(cap);
        };

        // disable the operator
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);
            let operator_cap = test_scenario::take_from_sender<SecureOperatorCap>(scenario_mut);
            let admin_cap = test_scenario::take_from_sender<SecureOwnerCap>(scenario_mut);
            secure_vault.set_disable_operator<SUI_TEST>(
                &admin_cap,
                OWNER,
                true,
            );
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(operator_cap);
            scenario_mut.return_to_sender(admin_cap);
        };

        // set disable operator again (make it enable)
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);
            let operator_cap = test_scenario::take_from_sender<SecureOperatorCap>(scenario_mut);
            let admin_cap = test_scenario::take_from_sender<SecureOwnerCap>(scenario_mut);
            secure_vault.set_disable_operator<SUI_TEST>(
                &admin_cap,
                OWNER,
                false,
            );
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(operator_cap);
            scenario_mut.return_to_sender(admin_cap);
        };

        // check operator state
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);

            let is_disabled = secure_vault::get_disabled_operator(&secure_vault, OWNER);
            assert!(is_disabled == false);

            test_scenario::return_shared(secure_vault);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = user_entry::EINFUFFICIENT_BALANCE, location = user_entry)]
    public fun test_user_deposit_fail_insufficient_balance() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // mint 50 SUI but deposit 100 SUI
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);
            let coin = coin::mint_for_testing<SUI_TEST>(
                50_000000000,
                test_scenario::ctx(scenario_mut),
            );

            user_entry::deposit<SUI_TEST>(
                &config,
                &mut vault,
                &mut secure_vault,
                coin,
                100_000000000,
                scenario_mut.ctx(),
            );

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        test_scenario::end(scenario);
    }
}
