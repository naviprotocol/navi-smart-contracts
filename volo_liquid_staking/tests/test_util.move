#[test_only]
#[allow(unused_use, unused_field)]
module liquid_staking::test_util {

    use liquid_staking::cert::{Self, CERT, Metadata};
    use std::ascii::{Self, String};
    use std::string::{Self};
    use liquid_staking::stake_pool::{Self, StakePool, AdminCap, OperatorCap};
    use liquid_staking::fee_config::{Self, FeeConfig};
    use sui::test_scenario::{Self, Scenario, next_tx, ctx, return_shared};
    use sui::test_utils;
    use sui::coin::{Self};
    use sui::vec_map::{Self, VecMap};
    use sui::sui::{SUI};
    use sui::balance;
    use sui::clock::{Self, Clock};
    use std::type_name::{Self};
    use sui::balance::{Supply, Balance};
    use sui_system::sui_system::{SuiSystemState};

    use sui::coin::{CoinMetadata, Coin, TreasuryCap};
        use sui_system::governance_test_utils::{
        // Self,
        // add_validator,
        // add_validator_candidate,
        advance_epoch,
        advance_epoch_with_reward_amounts as inner_advance_epoch_with_reward_amounts,
        create_validator_for_testing,
        create_sui_system_state_for_testing,
        stake_plus_current_rewards_for_validator,
        // stake_with,
        // remove_validator,
        // remove_validator_candidate,
        // total_sui_balance,
        // unstake,
    };

    #[test_only]
    public struct Print has copy, drop {
        str: String,
        num: u64,
    }

    #[test_only]
    public struct PrintMap<K: copy + drop, V: copy + drop> has copy, drop {
        str: String,
        keys: vector<K>,
        values: vector<V>,
    }

    const DECIMALS: u64 = 1_000_000_000;

    const VALIDATOR_ADDR_1: address = @0x1;
    const VALIDATOR_ADDR_2: address = @0x2;
    const VALIDATOR_ADDR_3: address = @0x3;
    const VALIDATOR_ADDR_4: address = @0x4;

    const OWNER: address = @0xA;
    const USER_INIT: address = @0xA;

    #[test_only]
    public fun init_protocol(scenario_mut: &mut Scenario) {
        print_raw(&ascii::string(b"------------------Test Start---------------------"));

        set_up_sui_system_state(scenario_mut);
        advance_epoch(scenario_mut);
        // Protocol init
        next_tx(scenario_mut, OWNER);
        {
            cert::test_init(ctx(scenario_mut));
            stake_pool::init_for_testing(ctx(scenario_mut));
        };

        // create lst
        // next_tx(scenario_mut, OWNER);
        // {
        //     let metadata = scenario_mut.take_from_sender<Metadata<CERT>>();
        //     let owner_cap = scenario_mut.take_from_sender<OwnerCapV1>();

        //     // stake_pool::create_lst(&metadata, &owner_cap, ctx(scenario_mut));
        //     scenario_mut.return_to_sender(owner_cap);
        //     scenario.return_to_sender(metadata);
        // };

        // unpause the pool
        next_tx(scenario_mut, OWNER);
        {
            let mut pool = scenario_mut.take_from_sender<StakePool>();
            let admin = scenario_mut.take_from_sender<AdminCap>();
            pool.set_paused(&admin, false);
            transfer::public_transfer(admin, OWNER);
            scenario_mut.return_to_sender(pool);
        };

        // mint operator
        next_tx(scenario_mut, OWNER);
        {
            let mut pool = scenario_mut.take_from_sender<StakePool>();
            let admin = scenario_mut.take_from_sender<AdminCap>();
            pool.mint_operator_cap(&admin, OWNER, ctx(scenario_mut));
            transfer::public_transfer(admin, OWNER);
            scenario_mut.return_to_sender(pool);
        };

        // stake 100 sui to initialize the validator weights
        stake(scenario_mut, 100 * DECIMALS, USER_INIT);

        // set validator weigth
        next_tx(scenario_mut, OWNER);
        {
            let mut pool = scenario_mut.take_from_sender<StakePool>();
            let operator = scenario_mut.take_from_sender<OperatorCap>();
            let mut system_state = test_scenario::take_shared<SuiSystemState>(scenario_mut);
            let mut metadata = scenario_mut.take_from_sender<Metadata<CERT>>();
            let mut validator_weights = vec_map::empty<address, u64>();
            validator_weights.insert(VALIDATOR_ADDR_1, 1);
            validator_weights.insert(VALIDATOR_ADDR_2, 2);
            validator_weights.insert(VALIDATOR_ADDR_3, 3);
            validator_weights.insert(VALIDATOR_ADDR_4, 4);

            pool.set_validator_weights(&mut metadata, &mut system_state, &operator, validator_weights, ctx(scenario_mut));
            transfer::public_transfer(operator, OWNER);
            // transfer::public_share_object(metadata);
            scenario_mut.return_to_sender(pool);
            scenario_mut.return_to_sender(metadata);
            return_shared(system_state);
        };
    }

    fun set_up_sui_system_state(scenario: &mut Scenario) {
        next_tx(scenario, @0x0);
        {
            let ctx = ctx(scenario);
            let validators = vector[
                create_validator_for_testing(VALIDATOR_ADDR_1, 100, ctx),
                create_validator_for_testing(VALIDATOR_ADDR_2, 100, ctx),
                create_validator_for_testing(VALIDATOR_ADDR_3, 100, ctx),
                create_validator_for_testing(VALIDATOR_ADDR_4, 100, ctx),
            ];
            create_sui_system_state_for_testing(validators, 0, 0, ctx);
        }
    }

    public fun stake(scenario: &mut Scenario, amount: u64, sender: address): u64 {
        let ret;
        next_tx(scenario, sender);
        {
            let mut metadata = scenario.take_from_sender<Metadata<CERT>>();
            let mut pool = scenario.take_from_sender<StakePool>();
            let mut system_state = test_scenario::take_shared<SuiSystemState>(scenario);

            let sui = coin::mint_for_testing<SUI>(amount, ctx(scenario)); 

            let vsui = pool.stake(&mut metadata, &mut system_state, sui, ctx(scenario));
            ret = vsui.value();
            transfer::public_transfer(vsui, sender);

            scenario.return_to_sender(metadata);
            scenario.return_to_sender(pool);
            return_shared(system_state);
        };
        ret
    }

    public fun unstake(scenario: &mut Scenario, amount: u64, sender: address): u64 {
        let ret;
        next_tx(scenario, sender);
        {
            let mut metadata = scenario.take_from_sender<Metadata<CERT>>();
            let mut pool = scenario.take_from_sender<StakePool>();
            let mut system_state = test_scenario::take_shared<SuiSystemState>(scenario);

            let mut vsui = get_coin<CERT>(scenario);
            let input_vsui = vsui.split(amount, ctx(scenario));

            let sui = pool.unstake(&mut metadata, &mut system_state, input_vsui, ctx(scenario));
            ret = sui.value();

            transfer::public_transfer(vsui, sender);
            transfer::public_transfer(sui, sender);

            scenario.return_to_sender(metadata);
            scenario.return_to_sender(pool);
            return_shared(system_state);
        };
        ret
    }

    public fun rebalance(scenario: &mut Scenario, sender: address) {
        next_tx(scenario, sender);
        {
            let mut pool = scenario.take_from_sender<StakePool>();
            let mut system_state = test_scenario::take_shared<SuiSystemState>(scenario);
            let mut metadata = scenario.take_from_sender<Metadata<CERT>>();

            pool.rebalance(&mut metadata, &mut system_state, ctx(scenario));

            scenario.return_to_sender(pool);
            scenario.return_to_sender(metadata);
            return_shared(system_state);
        };
    }

    public fun refresh(scenario: &mut Scenario, sender: address) {
        next_tx(scenario, sender);
        {
            let mut pool = scenario.take_from_sender<StakePool>();
            let mut metadata = scenario.take_from_sender<Metadata<CERT>>();
            let mut system_state = test_scenario::take_shared<SuiSystemState>(scenario);

            pool.refresh(&mut metadata, &mut system_state, ctx(scenario));

            scenario.return_to_sender(pool);
            scenario.return_to_sender(metadata);
            return_shared(system_state);
        };
    }

    public fun get_coin<T>(scenario: &mut Scenario): Coin<T> {
        let mut has_next = scenario.has_most_recent_for_sender<Coin<T>>();
        let mut coin = coin::zero<T>(ctx(scenario));
        while (has_next) {
            coin.join(scenario.take_from_sender<Coin<T>>());
            has_next = scenario.has_most_recent_for_sender<Coin<T>>();
        };
        coin
    }

    public fun get_coin_amount<T>(scenario: &mut Scenario, sender: address): u64 {
        next_tx(scenario, sender);
        {
            let coin = get_coin<T>(scenario);
            let x = coin.value();
            transfer::public_transfer(coin, scenario.ctx().sender());
            x
        }
    }

    public fun print(str: vector<u8>, num: u64) {
        let print = Print { str: ascii::string(str), num: num };
        std::debug::print(&print);
    }

    public fun print_raw<T>(x: &T) {
        std::debug::print(x);
    }

    public fun check_status(scenario: &mut Scenario) {

        let mut _keys = vector::empty<address>();
        let mut _values = vector::empty<u64>();
        next_tx(scenario, OWNER);
        {
            let pool = scenario.take_from_sender<StakePool>();
            let (inactive, active) = pool.validator_pool().validator_stake_amounts();
            let(_, inactive_value) = inactive.into_keys_values();
            let(keys, active_value) = active.into_keys_values();
            _keys.append(keys);
            let mut sum = 0;
            sum = sum + pool.validator_pool().sui_pool().value();
            inactive_value.do_ref!(|v| sum = sum + *v);
            active_value.do_ref!(|v| sum = sum + *v);

            _keys.do_ref!(|key| {
                _values.push_back(*active.get(key) + *inactive.get(key));
            });

            assert!(sum.diff(pool.validator_pool().total_sui_supply()) < 5, sum.diff(pool.validator_pool().total_sui_supply()));
            scenario.return_to_sender(pool);
        };
    }

    public fun print_status(scenario: &mut Scenario) {

        let mut begin = string::utf8(b"----data epoch ");
        begin.append(ctx(scenario).epoch().to_string());
        begin.append(string::utf8(b"----"));
        print_raw(&begin);

        next_tx(scenario, OWNER);
        {
            let pool = scenario.take_from_sender<StakePool>();
            let weights = pool.validator_pool().validator_weights();
            let (inactive, active) = pool.validator_pool().validator_stake_amounts();

            pretty_print(b"weights", &weights);
            pretty_print(b"inactive", &inactive);
            pretty_print(b"active", &active);
            print(b"sui pool", pool.validator_pool().sui_pool().value());
            print(b"total sui supply", pool.validator_pool().total_sui_supply());
            scenario.return_to_sender(pool);
        };

        let mut end = string::utf8(b"----data epoch ");
        end.append(ctx(scenario).epoch().to_string());
        end.append(string::utf8(b" end ----"));
        print_raw(&end);
    }

    public fun pretty_print<K: copy + drop, V: copy + drop>(str: vector<u8>, map: &VecMap<K, V>) {
        let mut keys = map.keys();
        let mut values = vector::empty<V>();
        keys.do_ref!(|key| {
            values.push_back(*map.get(key));
        });
        let print = PrintMap { str: ascii::string(str), keys: keys, values: values };
        std::debug::print(&print);
    }

    public fun advance_epoch_and_check_status(scenario: &mut Scenario) {
        advance_epoch(scenario);
        check_status(scenario);
    }

    public fun advance_epoch_with_reward_amounts(storage_reward: u64, computation_reward: u64, scenario: &mut Scenario) {
        inner_advance_epoch_with_reward_amounts(storage_reward, computation_reward, scenario);
        check_status(scenario);
    }

    public fun assert_validator_non_self_stake_amounts(validator_addrs: vector<address>, stake_amounts: vector<u64>, scenario: &mut Scenario) {
        let mut i = 0;
        while (i < validator_addrs.length()) {
            let validator_addr = validator_addrs[i];
            let amount = stake_amounts[i];
            scenario.next_tx(validator_addr);
            let mut system_state = scenario.take_shared<SuiSystemState>();
            let non_self_stake_amount = system_state.validator_stake_amount(validator_addr) - stake_plus_current_rewards_for_validator(validator_addr, &mut system_state, scenario);
            print(b"non_self_stake_amount", non_self_stake_amount);
            print(b"amount", amount);
            assert!(non_self_stake_amount.diff(amount) < 5, 0);
            test_scenario::return_shared(system_state);
            i = i + 1;
        };
    }

    // assert that last user can unstake
    public fun end_test(mut scenario: Scenario) {
        // print_status(&mut scenario);
        // check_status(&mut scenario);
        // rebalance(&mut scenario, OWNER);
        // print_status(&mut scenario);
        // check_status(&mut scenario);
        next_tx(&mut scenario, OWNER);
        {
            let mut pool = scenario.take_from_sender<StakePool>();
            let mut system_state = test_scenario::take_shared<SuiSystemState>(&mut scenario);
            let mut metadata = scenario.take_from_sender<Metadata<CERT>>();
            // pool.refresh(&mut metadata, &mut system_state, ctx(&mut scenario));
            // pool.mut_validator_pool().check_all_validators_rate(&mut system_state, ctx(&mut scenario));
            test_scenario::return_shared(system_state);
            scenario.return_to_sender(metadata);
            scenario.return_to_sender(pool);
        };

        next_tx(&mut scenario, OWNER);
        {
            let mut pool = scenario.take_from_sender<StakePool>();
            let admin_cap = scenario.take_from_sender<AdminCap>();
            let mut metadata = scenario.take_from_sender<Metadata<CERT>>();
            let mut system_state = scenario.take_shared<SuiSystemState>();
            let coin = pool.collect_fees(&mut metadata, &mut system_state, &admin_cap, scenario.ctx());
            print(b"reward fee", coin.value());
            coin.burn_for_testing();
            scenario.return_to_sender(admin_cap);
            scenario.return_to_sender(pool);
            scenario.return_to_sender(metadata);
            return_shared(system_state);
        };

        print_raw(&ascii::string(b"test end status"));
        print_status(&mut scenario);
        let amount = unstake(&mut scenario, 100 * DECIMALS, USER_INIT);
        // max 5% unstaking fee
        assert!(amount >= 95 * DECIMALS, 0);
        print(b"final unstake amount", amount);

        test_scenario::end(scenario);
    }

    public fun end_test_with_pool_empty(mut scenario: Scenario) {
        next_tx(&mut scenario, OWNER);
        {
            let mut pool = scenario.take_from_sender<StakePool>();
            let mut system_state = test_scenario::take_shared<SuiSystemState>(&mut scenario);
            let mut metadata = scenario.take_from_sender<Metadata<CERT>>();
            // pool.refresh(&mut metadata, &mut system_state, ctx(&mut scenario));
            // pool.mut_validator_pool().check_all_validators_rate(&mut system_state, ctx(&mut scenario));
            test_scenario::return_shared(system_state);
            scenario.return_to_sender(metadata);
            scenario.return_to_sender(pool);
        };

        next_tx(&mut scenario, OWNER);
        {
            let mut pool = scenario.take_from_sender<StakePool>();
            let admin_cap = scenario.take_from_sender<AdminCap>();
            let mut metadata = scenario.take_from_sender<Metadata<CERT>>();
            let mut system_state = scenario.take_shared<SuiSystemState>();
            let coin = pool.collect_fees(&mut metadata, &mut system_state, &admin_cap, scenario.ctx());
            print(b"reward fee", coin.value());
            coin.burn_for_testing();
            scenario.return_to_sender(admin_cap);
            scenario.return_to_sender(pool);
            scenario.return_to_sender(metadata);
            return_shared(system_state);
        };

        print_raw(&ascii::string(b"test end status"));
        print_status(&mut scenario);
        let amount = unstake(&mut scenario, 100 * DECIMALS, USER_INIT);
        // max 5% unstaking fee
        assert!(amount >= 95 * DECIMALS, 0);
        print(b"final unstake amount", amount);
        pool_empty_check(&mut scenario);
        test_scenario::end(scenario);
    }

    public fun pool_empty_check(scenario: &mut Scenario) {
        // check pool stake
        next_tx(scenario, OWNER);
        {
            let pool = scenario.take_from_sender<StakePool>();
            let metadata = scenario.take_from_sender<Metadata<CERT>>();
            let system_state = scenario.take_shared<SuiSystemState>();
            let total_stake = pool.validator_pool().total_sui_supply();
            assert!(total_stake == 0, total_stake);
            assert!(pool.get_ratio(&metadata) == 0, pool.get_ratio(&metadata));
            assert!(pool.validator_pool().sui_pool().value() == 0, 0);
            assert!(pool.validator_pool().total_sui_supply() == 0, 0);

            scenario.return_to_sender(pool);
            scenario.return_to_sender(metadata);
            return_shared(system_state);
        };
    }
}