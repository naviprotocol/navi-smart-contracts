module lending_core::manage {
    use std::type_name;
    use sui::object;
    use sui::transfer;
    use sui::clock::{Clock};
    use sui::coin::{Self, Coin};
    use sui::tx_context::{Self, TxContext};
    
    use lending_core::version::{Self};
    use lending_core::error::{Self};
    use lending_core::pool::{Self, Pool};
    use lending_core::storage::{Self, Storage};
    use lending_core::storage::{StorageAdminCap};
    use lending_core::flash_loan::{Self, Config as FlashLoanConfig};
    use lending_core::incentive_v2::{OwnerCap as IncentiveOwnerCap};
    use lending_core::incentive_v3::{Self, Incentive as IncentiveV3, RewardFund};
    
    public fun create_flash_loan_config(_: &StorageAdminCap, ctx: &mut TxContext) {
        flash_loan::create_config(ctx)
    }

    public fun create_flash_loan_asset<T>(
        _: &StorageAdminCap,
        config: &mut FlashLoanConfig,
        storage: &Storage,
        pool: &Pool<T>,
        asset_id: u8,
        rate_to_supplier: u64,
        rate_to_treasury: u64,
        maximum: u64,
        minimum: u64,
        ctx: &mut TxContext
    ) {
        let reserves_count = storage::get_reserves_count(storage);
        assert!(asset_id < reserves_count, error::reserve_not_found());

        let coin_type_from_storage = storage::get_coin_type(storage, asset_id);
        assert!(type_name::into_string(type_name::get<T>()) == coin_type_from_storage, error::invalid_coin_type());

        let pool_address = object::uid_to_address(pool::uid(pool));

        flash_loan::create_asset(
            config,
            asset_id,
            coin_type_from_storage,
            pool_address,
            rate_to_supplier,
            rate_to_treasury,
            maximum,
            minimum,
            ctx
        );
    }

    public fun set_flash_loan_asset_rate_to_supplier<T>(
        _: &StorageAdminCap,
        config: &mut FlashLoanConfig, 
        _value: u64        
    ) {
        flash_loan::set_asset_rate_to_supplier(config, type_name::into_string(type_name::get<T>()), _value)
    }

    public fun set_flash_loan_asset_rate_to_treasury<T>(
        _: &StorageAdminCap,
        config: &mut FlashLoanConfig, 
        _value: u64        
    ) {
        flash_loan::set_asset_rate_to_treasury(config, type_name::into_string(type_name::get<T>()), _value)
    }

    public fun set_flash_loan_asset_min<T>(
        _: &StorageAdminCap,
        config: &mut FlashLoanConfig, 
        _value: u64        
    ) {
        flash_loan::set_asset_min(config, type_name::into_string(type_name::get<T>()), _value)
    }

    public fun set_flash_loan_asset_max<T>(
        _: &StorageAdminCap,
        config: &mut FlashLoanConfig, 
        _value: u64        
    ) {
        flash_loan::set_asset_max(config, type_name::into_string(type_name::get<T>()), _value)
    }

    // Incentive V3
    public fun withdraw_borrow_fee<T>(_: &StorageAdminCap, incentive: &mut IncentiveV3, amount: u64, recipient: address, ctx: &mut TxContext) {
        let balance = incentive_v3::withdraw_borrow_fee<T>(incentive, amount, ctx);

        transfer::public_transfer(coin::from_balance(balance, ctx), recipient)
    }

    public fun incentive_v3_version_migrate(_: &StorageAdminCap, incentive: &mut IncentiveV3) {
        assert!(incentive_v3::version(incentive) < version::this_version(), error::incorrect_version());

        incentive_v3::version_migrate(incentive, version::this_version())
    }

    public fun create_incentive_v3_reward_fund<T>(_: &IncentiveOwnerCap, ctx: &mut TxContext) {
        incentive_v3::create_reward_fund<T>(ctx)
    }

    #[allow(lint(self_transfer))]
    public fun deposit_incentive_v3_reward_fund<T>(_: &IncentiveOwnerCap, reward_fund: &mut RewardFund<T>, deposit_coin: Coin<T>, amount: u64, ctx: &mut TxContext) {
        assert!(coin::value(&deposit_coin) >= amount, error::invalid_amount());
        let split_coin = coin::split<T>(&mut deposit_coin, amount, ctx);

        incentive_v3::deposit_reward_fund<T>(reward_fund, coin::into_balance(split_coin), ctx);

        transfer::public_transfer(deposit_coin, tx_context::sender(ctx))
    }

    public fun withdraw_incentive_v3_reward_fund<T>(_: &StorageAdminCap, reward_fund: &mut RewardFund<T>, amount: u64, recipient: address, ctx: &mut TxContext) {
        let balance = incentive_v3::withdraw_reward_fund<T>(reward_fund, amount, ctx);

        transfer::public_transfer(coin::from_balance(balance, ctx), recipient)
    }

    public fun create_incentive_v3(_: &IncentiveOwnerCap, ctx: &mut TxContext) {
        incentive_v3::create_incentive_v3(ctx)
    }

    public fun create_incentive_v3_pool<T>(_: &IncentiveOwnerCap, incentive: &mut IncentiveV3, storage: &Storage, asset_id: u8, ctx: &mut TxContext) {
        incentive_v3::create_pool<T>(incentive, storage, asset_id, ctx)
    }

    public fun create_incentive_v3_rule<T, RewardCoinType>(_: &IncentiveOwnerCap, clock: &Clock, incentive: &mut IncentiveV3, option: u8, ctx: &mut TxContext) {
        incentive_v3::create_rule<T, RewardCoinType>(clock, incentive, option, ctx)
    }

    public fun enable_incentive_v3_by_rule_id<T>(_: &IncentiveOwnerCap, incentive: &mut IncentiveV3, rule_id: address, ctx: &mut TxContext) {
        incentive_v3::set_enable_by_rule_id<T>(incentive, rule_id, true, ctx)
    }

    public fun disable_incentive_v3_by_rule_id<T>(_: &IncentiveOwnerCap, incentive: &mut IncentiveV3, rule_id: address, ctx: &mut TxContext) {
        incentive_v3::set_enable_by_rule_id<T>(incentive, rule_id, false, ctx)
    }

    public fun set_incentive_v3_reward_rate_by_rule_id<T>(_: &IncentiveOwnerCap, clock: &Clock, incentive: &mut IncentiveV3, storage: &mut Storage, rule_id: address, total_supply: u64, duration_ms: u64, ctx: &mut TxContext) {
        incentive_v3::set_reward_rate_by_rule_id<T>(clock, incentive, storage, rule_id, total_supply, duration_ms, ctx)
    }

    public fun set_incentive_v3_max_reward_rate_by_rule_id<T>(_: &IncentiveOwnerCap, incentive: &mut IncentiveV3, rule_id: address, max_total_supply: u64, duration_ms: u64) {
        incentive_v3::set_max_reward_rate_by_rule_id<T>(incentive, rule_id, max_total_supply, duration_ms)
    }

    public fun set_incentive_v3_borrow_fee_rate(_: &StorageAdminCap, incentive: &mut IncentiveV3, rate: u64, ctx: &mut TxContext) {
        incentive_v3::set_borrow_fee_rate(incentive, rate, ctx)
    }
}
