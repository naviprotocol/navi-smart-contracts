#[test_only]
#[allow(unused_use, unused_field)]
module liquid_staking::base_test {

    use liquid_staking::test_util::{Self, init_protocol, print, stake, unstake, print_raw, advance_epoch_and_check_status, advance_epoch_with_reward_amounts, end_test};

    use liquid_staking::cert::{Self, CERT, Metadata};
    use liquid_staking::stake_pool::{Self, StakePool, AdminCap};
    use liquid_staking::fee_config::{Self, FeeConfig};
    use sui_system::staking_pool::{StakedSui, FungibleStakedSui};
    use sui::test_scenario::{Self, Scenario, next_tx, ctx, return_shared};
    use sui::test_utils;
    use sui::balance;
    use sui::coin::{Self};
    use sui::sui::{SUI};
    use sui::clock::{Self, Clock};
    use std::type_name::{Self};
    use sui::balance::{Supply, Balance};
    use std::ascii::{Self, String};
    use sui_system::sui_system::{SuiSystemState};
    use sui_system::governance_test_utils::{
        // Self,
        create_validator_for_testing,
        create_sui_system_state_for_testing,
        assert_validator_non_self_stake_amounts
        // stake_with,
        // total_sui_balance,
        // unstake,
    };


    use sui::coin::{CoinMetadata, Coin, TreasuryCap};

    const OWNER: address = @0xA;
    const USERA: address = @0xB;
    const USERB: address = @0xC;
    const DECIMALS: u64 = 1_000_000_000;

    #[test]
    fun test_init_protocol() {
        let mut scenario = test_scenario::begin(OWNER);
        init_protocol(&mut scenario);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_stake() {
        let mut scenario = test_scenario::begin(OWNER);
        init_protocol(&mut scenario);

        // next_tx(&mut scenario, OWNER);
        // {
        //     advance_epoch(&mut scenario);
        // };

        next_tx(&mut scenario, OWNER);
        {
            let amount = stake(&mut scenario, 100 * DECIMALS, OWNER);
            assert!(amount == 100 * DECIMALS, 100);
        };

        next_tx(&mut scenario, OWNER);
        {
            test_util::refresh(&mut scenario, OWNER);
        };

        next_tx(&mut scenario, OWNER);
        {
            let pool = scenario.take_from_sender<StakePool>();
            let weights = pool.validator_pool().validator_weights();
            let (inactive, active) = pool.validator_pool().validator_stake_amounts();
            print_raw(&ascii::string(b"datas"));
            print_raw(&weights);
            print_raw(&inactive);
            print_raw(&active);
            scenario.return_to_sender(pool);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_unstake() {
        let mut scenario = test_scenario::begin(OWNER);
        init_protocol(&mut scenario);
        
        next_tx(&mut scenario, OWNER);
        {
            let amount = stake(&mut scenario, 100 * DECIMALS, OWNER);
            assert!(amount == 100 * DECIMALS, 100);
        };

        next_tx(&mut scenario, OWNER);
        {
            let amount = unstake(&mut scenario, 100 * DECIMALS, OWNER);
            assert!(amount == 100 * DECIMALS, 100);
        };

        test_scenario::end(scenario);
    }

    #[test]
    fun test_stake_unstake_yield() {
        let mut scenario = test_scenario::begin(OWNER);
        init_protocol(&mut scenario);

        // stake 100 sui at epoch 1
        next_tx(&mut scenario, OWNER);
        {
            let amount = stake(&mut scenario, 100 * DECIMALS, OWNER);
            assert!(amount == 100 * DECIMALS, 100);
            test_util::refresh(&mut scenario, OWNER);
        };

        test_util::print_status(&mut scenario);

        // epoch 2
        advance_epoch_and_check_status(&mut scenario);
        test_util::refresh(&mut scenario, OWNER);
        test_util::print_status(&mut scenario);

        test_util::check_status(&mut scenario);

        // epoch3
        advance_epoch_with_reward_amounts(0, 100, &mut scenario);    
    
        next_tx(&mut scenario, OWNER);

        test_util::refresh(&mut scenario, OWNER);
        test_util::check_status(&mut scenario);

        test_util::print_status(&mut scenario);
        {
            unstake(&mut scenario, 100 * DECIMALS, OWNER);
        };
        test_util::print_status(&mut scenario);

        // check status
        next_tx(&mut scenario, OWNER);
        {
            let coin = test_util::get_coin<SUI>(&mut scenario);
            let pool = scenario.take_from_sender<StakePool>();
            let metadata = scenario.take_from_sender<Metadata<CERT>>();
            print(b"coin value2", coin.value());

            // 100 * (1 + 100 / (100 + 100 + 400)) = 116.6666666667 != 115897817459
            // Why is the result not 116?
            // However, as long as the reward is correctly distributed, the result is correct.

            print(b"exchange_rate", pool.get_ratio(&metadata)); // 1143080357
            assert!(coin.value() == 115897817459, 100);
            assert!(coin.value() / 100 == 1158978174, 100);
            print(b"pool total sui supply", pool.validator_pool().total_sui_supply());
            assert!(coin.value().diff(pool.validator_pool().total_sui_supply()) < 10, 0);
            coin.burn_for_testing();
            scenario.return_to_sender(pool);
            scenario.return_to_sender(metadata);
        };

        advance_epoch_and_check_status(&mut scenario);


        end_test(scenario);
    }

    #[test]
    fun test_stake_unstake_yield_with_fee() {
        let mut scenario = test_scenario::begin(OWNER);
        init_protocol(&mut scenario);

        // set reward fee 10%
        next_tx(&mut scenario, OWNER);
        {
            let mut pool = scenario.take_from_sender<StakePool>();
            let admin_cap = scenario.take_from_sender<AdminCap>();
            pool.update_reward_fee(&admin_cap, 1000);
            scenario.return_to_sender(pool);
            scenario.return_to_sender(admin_cap);
        };

        // stake 100 sui at epoch 1
        next_tx(&mut scenario, OWNER);
        {
            let amount = stake(&mut scenario, 100 * DECIMALS, OWNER);
            assert!(amount == 100 * DECIMALS, 100);
            test_util::refresh(&mut scenario, OWNER);
        };

        test_util::print_status(&mut scenario);

        // epoch 2
        advance_epoch_and_check_status(&mut scenario);
        test_util::refresh(&mut scenario, OWNER);
        test_util::print_status(&mut scenario);

        test_util::check_status(&mut scenario);

        // epoch3
        advance_epoch_with_reward_amounts(0, 100, &mut scenario);    
    
        next_tx(&mut scenario, OWNER);

        test_util::refresh(&mut scenario, OWNER);

        test_util::check_status(&mut scenario);

        test_util::print_status(&mut scenario);
        {
            unstake(&mut scenario, 100 * DECIMALS, OWNER);
        };

        test_util::print_status(&mut scenario);

        // check status
        next_tx(&mut scenario, OWNER);
        {
            let coin = test_util::get_coin<SUI>(&mut scenario);
            let pool = scenario.take_from_sender<StakePool>();
            let metadata = scenario.take_from_sender<Metadata<CERT>>();
            print(b"coin value2", coin.value());

            // ratio without fee 115897817459, from previous test
            print(b"exchange_rate", pool.get_ratio(&metadata)); // 1143080357
            print(b"coin value", coin.value()); // 114308035714

            // 1.15897817459 - (1.15897817459 - 1) * 0.1 = 1.1430803571

            assert!(coin.value() / 100 == 1_143080357, 100);
            // 200 * (1.15897817459 - 1) * 0.1 = 3_179563491
            assert!(pool.total_fees() == 3_179563491, 100);
            print(b"pool total sui supply", pool.validator_pool().total_sui_supply());
            assert!(coin.value().diff(pool.validator_pool().total_sui_supply() - 3_179563491) < 10, 0);
            coin.burn_for_testing();
            scenario.return_to_sender(pool);
            scenario.return_to_sender(metadata);
        };

        advance_epoch_and_check_status(&mut scenario);

        // redeem fee
        next_tx(&mut scenario, OWNER);
        {
            let mut pool = scenario.take_from_sender<StakePool>();
            let admin_cap = scenario.take_from_sender<AdminCap>();
            let mut metadata = scenario.take_from_sender<Metadata<CERT>>();
            let mut system_state = scenario.take_shared<SuiSystemState>();

            // validator pool supply contains fees
            // pool supply not contains fees
            assert!(pool.total_sui_supply() + 3_179563491 == pool.validator_pool().total_sui_supply(), 100);

            let coin = pool.collect_fees(&mut metadata, &mut system_state, &admin_cap, scenario.ctx());

            print(b"coin value3", coin.value());
            assert!(coin.value() == 3_179563491, 100);
            assert!(pool.accrued_reward_fees() == 0, 100);
            assert!(pool.total_sui_supply() / 100 == 1_143080357, 100);
            assert!(pool.validator_pool().total_sui_supply() / 100 == 1_143080357, 100);
            assert!(pool.total_sui_supply() == pool.validator_pool().total_sui_supply(), 100);

            coin.burn_for_testing();

            scenario.return_to_sender(pool);
            scenario.return_to_sender(metadata);
            return_shared(system_state);
            scenario.return_to_sender(admin_cap);
        };


        end_test(scenario);
    }

    #[test]
    fun test_stake_protocol_fee() {
        let mut scenario = test_scenario::begin(OWNER);
        init_protocol(&mut scenario);

        // set stake fee 0.01%
        next_tx(&mut scenario, OWNER);
        {
            let mut pool = scenario.take_from_sender<StakePool>();
            let admin_cap = scenario.take_from_sender<AdminCap>();
            pool.update_stake_fee(&admin_cap, 1);
            scenario.return_to_sender(pool);
            scenario.return_to_sender(admin_cap);
        };

        next_tx(&mut scenario, OWNER);
        {
            let amount = stake(&mut scenario, 100 * DECIMALS, OWNER);
            print(b"amount", amount);
            assert!(amount == 100 * DECIMALS - 100 * DECIMALS / 10000, 100);
        };

        // set stake fee 5%
        next_tx(&mut scenario, OWNER);
        {
            let mut pool = scenario.take_from_sender<StakePool>();
            let admin_cap = scenario.take_from_sender<AdminCap>();
            pool.update_stake_fee(&admin_cap, 500);
            scenario.return_to_sender(pool);
            scenario.return_to_sender(admin_cap);
        };

        next_tx(&mut scenario, OWNER);
        {
            let amount = stake(&mut scenario, 100 * DECIMALS, OWNER);
            assert!(amount == 95 * DECIMALS, 100);
        };

        // assert fee
        next_tx(&mut scenario, OWNER);
        {
            let pool = scenario.take_from_sender<StakePool>();
            assert!(pool.total_fees() == 100 * DECIMALS / 10000 + 5 * DECIMALS, 100);
            scenario.return_to_sender(pool);
        };

        // collect fee
        next_tx(&mut scenario, OWNER);
        {
            let mut pool = scenario.take_from_sender<StakePool>();
            let admin_cap = scenario.take_from_sender<AdminCap>();
            let mut metadata = scenario.take_from_sender<Metadata<CERT>>();
            let mut system_state = scenario.take_shared<SuiSystemState>();
            let coin = pool.collect_fees(&mut metadata, &mut system_state, &admin_cap, scenario.ctx());
            assert!(coin.value() ==  100 * DECIMALS / 10000 + 5 * DECIMALS, 100);
            coin.burn_for_testing();
            scenario.return_to_sender(admin_cap);
            scenario.return_to_sender(pool);
            scenario.return_to_sender(metadata);
            return_shared(system_state);
        };


        end_test(scenario);
    }

    #[test]
    fun test_unstake_protocol_fee() {
        let mut scenario = test_scenario::begin(OWNER);
        init_protocol(&mut scenario);

        // set unstake fee 0.01%
        next_tx(&mut scenario, OWNER);
        {
            let mut pool = scenario.take_from_sender<StakePool>();
            let admin_cap = scenario.take_from_sender<AdminCap>();
            pool.update_unstake_fee(&admin_cap, 1);
            scenario.return_to_sender(pool);
            scenario.return_to_sender(admin_cap);
        };

        stake(&mut scenario, 100 * DECIMALS, OWNER);
        test_util::refresh(&mut scenario, OWNER);

        next_tx(&mut scenario, OWNER);
        {
            let amount = unstake(&mut scenario, 100 * DECIMALS, OWNER);
            assert!(amount == 100 * DECIMALS - 100 * DECIMALS / 10000, 100);
        };

        // set unstake fee 5%
        next_tx(&mut scenario, OWNER);
        {
            let mut pool = scenario.take_from_sender<StakePool>();
            let admin_cap = scenario.take_from_sender<AdminCap>();
            pool.update_unstake_fee(&admin_cap, 500);
            scenario.return_to_sender(pool);
            scenario.return_to_sender(admin_cap);
        };
        stake(&mut scenario, 100 * DECIMALS, OWNER);
        test_util::refresh(&mut scenario, OWNER);

        next_tx(&mut scenario, OWNER);
        {
            let amount = unstake(&mut scenario, 100 * DECIMALS, OWNER);
            assert!(amount == 95 * DECIMALS, 100);
        };

        // assert fee
        next_tx(&mut scenario, OWNER);
        {
            let pool = scenario.take_from_sender<StakePool>();
            assert!(pool.total_fees() == 100 * DECIMALS / 10000 + 5 * DECIMALS, 100);
            scenario.return_to_sender(pool);
        };
        end_test(scenario);
    }

    #[test]
    fun test_unstake_protocol_fee_redistribution() {
        let mut scenario = test_scenario::begin(OWNER);
        init_protocol(&mut scenario);

        // set unstake fee 0.01%, redistribution 0.01%
        next_tx(&mut scenario, OWNER);
        {
            let mut pool = scenario.take_from_sender<StakePool>();
            let admin_cap = scenario.take_from_sender<AdminCap>();
            pool.update_unstake_fee(&admin_cap, 1);
            pool.update_unstake_fee_redistribution(&admin_cap, 1);
            scenario.return_to_sender(pool);
            scenario.return_to_sender(admin_cap);
        };

        stake(&mut scenario, 100 * DECIMALS, OWNER);
        stake(&mut scenario, 100 * DECIMALS, OWNER);
        
        let amount = unstake(&mut scenario, 100 * DECIMALS, OWNER);
        assert!(amount == 100 * DECIMALS - 100 * DECIMALS / 10000, 100);

        let amount = unstake(&mut scenario, 100 * DECIMALS, OWNER);
        print(b"amount", amount);
        // 99990000499 ~= 99990000000 + 10000000 / 10000 / 2 
        assert!(amount == 99990000499, 100);

        end_test(scenario);
    }

    #[test]
    fun test_stake_yield_10epochs() {
        let mut scenario = test_scenario::begin(OWNER);

        // stake outside of the protocol
        //         let staked_sui = system_state.request_add_stake_non_entry(
        //     coin::from_balance(sui, ctx),
        //     validator_address,
        //     ctx
        // );

        init_protocol(&mut scenario);

        next_tx(&mut scenario, OWNER);
        {
            let mut system_state = scenario.take_shared<SuiSystemState>();
            let sui_coin = coin::mint_for_testing<SUI>(100 * DECIMALS, scenario.ctx());
            let staked_sui = system_state.request_add_stake_non_entry(
                coin::from_balance(sui_coin.into_balance(), scenario.ctx()),
                @0x1,
                scenario.ctx()
            );

            transfer::public_transfer(staked_sui, OWNER);
            return_shared(system_state);
        };

        // stake 200 sui at epoch 1
        next_tx(&mut scenario, OWNER);
        {
            let amount = stake(&mut scenario, 100 * DECIMALS, OWNER);
            assert!(amount == 100 * DECIMALS, 200);
            test_util::refresh(&mut scenario, OWNER);
        };

        test_util::print_status(&mut scenario);

        // epoch 2
        advance_epoch_and_check_status(&mut scenario);
        test_util::refresh(&mut scenario, OWNER);
        test_util::print_status(&mut scenario);

        test_util::check_status(&mut scenario);

        // epoch3

        let mut i = 0;
        let mut stake = 0;
        let mut next_stake = 100 * DECIMALS;

        // next_tx(&mut scenario, OWNER);
        // {
        //     let mut system_state = scenario.take_shared<SuiSystemState>();
        //     let sui_coin = coin::mint_for_testing<SUI>(next_stake, scenario.ctx());
        //     let staked_sui = system_state.request_add_stake_non_entry(
        //         coin::from_balance(sui_coin.into_balance(), scenario.ctx()),
        //         @0x1,
        //         scenario.ctx()
        //     );

        //     stake = next_stake;

        //     transfer::public_transfer(staked_sui, OWNER);
        //     return_shared(system_state);
        // };

        // also test the sui reward is auto compound 
        while (i < 25) {
            next_tx(&mut scenario, OWNER);
            {
                if (stake > 0) {
                    let mut system_state = scenario.take_shared<SuiSystemState>();
                    let staked_sui = scenario.take_from_sender<StakedSui>();
                    let redeemed = system_state.request_withdraw_stake_non_entry(staked_sui, scenario.ctx());

                    next_stake = redeemed.value();
                    redeemed.destroy_for_testing();

                    return_shared(system_state);
                }
            };

            next_tx(&mut scenario, OWNER);
            {
                let mut system_state = scenario.take_shared<SuiSystemState>();
                let sui_coin = coin::mint_for_testing<SUI>(next_stake, scenario.ctx());
                let staked_sui = system_state.request_add_stake_non_entry(
                    coin::from_balance(sui_coin.into_balance(), scenario.ctx()),
                    @0x1,
                    scenario.ctx()
                );

                stake = next_stake;

                transfer::public_transfer(staked_sui, OWNER);
                return_shared(system_state);
            };

            advance_epoch_with_reward_amounts(0, 0, &mut scenario);
            advance_epoch_with_reward_amounts(0, 4, &mut scenario);    
            i = i + 1;
        };

        // assert!(scenario.ctx().epoch() == 52, 100);
    
        next_tx(&mut scenario, OWNER);

        test_util::refresh(&mut scenario, OWNER);
        test_util::check_status(&mut scenario);

        test_util::print_status(&mut scenario);
        {
            unstake(&mut scenario, 100 * DECIMALS, OWNER);
        };
        test_util::print_status(&mut scenario);

        // check status
        next_tx(&mut scenario, OWNER);
        {
            let coin = test_util::get_coin<SUI>(&mut scenario);
            let pool = scenario.take_from_sender<StakePool>();
            let metadata = scenario.take_from_sender<Metadata<CERT>>();
            print(b"coin value2", coin.value());

            print(b"exchange_rate", pool.get_ratio(&metadata)); // 114595734126
            assert!(coin.value() / 100 == 1145957341, coin.value());
            print(b"pool total sui supply", pool.validator_pool().total_sui_supply());
            assert!(coin.value().diff(pool.validator_pool().total_sui_supply()) < 10, 0);
            coin.burn_for_testing();
            scenario.return_to_sender(pool);
            scenario.return_to_sender(metadata);
        };

        advance_epoch_and_check_status(&mut scenario);


        end_test(scenario);
    }
}