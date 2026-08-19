/// Event
module lending_core::event {
    use sui::event::emit;
    use std::ascii::{String};
    friend lending_core::flash_loan;
    friend lending_core::lending;
    friend lending_core::manage;
    friend lending_core::logic;
    friend lending_core::pool;
    friend lending_core::storage;
    friend lending_core::incentive_v3;
    friend lending_core::pool_manager;

    // Flash Loan Event
    struct ConfigCreated has copy, drop {
        sender: address,
        id: address,
        market_id: u64,
    }
    public(friend) fun emit_config_created(sender: address, id: address, market_id: u64) {
        emit(ConfigCreated {sender, id, market_id})
    }

    struct AssetConfigCreated has copy, drop {
        sender: address,
        config_id: address,
        asset_id: address,
        market_id: u64,
    }
    public(friend) fun emit_asset_config_created(sender: address, config_id: address, asset_id: address, market_id: u64) {
        emit(AssetConfigCreated {sender, config_id, asset_id, market_id})
    }

    struct FlashLoan has copy, drop {
        sender: address,
        asset: address,
        amount: u64,
        market_id: u64,
    }
    public(friend) fun emit_flash_loan(sender: address, asset: address, amount: u64, market_id: u64) {
        emit(FlashLoan {sender, asset, amount, market_id})
    }

    struct FlashRepay has copy, drop {
        sender: address,
        asset: address,
        amount: u64,
        fee_to_supplier: u64,
        fee_to_treasury: u64,
        market_id: u64,
    }
    public(friend) fun emit_flash_repay(sender: address, asset: address, amount: u64, fee_to_supplier: u64, fee_to_treasury: u64, market_id: u64) {
        emit(FlashRepay {sender, asset, amount, fee_to_supplier, fee_to_treasury, market_id})
    }

    // Incentive_v3 Event
    // Event
    struct RewardFundCreated has copy, drop {
        sender: address,
        reward_fund_id: address,
        coin_type: String,
        market_id: u64,
    }
    public(friend) fun emit_reward_fund_created(sender: address, reward_fund_id: address, coin_type: String, market_id: u64) {
        emit(RewardFundCreated {sender, reward_fund_id, coin_type, market_id})
    }

    struct RewardFundDeposited has copy, drop {
        sender: address,
        reward_fund_id: address,
        amount: u64,
        market_id: u64,
    }
    public(friend) fun emit_reward_fund_deposited(sender: address, reward_fund_id: address, amount: u64, market_id: u64) {
        emit(RewardFundDeposited {sender, reward_fund_id, amount, market_id})
    }

    struct RewardFundWithdrawn has copy, drop {
        sender: address,
        reward_fund_id: address,
        amount: u64,
        market_id: u64,
    }
    public(friend) fun emit_reward_fund_withdrawn(sender: address, reward_fund_id: address, amount: u64, market_id: u64) {
        emit(RewardFundWithdrawn {sender, reward_fund_id, amount, market_id})
    }

    struct IncentiveCreated has copy, drop {
        sender: address,
        incentive_id: address,
        market_id: u64,
    }
    public(friend) fun emit_incentive_created(sender: address, incentive_id: address, market_id: u64) {
        emit(IncentiveCreated {sender, incentive_id, market_id})
    }

    struct AssetPoolCreated has copy, drop {
        sender: address,
        asset_id: u8,
        asset_coin_type: String,
        pool_id: address,
        market_id: u64,
    }
    public(friend) fun emit_asset_pool_created(sender: address, asset_id: u8, asset_coin_type: String, pool_id: address, market_id: u64) {
        emit(AssetPoolCreated {sender, asset_id, asset_coin_type, pool_id, market_id})
    }

    struct RuleCreated has copy, drop {
        sender: address,
        pool: String,
        rule_id: address,
        option: u8,
        reward_coin_type: String,
        market_id: u64,
    }
    public(friend) fun emit_rule_created(sender: address, pool: String, rule_id: address, option: u8, reward_coin_type: String, market_id: u64) {
        emit(RuleCreated {sender, pool, rule_id, option, reward_coin_type, market_id})
    }

    struct BorrowFeeRateUpdated has copy, drop {
        sender: address,
        rate: u64,
        market_id: u64,
    }
    public(friend) fun emit_borrow_fee_rate_updated(sender: address, rate: u64, market_id: u64) {
        emit(BorrowFeeRateUpdated {sender, rate, market_id})
    }

    struct BorrowFeeWithdrawn has copy, drop {
        sender: address,
        coin_type: String,
        amount: u64,
        market_id: u64,
    }
    public(friend) fun emit_borrow_fee_withdrawn(sender: address, coin_type: String, amount: u64, market_id: u64) {
        emit(BorrowFeeWithdrawn {sender, coin_type, amount, market_id})
    }

    struct RewardStateUpdated has copy, drop {
        sender: address,
        rule_id: address,
        enable: bool,
        market_id: u64,
    }
    public(friend) fun emit_reward_state_updated(sender: address, rule_id: address, enable: bool, market_id: u64) {
        emit(RewardStateUpdated {sender, rule_id, enable, market_id})
    }

    struct MaxRewardRateUpdated has copy, drop {
        rule_id: address,
        max_total_supply: u64,
        duration_ms: u64,
        market_id: u64,
    }
    public(friend) fun emit_max_reward_rate_updated(rule_id: address, max_total_supply: u64, duration_ms: u64, market_id: u64) {
        emit(MaxRewardRateUpdated {rule_id, max_total_supply, duration_ms, market_id})
    }

    struct RewardRateUpdated has copy, drop {
        sender: address,
        pool: String,
        rule_id: address,
        rate: u256,
        total_supply: u64,
        duration_ms: u64,
        timestamp: u64,
        market_id: u64,
    }
    public(friend) fun emit_reward_rate_updated(sender: address, pool: String, rule_id: address, rate: u256, total_supply: u64, duration_ms: u64, timestamp: u64, market_id: u64) {
        emit(RewardRateUpdated {sender, pool, rule_id, rate, total_supply, duration_ms, timestamp, market_id})
    }

    struct RewardClaimed has copy, drop {
        user: address,
        total_claimed: u64,
        coin_type: String,
        rule_ids: vector<address>,
        rule_indices: vector<u256>,
        market_id: u64,
    }
    public(friend) fun emit_reward_claimed(user: address, total_claimed: u64, coin_type: String, rule_ids: vector<address>, rule_indices: vector<u256>, market_id: u64) {
        emit(RewardClaimed {user, total_claimed, coin_type, rule_ids, rule_indices, market_id})
    }

    struct AssetBorrowFeeRateUpdated has copy, drop {
        sender: address,
        asset_id: u8,
        user: address,
        rate: u64,
        market_id: u64,
    }
    public(friend) fun emit_asset_borrow_fee_rate_updated(sender: address, asset_id: u8, user: address, rate: u64, market_id: u64) {
        emit(AssetBorrowFeeRateUpdated {sender, asset_id, user, rate, market_id})
    }

    struct AssetBorrowFeeRateRemoved has copy, drop {
        sender: address,
        asset_id: u8,
        user: address,
        market_id: u64,
    }
    public(friend) fun emit_asset_borrow_fee_rate_removed(sender: address, asset_id: u8, user: address, market_id: u64) {
        emit(AssetBorrowFeeRateRemoved {sender, asset_id, user, market_id})
    }

    struct BorrowFeeDeposited has copy, drop {
        sender: address,
        coin_type: String,
        fee: u64,
        market_id: u64,
    }
    public(friend) fun emit_borrow_fee_deposited(sender: address, coin_type: String, fee: u64, market_id: u64) {
        emit(BorrowFeeDeposited {sender, coin_type, fee, market_id})
    }

    // Lending Event
    // Event
    struct DepositEvent has copy, drop {
        reserve: u8,
        sender: address,
        amount: u64,
        market_id: u64,
    }
    public(friend) fun emit_deposit_event(reserve: u8, sender: address, amount: u64, market_id: u64) {
        emit(DepositEvent {reserve, sender, amount, market_id})
    }

    struct DepositOnBehalfOfEvent has copy, drop {
        reserve: u8,
        sender: address,
        user: address,
        amount: u64,
        market_id: u64,
    }
    public(friend) fun emit_deposit_on_behalf_of_event(reserve: u8, sender: address, user: address, amount: u64, market_id: u64) {
        emit(DepositOnBehalfOfEvent {reserve, sender, user, amount, market_id})
    }

    struct WithdrawEvent has copy, drop {
        reserve: u8,
        sender: address,
        to: address,
        amount: u64,
        market_id: u64,
    }
    public(friend) fun emit_withdraw_event(reserve: u8, sender: address, to: address, amount: u64, market_id: u64) {
        emit(WithdrawEvent {reserve, sender, to, amount, market_id})
    }

    struct BorrowEvent has copy, drop {
        reserve: u8,
        sender: address,
        amount: u64,
        market_id: u64,
    }
    public(friend) fun emit_borrow_event(reserve: u8, sender: address, amount: u64, market_id: u64) {
        emit(BorrowEvent {reserve, sender, amount, market_id})
    }

    struct RepayEvent has copy, drop {
        reserve: u8,
        sender: address,
        amount: u64,
        market_id: u64,
    }
    public(friend) fun emit_repay_event(reserve: u8, sender: address, amount: u64, market_id: u64) {
        emit(RepayEvent {reserve, sender, amount, market_id})
    }
    
    struct RepayOnBehalfOfEvent has copy, drop {
        reserve: u8,
        sender: address,
        user: address,
        amount: u64,
        market_id: u64,
    }
    public(friend) fun emit_repay_on_behalf_of_event(reserve: u8, sender: address, user: address, amount: u64, market_id: u64) {
        emit(RepayOnBehalfOfEvent {reserve, sender, user, amount, market_id})
    }

    #[allow(unused_field)]
    struct LiquidationCallEvent has copy, drop {
        reserve: u8,
        sender: address,
        liquidate_user: address,
        liquidate_amount: u64,
        market_id: u64,
    }
    public(friend) fun emit_liquidation_call_event(reserve: u8, sender: address, liquidate_user: address, liquidate_amount: u64, market_id: u64) {
        emit(LiquidationCallEvent {reserve, sender, liquidate_user, liquidate_amount, market_id})
    }

    struct LiquidationEvent has copy, drop {
        sender: address,
        user: address,
        collateral_asset: u8,
        collateral_price: u256,
        collateral_amount: u64,
        treasury: u64,
        debt_asset: u8,
        debt_price: u256,
        debt_amount: u64,
        market_id: u64,
    }
    public(friend) fun emit_liquidation_event(
        sender: address,
        user: address,
        collateral_asset: u8,
        collateral_price: u256,
        collateral_amount: u64,
        treasury: u64,
        debt_asset: u8,
        debt_price: u256,
        debt_amount: u64,
        market_id: u64
    ) {
        emit(LiquidationEvent {
            sender,
            user,
            collateral_asset,
            collateral_price,
            collateral_amount,
            treasury,
            debt_asset,
            debt_price,
            debt_amount,
            market_id,
        })
    }

    // logic Event
    struct StateUpdated has copy, drop {
        user: address,
        asset: u8,
        user_supply_balance: u256,
        user_borrow_balance: u256,
        new_supply_index: u256,
        new_borrow_index: u256,
        market_id: u64,
    }
    public(friend) fun emit_state_updated(user: address, asset: u8, user_supply_balance: u256, user_borrow_balance: u256, new_supply_index: u256, new_borrow_index: u256, market_id: u64) {
        emit(StateUpdated {user, asset, user_supply_balance, user_borrow_balance, new_supply_index, new_borrow_index, market_id})
    }

    // pool_manager Event
    struct FundUpdated has copy, drop {
        original_sui_amount: u64,
        current_sui_amount: u64,
        vsui_balance_amount: u64,
        // treasury_amount: u64,
        target_sui_amount: u64,
        manager_id: address,
    }
    public(friend) fun emit_fund_updated(original_sui_amount: u64, current_sui_amount: u64, vsui_balance_amount: u64, target_sui_amount: u64, manager_id: address) {
        emit(FundUpdated {original_sui_amount, current_sui_amount, vsui_balance_amount, target_sui_amount, manager_id})
    }

    struct StakingTreasuryWithdrawn has copy, drop {
        taken_vsui_balance_amount: u64,
        equal_sui_balance_amount: u64,
        manager_id: address,
    }
    public(friend) fun emit_staking_treasury_withdrawn(taken_vsui_balance_amount: u64, equal_sui_balance_amount: u64, manager_id: address) {
        emit(StakingTreasuryWithdrawn {taken_vsui_balance_amount, equal_sui_balance_amount, manager_id})
    }

    // pool Event
     // Event
    struct PoolCreate has copy, drop {
        creator: address,
        coin_type: String,
        pool_id: address,
        market_id: u64,
    }
    public(friend) fun emit_pool_create(creator: address, coin_type: String, pool_id: address, market_id: u64) {
        emit(PoolCreate {creator, coin_type, pool_id, market_id})
    }

    struct PoolBalanceRegister has copy, drop {
        sender: address,
        amount: u64,
        new_amount: u64,
        pool: String,
        market_id: u64,
    }
    public(friend) fun emit_pool_balance_register(sender: address, amount: u64, new_amount: u64, pool: String, market_id: u64) {
        emit(PoolBalanceRegister {sender, amount, new_amount, pool, market_id})
    }

    struct PoolDeposit has copy, drop {
        sender: address,
        amount: u64,
        pool: String,
        market_id: u64,
    }
    public(friend) fun emit_pool_deposit(sender: address, amount: u64, pool: String, market_id: u64) {
        emit(PoolDeposit {sender, amount, pool, market_id})
    }

    struct PoolWithdraw has copy, drop {
        sender: address,
        recipient: address,
        amount: u64,
        pool: String,
        market_id: u64,
    }
    public(friend) fun emit_pool_withdraw(sender: address, recipient: address, amount: u64, pool: String, market_id: u64) {
        emit(PoolWithdraw {sender, recipient, amount, pool, market_id})
    }

    struct PoolWithdrawReserve has copy, drop {
        sender: address,
        recipient: address,
        amount: u64,
        before: u64,
        after: u64,
        pool: String,
        poolId: address,
        market_id: u64,
    }
    public(friend) fun emit_pool_withdraw_reserve(sender: address, recipient: address, amount: u64, before: u64, after: u64, pool: String, poolId: address, market_id: u64) {
        emit(PoolWithdrawReserve {sender, recipient, amount, before, after, pool, poolId, market_id})
    }

// Event
    struct StorageConfiguratorSetting has copy, drop {  
        sender: address,
        configurator: address,
        value: bool,
        market_id: u64,
    }
    public(friend) fun emit_storage_configurator_setting(sender: address, configurator: address, value: bool, market_id: u64) {
        emit(StorageConfiguratorSetting {sender, configurator, value, market_id})
    }

    struct Paused has copy, drop {
        paused: bool,
        market_id: u64,
    }
    public(friend) fun emit_paused(paused: bool, market_id: u64) {
        emit(Paused {paused, market_id})
    }

    struct WithdrawTreasuryEvent has copy, drop {
        sender: address,
        recipient: address,
        asset: u8,
        amount: u256,
        poolId: address,
        before: u256,
        after: u256,
        index: u256,
        market_id: u64,
    }
    public(friend) fun emit_withdraw_treasury_event(sender: address, recipient: address, asset: u8, amount: u256, poolId: address, before: u256, after: u256, index: u256, market_id: u64) {
        emit(WithdrawTreasuryEvent {sender, recipient, asset, amount, poolId, before, after, index, market_id})
    }

    struct LiquidatorSet has copy, drop {
        liquidator: address,
        user: address,
        is_liquidatable: bool,
        market_id: u64,
    } 
    public(friend) fun emit_liquidator_set(liquidator: address, user: address, is_liquidatable: bool, market_id: u64) {
        emit(LiquidatorSet {liquidator, user, is_liquidatable, market_id})
    }

    struct ProtectedUserSet has copy, drop {
        user: address,
        is_protected: bool,
        market_id: u64,
    } 
    public(friend) fun emit_protected_user_set(user: address, is_protected: bool, market_id: u64) {
        emit(ProtectedUserSet {user, is_protected, market_id})
    }
    struct EmodePairCreated has copy, drop {
        emode_id: u64,
        assetA: u8,
        assetB: u8,
        market_id: u64,
    }
    public(friend) fun emit_emode_pair_created(emode_id: u64, assetA: u8, assetB: u8, market_id: u64) {
        emit(EmodePairCreated {emode_id, assetA, assetB, market_id})
    }

    struct EmodeParamSet has copy, drop {
        emode_id: u64,
        asset: u8,
        value: u256,
        param_type: String,
        market_id: u64,
    }
    public(friend) fun emit_emode_param_set(emode_id: u64, asset: u8, value: u256, param_type: String, market_id: u64) {
        emit(EmodeParamSet {emode_id, asset, value, param_type, market_id})
    }

    struct EmodeActiveSet has copy, drop {
        emode_id: u64,
        is_active: bool,
        market_id: u64,
    }
    public(friend) fun emit_emode_active_set(emode_id: u64, is_active: bool, market_id: u64) {
        emit(EmodeActiveSet {emode_id, is_active, market_id})
    }

    struct EmodeUserStateChanged has copy, drop {
        user: address,
        emode_id: u64,
        is_entered: bool,
        market_id: u64,
    }
    public(friend) fun emit_emode_user_state_changed(user: address, emode_id: u64, is_entered: bool, market_id: u64) {
        emit(EmodeUserStateChanged {user, emode_id, is_entered, market_id})
    }

    struct MarketCreated has copy, drop { market_id: u64 }
    public(friend) fun emit_market_created(market_id: u64) {
        emit(MarketCreated {market_id})
    }

    struct BorrowWeightSet has copy, drop {
        asset: u8,
        weight: u64,
        market_id: u64,
    }
    public(friend) fun emit_borrow_weight_set(asset: u8, weight: u64, market_id: u64) {
        emit(BorrowWeightSet {asset, weight, market_id})
    }

    struct BorrowWeightRemoved has copy, drop { asset: u8, market_id: u64 }
    public(friend) fun emit_borrow_weight_removed(asset: u8, market_id: u64) {
        emit(BorrowWeightRemoved {asset, market_id})
    }

    struct StorageParamsUpdated has copy, drop {
        asset: u8,
        param_type: String,
        value: u256,
        market_id: u64,
    }
    public(friend) fun emit_storage_params_updated(asset: u8, param_type: String, value: u256, market_id: u64) {
        emit(StorageParamsUpdated {asset, param_type, value, market_id})
    }

}