module lending_core::manage {
    use std::type_name;
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::clock::{Clock};
    use sui::coin::{Self, Coin};
    use sui::tx_context::{Self, TxContext};
    use lending_core::version::{Self};
    use lending_core::error::{Self};
    use lending_core::pool::{Self, Pool};
    use lending_core::storage::{Self, Storage};
    use lending_core::storage::{StorageAdminCap, OwnerCap as StorageOwnerCap};
    use lending_core::flash_loan::{Self, Config as FlashLoanConfig};
    use lending_core::incentive_v2::{OwnerCap as IncentiveOwnerCap};
    use lending_core::incentive_v3::{Self, Incentive as IncentiveV3, RewardFund};
    use lending_core::storage::EmodeAsset;

    struct BorrowFeeCap has key, store {
        id: UID,
    }

    #[allow(unused_variable)]
    public fun create_flash_loan_config(_: &StorageAdminCap, ctx: &mut TxContext) {
        abort 0;
    }

    public fun create_flash_loan_config_with_storage(_: &StorageAdminCap, storage: &Storage, ctx: &mut TxContext) {
        flash_loan::create_config_with_market_id(storage, ctx)
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
        assert!(flash_loan::get_market_id(config) == storage::get_market_id(storage), error::unmatched_market_id());
        assert!(storage::get_market_id(storage) == pool::get_market_id(pool), error::unmatched_market_id());

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
        abort 0;
    }

    public fun create_incentive_v3_reward_fund_with_storage<T>(_: &IncentiveOwnerCap, storage: &Storage, ctx: &mut TxContext) {
        incentive_v3::create_reward_fund_with_market_id<T>(storage, ctx)
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
        abort 0;
    }

    public fun create_incentive_v3_with_storage(_: &IncentiveOwnerCap, storage: &Storage, ctx: &mut TxContext) {
        incentive_v3::create_incentive_v3_with_market_id(storage, ctx)
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

    // init
    public fun init_fields_batch(_: &StorageOwnerCap, storage: &mut Storage, incentive: &mut IncentiveV3, ctx: &mut TxContext) {
        incentive_v3::init_borrow_fee_fields(incentive, ctx);
        storage::init_protected_liquidation_fields(storage, ctx)
    }

    public fun mint_borrow_fee_cap(_: &StorageAdminCap, recipient: address, ctx: &mut TxContext) {
        transfer::public_transfer(BorrowFeeCap {id: object::new(ctx)}, recipient);
    }

    public fun set_borrow_fee_rate(_: &BorrowFeeCap, incentive: &mut IncentiveV3, rate: u64, ctx: &mut TxContext) {
        incentive_v3::set_borrow_fee_rate(incentive, rate, ctx)
    }
    
    public fun set_asset_borrow_fee_rate(_: &BorrowFeeCap, incentive: &mut IncentiveV3, asset_id: u8, rate: u64, ctx: &mut TxContext) {
        incentive_v3::set_asset_borrow_fee_rate(incentive, asset_id, rate, ctx)
    }

    public fun set_user_borrow_fee_rate(_: &BorrowFeeCap, incentive: &mut IncentiveV3, user: address, asset_id: u8, rate: u64, ctx: &mut TxContext) {
        incentive_v3::set_user_borrow_fee_rate(incentive, user, asset_id, rate, ctx)
    }

    public fun remove_incentive_v3_asset_borrow_fee_rate(_: &BorrowFeeCap, incentive: &mut IncentiveV3, asset_id: u8, ctx: &mut TxContext) {
        incentive_v3::remove_asset_borrow_fee_rate(incentive, asset_id, ctx)
    }

    public fun remove_incentive_v3_user_borrow_fee_rate(_: &BorrowFeeCap, incentive: &mut IncentiveV3, user: address, asset_id: u8, ctx: &TxContext) {
        incentive_v3::remove_user_borrow_fee_rate(incentive, user, asset_id, ctx)
    }

    public fun set_designated_liquidators(_: &StorageOwnerCap, storage: &mut Storage, liquidator: address, user: address, is_designated: bool, ctx: &mut TxContext) {
        storage::set_designated_liquidators(storage, liquidator, user, is_designated, ctx)
    }

    public fun set_protected_liquidation_users(_: &StorageOwnerCap, storage: &mut Storage, user: address, is_protected: bool) {
        storage::set_protected_liquidation_users(storage, user, is_protected)
    }

    public fun create_emode_asset(_: &StorageAdminCap, asset: u8, is_collateral: bool, is_debt: bool, ltv: u256, lt: u256, liquidation_bonus: u256): EmodeAsset {
        storage::create_emode_asset(asset, is_collateral, is_debt, ltv, lt, liquidation_bonus)
    }

    public fun create_emode_pair(_: &StorageAdminCap, storage: &mut Storage, assetA: EmodeAsset, assetB: EmodeAsset) {
        storage::create_emode_pair(storage, assetA, assetB)
    }
    
    public fun set_emode_config_active(_: &StorageAdminCap, storage: &mut Storage, emode_id: u64, is_active: bool) {
        storage::set_emode_config_active(storage, emode_id, is_active)
    }

    public fun set_emode_asset_lt(_: &StorageAdminCap, storage: &mut Storage, emode_id: u64, asset: u8, lt: u256) {
        storage::set_emode_asset_lt(storage, emode_id, asset, lt)
    }
    
    public fun set_emode_asset_ltv(_: &StorageAdminCap, storage: &mut Storage, emode_id: u64, asset: u8, ltv: u256) {
        storage::set_emode_asset_ltv(storage, emode_id, asset, ltv)
    }

    public fun set_emode_asset_liquidation_bonus(_: &StorageAdminCap, storage: &mut Storage, emode_id: u64, asset: u8, liquidation_bonus: u256) {
        storage::set_emode_asset_liquidation_bonus(storage, emode_id, asset, liquidation_bonus)
    }

    public fun create_new_market(_: &StorageAdminCap, main_storage: &mut Storage, ctx: &mut TxContext) {
        storage::create_new_market(main_storage, ctx)
    }

    public fun set_borrow_weight(_: &StorageAdminCap, storage: &mut Storage, asset: u8, weight: u64) {
        storage::set_borrow_weight(storage, asset, weight)
    }

    public fun remove_borrow_weight(_: &StorageAdminCap, storage: &mut Storage, asset: u8) {
        storage::remove_borrow_weight(storage, asset)
    }

}
