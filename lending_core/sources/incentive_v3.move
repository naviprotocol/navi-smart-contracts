/// The `incentive_v3` module manages the incentive structures for the lending protocol.
/// It includes functionality for creating and managing incentives, pools, and rules,
/// as well as handling reward distribution and borrow fee management.
#[allow(unused_variable, lint(public_entry))]
module lending_core::incentive_v3 {
    use std::vector::{Self};
    use std::ascii::{Self, String};
    use std::type_name::{Self, TypeName};

    use sui::event::{emit};
    use sui::bag::{Self, Bag};
    use sui::object::{Self, UID};
    use sui::transfer::{Self};
    use sui::coin::{Self, Coin};
    use sui::table::{Self, Table};
    use sui::clock::{Self, Clock};
    use sui::balance::{Self, Balance};
    use sui::vec_map::{Self, VecMap};
    use sui::tx_context::{Self, TxContext};
    use sui::dynamic_field::{Self};

    use lending_core::ray_math::{Self};
    use lending_core::error::{Self};
    use lending_core::pool::{Pool};
    use lending_core::version::{Self};
    use lending_core::lending::{Self};
    use lending_core::constants::{Self};
    use lending_core::storage::{Self, Storage};
    use lending_core::event;
    use lending_core::account::{Self, AccountCap};
    use lending_core::incentive_v2::{Self, Incentive as IncentiveV2};
    use oracle::oracle::{PriceOracle};
    use lending_core::storage::StorageAdminCap;

    use sui_system::sui_system::{SuiSystemState};

    friend lending_core::manage;

    struct Incentive has key, store {
        id: UID,
        version: u64,
        pools: VecMap<String, AssetPool>,
        borrow_fee_rate: u64,
        fee_balance: Bag, // K: TypeName(CoinType): V: Balance<CoinType>
    }

    struct AssetPool has key, store {
        id: UID,
        asset: u8,
        asset_coin_type: String, // just for display
        rules: VecMap<address, Rule>,
    }

    struct Rule has key, store {
        id: UID,
        option: u8,
        enable: bool,
        reward_coin_type: String,
        rate: u256, // RAY number,ray_div(total_release, duration) --> 20usdt in 1month = ray_div(20 * 1e6, (86400 * 30 * 1000)) = 7.716049575617284e+24
        max_rate: u256, // rate limit to prevent operation errors --> 0 means no limit
        last_update_at: u64, // milliseconds
        global_index: u256,
        user_index: Table<address, u256>,
        user_total_rewards: Table<address, u256>, // total rewards of the user
        user_rewards_claimed: Table<address, u256>, // total rewards of the user claimed
    }

    struct RewardFund<phantom CoinType> has key, store {
        id: UID,
        balance: Balance<CoinType>,
        coin_type: String,
    }

    // Claimable rewards for a user
    struct ClaimableReward has copy, drop {
        asset_coin_type: String,
        reward_coin_type: String,
        user_claimable_reward: u256,
        user_claimed_reward: u256,
        rule_ids: vector<address>,
    }

    // Event
    struct RewardFundCreated has copy, drop {
        sender: address,
        reward_fund_id: address,
        coin_type: String,
    }

    struct RewardFundDeposited has copy, drop {
        sender: address,
        reward_fund_id: address,
        amount: u64,
    }

    struct RewardFundWithdrawn has copy, drop {
        sender: address,
        reward_fund_id: address,
        amount: u64,
    }

    struct IncentiveCreated has copy, drop {
        sender: address,
        incentive_id: address,
    }

    struct AssetPoolCreated has copy, drop {
        sender: address,
        asset_id: u8,
        asset_coin_type: String,
        pool_id: address,
    }

    struct RuleCreated has copy, drop {
        sender: address,
        pool: String,
        rule_id: address,
        option: u8,
        reward_coin_type: String,
    }

    struct BorrowFeeRateUpdated has copy, drop {
        sender: address,
        rate: u64,
    }

    struct BorrowFeeWithdrawn has copy, drop {
        sender: address,
        coin_type: String,
        amount: u64,
    }

    struct RewardStateUpdated has copy, drop {
        sender: address,
        rule_id: address,
        enable: bool,
    }

    struct MaxRewardRateUpdated has copy, drop {
        rule_id: address,
        max_total_supply: u64,
        duration_ms: u64,
    }

    struct RewardRateUpdated has copy, drop {
        sender: address,
        pool: String,
        rule_id: address,
        rate: u256,
        total_supply: u64,
        duration_ms: u64,
        timestamp: u64,
    }

    struct RewardClaimed has copy, drop {
        user: address,
        total_claimed: u64,
        coin_type: String,
        rule_ids: vector<address>,
        rule_indices: vector<u256>,
    }

    struct AssetBorrowFeeRateUpdated has copy, drop {
        sender: address,
        asset_id: u8,
        user: address,
        rate: u64,
    }

    struct AssetBorrowFeeRateRemoved has copy, drop {
        sender: address,
        asset_id: u8,
        user: address,
    }

    struct BorrowFeeDeposited has copy, drop {
        sender: address,
        coin_type: String,
        fee: u64
    }

    // === dynamic field keys ===
    struct ASSET_BORROW_FEES_KEY has copy, drop, store {}
    struct USER_BORROW_FEES_KEY has copy, drop, store {}
    struct MARKET_ID_KEY has copy, drop, store {}

    // Functions
    public fun version(incentive: &Incentive): u64 {
        incentive.version
    }

    public fun version_verification(incentive: &Incentive) {
        version::pre_check_version(incentive.version)
    }

    public(friend) fun version_migrate(incentive: &mut Incentive, version: u64) {
        incentive.version = version;
    }

    public(friend) fun create_reward_fund<T>(market_id: u64, ctx: &mut TxContext) {
        abort 0
    }

    public(friend) fun create_reward_fund_with_market_id<T>(storage: &Storage, ctx: &mut TxContext) {
        storage::version_verification(storage);
        let (market_id, _, _) = storage::get_storage_market_info(storage);
        let coin_type = type_name::into_string(type_name::get<T>());

        let id = object::new(ctx);
        let addr = object::uid_to_address(&id);

        let fund = RewardFund<T> {
            id,
            balance: balance::zero<T>(),
            coin_type,
        };

        dynamic_field::add(&mut fund.id, MARKET_ID_KEY {}, market_id);

        transfer::share_object(fund);
        event::emit_reward_fund_created(tx_context::sender(ctx), addr, coin_type, market_id);
    }

    public(friend) fun deposit_reward_fund<T>(reward_fund: &mut RewardFund<T>, reward_balance: Balance<T>, ctx: &TxContext) {
        let amount = balance::value(&reward_balance);
        balance::join(&mut reward_fund.balance, reward_balance);

        let market_id = get_fund_market_id(reward_fund);
        event::emit_reward_fund_deposited(
            tx_context::sender(ctx),
            object::uid_to_address(&reward_fund.id),
            amount,
            market_id
        );
    }

    public(friend) fun withdraw_reward_fund<T>(reward_fund: &mut RewardFund<T>, amount: u64, ctx: &TxContext): Balance<T> {
        let amt = std::u64::min(amount, balance::value(&reward_fund.balance));
        let withdraw_balance = balance::split(&mut reward_fund.balance, amt);

        let market_id = get_fund_market_id(reward_fund);
        event::emit_reward_fund_withdrawn(
            tx_context::sender(ctx),
            object::uid_to_address(&reward_fund.id),
            amt,
            market_id
        );

        withdraw_balance
    }

    public(friend) fun create_incentive_v3(ctx: &mut TxContext) {
        abort 0
    }

    public(friend) fun create_incentive_v3_with_market_id(storage: &Storage, ctx: &mut TxContext) {
        storage::version_verification(storage);
        let (market_id, _, _) = storage::get_storage_market_info(storage);
        let id = object::new(ctx);
        let addr = object::uid_to_address(&id);

        let i = Incentive {
            id,
            version: version::this_version(),
            pools: vec_map::empty(),
            borrow_fee_rate: 0,
            fee_balance: bag::new(ctx),
        };

        init_borrow_fee_fields(&mut i, ctx);
        dynamic_field::add(&mut i.id, MARKET_ID_KEY {}, market_id);
        
        transfer::share_object(i);
        event::emit_incentive_created(tx_context::sender(ctx), addr, market_id)
    }

    public fun init_for_main_market(_: &StorageAdminCap, incentive: &mut Incentive) {
        dynamic_field::add(&mut incentive.id, MARKET_ID_KEY {}, 0u64);
    }

    public fun init_fund_for_market<T>(_: &StorageAdminCap, reward_fund: &mut RewardFund<T>) {
        dynamic_field::add(&mut reward_fund.id, MARKET_ID_KEY {}, 0u64);
    }

    public(friend) fun create_pool<T>(incentive: &mut Incentive, storage: &Storage, asset_id: u8, ctx: &mut TxContext) {
        version_verification(incentive); // version check
        verify_market_storage_incentive(storage, incentive);

        let coin_type = type_name::into_string(type_name::get<T>());
        assert!(coin_type == storage::get_coin_type(storage, asset_id), error::invalid_coin_type()); // coin type check
        assert!(!vec_map::contains(&incentive.pools, &coin_type), error::duplicate_config());

        let id = object::new(ctx);
        let addr = object::uid_to_address(&id);

        let pool = AssetPool {
            id,
            asset: asset_id,
            asset_coin_type: coin_type,
            rules: vec_map::empty(),
        };

        vec_map::insert(&mut incentive.pools, coin_type, pool);
        let market_id = storage::get_market_id(storage);
        event::emit_asset_pool_created(tx_context::sender(ctx), asset_id, coin_type, addr, market_id);
    }

    public(friend) fun create_rule<T, RewardCoinType>(clock: &Clock, incentive: &mut Incentive, option: u8, ctx: &mut TxContext) {
        version_verification(incentive); // version check
        assert!(option == constants::option_type_supply() || option == constants::option_type_borrow(), error::invalid_option());

        let coin_type = type_name::into_string(type_name::get<T>());
        assert!(vec_map::contains(&incentive.pools, &coin_type), error::pool_not_found());

        let pool = vec_map::get_mut(&mut incentive.pools, &coin_type);

        let reward_coin_type = type_name::into_string(type_name::get<RewardCoinType>());
        assert!(!contains_rule(pool, option, reward_coin_type), error::duplicate_config());

        let id = object::new(ctx);
        let addr = object::uid_to_address(&id);
        let rule = Rule {
            id,
            option,
            enable: true,
            reward_coin_type: reward_coin_type,
            rate: 0,
            max_rate: 0,
            last_update_at: clock::timestamp_ms(clock),
            global_index: 0,
            user_index: table::new<address, u256>(ctx),
            user_total_rewards: table::new<address, u256>(ctx),
            user_rewards_claimed: table::new<address, u256>(ctx),
        };

        vec_map::insert(&mut pool.rules, addr, rule);
        let market_id = get_market_id(incentive);
        event::emit_rule_created(tx_context::sender(ctx), coin_type, addr, option, reward_coin_type, market_id);
    }

    public fun contains_rule(pool: &AssetPool, option: u8, reward_coin_type: String): bool {
        let rule_keys = vec_map::keys(&pool.rules);
        while (vector::length(&rule_keys) > 0) {
            let key = vector::pop_back(&mut rule_keys);

            let rule = vec_map::get(&pool.rules, &key);
            if (rule.option == option && rule.reward_coin_type == reward_coin_type) {
                return true
            }
        };

        false
    }

    public(friend) fun set_borrow_fee_rate(incentive: &mut Incentive, rate: u64, ctx: &TxContext) {
        version_verification(incentive); // version check
        // max 10% borrow fee rate
        assert!(rate <= constants::percentage_benchmark() / 10, error::invalid_value());

        incentive.borrow_fee_rate = rate;

        let market_id = get_market_id(incentive);
        event::emit_borrow_fee_rate_updated(tx_context::sender(ctx), rate, market_id);
    }

    public(friend) fun init_borrow_fee_fields(incentive: &mut Incentive, ctx: &mut TxContext) {
        let asset_borrow_fees = table::new<u8, u64>(ctx);
        let user_borrow_fees = table::new<address, Table<u8, u64>>(ctx);
        dynamic_field::add(&mut incentive.id, ASSET_BORROW_FEES_KEY {}, asset_borrow_fees);
        dynamic_field::add(&mut incentive.id, USER_BORROW_FEES_KEY {}, user_borrow_fees);
    }

    // set the borrow fee rate for the asset
    public(friend) fun set_asset_borrow_fee_rate(incentive: &mut Incentive, asset_id: u8, fee_rate: u64, ctx: &TxContext) {
        version_verification(incentive);
        assert!(fee_rate <= constants::percentage_benchmark() / 10, error::invalid_value());
        let asset_borrow_fees = dynamic_field::borrow_mut(&mut incentive.id, ASSET_BORROW_FEES_KEY {});
        if (!table::contains(asset_borrow_fees, asset_id)) {
            table::add(asset_borrow_fees, asset_id, fee_rate);
        } else {
            *table::borrow_mut(asset_borrow_fees, asset_id) = fee_rate;
        };

        let market_id = get_market_id(incentive);
        event::emit_asset_borrow_fee_rate_updated(tx_context::sender(ctx), asset_id, @0x0, fee_rate, market_id);
    }

    // if we want the asset uses default fee rate
    public(friend) fun remove_asset_borrow_fee_rate(incentive: &mut Incentive, asset_id: u8, ctx: &TxContext) {
        version_verification(incentive);
        let asset_borrow_fees = dynamic_field::borrow_mut<ASSET_BORROW_FEES_KEY ,Table<u8, u64>>(&mut incentive.id, ASSET_BORROW_FEES_KEY {});
        if (table::contains(asset_borrow_fees, asset_id)) {
            table::remove(asset_borrow_fees, asset_id);
        };

        let market_id = get_market_id(incentive);
        event::emit_asset_borrow_fee_rate_removed(tx_context::sender(ctx), asset_id, @0x0, market_id);
    }

    // set the user fee rate
    public(friend) fun set_user_borrow_fee_rate(incentive: &mut Incentive, user: address, asset_id: u8, fee_rate: u64, ctx: &mut TxContext) {
        version_verification(incentive);
        assert!(fee_rate <= constants::percentage_benchmark() / 10, error::invalid_value());
        let user_borrow_fees = dynamic_field::borrow_mut(&mut incentive.id, USER_BORROW_FEES_KEY {});
        if (!table::contains(user_borrow_fees, user)) {
            table::add(user_borrow_fees, user, table::new<u8, u64>(ctx));
        };
        let user_borrow_fee_rates = table::borrow_mut(user_borrow_fees, user);
        if (!table::contains(user_borrow_fee_rates, asset_id)) {
            table::add(user_borrow_fee_rates, asset_id, fee_rate);
        } else {
            *table::borrow_mut(user_borrow_fee_rates, asset_id) = fee_rate;
        };
        let market_id = get_market_id(incentive);
        event::emit_asset_borrow_fee_rate_updated(tx_context::sender(ctx), asset_id, user, fee_rate, market_id);
    }

    // if we want the user uses default fee rate
    public(friend) fun remove_user_borrow_fee_rate(incentive: &mut Incentive, user: address, asset_id: u8, ctx: &TxContext) {
        version_verification(incentive);
        let user_borrow_fees = dynamic_field::borrow_mut<USER_BORROW_FEES_KEY ,Table<address, Table<u8, u64>>>(&mut incentive.id, USER_BORROW_FEES_KEY {});
        if (table::contains(user_borrow_fees, user)) {
            let user_borrow_fee_rates = table::borrow_mut(user_borrow_fees, user);
            if (table::contains(user_borrow_fee_rates, asset_id)) {
                table::remove(user_borrow_fee_rates, asset_id);
            };
        };

        let market_id = get_market_id(incentive);
        event::emit_asset_borrow_fee_rate_removed(tx_context::sender(ctx), asset_id, user, market_id);
    }

    public(friend) fun withdraw_borrow_fee<T>(incentive: &mut Incentive, amount: u64, ctx: &TxContext): Balance<T> {
        version_verification(incentive); // version check

        let type_name = type_name::get<T>();
        assert!(bag::contains(&incentive.fee_balance, type_name), error::invalid_coin_type());

        let balance = bag::borrow_mut<TypeName, Balance<T>>(&mut incentive.fee_balance, type_name);
        let amt = std::u64::min(amount, balance::value(balance));

        let withdraw_balance = balance::split(balance, amt);

        let market_id = get_market_id(incentive);
        event::emit_borrow_fee_withdrawn(tx_context::sender(ctx), type_name::into_string(type_name), amt, market_id);

        withdraw_balance
    }

    fun deposit_borrow_fee<T>(incentive: &mut Incentive, balance_mut: &mut Balance<T>, fee_amount: u64, sender: address) {
        if (fee_amount > 0) {
            let type_name = type_name::get<T>();
            let fee = balance::split(balance_mut, fee_amount);

            if (bag::contains(&incentive.fee_balance, type_name)) {
                let existing_fee_balance = bag::borrow_mut<TypeName, Balance<T>>(&mut incentive.fee_balance, type_name);
                balance::join(existing_fee_balance, fee);
            } else {
                bag::add(&mut incentive.fee_balance, type_name, fee);
            };

            let market_id = get_market_id(incentive);
            event::emit_borrow_fee_deposited(sender, type_name::into_string(type_name), fee_amount, market_id);
        }
    }

    public(friend) fun set_enable_by_rule_id<T>(incentive: &mut Incentive, rule_id: address, enable: bool, ctx: &TxContext) {
        version_verification(incentive); // version check
        let rule = get_mut_rule<T>(incentive, rule_id);
        rule.enable = enable;

        let market_id = get_market_id(incentive);
        event::emit_reward_state_updated(tx_context::sender(ctx), rule_id, enable, market_id);
    }

    public(friend) fun set_max_reward_rate_by_rule_id<T>(incentive: &mut Incentive, rule_id: address, max_total_supply: u64, duration_ms: u64) {
        version_verification(incentive); // version check
        
        let rule = get_mut_rule<T>(incentive, rule_id);
        let max_rate = ray_math::ray_div((max_total_supply as u256), (duration_ms as u256));
        rule.max_rate = max_rate;

        let market_id = get_market_id(incentive);
        event::emit_max_reward_rate_updated(rule_id, max_total_supply, duration_ms, market_id);
    }

    public(friend) fun set_reward_rate_by_rule_id<T>(clock: &Clock, incentive: &mut Incentive, storage: &mut Storage, rule_id: address, total_supply: u64, duration_ms: u64, ctx: &TxContext) {
        version_verification(incentive); // version check
        // use @0x0 to update the reward state for convenience
        update_reward_state_by_asset<T>(clock, incentive, storage, @0x0);
        verify_market_storage_incentive(storage, incentive);
        let market_id = get_market_id(incentive);
        let rate = 0;
        if (duration_ms > 0) {
            rate = ray_math::ray_div((total_supply as u256), (duration_ms as u256));
        };

        let coin_type = type_name::into_string(type_name::get<T>());
        let rule = get_mut_rule<T>(incentive, rule_id);

        assert!(rule.max_rate == 0 || rate <= rule.max_rate, error::invalid_value());

        rule.rate = rate;
        rule.last_update_at = clock::timestamp_ms(clock);

        event::emit_reward_rate_updated(
            tx_context::sender(ctx),
            coin_type,
            rule_id,
            rate,
            total_supply,
            duration_ms,
            rule.last_update_at,
            market_id
        );
    }

    fun base_claim_reward_by_rules<RewardCoinType>(clock: &Clock, storage: &mut Storage, incentive: &mut Incentive, reward_fund: &mut RewardFund<RewardCoinType>, coin_types: vector<String>, rule_ids: vector<address>, user: address): Balance<RewardCoinType> {
        version_verification(incentive);
        assert!(vector::length(&coin_types) == vector::length(&rule_ids), error::invalid_coin_type());
        verify_market_storage_incentive(storage, incentive);
        verify_market_incentive_funds(incentive, reward_fund);
        let reward_balance = balance::zero<RewardCoinType>();
        let rule_indices = vector::empty<u256>();
        let i = 0;
        let len = vector::length(&coin_types);
        while (i < len) {
            let rule_id = *vector::borrow(&rule_ids, i);
            let coin_type = *vector::borrow(&coin_types, i);
            let (index, _balance) = base_claim_reward_by_rule<RewardCoinType>(clock, storage, incentive, reward_fund, coin_type,  rule_id, user);
            vector::push_back(&mut rule_indices, index);

            _ = balance::join(&mut reward_balance, _balance);
            i = i + 1;
        };

        let reward_balance_value = balance::value(&reward_balance);
        let market_id = get_market_id(incentive);
        event::emit_reward_claimed(
            user,
            reward_balance_value,
            type_name::into_string(type_name::get<RewardCoinType>()),
            rule_ids,
            rule_indices,
            market_id
        );

        reward_balance
    }

    fun base_claim_reward_by_rule<RewardCoinType>(clock: &Clock, storage: &mut Storage, incentive: &mut Incentive, reward_fund: &mut RewardFund<RewardCoinType>, coin_type: String, rule_id: address, user: address): (u256, Balance<RewardCoinType>) {
        assert!(vec_map::contains(&incentive.pools, &coin_type), error::pool_not_found());

        let pool = vec_map::get_mut(&mut incentive.pools, &coin_type);
        assert!(vec_map::contains(&pool.rules, &rule_id), error::rule_not_found());

        let rule = vec_map::get_mut(&mut pool.rules, &rule_id);
        let reward_coin_type = type_name::into_string(type_name::get<RewardCoinType>());
        assert!(rule.reward_coin_type == reward_coin_type, error::invalid_coin_type());

        // exits if the rule is not enabled
        if (!rule.enable) {
            return (rule.global_index, balance::zero<RewardCoinType>())
        };

        // update the user reward
        update_reward_state_by_rule(clock, storage, pool.asset, rule, user);

        let user_total_reward = *table::borrow(&rule.user_total_rewards, user);

        if (!table::contains(&rule.user_rewards_claimed, user)) {
            table::add(&mut rule.user_rewards_claimed, user, 0);
        };
        let user_reward_claimed = table::borrow_mut(&mut rule.user_rewards_claimed, user);

        let reward = if (user_total_reward > *user_reward_claimed) {
            user_total_reward - *user_reward_claimed
        } else {
            0
        };
        *user_reward_claimed = user_total_reward;

        if (reward > 0) {
            return (rule.global_index, balance::split(&mut reward_fund.balance, (reward as u64)))
        } else {
            return (rule.global_index, balance::zero<RewardCoinType>())
        }
    }

    // returns: user_total_supply, user_total_borrow, total_supply, total_borrow
    public fun get_effective_balance(storage: &mut Storage, asset: u8, user: address): (u256, u256, u256, u256) {
        // get the total supply and borrow
        let (total_supply, total_borrow) = storage::get_total_supply(storage, asset);
        let (user_supply, user_borrow) = storage::get_user_balance(storage, asset, user);
        let (supply_index, borrow_index) = storage::get_index(storage, asset);

        // calculate the total supply and borrow
        let total_supply = ray_math::ray_mul(total_supply, supply_index);
        let total_borrow = ray_math::ray_mul(total_borrow, borrow_index);
        let user_supply = ray_math::ray_mul(user_supply, supply_index);
        let user_borrow = ray_math::ray_mul(user_borrow, borrow_index);

        // calculate the user effective supply
        let user_effective_supply: u256 = 0;
        if (user_supply > user_borrow) {
            user_effective_supply = user_supply - user_borrow;
        };

        // calculate the user effective borrow
        let user_effective_borrow: u256 = 0;
        if (user_borrow > user_supply) {
            user_effective_borrow = user_borrow - user_supply;
        };

        (user_effective_supply, user_effective_borrow, total_supply, total_borrow)
    }

    /** update the reward state by asset
     * @param clock: the clock
     * @param incentive: the incentive
     * @param storage: the storage
     * @param user: the user address
     */
    public fun update_reward_state_by_asset<T>(clock: &Clock, incentive: &mut Incentive, storage: &mut Storage, user: address) {
        version_verification(incentive);
        verify_market_storage_incentive(storage, incentive);
        let coin_type = type_name::into_string(type_name::get<T>());
        if (!vec_map::contains(&incentive.pools, &coin_type)) {
            return
        };
        let pool = vec_map::get_mut(&mut incentive.pools, &coin_type);
        let (user_effective_supply, user_effective_borrow, total_supply, total_borrow) = get_effective_balance(storage, pool.asset, user);

        // update rewards
        let rule_keys = vec_map::keys(&pool.rules);
        while (vector::length(&rule_keys) > 0) {
            let key = vector::pop_back(&mut rule_keys);
            let rule = vec_map::get_mut(&mut pool.rules, &key);

            // update the user reward
            update_reward_state_by_rule_and_balance(clock, rule, user, user_effective_supply, user_effective_borrow, total_supply, total_borrow);
        }
    }

    fun update_reward_state_by_rule(clock: &Clock, storage: &mut Storage, asset: u8, rule: &mut Rule, user: address) {
        let (user_effective_supply, user_effective_borrow, total_supply, total_borrow) = get_effective_balance(storage, asset, user);
        update_reward_state_by_rule_and_balance(clock, rule, user, user_effective_supply, user_effective_borrow, total_supply, total_borrow);
    }

    // update the global index and user reward
    // @param clock: the clock
    // @param rule: the incentive rule
    // @param user: the user address
    // @param user_effective_supply: the user effective supply
    // @param user_effective_borrow: the user effective borrow
    // @param total_supply: the total supply (total supply * supply index)
    // @param total_borrow: the total borrow (total borrow * borrow index)
    fun update_reward_state_by_rule_and_balance(clock: &Clock, rule: &mut Rule, user: address, user_effective_supply: u256, user_effective_borrow: u256, total_supply: u256, total_borrow: u256) {
        let new_global_index = calculate_global_index(clock, rule, total_supply, total_borrow);
        let new_user_total_reward = calculate_user_reward(rule, new_global_index, user, user_effective_supply, user_effective_borrow);
        // update the user index to the new global index
        if (table::contains(&rule.user_index, user)) {
            let user_index = table::borrow_mut(&mut rule.user_index, user);
            *user_index = new_global_index;
        } else {
            table::add(&mut rule.user_index, user, new_global_index);
        };

        // update the user rewards to plus the new reward
        if (table::contains(&rule.user_total_rewards, user)) {
            let user_total_reward = table::borrow_mut(&mut rule.user_total_rewards, user);
            *user_total_reward = new_user_total_reward;
        } else {
            table::add(&mut rule.user_total_rewards, user, new_user_total_reward);
        };

        // update the last update time and global index
        rule.last_update_at = clock::timestamp_ms(clock);
        rule.global_index = new_global_index;    
    }

    fun calculate_global_index(clock: &Clock, rule: &Rule, total_supply: u256, total_borrow: u256): u256 {
        let total_balance = if (rule.option == constants::option_type_supply()) {
            total_supply
        } else if (rule.option == constants::option_type_borrow()) {
            total_borrow
        } else {
            abort 0
        };
        
        let now = clock::timestamp_ms(clock);
        let duration = now - rule.last_update_at;
        let index_increased = if (duration == 0 || total_balance == 0) {
            0
        } else {
            (rule.rate * (duration as u256)) / total_balance
        };
        rule.global_index + index_increased
    }

    fun calculate_user_reward(rule: &Rule, global_index: u256, user: address, user_effective_supply: u256, user_effective_borrow: u256): u256 {
        let user_balance = if (rule.option == constants::option_type_supply()) {
            user_effective_supply
        } else if (rule.option == constants::option_type_borrow()) {
            user_effective_borrow
        } else {
            abort 0
        };
        let user_index_diff = global_index - get_user_index_by_rule(rule, user);
        let user_reward = get_user_total_rewards_by_rule(rule, user);
        user_reward + ray_math::ray_mul(user_balance, user_index_diff)
    }

    fun get_mut_rule<T>(incentive: &mut Incentive, rule_id: address): &mut Rule {
        let coin_type = type_name::into_string(type_name::get<T>());
        assert!(vec_map::contains(&incentive.pools, &coin_type), error::pool_not_found());

        let pool = vec_map::get_mut(&mut incentive.pools, &coin_type);
        assert!(vec_map::contains(&pool.rules, &rule_id), error::rule_not_found());

        vec_map::get_mut(&mut pool.rules, &rule_id)
    }

    // Public Get Functions
    /// Returns the pools of the incentive.Keys are the coin type of the pool.
    public fun pools(incentive: &Incentive): &VecMap<String, AssetPool> {
        &incentive.pools
    }

    // Pool
    public fun get_pool_info(pool: &AssetPool): (address, u8, String, &VecMap<address, Rule>) {
        (object::uid_to_address(&pool.id), pool.asset, pool.asset_coin_type, &pool.rules)
    }

    // Rule Info
    // id: UID,
    // option: u8,
    // enable: bool,
    // reward_coin_type: String,
    // rate: u256, 
    // last_update_at: u64,
    // global_index: u256,
    // user_index: Table<address, u256>,
    // user_total_rewards: Table<address, u256>,
    // user_rewards_claimed: Table<address, u256>,
    public fun get_rule_info(rule: &Rule): (address, u8, bool, String, u256, u64, u256, &Table<address, u256>, &Table<address, u256>, &Table<address, u256>) {
        (
            object::uid_to_address(&rule.id), 
            rule.option, 
            rule.enable, 
            rule.reward_coin_type, 
            rule.rate, 
            rule.last_update_at, 
            rule.global_index, 
            &rule.user_index, 
            &rule.user_total_rewards, 
            &rule.user_rewards_claimed, 
        )
    }

    public fun get_user_index_by_rule(rule: &Rule, user: address): u256 {
        if (table::contains(&rule.user_index, user)) {
            *table::borrow(&rule.user_index, user)
        } else {
            0
        }
    }

    public fun get_user_total_rewards_by_rule(rule: &Rule, user: address): u256 {
        if (table::contains(&rule.user_total_rewards, user)) {
            *table::borrow(&rule.user_total_rewards, user)
        } else {
            0
        }
    }

    public fun get_user_rewards_claimed_by_rule(rule: &Rule, user: address): u256 {
        if (table::contains(&rule.user_rewards_claimed, user)) {
            *table::borrow(&rule.user_rewards_claimed, user)
        } else {
            0
        }
    }

    public fun get_balance_value_by_reward_fund<T>(reward_fund: &RewardFund<T>): u64 {
        balance::value(&reward_fund.balance)
    }

    public fun get_user_claimable_rewards(clock: &Clock, storage: &mut Storage, incentive: &Incentive, user: address): vector<ClaimableReward> {
        version_verification(incentive);
        verify_market_storage_incentive(storage, incentive);
        
        let data = vec_map::empty<String, ClaimableReward>();

        let pools = vec_map::keys(&incentive.pools);
        while (vector::length(&pools) > 0) {
            let pool_key = vector::pop_back(&mut pools);
            let asset_pool = vec_map::get(&incentive.pools, &pool_key);
            let rules = vec_map::keys(&asset_pool.rules);
            let (user_effective_supply, user_effective_borrow, total_supply, total_borrow) = get_effective_balance(storage, asset_pool.asset, user);

            while (vector::length(&rules) > 0) {
                let rule_key = vector::pop_back(&mut rules);
                let rule = vec_map::get(&asset_pool.rules, &rule_key);

                let global_index = calculate_global_index(clock, rule, total_supply, total_borrow);
                let user_total_reward = calculate_user_reward(rule, global_index, user, user_effective_supply, user_effective_borrow);
                let user_claimed_reward = get_user_rewards_claimed_by_rule(rule, user);

                let user_claimable_reward = if (user_total_reward > user_claimed_reward) {
                    user_total_reward - user_claimed_reward
                } else {
                    0
                };

                let key = ascii::string(ascii::into_bytes(pool_key));
                ascii::append(&mut key, ascii::string(b","));
                ascii::append(&mut key, rule.reward_coin_type); 

                if (!vec_map::contains(&data, &key)) {
                    vec_map::insert(&mut data, key, ClaimableReward{
                        asset_coin_type: pool_key,
                        reward_coin_type: rule.reward_coin_type,
                        user_claimable_reward: 0,
                        user_claimed_reward: 0,
                        rule_ids: vector::empty()
                    });
                };

                let claimable_reward = vec_map::get_mut(&mut data, &key);
                claimable_reward.user_claimable_reward = claimable_reward.user_claimable_reward + user_claimable_reward;
                claimable_reward.user_claimed_reward = claimable_reward.user_claimed_reward + user_claimed_reward;
                // skip if no reward in this rule
                if (user_claimable_reward > 0) {
                    vector::push_back(&mut claimable_reward.rule_ids, rule_key);
                };
            };
        };

        let return_data = vector::empty<ClaimableReward>();
        let keys = vec_map::keys(&data);
        while (vector::length(&keys) > 0) {
            let key = vector::pop_back(&mut keys);
            let claimable_reward = vec_map::get(&data, &key);
            // skip if no data in this rule
            if (claimable_reward.user_claimable_reward > 0 || claimable_reward.user_claimed_reward > 0) {
                vector::push_back(&mut return_data, *claimable_reward);
            }
        };

        return_data
    }

    /// parse the claimable rewards to return the asset coin types, reward coin types, user total rewards, user claimed rewards, and rule ids
    public fun parse_claimable_rewards(claimable_rewards: vector<ClaimableReward>): (vector<String>, vector<String>, vector<u256>, vector<u256>, vector<vector<address>>) {
        let asset_coin_types = vector::empty<String>();
        let reward_coin_types = vector::empty<String>();
        let user_claimable_rewards = vector::empty<u256>();
        let user_claimed_rewards = vector::empty<u256>();
        let rule_ids = vector::empty<vector<address>>();

        while (vector::length(&claimable_rewards) > 0) {
            let claimable_reward = vector::pop_back(&mut claimable_rewards);
            vector::push_back(&mut asset_coin_types, claimable_reward.asset_coin_type);
            vector::push_back(&mut reward_coin_types, claimable_reward.reward_coin_type);
            vector::push_back(&mut user_claimable_rewards, claimable_reward.user_claimable_reward);
            vector::push_back(&mut user_claimed_rewards, claimable_reward.user_claimed_reward);
            vector::push_back(&mut rule_ids, claimable_reward.rule_ids);
        };

        (asset_coin_types, reward_coin_types, user_claimable_rewards, user_claimed_rewards, rule_ids)
    }

    // Public functions
    public fun claim_reward<RewardCoinType>(clock: &Clock, incentive: &mut Incentive, storage: &mut Storage, reward_fund: &mut RewardFund<RewardCoinType>, coin_types: vector<String>, rule_ids: vector<address>, ctx: &mut TxContext): Balance<RewardCoinType> {
        base_claim_reward_by_rules<RewardCoinType>(clock, storage, incentive, reward_fund, coin_types, rule_ids, tx_context::sender(ctx))
    }

    #[allow(lint(self_transfer))]
    public entry fun claim_reward_entry<RewardCoinType>(clock: &Clock, incentive: &mut Incentive, storage: &mut Storage, reward_fund: &mut RewardFund<RewardCoinType>, coin_types: vector<String>, rule_ids: vector<address>, ctx: &mut TxContext) {
        let balance = base_claim_reward_by_rules<RewardCoinType>(clock, storage, incentive, reward_fund, coin_types, rule_ids, tx_context::sender(ctx));
        transfer::public_transfer(coin::from_balance(balance, ctx), tx_context::sender(ctx))
    }

    public fun claim_reward_with_account_cap<RewardCoinType>(clock: &Clock, incentive: &mut Incentive, storage: &mut Storage, reward_fund: &mut RewardFund<RewardCoinType>, coin_types: vector<String>, rule_ids: vector<address>, account_cap: &AccountCap): Balance<RewardCoinType> {
        let sender = account::account_owner(account_cap);
        base_claim_reward_by_rules<RewardCoinType>(clock, storage, incentive, reward_fund, coin_types, rule_ids, sender)
    }

    public entry fun entry_deposit<CoinType>(
        clock: &Clock,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        deposit_coin: Coin<CoinType>,
        amount: u64,
        incentive_v2: &mut IncentiveV2,
        incentive_v3: &mut Incentive,
        ctx: &mut TxContext
    ) {
        let user = tx_context::sender(ctx);
        // incentive_v2::update_reward_all(clock, incentive_v2, storage, asset, user);
        update_reward_state_by_asset<CoinType>(clock, incentive_v3, storage, user);

        lending::deposit_coin<CoinType>(clock, storage, pool, asset, deposit_coin, amount, ctx);
    }

    public fun deposit_with_account_cap<CoinType>(
        clock: &Clock,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        deposit_coin: Coin<CoinType>,
        incentive_v2: &mut IncentiveV2,
        incentive_v3: &mut Incentive,
        account_cap: &AccountCap
    ) {
        let owner = account::account_owner(account_cap);
        // incentive_v2::update_reward_all(clock, incentive_v2, storage, asset, owner);
        update_reward_state_by_asset<CoinType>(clock, incentive_v3, storage, owner);

        lending::deposit_with_account_cap<CoinType>(clock, storage, pool, asset, deposit_coin, account_cap);
    }

    public entry fun entry_deposit_on_behalf_of_user<CoinType>(
        clock: &Clock,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        deposit_coin: Coin<CoinType>,
        amount: u64,
        user: address,
        incentive_v2: &mut IncentiveV2,
        incentive_v3: &mut Incentive,
        ctx: &mut TxContext
    ) {
        // incentive_v2::update_reward_all(clock, incentive_v2, storage, asset, user);
        update_reward_state_by_asset<CoinType>(clock, incentive_v3, storage, user);

        lending::deposit_on_behalf_of_user<CoinType>(clock, storage, pool, asset, user, deposit_coin, amount, ctx);
    }

    // V1: Only supports non-SUI assets. May be deprecated in the future, use v2 instead.
    public entry fun entry_withdraw<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        amount: u64,
        incentive_v2: &mut IncentiveV2,
        incentive_v3: &mut Incentive,
        ctx: &mut TxContext
    ) {
        let user = tx_context::sender(ctx);
        // incentive_v2::update_reward_all(clock, incentive_v2, storage, asset, user);
        update_reward_state_by_asset<CoinType>(clock, incentive_v3, storage, user);

        let _balance = lending::withdraw_coin<CoinType>(clock, oracle, storage, pool, asset, amount, ctx);
        let _coin = coin::from_balance(_balance, ctx);
        transfer::public_transfer(_coin, user);
    }

    // V2: Supports all assets. Adds sui_system and ctx parameters for SUI pools with staking/unstaking.
    public entry fun entry_withdraw_v2<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        amount: u64,
        incentive_v2: &mut IncentiveV2,
        incentive_v3: &mut Incentive,
        system_state: &mut SuiSystemState,
        ctx: &mut TxContext
    ) {
        let user = tx_context::sender(ctx);
        // incentive_v2::update_reward_all(clock, incentive_v2, storage, asset, user);
        update_reward_state_by_asset<CoinType>(clock, incentive_v3, storage, user);

        let _balance = lending::withdraw_coin_v2<CoinType>(clock, oracle, storage, pool, asset, amount, system_state, ctx);
        let _coin = coin::from_balance(_balance, ctx);
        transfer::public_transfer(_coin, user);
    }

    // V1: Only supports non-SUI assets. May be deprecated in the future, use v2 instead.
    public fun withdraw_with_account_cap<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        amount: u64,
        incentive_v2: &mut IncentiveV2,
        incentive_v3: &mut Incentive,
        account_cap: &AccountCap
    ): Balance<CoinType> {
        let owner = account::account_owner(account_cap);
        // incentive_v2::update_reward_all(clock, incentive_v2, storage, asset, owner);
        update_reward_state_by_asset<CoinType>(clock, incentive_v3, storage, owner);

        lending::withdraw_with_account_cap<CoinType>(clock, oracle, storage, pool, asset, amount, account_cap)
    }

    // V2: Supports all assets. Adds sui_system and ctx parameters for SUI pools with staking/unstaking.
    public fun withdraw_with_account_cap_v2<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        amount: u64,
        incentive_v2: &mut IncentiveV2,
        incentive_v3: &mut Incentive,
        account_cap: &AccountCap,
        system_state: &mut SuiSystemState,
        ctx: &mut TxContext
    ): Balance<CoinType> {
        let owner = account::account_owner(account_cap);
        // incentive_v2::update_reward_all(clock, incentive_v2, storage, asset, owner);
        update_reward_state_by_asset<CoinType>(clock, incentive_v3, storage, owner);

        lending::withdraw_with_account_cap_v2<CoinType>(clock, oracle, storage, pool, asset, amount, account_cap, system_state, ctx)
    }

    // V1: Only supports non-SUI assets. May be deprecated in the future, use v2 instead.
    public fun withdraw<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        amount: u64,
        incentive_v2: &mut IncentiveV2,
        incentive_v3: &mut Incentive,
        ctx: &mut TxContext
    ): Balance<CoinType> {
        let user = tx_context::sender(ctx);
        // incentive_v2::update_reward_all(clock, incentive_v2, storage, asset, user);
        update_reward_state_by_asset<CoinType>(clock, incentive_v3, storage, user);

        let _balance = lending::withdraw_coin<CoinType>(clock, oracle, storage, pool, asset, amount, ctx);
        return _balance
    }

    // V2: Supports all assets. Adds sui_system and ctx parameters for SUI pools with staking/unstaking.
    public fun withdraw_v2<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        amount: u64,
        incentive_v2: &mut IncentiveV2,
        incentive_v3: &mut Incentive,
        system_state: &mut SuiSystemState,
        ctx: &mut TxContext
    ): Balance<CoinType> {
        let user = tx_context::sender(ctx);
        // incentive_v2::update_reward_all(clock, incentive_v2, storage, asset, user);
        update_reward_state_by_asset<CoinType>(clock, incentive_v3, storage, user);

        let _balance = lending::withdraw_coin_v2<CoinType>(clock, oracle, storage, pool, asset, amount, system_state, ctx);
        return _balance
    }

    // deprecated
    fun get_borrow_fee(incentive: &Incentive, amount: u64): u64 {
        if (incentive.borrow_fee_rate > 0) {
            amount * incentive.borrow_fee_rate / constants::percentage_benchmark()
        } else {
            0
        }
    }

    public fun get_borrow_fee_v2(incentive: &Incentive, user: address, asset_id: u8, amount: u64): u64 {
        let asset_borrow_fees = dynamic_field::borrow<ASSET_BORROW_FEES_KEY ,Table<u8, u64>>(&incentive.id, ASSET_BORROW_FEES_KEY {});
        
        let fee_rate = incentive.borrow_fee_rate;

        if (table::contains(asset_borrow_fees, asset_id)) {
                fee_rate = *table::borrow(asset_borrow_fees, asset_id)
        };

        let user_borrow_fees = dynamic_field::borrow<USER_BORROW_FEES_KEY ,Table<address, Table<u8, u64>>>(&incentive.id, USER_BORROW_FEES_KEY {});
        if (table::contains(user_borrow_fees, user) 
            && (table::contains(table::borrow(user_borrow_fees, user), asset_id))) {
                fee_rate = *table::borrow(table::borrow(user_borrow_fees, user), asset_id)
        };

        if (fee_rate > 0) {
            amount * fee_rate / constants::percentage_benchmark()
        } else {
            0
        }
    }

    // V1: Only supports non-SUI assets. May be deprecated in the future, use v2 instead.
    public entry fun entry_borrow<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        amount: u64,
        incentive_v2: &mut IncentiveV2,
        incentive_v3: &mut Incentive,
        ctx: &mut TxContext
    ) {
        let user = tx_context::sender(ctx);
        // incentive_v2::update_reward_all(clock, incentive_v2, storage, asset, user);
        update_reward_state_by_asset<CoinType>(clock, incentive_v3, storage, user);

        let fee = get_borrow_fee_v2(incentive_v3, user, asset, amount);

        let _balance = lending::borrow_coin<CoinType>(clock, oracle, storage, pool, asset, amount + fee, ctx);

        deposit_borrow_fee(incentive_v3, &mut _balance, fee, user);

        let _coin = coin::from_balance(_balance, ctx);
        transfer::public_transfer(_coin, tx_context::sender(ctx));
    }

    // V2: Supports all assets. Adds sui_system and ctx parameters for SUI pools with staking/unstaking.
    public entry fun entry_borrow_v2<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        amount: u64,
        incentive_v2: &mut IncentiveV2,
        incentive_v3: &mut Incentive,
        system_state: &mut SuiSystemState,
        ctx: &mut TxContext
    ) {
        let user = tx_context::sender(ctx);
        // incentive_v2::update_reward_all(clock, incentive_v2, storage, asset, user);
        update_reward_state_by_asset<CoinType>(clock, incentive_v3, storage, user);

        let fee = get_borrow_fee_v2(incentive_v3, user, asset, amount);

        let _balance = lending::borrow_coin_v2<CoinType>(clock, oracle, storage, pool, asset, amount + fee, system_state, ctx);

        deposit_borrow_fee(incentive_v3, &mut _balance, fee, user);

        let _coin = coin::from_balance(_balance, ctx);
        transfer::public_transfer(_coin, tx_context::sender(ctx));
    }

    // V1: Only supports non-SUI assets. May be deprecated in the future, use v2 instead.
    public fun borrow_with_account_cap<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        amount: u64,
        incentive_v2: &mut IncentiveV2,
        incentive_v3: &mut Incentive,
        account_cap: &AccountCap
    ): Balance<CoinType> {
        let owner = account::account_owner(account_cap);
        // incentive_v2::update_reward_all(clock, incentive_v2, storage, asset, owner);
        update_reward_state_by_asset<CoinType>(clock, incentive_v3, storage, owner);

        let fee = get_borrow_fee_v2(incentive_v3, owner, asset, amount);

        let _balance = lending::borrow_with_account_cap<CoinType>(clock, oracle, storage, pool, asset, amount + fee, account_cap);

        deposit_borrow_fee(incentive_v3, &mut _balance, fee, owner);

        _balance
    }

    // V2: Supports all assets. Adds sui_system and ctx parameters for SUI pools with staking/unstaking.
    public fun borrow_with_account_cap_v2<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        amount: u64,
        incentive_v2: &mut IncentiveV2,
        incentive_v3: &mut Incentive,
        account_cap: &AccountCap,
        system_state: &mut SuiSystemState,
        ctx: &mut TxContext
    ): Balance<CoinType> {
        let owner = account::account_owner(account_cap);
        // incentive_v2::update_reward_all(clock, incentive_v2, storage, asset, owner);
        update_reward_state_by_asset<CoinType>(clock, incentive_v3, storage, owner);

        let fee = get_borrow_fee_v2(incentive_v3, owner, asset, amount);

        let _balance = lending::borrow_with_account_cap_v2<CoinType>(clock, oracle, storage, pool, asset, amount + fee, account_cap, system_state, ctx);

        deposit_borrow_fee(incentive_v3, &mut _balance, fee, owner);

        _balance
    }

    // V1: Only supports non-SUI assets. May be deprecated in the future, use v2 instead.
    public fun borrow<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        amount: u64,
        incentive_v2: &mut IncentiveV2,
        incentive_v3: &mut Incentive,
        ctx: &mut TxContext
    ): Balance<CoinType> {
        let user = tx_context::sender(ctx);
        // incentive_v2::update_reward_all(clock, incentive_v2, storage, asset, user);
        update_reward_state_by_asset<CoinType>(clock, incentive_v3, storage, user);

        let fee = get_borrow_fee_v2(incentive_v3, user, asset, amount);

        let _balance = lending::borrow_coin<CoinType>(clock, oracle, storage, pool, asset, amount + fee, ctx);

        deposit_borrow_fee(incentive_v3, &mut _balance, fee, user);

        _balance
    }

    // V2: Supports all assets. Adds sui_system and ctx parameters for SUI pools with staking/unstaking.
    public fun borrow_v2<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        amount: u64,
        incentive_v2: &mut IncentiveV2,
        incentive_v3: &mut Incentive,
        system_state: &mut SuiSystemState,
        ctx: &mut TxContext
    ): Balance<CoinType> {
        let user = tx_context::sender(ctx);
        // incentive_v2::update_reward_all(clock, incentive_v2, storage, asset, user);
        update_reward_state_by_asset<CoinType>(clock, incentive_v3, storage, user);

        let fee = get_borrow_fee_v2(incentive_v3, user, asset, amount);

        let _balance = lending::borrow_coin_v2<CoinType>(clock, oracle, storage, pool, asset, amount + fee, system_state, ctx);

        deposit_borrow_fee(incentive_v3, &mut _balance, fee, user);

        _balance
    }

    public entry fun entry_repay<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        repay_coin: Coin<CoinType>,
        amount: u64,
        incentive_v2: &mut IncentiveV2,
        incentive_v3: &mut Incentive,
        ctx: &mut TxContext
    ) {
        let user = tx_context::sender(ctx);
        // incentive_v2::update_reward_all(clock, incentive_v2, storage, asset, tx_context::sender(ctx));
        update_reward_state_by_asset<CoinType>(clock, incentive_v3, storage, user);

        let _balance = lending::repay_coin<CoinType>(clock, oracle, storage, pool, asset, repay_coin, amount, ctx);
        let _balance_value = balance::value(&_balance);
        if (_balance_value > 0) {
            let _coin = coin::from_balance(_balance, ctx);
            transfer::public_transfer(_coin, tx_context::sender(ctx));
        } else {
            balance::destroy_zero(_balance)
        }
    }

    public fun repay_with_account_cap<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        repay_coin: Coin<CoinType>,
        incentive_v2: &mut IncentiveV2,
        incentive_v3: &mut Incentive,
        account_cap: &AccountCap
    ): Balance<CoinType> {
        let owner = account::account_owner(account_cap);
        // incentive_v2::update_reward_all(clock, incentive_v2, storage, asset, owner);
        update_reward_state_by_asset<CoinType>(clock, incentive_v3, storage, owner);

        lending::repay_with_account_cap<CoinType>(clock, oracle, storage, pool, asset, repay_coin, account_cap)
    }

    #[allow(lint(self_transfer))]
    public fun entry_repay_on_behalf_of_user<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        repay_coin: Coin<CoinType>,
        amount: u64,
        user: address,
        incentive_v2: &mut IncentiveV2,
        incentive_v3: &mut Incentive,
        ctx: &mut TxContext
    ) {
        // incentive_v2::update_reward_all(clock, incentive_v2, storage, asset, user);
        update_reward_state_by_asset<CoinType>(clock, incentive_v3, storage, user);

        let _balance = lending::repay_on_behalf_of_user<CoinType>(clock, oracle, storage, pool, asset, user, repay_coin, amount, ctx);
        let _balance_value = balance::value(&_balance);
        if (_balance_value > 0) {
            let _coin = coin::from_balance(_balance, ctx);
            transfer::public_transfer(_coin, tx_context::sender(ctx));
        } else {
            balance::destroy_zero(_balance)
        }
    }

    public fun repay<CoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        repay_coin: Coin<CoinType>,
        amount: u64,
        incentive_v2: &mut IncentiveV2,
        incentive_v3: &mut Incentive,
        ctx: &mut TxContext
    ): Balance<CoinType> {
        let user = tx_context::sender(ctx);
        // incentive_v2::update_reward_all(clock, incentive_v2, storage, asset, user);
        update_reward_state_by_asset<CoinType>(clock, incentive_v3, storage, user);

        let _balance = lending::repay_coin<CoinType>(clock, oracle, storage, pool, asset, repay_coin, amount, ctx);
        return _balance
    }

    // V1: Only supports non-SUI assets. May be deprecated in the future, use v2 instead.
    public entry fun entry_liquidation<DebtCoinType, CollateralCoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        debt_asset: u8,
        debt_pool: &mut Pool<DebtCoinType>,
        debt_coin: Coin<DebtCoinType>,
        collateral_asset: u8,
        collateral_pool: &mut Pool<CollateralCoinType>,
        liquidate_user: address,
        liquidate_amount: u64,
        incentive_v2: &mut IncentiveV2,
        incentive_v3: &mut Incentive,
        ctx: &mut TxContext
    ) {
        // incentive_v2::update_reward_all(clock, incentive_v2, storage, collateral_asset, @0x0);
        // incentive_v2::update_reward_all(clock, incentive_v2, storage, debt_asset, @0x0);

        update_reward_state_by_asset<DebtCoinType>(clock, incentive_v3, storage, liquidate_user);
        update_reward_state_by_asset<CollateralCoinType>(clock, incentive_v3, storage, liquidate_user);
        let sender = tx_context::sender(ctx);
        let (_bonus_balance, _excess_balance) = lending::liquidation(
            clock,
            oracle,
            storage,
            debt_asset,
            debt_pool,
            debt_coin,
            collateral_asset,
            collateral_pool,
            liquidate_user,
            liquidate_amount,
            ctx
        );

        // handle excess balance
        let _excess_value = balance::value(&_excess_balance);
        if (_excess_value > 0) {
            let _coin = coin::from_balance(_excess_balance, ctx);
            transfer::public_transfer(_coin, sender);
        } else {
            balance::destroy_zero(_excess_balance)
        };

        // handle bonus balance
        let _bonus_value = balance::value(&_bonus_balance);
        if (_bonus_value > 0) {
            let _coin = coin::from_balance(_bonus_balance, ctx);
            transfer::public_transfer(_coin, sender);
        } else {
            balance::destroy_zero(_bonus_balance)
        }
    }

    // V2: Supports all assets. Adds sui_system and ctx parameters for SUI pools with staking/unstaking.
    public entry fun entry_liquidation_v2<DebtCoinType, CollateralCoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        debt_asset: u8,
        debt_pool: &mut Pool<DebtCoinType>,
        debt_coin: Coin<DebtCoinType>,
        collateral_asset: u8,
        collateral_pool: &mut Pool<CollateralCoinType>,
        liquidate_user: address,
        liquidate_amount: u64,
        incentive_v2: &mut IncentiveV2,
        incentive_v3: &mut Incentive,
        system_state: &mut SuiSystemState, 
        ctx: &mut TxContext
    ) {
        // incentive_v2::update_reward_all(clock, incentive_v2, storage, collateral_asset, @0x0);
        // incentive_v2::update_reward_all(clock, incentive_v2, storage, debt_asset, @0x0);

        update_reward_state_by_asset<DebtCoinType>(clock, incentive_v3, storage, liquidate_user);
        update_reward_state_by_asset<CollateralCoinType>(clock, incentive_v3, storage, liquidate_user);
        let sender = tx_context::sender(ctx);
        let (_bonus_balance, _excess_balance) = lending::liquidation_v2(
            clock,
            oracle,
            storage,
            debt_asset,
            debt_pool,
            debt_coin,
            collateral_asset,
            collateral_pool,
            liquidate_user,
            liquidate_amount,
            system_state,
            ctx,
        );

        // handle excess balance
        let _excess_value = balance::value(&_excess_balance);
        if (_excess_value > 0) {
            let _coin = coin::from_balance(_excess_balance, ctx);
            transfer::public_transfer(_coin, sender);
        } else {
            balance::destroy_zero(_excess_balance)
        };

        // handle bonus balance
        let _bonus_value = balance::value(&_bonus_balance);
        if (_bonus_value > 0) {
            let _coin = coin::from_balance(_bonus_balance, ctx);
            transfer::public_transfer(_coin, sender);
        } else {
            balance::destroy_zero(_bonus_balance)
        }
    }

    // V1: Only supports non-SUI assets. May be deprecated in the future, use v2 instead.
    public fun liquidation<DebtCoinType, CollateralCoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        debt_asset: u8,
        debt_pool: &mut Pool<DebtCoinType>,
        debt_balance: Balance<DebtCoinType>,
        collateral_asset: u8,
        collateral_pool: &mut Pool<CollateralCoinType>,
        liquidate_user: address,
        incentive_v2: &mut IncentiveV2,
        incentive_v3: &mut Incentive,
        ctx: &mut TxContext
    ): (Balance<CollateralCoinType>, Balance<DebtCoinType>) {
        // incentive_v2::update_reward_all(clock, incentive_v2, storage, collateral_asset, @0x0);
        // incentive_v2::update_reward_all(clock, incentive_v2, storage, debt_asset, @0x0);

        update_reward_state_by_asset<DebtCoinType>(clock, incentive_v3, storage, liquidate_user);
        update_reward_state_by_asset<CollateralCoinType>(clock, incentive_v3, storage, liquidate_user);

        lending::liquidation_non_entry(
            clock,
            oracle,
            storage,
            debt_asset,
            debt_pool,
            debt_balance,
            collateral_asset,
            collateral_pool,
            liquidate_user,
            ctx
        )
    }

    // V2: Supports all assets. Adds sui_system and ctx parameters for SUI pools with staking/unstaking.
    public fun liquidation_v2<DebtCoinType, CollateralCoinType>(
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        debt_asset: u8,
        debt_pool: &mut Pool<DebtCoinType>,
        debt_balance: Balance<DebtCoinType>,
        collateral_asset: u8,
        collateral_pool: &mut Pool<CollateralCoinType>,
        liquidate_user: address,
        incentive_v2: &mut IncentiveV2,
        incentive_v3: &mut Incentive,
        system_state: &mut SuiSystemState, 
        ctx: &mut TxContext
    ): (Balance<CollateralCoinType>, Balance<DebtCoinType>) {
        // incentive_v2::update_reward_all(clock, incentive_v2, storage, collateral_asset, @0x0);
        // incentive_v2::update_reward_all(clock, incentive_v2, storage, debt_asset, @0x0);

        update_reward_state_by_asset<DebtCoinType>(clock, incentive_v3, storage, liquidate_user);
        update_reward_state_by_asset<CollateralCoinType>(clock, incentive_v3, storage, liquidate_user);

        lending::liquidation_non_entry_v2(
            clock,
            oracle,
            storage,
            debt_asset,
            debt_pool,
            debt_balance,
            collateral_asset,
            collateral_pool,
            liquidate_user,
            system_state,
            ctx,
        )
    }

    public fun get_market_id(incentive_v3: &Incentive): u64 {
        *dynamic_field::borrow<MARKET_ID_KEY, u64>(&incentive_v3.id, MARKET_ID_KEY {})
    }

    public fun get_fund_market_id<T>(reward_fund: &RewardFund<T>): u64 {
        *dynamic_field::borrow<MARKET_ID_KEY, u64>(&reward_fund.id, MARKET_ID_KEY {})
    }

    public fun verify_market_storage_incentive(storage: &Storage, incentive: &Incentive) {
        assert!(storage::get_market_id(storage) == get_market_id(incentive), error::unmatched_market_id());
    }

    public fun verify_market_incentive_funds<T>(incentive: &Incentive, funds_pool: &RewardFund<T>) {
        assert!(get_market_id(incentive) == get_fund_market_id(funds_pool), error::unmatched_market_id());
    }

    #[test_only]
    /// Return asset, asset_coin_type, rules number
    public fun get_asset_pool_params_for_testing<CoinType>(incentive_v3: &Incentive): (address,u8, String, u64) {
        let key = type_name::into_string(type_name::get<CoinType>());
        let pool = vec_map::get(&incentive_v3.pools, &key);
        (
            object::uid_to_address(&pool.id),
            pool.asset,
            pool.asset_coin_type, 
            vec_map::size(&pool.rules)
        )
    }

    #[test_only]
    /// Return coin_type, balance amount
    public fun get_reward_fund_params_for_testing<CoinType>(reward_fund: &RewardFund<CoinType>): (String, u64) {
        (
            reward_fund.coin_type,
            balance::value(&reward_fund.balance)
        )
    }

    #[test_only]
    /// Return enable, rate, last_update_at, global_index
    public fun get_rule_params_for_testing<CoinType, RewardCoinType>(incentive_v3: &Incentive, option: u8): (address, bool, u256, u64, u256) {
        let key = type_name::into_string(type_name::get<CoinType>());
        let reward_type_str = type_name::into_string(type_name::get<RewardCoinType>());

        let pool = vec_map::get(&incentive_v3.pools, &key);
        let i = vec_map::size(&pool.rules);
        while (i > 0) {
            let (_, rule) = vec_map::get_entry_by_idx(&pool.rules, i - 1);
            if (rule.option == option && rule.reward_coin_type == reward_type_str) {
                return (
                    object::uid_to_address(&rule.id),
                    rule.enable,
                    rule.rate, 
                    rule.last_update_at,
                    rule.global_index
                )
            };
            i = i - 1;
        };
        abort 0
    }

    #[test_only]
    public fun get_mut_rule_for_testing<CoinType>(incentive_v3: &mut Incentive, rule_id: address): &mut Rule {
        get_mut_rule<CoinType>(incentive_v3, rule_id)
    }

    #[test_only]
    public fun get_borrow_fee_for_testing(incentive_v3: &Incentive, amount: u64): u64 {
        get_borrow_fee(incentive_v3, amount)
    }

    #[test_only]
    public fun get_borrow_fee_v2_for_testing(incentive_v3: &mut Incentive, user: address, asset_id: u8, amount: u64): u64 {
        get_borrow_fee_v2(incentive_v3, user, asset_id, amount)
    }

    #[test_only]
    public fun update_index_for_testing<CoinType>(clock: &Clock, incentive: &mut Incentive, storage: &mut Storage)  {
        update_reward_state_by_asset<CoinType>(clock, incentive, storage, @0x0);
    }

    #[test_only]
    public fun delete_rule_for_testing<CoinType>(incentive: &mut Incentive, rule_id: address) {
        let coin_type = type_name::into_string(type_name::get<CoinType>());
        let pool = vec_map::get_mut(&mut incentive.pools, &coin_type);
        let (_addr, Rule { 
            id,
            option,
            enable,
            reward_coin_type,
            rate,
            max_rate,
            last_update_at,
            global_index,
            user_index,
            user_total_rewards,
            user_rewards_claimed
        }) = vec_map::remove(&mut pool.rules, &rule_id);
        object::delete(id);
        table::drop(user_index);
        table::drop(user_total_rewards);
        table::drop(user_rewards_claimed);
    }
    
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        let id = object::new(ctx);
        let addr = object::uid_to_address(&id);

        let i = Incentive {
            id,
            version: version::this_version(),
            pools: vec_map::empty(),
            borrow_fee_rate: 0,
            fee_balance: bag::new(ctx),
        };

        init_borrow_fee_fields(&mut i, ctx);
        dynamic_field::add(&mut i.id, MARKET_ID_KEY {}, 0);
        
        transfer::share_object(i);
        event::emit_incentive_created(tx_context::sender(ctx), addr, 0)
    }
}
