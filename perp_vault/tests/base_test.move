#[test_only, allow(unused_const, unused_use, unused_variable)]
module dvault::base_test {
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, CoinMetadata, Coin};
    use sui::test_scenario::{Self, Scenario};
    use dvault::active_vault::{Self, ActiveVault, Config, OwnerCap as DvaultOwnerCap};
    use dvault::secure_vault::{Self, SecureVault};
    use dvault::dvault_manage::{Self};
    use dvault::sui_test::{Self, SUI_TEST};
    use dvault::usdc_test::{Self, USDC_TEST};
    use dvault::user_entry::{Self};
    use dvault::secure_vault::{SecureOperatorCap, SecureOwnerCap};

    use sui::ed25519;

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
            dvault_manage::create_vault<SUI_TEST>(&cap, &mut config, &metadata, 2_000000000, 1_000000000, scenario_mut.ctx());
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
            dvault_manage::create_vault<USDC_TEST>(&cap, &mut config, &metadata, 2_000000, 1_000000, scenario_mut.ctx());
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
    public fun test_deposit() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);
            let coin = coin::mint_for_testing<SUI_TEST>(100_000000000, test_scenario::ctx(scenario_mut));

            user_entry::deposit<SUI_TEST>(&config, &mut vault, &mut secure_vault, coin, 100_000000000, scenario_mut.ctx());

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };
        test_scenario::end(scenario);
    }

    #[test]
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
            let coin = coin::mint_for_testing<SUI_TEST>(100_000000000, test_scenario::ctx(scenario_mut));

            user_entry::deposit<SUI_TEST>(&config, &mut vault, &mut secure_vault, coin, 100_000000000, scenario_mut.ctx());

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

            let msg1 = active_vault::keccak_message<SUI_TEST>(1, 1, ALICE, 1_000000000, BOB, b"aaaa");
            std::debug::print(&msg1);
            // 0x39fae67be485475f6ce184f43d96af402b5b3eb9c237a3b76ab6606f7fb9c256

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 = x"916db9ce4c38490dd0882d7918ac85f9e658c2b1ae43ab1205e9ad7dd5b260fd6ba0f5b9b3ce75013034b39813614c2e79a92fac9b1e1dac7d108f806263eb01";
            let sig2 = x"6e54f3c1b5369b0c3e6032d6122037c3cb472faa27e11f1804f3d5b9bb42e325aa47cd172dbb28e3ec2ead69a5b29df43fd752643cf300e7822bb725e99fd10c";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(&clock, &config, &mut vault, 1, 1, 1_000000000, BOB, signatures, b"aaaa", scenario_mut.ctx());

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

            let msg1 = active_vault::keccak_message<SUI_TEST>(1, 1, ALICE, 1_000000000, BOB, b"aaaa");

            let (deposit_enable, withdraw_enable, max_vault_balance, deposit_minimum_balance, withdraw_minimum_balance, order_id_counter, used_hashes, deposit_order_ids, used_order_ids, withdraw_security_period) = active_vault::get_vault_config<SUI_TEST>(&vault);
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
            let coin = coin::mint_for_testing<SUI_TEST>(100_000000000, test_scenario::ctx(scenario_mut));

            user_entry::deposit<SUI_TEST>(&config, &mut vault, &mut secure_vault, coin, 100_000000000, scenario_mut.ctx());

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
            dvault_manage::add_security_period<SUI_TEST>(&cap, &mut vault, &config, 86400 * 100, 1_000000000, scenario_mut.ctx());
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

            let msg1 = active_vault::keccak_message<SUI_TEST>(1, 1, ALICE, 1_000000000, BOB, b"aaaa");
            std::debug::print(&msg1);
            // 0x39fae67be485475f6ce184f43d96af402b5b3eb9c237a3b76ab6606f7fb9c256

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 = x"916db9ce4c38490dd0882d7918ac85f9e658c2b1ae43ab1205e9ad7dd5b260fd6ba0f5b9b3ce75013034b39813614c2e79a92fac9b1e1dac7d108f806263eb01";
            let sig2 = x"6e54f3c1b5369b0c3e6032d6122037c3cb472faa27e11f1804f3d5b9bb42e325aa47cd172dbb28e3ec2ead69a5b29df43fd752643cf300e7822bb725e99fd10c";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(&clock, &config, &mut vault, 1, 1, 1_000000000, BOB, signatures, b"aaaa", scenario_mut.ctx());

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

            let msg1 = active_vault::keccak_message<SUI_TEST>(1, 1, ALICE, 1_000000000, BOB, b"aaaa");

            let (deposit_enable, withdraw_enable, max_vault_balance, deposit_minimum_balance, withdraw_minimum_balance, order_id_counter, used_hashes, deposit_order_ids, used_order_ids, withdraw_security_period) = active_vault::get_vault_config<SUI_TEST>(&vault);
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

    
        // withdraw after 1 day
        test_scenario::next_tx(scenario_mut, ALICE);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let mut clock = clock::create_for_testing(scenario_mut.ctx());
            clock.increment_for_testing(86400 * 1000);

            let msg1 = active_vault::keccak_message<SUI_TEST>(2, 86400 * 1000 + 1, ALICE, 1_000000000, BOB, b"aaaa");
            std::debug::print(&msg1);
            // 0xdc9635e7a6a56898c3498fdf377b084b4d5870676ba3131eb26fb02c5a1a63b6

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 = x"933d04ecd789c582b7e1bd02d18b83b01a6b4ec030d0c250807e4babfba4170fac4f4513ffda4a4ee3e43daa5d8ceed119c1d0e8b073f626f05874cd4556d601";
            let sig2 = x"f0c40b9cb283f92f0d38ab1e69d946c88f104ab290afb062ef70d874ec53633ad740d6c7dfaa9f6e501a43bb5de9a7efd8fb9548cb79c95820dc3d317e2ae306";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(&clock, &config, &mut vault, 2, 86400 * 1000 + 1, 1_000000000, BOB, signatures, b"aaaa", scenario_mut.ctx());

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        test_scenario::end(scenario);
    }

    #[test]
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
            let coin = coin::mint_for_testing<SUI_TEST>(100_000000000, test_scenario::ctx(scenario_mut));

            user_entry::deposit<SUI_TEST>(&config, &mut vault, &mut secure_vault, coin, 100_000000000, scenario_mut.ctx());

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        // set security period
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            dvault_manage::add_security_period<SUI_TEST>(&cap, &mut vault, &config, 86400 * 1000, 1_000000000, scenario_mut.ctx());
            scenario_mut.return_to_sender(cap);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
        };

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let config = test_scenario::take_shared<Config>(scenario_mut);
            dvault_manage::add_security_period<SUI_TEST>(&cap, &mut vault, &config, 864000 * 1000, 10_000000000, scenario_mut.ctx());
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

            let msg1 = active_vault::keccak_message<SUI_TEST>(1, 1, ALICE, 1_000000000, BOB, b"aaaa");
            std::debug::print(&msg1);
            // 0x39fae67be485475f6ce184f43d96af402b5b3eb9c237a3b76ab6606f7fb9c256

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 = x"916db9ce4c38490dd0882d7918ac85f9e658c2b1ae43ab1205e9ad7dd5b260fd6ba0f5b9b3ce75013034b39813614c2e79a92fac9b1e1dac7d108f806263eb01";
            let sig2 = x"6e54f3c1b5369b0c3e6032d6122037c3cb472faa27e11f1804f3d5b9bb42e325aa47cd172dbb28e3ec2ead69a5b29df43fd752643cf300e7822bb725e99fd10c";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(&clock, &config, &mut vault, 1, 1, 1_000000000, BOB, signatures, b"aaaa", scenario_mut.ctx());

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

            let msg1 = active_vault::keccak_message<SUI_TEST>(2, 86400 * 1000 + 1, ALICE, 1_000000000, BOB, b"aaaa");
            std::debug::print(&msg1);
            // 0xdc9635e7a6a56898c3498fdf377b084b4d5870676ba3131eb26fb02c5a1a63b6

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 = x"933d04ecd789c582b7e1bd02d18b83b01a6b4ec030d0c250807e4babfba4170fac4f4513ffda4a4ee3e43daa5d8ceed119c1d0e8b073f626f05874cd4556d601";
            let sig2 = x"f0c40b9cb283f92f0d38ab1e69d946c88f104ab290afb062ef70d874ec53633ad740d6c7dfaa9f6e501a43bb5de9a7efd8fb9548cb79c95820dc3d317e2ae306";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(&clock, &config, &mut vault, 2, 86400 * 1000 + 1, 1_000000000, BOB, signatures, b"aaaa", scenario_mut.ctx());

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };

        // check state
        test_scenario::next_tx(scenario_mut, BOB);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            
            let (enable, duration, limit, period_amount) = active_vault::get_security_period<SUI_TEST>(&vault, 0);
            assert!(enable == true);
            assert!(duration == 86400 * 1000);
            assert!(limit == 1_000000000);
            assert!(period_amount.borrow(0) == 1_000000000);
            assert!(period_amount.borrow(1) == 1_000000000);
            assert!(period_amount.contains(2) == false);

            let (enable, duration, limit, period_amount) = active_vault::get_security_period<SUI_TEST>(&vault, 1);
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
    #[expected_failure(abort_code = active_vault::EWITHDRAWAL_AMOUNT_OVERFLOW, location = active_vault)]
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
            let coin = coin::mint_for_testing<SUI_TEST>(100_000000000, test_scenario::ctx(scenario_mut));

            user_entry::deposit<SUI_TEST>(&config, &mut vault, &mut secure_vault, coin, 100_000000000, scenario_mut.ctx());

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
            dvault_manage::add_security_period<SUI_TEST>(&cap, &mut vault, &config, 86400 * 1000, 1_000000000, scenario_mut.ctx());
            scenario_mut.return_to_sender(cap);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
        };

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let cap = test_scenario::take_from_sender<DvaultOwnerCap>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let config = test_scenario::take_shared<Config>(scenario_mut);
            dvault_manage::add_security_period<SUI_TEST>(&cap, &mut vault, &config, 86400 * 2000, 1_500000000, scenario_mut.ctx());
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

            let msg1 = active_vault::keccak_message<SUI_TEST>(1, 1, ALICE, 1_000000000, BOB, b"aaaa");
            std::debug::print(&msg1);
            // 0x39fae67be485475f6ce184f43d96af402b5b3eb9c237a3b76ab6606f7fb9c256

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 = x"916db9ce4c38490dd0882d7918ac85f9e658c2b1ae43ab1205e9ad7dd5b260fd6ba0f5b9b3ce75013034b39813614c2e79a92fac9b1e1dac7d108f806263eb01";
            let sig2 = x"6e54f3c1b5369b0c3e6032d6122037c3cb472faa27e11f1804f3d5b9bb42e325aa47cd172dbb28e3ec2ead69a5b29df43fd752643cf300e7822bb725e99fd10c";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(&clock, &config, &mut vault, 1, 1, 1_000000000, BOB, signatures, b"aaaa", scenario_mut.ctx());

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

            let msg1 = active_vault::keccak_message<SUI_TEST>(2, 86400 * 1000 + 1, ALICE, 1_000000000, BOB, b"aaaa");
            std::debug::print(&msg1);
            // 0xdc9635e7a6a56898c3498fdf377b084b4d5870676ba3131eb26fb02c5a1a63b6

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 = x"933d04ecd789c582b7e1bd02d18b83b01a6b4ec030d0c250807e4babfba4170fac4f4513ffda4a4ee3e43daa5d8ceed119c1d0e8b073f626f05874cd4556d601";
            let sig2 = x"f0c40b9cb283f92f0d38ab1e69d946c88f104ab290afb062ef70d874ec53633ad740d6c7dfaa9f6e501a43bb5de9a7efd8fb9548cb79c95820dc3d317e2ae306";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(&clock, &config, &mut vault, 2, 86400 * 1000 + 1, 1_000000000, BOB, signatures, b"aaaa", scenario_mut.ctx());

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = active_vault::EWITHDRAWAL_AMOUNT_OVERFLOW, location = active_vault)]
    public fun test_fail_withdraw_exceed_security_period() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

        // deposit
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);
            let coin = coin::mint_for_testing<SUI_TEST>(100_000000000, test_scenario::ctx(scenario_mut));

            user_entry::deposit<SUI_TEST>(&config, &mut vault, &mut secure_vault, coin, 100_000000000, scenario_mut.ctx());

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
            dvault_manage::add_security_period<SUI_TEST>(&cap, &mut vault, &config, 86400 * 100, 1_000000000, scenario_mut.ctx());
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

            let msg1 = active_vault::keccak_message<SUI_TEST>(1, 1, ALICE, 1_000000000, BOB, b"aaaa");
            std::debug::print(&msg1);
            // 0x39fae67be485475f6ce184f43d96af402b5b3eb9c237a3b76ab6606f7fb9c256

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 = x"916db9ce4c38490dd0882d7918ac85f9e658c2b1ae43ab1205e9ad7dd5b260fd6ba0f5b9b3ce75013034b39813614c2e79a92fac9b1e1dac7d108f806263eb01";
            let sig2 = x"6e54f3c1b5369b0c3e6032d6122037c3cb472faa27e11f1804f3d5b9bb42e325aa47cd172dbb28e3ec2ead69a5b29df43fd752643cf300e7822bb725e99fd10c";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(&clock, &config, &mut vault, 1, 1, 1_000000000, BOB, signatures, b"aaaa", scenario_mut.ctx());

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
    
        // withdraw again
        test_scenario::next_tx(scenario_mut, ALICE);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let clock = clock::create_for_testing(scenario_mut.ctx());

            let msg1 = active_vault::keccak_message<SUI_TEST>(2, 86400 * 1000 + 1, ALICE, 1_000000000, BOB, b"aaaa");
            std::debug::print(&msg1);
            // 0xdc9635e7a6a56898c3498fdf377b084b4d5870676ba3131eb26fb02c5a1a63b6

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 = x"933d04ecd789c582b7e1bd02d18b83b01a6b4ec030d0c250807e4babfba4170fac4f4513ffda4a4ee3e43daa5d8ceed119c1d0e8b073f626f05874cd4556d601";
            let sig2 = x"f0c40b9cb283f92f0d38ab1e69d946c88f104ab290afb062ef70d874ec53633ad740d6c7dfaa9f6e501a43bb5de9a7efd8fb9548cb79c95820dc3d317e2ae306";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(&clock, &config, &mut vault, 2, 86400 * 1000 + 1, 1_000000000, BOB, signatures, b"aaaa", scenario_mut.ctx());

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
    // set minimum deposit amount to 1 SUI
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
            let coin = coin::mint_for_testing<SUI_TEST>(1_000000000 - 1, test_scenario::ctx(scenario_mut));

            user_entry::deposit<SUI_TEST>(&config, &mut vault, &mut secure_vault, coin, 1_000000000 - 1, scenario_mut.ctx());

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = active_vault::EWITHDRAW_AMOUNT_TOO_LOW, location = active_vault)]
    // set minimum withdraw amount to 1 SUI
    public fun test_set_min_withdraw() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);

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

        // withdraw
        test_scenario::next_tx(scenario_mut, ALICE);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let clock = clock::create_for_testing(scenario_mut.ctx());

            let msg1 = active_vault::keccak_message<SUI_TEST>(1, 1, ALICE, 1_000000000, BOB, b"aaaa");
            std::debug::print(&msg1);
            // 0x39fae67be485475f6ce184f43d96af402b5b3eb9c237a3b76ab6606f7fb9c256

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 = x"916db9ce4c38490dd0882d7918ac85f9e658c2b1ae43ab1205e9ad7dd5b260fd6ba0f5b9b3ce75013034b39813614c2e79a92fac9b1e1dac7d108f806263eb01";
            let sig2 = x"6e54f3c1b5369b0c3e6032d6122037c3cb472faa27e11f1804f3d5b9bb42e325aa47cd172dbb28e3ec2ead69a5b29df43fd752643cf300e7822bb725e99fd10c";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(&clock, &config, &mut vault, 1, 1, 1_000000000 - 1, BOB, signatures, b"aaaa", scenario_mut.ctx());

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        test_scenario::end(scenario);
    }

    #[test]
    // set max vault balance to 4 SUI
    // deposit 2sui, 2sui and 4sui
    // final balance should be 4sui in active vault and 4sui in secure vault
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
            let coin = coin::mint_for_testing<SUI_TEST>(2_000000000, test_scenario::ctx(scenario_mut));
            user_entry::deposit<SUI_TEST>(&config, &mut vault, &mut secure_vault, coin, 2_000000000, scenario_mut.ctx());

            let coin = coin::mint_for_testing<SUI_TEST>(2_000000000, test_scenario::ctx(scenario_mut));
            user_entry::deposit<SUI_TEST>(&config, &mut vault, &mut secure_vault, coin, 2_000000000, scenario_mut.ctx());

            let coin = coin::mint_for_testing<SUI_TEST>(4_000000000, test_scenario::ctx(scenario_mut));
            user_entry::deposit<SUI_TEST>(&config, &mut vault, &mut secure_vault, coin, 4_000000000, scenario_mut.ctx());

            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);

            let (deposit_enable, withdraw_enable, max_vault_balance, deposit_minimum_balance, withdraw_minimum_balance, order_id_counter, used_hashes, deposit_order_ids, used_order_ids, withdraw_security_period) = active_vault::get_vault_config<SUI_TEST>(&vault);
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
    public fun test_withdraw_fail_if_signer_not_enough() {
        let mut scenario = test_scenario::begin(OWNER);
        let scenario_mut = &mut scenario;
        init_dvault(scenario_mut);
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
            dvault_manage::set_minimum_withdraw<SUI_TEST>(&cap, &mut vault, &config, 1_000000000);

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(cap);
        };

        // withdraw
        test_scenario::next_tx(scenario_mut, ALICE);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let clock = clock::create_for_testing(scenario_mut.ctx());

            let msg1 = active_vault::keccak_message<SUI_TEST>(1, 1, ALICE, 1_000000000, BOB, b"aaaa");
            std::debug::print(&msg1);
            // 0x39fae67be485475f6ce184f43d96af402b5b3eb9c237a3b76ab6606f7fb9c256

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 = x"916db9ce4c38490dd0882d7918ac85f9e658c2b1ae43ab1205e9ad7dd5b260fd6ba0f5b9b3ce75013034b39813614c2e79a92fac9b1e1dac7d108f806263eb01";
            let sig2 = x"6e54f3c1b5369b0c3e6032d6122037c3cb472faa27e11f1804f3d5b9bb42e325aa47cd172dbb28e3ec2ead69a5b29df43fd752643cf300e7822bb725e99fd10c";
            signatures.push_back(sig1);
            signatures.push_back(sig2);

            // fail -> assert!(signatures.length() >= config.threshold, EINVALID_SIGNATURES);
            user_entry::withdraw(&clock, &config, &mut vault, 1, 1, 1_000000000 - 1, BOB, signatures, b"aaaa", scenario_mut.ctx());

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = active_vault::ETRANSACTION_HASH_ALREADY_USED, location = active_vault)]
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
            let coin = coin::mint_for_testing<SUI_TEST>(100_000000000, test_scenario::ctx(scenario_mut));

            user_entry::deposit<SUI_TEST>(&config, &mut vault, &mut secure_vault, coin, 100_000000000, scenario_mut.ctx());

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

            let msg1 = active_vault::keccak_message<SUI_TEST>(1, 1, ALICE, 1_000000000, BOB, b"aaaa");
            std::debug::print(&msg1);
            // 0x39fae67be485475f6ce184f43d96af402b5b3eb9c237a3b76ab6606f7fb9c256

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 = x"916db9ce4c38490dd0882d7918ac85f9e658c2b1ae43ab1205e9ad7dd5b260fd6ba0f5b9b3ce75013034b39813614c2e79a92fac9b1e1dac7d108f806263eb01";
            let sig2 = x"6e54f3c1b5369b0c3e6032d6122037c3cb472faa27e11f1804f3d5b9bb42e325aa47cd172dbb28e3ec2ead69a5b29df43fd752643cf300e7822bb725e99fd10c";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(&clock, &config, &mut vault, 1, 1, 1_000000000, BOB, signatures, b"aaaa", scenario_mut.ctx());

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

            let msg1 = active_vault::keccak_message<SUI_TEST>(1, 1, ALICE, 1_000000000, BOB, b"aaaa");
            std::debug::print(&msg1);
            // 0x39fae67be485475f6ce184f43d96af402b5b3eb9c237a3b76ab6606f7fb9c256

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 = x"916db9ce4c38490dd0882d7918ac85f9e658c2b1ae43ab1205e9ad7dd5b260fd6ba0f5b9b3ce75013034b39813614c2e79a92fac9b1e1dac7d108f806263eb01";
            let sig2 = x"6e54f3c1b5369b0c3e6032d6122037c3cb472faa27e11f1804f3d5b9bb42e325aa47cd172dbb28e3ec2ead69a5b29df43fd752643cf300e7822bb725e99fd10c";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(&clock, &config, &mut vault, 1, 1, 1_000000000, BOB, signatures, b"aaaa", scenario_mut.ctx());

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = active_vault::EORDER_ID_ALREADY_USED, location = active_vault)]
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
            let coin = coin::mint_for_testing<SUI_TEST>(100_000000000, test_scenario::ctx(scenario_mut));

            user_entry::deposit<SUI_TEST>(&config, &mut vault, &mut secure_vault, coin, 100_000000000, scenario_mut.ctx());

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

            let msg1 = active_vault::keccak_message<SUI_TEST>(1, 1, ALICE, 1_000000000, BOB, b"aaaa");
            std::debug::print(&msg1);
            // 0x39fae67be485475f6ce184f43d96af402b5b3eb9c237a3b76ab6606f7fb9c256

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 = x"916db9ce4c38490dd0882d7918ac85f9e658c2b1ae43ab1205e9ad7dd5b260fd6ba0f5b9b3ce75013034b39813614c2e79a92fac9b1e1dac7d108f806263eb01";
            let sig2 = x"6e54f3c1b5369b0c3e6032d6122037c3cb472faa27e11f1804f3d5b9bb42e325aa47cd172dbb28e3ec2ead69a5b29df43fd752643cf300e7822bb725e99fd10c";
            signatures.push_back(sig1);
            signatures.push_back(sig2);
            user_entry::withdraw(&clock, &config, &mut vault, 1, 1, 1_000000000, BOB, signatures, b"aaaa", scenario_mut.ctx());

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

            let msg1 = active_vault::keccak_message<SUI_TEST>(1, 2, ALICE, 1_000000000, BOB, b"aaaa");
            std::debug::print(&msg1);

            let mut signatures = vector::empty<vector<u8>>();

            let sig1 = x"916db9ce4c38490dd0882d7918ac85f9e658c2b1ae43ab1205e9ad7dd5b260fd6ba0f5b9b3ce75013034b39813614c2e79a92fac9b1e1dac7d108f806263eb01";
            let sig2 = x"6e54f3c1b5369b0c3e6032d6122037c3cb472faa27e11f1804f3d5b9bb42e325aa47cd172dbb28e3ec2ead69a5b29df43fd752643cf300e7822bb725e99fd10c";
            signatures.push_back(sig1);
            signatures.push_back(sig2);

            // same order_id, same order_time
            user_entry::withdraw(&clock, &config, &mut vault, 1, 2, 1_000000000, BOB, signatures, b"aaaa", scenario_mut.ctx());

            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
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

        // deposit 100sui
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);
            let coin = coin::mint_for_testing<SUI_TEST>(100_000000000, test_scenario::ctx(scenario_mut));
            user_entry::deposit<SUI_TEST>(&config, &mut vault, &mut secure_vault, coin, 100_000000000, scenario_mut.ctx());
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
            let cap = test_scenario::take_from_sender<SecureOperatorCap>(scenario_mut);
            dvault_manage::operator_withdraw_secure_vault(&cap, &config, &mut vault, &mut secure_vault, 100_000000000, scenario_mut.ctx());
            scenario_mut.return_to_sender(cap);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        // check balance
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let (deposit_enable, withdraw_enable, max_vault_balance, deposit_minimum_balance, withdraw_minimum_balance, order_id_counter, used_hashes, deposit_order_ids, used_order_ids, withdraw_security_period) = active_vault::get_vault_config<SUI_TEST>(&vault);
            assert!(vault.balance_value() == 100_000000000, 0);
            assert!(max_vault_balance == 1_000000000, 0);
            test_scenario::return_shared(vault);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = secure_vault::EOPERATOR_DISABLED, location = secure_vault)]
    public fun test_fail_disable_operator_withdraw_secure_vault() {
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
            let coin = coin::mint_for_testing<SUI_TEST>(100_000000000, test_scenario::ctx(scenario_mut));
            user_entry::deposit<SUI_TEST>(&config, &mut vault, &mut secure_vault, coin, 100_000000000, scenario_mut.ctx());
            test_scenario::return_shared(vault);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);
            let operator_cap = test_scenario::take_from_sender<SecureOperatorCap>(scenario_mut);
            let admin_cap = test_scenario::take_from_sender<SecureOwnerCap>(scenario_mut);
            secure_vault.set_disable_operator<SUI_TEST>( &admin_cap, operator_cap.cap_to_address(), true);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(operator_cap);
            scenario_mut.return_to_sender(admin_cap);
        };

        // withdraw
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);
            let mut vault = test_scenario::take_shared<ActiveVault<SUI_TEST>>(scenario_mut);
            let cap = test_scenario::take_from_sender<SecureOperatorCap>(scenario_mut);
            dvault_manage::operator_withdraw_secure_vault(&cap, &config, &mut vault, &mut secure_vault, 1_0000000000 - 1, scenario_mut.ctx());
            scenario_mut.return_to_sender(cap);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
        };


        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = secure_vault::EWITHDRAW_AMOUNT_TOO_HIGH_IN_EPOCH, location = secure_vault)]
    public fun test_fail_limit_operator_withdraw_secure_vault() {
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
            let coin = coin::mint_for_testing<SUI_TEST>(100_000000000, test_scenario::ctx(scenario_mut));
            user_entry::deposit<SUI_TEST>(&config, &mut vault, &mut secure_vault, coin, 100_000000000, scenario_mut.ctx());
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
            secure_vault.set_operator_epoch_max_amount<SUI_TEST>( &admin_cap, 1_000000000);
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

            dvault_manage::operator_withdraw_secure_vault(&cap, &config, &mut vault, &mut secure_vault, 1_0000000000 - 1, scenario_mut.ctx());

            scenario_mut.return_to_sender(cap);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(config);
        };


        test_scenario::end(scenario);
    }

    #[test]
    public fun test_owner_withdraw_secure_vault() {
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
            let coin = coin::mint_for_testing<SUI_TEST>(100_000000000, test_scenario::ctx(scenario_mut));
            user_entry::deposit<SUI_TEST>(&config, &mut vault, &mut secure_vault, coin, 100_000000000, scenario_mut.ctx());
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
            secure_vault.set_operator_epoch_max_amount<SUI_TEST>( &admin_cap, 1_000000000);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
            scenario_mut.return_to_sender(operator_cap);
            scenario_mut.return_to_sender(admin_cap);
        };

        // withdraw
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let config = test_scenario::take_shared<Config>(scenario_mut);
            let mut secure_vault = test_scenario::take_shared<SecureVault<SUI_TEST>>(scenario_mut);
            let cap = test_scenario::take_from_sender<SecureOwnerCap>(scenario_mut);
            let _balance = secure_vault.admin_withdraw_secure_vault<SUI_TEST>(&cap, 100_000000000);
            transfer::public_transfer(_balance.into_coin(scenario_mut.ctx()), OWNER);
            scenario_mut.return_to_sender(cap);
            test_scenario::return_shared(secure_vault);
            test_scenario::return_shared(config);
        };

        // check balance
        test_scenario::next_tx(scenario_mut, OWNER);
        {
            let coin = test_scenario::take_from_sender<Coin<SUI_TEST>>(scenario_mut);
            assert!(coin.value() == 100_000000000, 0);
            scenario_mut.return_to_sender(coin);
        };

        test_scenario::end(scenario);
    }
}