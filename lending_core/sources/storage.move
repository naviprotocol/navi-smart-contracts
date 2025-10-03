#[allow(unused_field)]
module lending_core::storage {
    use std::vector;
    use std::type_name;
    use std::ascii::{String};

    use sui::transfer;
    use sui::event::emit;
    use sui::object::{Self, UID};
    use sui::table::{Self, Table};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, CoinMetadata};
    use sui::tx_context::{Self, TxContext};

    use math::ray_math;
    use lending_core::pool::{Self, Pool, PoolAdminCap};
    use lending_core::version::{Self};
    use lending_core::error::{Self};
    use lending_core::constants::{Self};

    friend lending_core::logic;
    friend lending_core::flash_loan;

    struct OwnerCap has key, store {
        id: UID,
    }

    struct StorageAdminCap has key, store {
        id: UID,
    }

    struct Storage has key, store {
        id: UID,
        version: u64,
        paused: bool, // Whether the pool is paused
        reserves: Table<u8, ReserveData>, // Reserve list. like: {0: ReserveData<USDT>, 1: ReserveData<ETH>}
        reserves_count: u8, // Total reserves count
        users: vector<address>, // uset list, like [0x01, 0x02]
        user_info: Table<address, UserInfo>
    }

    // supply_balance & borrow_balance, It is used to keep track of all balance
    struct ReserveData has store {
        id: u8, // reserve index
        oracle_id: u8, // The id from navi oracle, update from admin
        coin_type: String, // The coin type, like 0x02::sui::SUI
        is_isolated: bool, // THe isolated of the reserve, update from admin
        supply_cap_ceiling: u256, // Total supply limit of reserve, update from admin
        borrow_cap_ceiling: u256, // Total borrow percentage of reserve, update from admin
        current_supply_rate: u256, // Current supply rates, update from protocol
        current_borrow_rate: u256, // Current borrow rates, update from protocol
        current_supply_index: u256, // The supply exchange rate, update from protocol
        current_borrow_index: u256, // The borrow exchange rate, update from protocol
        supply_balance: TokenBalance, // The total amount deposit inside the pool
        borrow_balance: TokenBalance, // The total amount borrow inside the pool
        last_update_timestamp: u64, // Last update time for reserve, update from protocol
        // Loan-to-value, used to define the maximum amount of assets that can be borrowed against a given collateral
        ltv: u256,
        treasury_factor: u256, // The fee ratio, update from admin
        treasury_balance: u256, // The fee balance, update from protocol
        borrow_rate_factors: BorrowRateFactors, // Basic Configuration, rate and multiplier etc.
        liquidation_factors: LiquidationFactors, // Liquidation configuration
        // Reserved fields, no use for now
        reserve_field_a: u256,
        reserve_field_b: u256,
        reserve_field_c: u256,
    }

    struct UserInfo has store {
        collaterals: vector<u8>,
        loans: vector<u8>
    }

    struct ReserveConfigurationMap has copy, store {
        data: u256
    }

    struct UserConfigurationMap has copy, store {
        data: u256
    }

    struct TokenBalance has store {
        user_state: Table<address, u256>,
        total_supply: u256,
    }

    struct BorrowRateFactors has store {
        // Base borrow rate of the asset
        base_rate: u256,
        multiplier: u256,
        jump_rate_multiplier: u256,
        // Used to set community incentives
        reserve_factor: u256,
        optimal_utilization: u256
    }

    struct LiquidationFactors has store {
        ratio: u256, 
        bonus: u256,
        threshold: u256,
    }

    // Event
    struct StorageConfiguratorSetting has copy, drop {  
        sender: address,
        configurator: address,
        value: bool,
    }

    struct Paused has copy, drop {
        paused: bool
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
    }
    
    // Entry
    fun init(ctx: &mut TxContext) {
        transfer::public_transfer(StorageAdminCap {id: object::new(ctx)}, tx_context::sender(ctx));
        transfer::public_transfer(OwnerCap {id: object::new(ctx)}, tx_context::sender(ctx));

        transfer::share_object(Storage {
            id: object::new(ctx),
            version: version::this_version(),
            paused: false,
            reserves: table::new<u8, ReserveData>(ctx),
            reserves_count: 0,
            users: vector::empty<address>(),
            user_info: table::new<address, UserInfo>(ctx),
        })
    }

    public fun when_not_paused(storage: &Storage) {
        assert!(!pause(storage), error::paused())
    }

    public fun version_verification(storage: &Storage) {
        version::pre_check_version(storage.version)
    }

    public entry fun version_migrate(_: &StorageAdminCap, storage: &mut Storage) {
        assert!(storage.version < version::this_version(), error::not_available_version());
        storage.version = version::this_version();
    }

    public entry fun init_reserve<CoinType>(
        _: &StorageAdminCap,
        pool_admin_cap: &PoolAdminCap,
        clock: &Clock,
        storage: &mut Storage,
        oracle_id: u8,
        is_isolated: bool,
        supply_cap_ceiling: u256,
        borrow_cap_ceiling: u256,
        base_rate: u256,
        optimal_utilization: u256,
        multiplier: u256,
        jump_rate_multiplier: u256,
        reserve_factor: u256,
        ltv: u256,
        treasury_factor: u256,
        liquidation_ratio: u256,
        liquidation_bonus: u256,
        liquidation_threshold: u256,
        coin_metadata: &CoinMetadata<CoinType>,
        ctx: &mut TxContext
    ) {
        version_verification(storage);

        let current_idx = storage.reserves_count;
        assert!(current_idx < constants::max_number_of_reserves(), error::no_more_reserves_allowed());
        reserve_validation<CoinType>(storage);

        percentage_ray_validation(borrow_cap_ceiling);
        percentage_ray_validation(optimal_utilization);
        percentage_ray_validation(reserve_factor);
        percentage_ray_validation(treasury_factor);
        percentage_ray_validation(liquidation_ratio);
        percentage_ray_validation(liquidation_bonus);

        percentage_ray_validation(ltv);
        percentage_ray_validation(liquidation_threshold);
        
        let reserve_data = ReserveData {
            id: storage.reserves_count,
            oracle_id: oracle_id,
            coin_type: type_name::into_string(type_name::get<CoinType>()),
            is_isolated: is_isolated,
            supply_cap_ceiling: supply_cap_ceiling,
            borrow_cap_ceiling: borrow_cap_ceiling,
            current_supply_rate: 0,
            current_borrow_rate: 0,
            current_supply_index: ray_math::ray(),
            current_borrow_index: ray_math::ray(),
            ltv: ltv,
            treasury_factor: treasury_factor,
            treasury_balance: 0,
            supply_balance: TokenBalance {
                user_state: table::new<address, u256>(ctx),
                total_supply: 0,
            },
            borrow_balance: TokenBalance {
                user_state: table::new<address, u256>(ctx),
                total_supply: 0,
            },
            last_update_timestamp: clock::timestamp_ms(clock),
            borrow_rate_factors: BorrowRateFactors {
                base_rate: base_rate,
                multiplier: multiplier,
                jump_rate_multiplier: jump_rate_multiplier,
                reserve_factor: reserve_factor,
                optimal_utilization: optimal_utilization,
            },
            liquidation_factors: LiquidationFactors {
                ratio: liquidation_ratio,
                bonus: liquidation_bonus,
                threshold: liquidation_threshold,
            },
            reserve_field_a: 0,
            reserve_field_b: 0,
            reserve_field_c: 0
        };

        table::add(&mut storage.reserves, current_idx, reserve_data);
        storage.reserves_count = current_idx + 1;

        let decimals = coin::get_decimals(coin_metadata);
        pool::create_pool<CoinType>(pool_admin_cap, decimals, ctx);
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    //                    The methods required for protocol parameter updates                   //
    //////////////////////////////////////////////////////////////////////////////////////////////
    public entry fun set_pause(_: &OwnerCap, storage: &mut Storage, val: bool) {
        version_verification(storage);

        storage.paused = val;
        emit(Paused {paused: val})
    }

    public fun set_supply_cap(_: &OwnerCap, storage: &mut Storage, asset: u8, supply_cap_ceiling: u256) {
        version_verification(storage);

        let reserve = table::borrow_mut(&mut storage.reserves, asset);
        reserve.supply_cap_ceiling = supply_cap_ceiling;
    }

    public fun set_borrow_cap(_: &OwnerCap, storage: &mut Storage, asset: u8, borrow_cap_ceiling: u256) {
        version_verification(storage);
        percentage_ray_validation(borrow_cap_ceiling);

        let reserve = table::borrow_mut(&mut storage.reserves, asset);
        reserve.borrow_cap_ceiling = borrow_cap_ceiling;
    }

    public fun set_ltv(_: &OwnerCap, storage: &mut Storage, asset: u8, ltv: u256) {
        version_verification(storage);
        percentage_ray_validation(ltv);

        let reserve = table::borrow_mut(&mut storage.reserves, asset);
        reserve.ltv = ltv;
    }

    public fun set_treasury_factor(_: &OwnerCap, storage: &mut Storage, asset: u8, treasury_factor: u256) {
        version_verification(storage);
        percentage_ray_validation(treasury_factor);

        let reserve = table::borrow_mut(&mut storage.reserves, asset);
        reserve.treasury_factor = treasury_factor
    }

    public fun set_base_rate(_: &OwnerCap, storage: &mut Storage, asset: u8, base_rate: u256) {
        version_verification(storage);

        let reserve = table::borrow_mut(&mut storage.reserves, asset);
        reserve.borrow_rate_factors.base_rate = base_rate;
    }

    public fun set_multiplier(_: &OwnerCap, storage: &mut Storage, asset: u8, multiplier: u256) {
        version_verification(storage);

        let reserve = table::borrow_mut(&mut storage.reserves, asset);
        reserve.borrow_rate_factors.multiplier = multiplier;
    }

    public fun set_jump_rate_multiplier(_: &OwnerCap, storage: &mut Storage, asset: u8, jump_rate_multiplier: u256) {
        version_verification(storage);

        let reserve = table::borrow_mut(&mut storage.reserves, asset);
        reserve.borrow_rate_factors.jump_rate_multiplier = jump_rate_multiplier;
    }

    public fun set_reserve_factor(_: &OwnerCap, storage: &mut Storage, asset: u8, reserve_factor: u256) {
        version_verification(storage);
        percentage_ray_validation(reserve_factor);

        let reserve = table::borrow_mut(&mut storage.reserves, asset);
        reserve.borrow_rate_factors.reserve_factor = reserve_factor;
    }

    public fun set_optimal_utilization(_: &OwnerCap, storage: &mut Storage, asset: u8, optimal_utilization: u256) {
        version_verification(storage);
        percentage_ray_validation(optimal_utilization);

        let reserve = table::borrow_mut(&mut storage.reserves, asset);
        reserve.borrow_rate_factors.optimal_utilization = optimal_utilization;
    }

    public fun set_liquidation_ratio(_: &OwnerCap, storage: &mut Storage, asset: u8, liquidation_ratio: u256) {
        version_verification(storage);
        percentage_ray_validation(liquidation_ratio);

        let reserve = table::borrow_mut(&mut storage.reserves, asset);
        reserve.liquidation_factors.ratio = liquidation_ratio;
    }

    public fun set_liquidation_bonus(_: &OwnerCap, storage: &mut Storage, asset: u8, liquidation_bonus: u256) {
        version_verification(storage);
        percentage_ray_validation(liquidation_bonus);
        
        let reserve = table::borrow_mut(&mut storage.reserves, asset);
        reserve.liquidation_factors.bonus = liquidation_bonus;
    }

    public fun set_liquidation_threshold(_: &OwnerCap, storage: &mut Storage, asset: u8, liquidation_threshold: u256) {
        version_verification(storage);
        percentage_ray_validation(liquidation_threshold);

        let reserve = table::borrow_mut(&mut storage.reserves, asset);
        reserve.liquidation_factors.threshold = liquidation_threshold;
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    //                             The methods required to get value                            //
    //////////////////////////////////////////////////////////////////////////////////////////////
    public fun reserve_validation<CoinType>(storage: &Storage) {
        // Title: Get the status of the pool. true: The pool is paused
        let name = type_name::into_string(type_name::get<CoinType>());
        let count = storage.reserves_count;
        let i = 0;
        
        while (i < count) {
            let reserve = table::borrow(&storage.reserves, i);
            assert!(reserve.coin_type != name, error::duplicate_reserve());
            i = i + 1;
        }
    }
    
    public fun pause(storage: &Storage): bool {
        storage.paused
    }

    public fun get_reserves_count(storage: &Storage): u8 {
        storage.reserves_count
    }

    public fun get_user_assets(storage: &Storage, user: address): (vector<u8>, vector<u8>){
        if (!table::contains(&storage.user_info, user)) {
            return (vector::empty<u8>(), vector::empty<u8>())
        };

        let user_info = table::borrow(&storage.user_info, user);
        (user_info.collaterals, user_info.loans)
    }

    public fun get_oracle_id(storage: &Storage, asset: u8): u8 {
        table::borrow(&storage.reserves, asset).oracle_id
    }

    public fun get_coin_type(storage: &Storage, asset: u8): String {
        table::borrow(&storage.reserves, asset).coin_type
    }

    public fun get_supply_cap_ceiling(storage: &mut Storage, asset: u8): u256 {
        table::borrow(&storage.reserves, asset).supply_cap_ceiling
    }

    public fun get_borrow_cap_ceiling_ratio(storage: &mut Storage, asset: u8): u256 {
        table::borrow(&storage.reserves, asset).borrow_cap_ceiling
    }

    public fun get_current_rate(storage: &mut Storage, asset: u8): (u256, u256) {
        let reserve = table::borrow(&storage.reserves, asset);
        (
            reserve.current_supply_rate,
            reserve.current_borrow_rate
        )
    }

    public fun get_index(storage: &mut Storage, asset: u8): (u256, u256) {
        let reserve = table::borrow(&storage.reserves, asset);
        (
            reserve.current_supply_index,
            reserve.current_borrow_index
        )
    }

    public fun get_total_supply(storage: &mut Storage, asset: u8): (u256, u256) {
        let reserve = table::borrow(&storage.reserves, asset);
        (
            reserve.supply_balance.total_supply,
            reserve.borrow_balance.total_supply
        )
    }

    public fun get_user_balance(storage: &mut Storage, asset: u8, user: address): (u256, u256) {
        let reserve = table::borrow(&storage.reserves, asset);
        let supply_balance = 0;
        let borrow_balance = 0;

        if (table::contains(&reserve.supply_balance.user_state, user)) {
            supply_balance = *table::borrow(&reserve.supply_balance.user_state, user)
        };
        if (table::contains(&reserve.borrow_balance.user_state, user)) {
            borrow_balance = *table::borrow(&reserve.borrow_balance.user_state, user)
        };

        (supply_balance, borrow_balance)
    }

    public fun get_last_update_timestamp(storage: &Storage, asset: u8): u64 {
        table::borrow(&storage.reserves, asset).last_update_timestamp
    }

    public fun get_asset_ltv(storage: &Storage, asset: u8): u256 {
        table::borrow(&storage.reserves, asset).ltv
    }

    public fun get_treasury_factor(storage: &mut Storage, asset: u8): u256 {
        table::borrow(&storage.reserves, asset).treasury_factor
    }

    public fun get_treasury_balance(storage: &Storage, asset: u8): u256 {
        table::borrow(&storage.reserves, asset).treasury_balance
    }

    public fun get_borrow_rate_factors(storage: &mut Storage, asset: u8): (u256, u256, u256, u256, u256)  {
        let reserve = table::borrow(&storage.reserves, asset);
        (
            reserve.borrow_rate_factors.base_rate,
            reserve.borrow_rate_factors.multiplier,
            reserve.borrow_rate_factors.jump_rate_multiplier,
            reserve.borrow_rate_factors.reserve_factor,
            reserve.borrow_rate_factors.optimal_utilization,
        )
    }

    public fun get_liquidation_factors(storage: &mut Storage, asset: u8): (u256, u256, u256) {
        let reserve = table::borrow(&storage.reserves, asset);
        (
            reserve.liquidation_factors.ratio,
            reserve.liquidation_factors.bonus,
            reserve.liquidation_factors.threshold,
        )
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    //                         The Methods required for protocol updates                        //
    //////////////////////////////////////////////////////////////////////////////////////////////
    public(friend) fun update_interest_rate(storage: &mut Storage, asset: u8, new_borrow_rate: u256, new_supply_rate: u256) {
        version_verification(storage);

        let reserve = table::borrow_mut(&mut storage.reserves, asset);
        reserve.current_supply_rate = new_supply_rate;
        reserve.current_borrow_rate = new_borrow_rate;
    }

    // input order: borrow_index, supply_index
    public(friend) fun update_state(
        storage: &mut Storage,
        asset: u8,
        new_borrow_index: u256,
        new_supply_index: u256,
        last_update_timestamp: u64,
        scaled_treasury_amount: u256
    ) {
        version_verification(storage);

        let reserve = table::borrow_mut(&mut storage.reserves, asset);

        reserve.current_borrow_index = new_borrow_index;
        reserve.current_supply_index = new_supply_index;
        reserve.last_update_timestamp = last_update_timestamp;
        reserve.treasury_balance = reserve.treasury_balance + scaled_treasury_amount;
    }

    public(friend) fun increase_balance_for_pool(storage: &mut Storage, asset: u8, in_supply: u256, in_borrow: u256) {
        version_verification(storage);

        let reserve = table::borrow_mut(&mut storage.reserves, asset);
        let supply_balance = &mut reserve.supply_balance;
        let borrow_balance = &mut reserve.borrow_balance;

        supply_balance.total_supply = supply_balance.total_supply + in_supply;
        borrow_balance.total_supply = borrow_balance.total_supply + in_borrow;
    }

    public(friend) fun increase_supply_balance(storage: &mut Storage, asset: u8, user: address, amount: u256) {
        version_verification(storage);

        let reserve = table::borrow_mut(&mut storage.reserves, asset);
        let supply_balance = &mut reserve.supply_balance;

        increase_balance(supply_balance, user, amount)
    }

    public(friend) fun decrease_supply_balance(storage: &mut Storage, asset: u8, user: address, amount: u256) {
        version_verification(storage);

        let reserve = table::borrow_mut(&mut storage.reserves, asset);
        let supply_balance = &mut reserve.supply_balance;

        decrease_balance(supply_balance, user, amount)
    }

    public(friend) fun increase_borrow_balance(storage: &mut Storage, asset: u8, user: address, amount: u256) {
        version_verification(storage);

        let reserve = table::borrow_mut(&mut storage.reserves, asset);
        let borrow_balance = &mut reserve.borrow_balance;
        
        increase_balance(borrow_balance, user, amount)
    }

    public(friend) fun decrease_borrow_balance(storage: &mut Storage, asset: u8, user: address, amount: u256) {
        version_verification(storage);
        
        let reserve = table::borrow_mut(&mut storage.reserves, asset);
        let borrow_balance = &mut reserve.borrow_balance;

        decrease_balance(borrow_balance, user, amount)
    }

    fun increase_balance(_balance: &mut TokenBalance, user: address, amount: u256) {
        let current_amount = 0;

        if (table::contains(&_balance.user_state, user)) {
            current_amount = table::remove(&mut _balance.user_state, user)
        };

        table::add(&mut _balance.user_state, user, current_amount + amount);
        _balance.total_supply = _balance.total_supply + amount
    }

    fun decrease_balance(_balance: &mut TokenBalance, user: address, amount: u256) {
        let current_amount = 0;

        if (table::contains(&_balance.user_state, user)) {
            current_amount = table::remove(&mut _balance.user_state, user)
        };
        assert!(current_amount >= amount, error::insufficient_balance());

        table::add(&mut _balance.user_state, user, current_amount - amount);
        _balance.total_supply = _balance.total_supply - amount
    }

    public(friend) fun increase_treasury_balance(storage: &mut Storage, asset: u8, amount: u256) {
        let reserve = table::borrow_mut(&mut storage.reserves, asset);
        reserve.treasury_balance = reserve.treasury_balance + amount;
    }

    public(friend) fun increase_total_supply_balance(storage: &mut Storage, asset: u8, amount: u256) {
        let reserve = table::borrow_mut(&mut storage.reserves, asset);
        let total_supply_balance = &mut reserve.supply_balance;

        total_supply_balance.total_supply = total_supply_balance.total_supply + amount;
    }

    public(friend) fun update_user_loans(storage: &mut Storage, asset: u8, user: address) {
        if (!table::contains(&storage.user_info, user)) {
            let loans = vector::empty<u8>();
            vector::push_back(&mut loans, asset);

            let user_info = UserInfo {
                collaterals: vector::empty<u8>(),
                loans: loans,
            };
            table::add(&mut storage.user_info, user, user_info)
        } else {
            let user_info = table::borrow_mut(&mut storage.user_info, user);
            if (!vector::contains(&user_info.loans, &asset)) {
                vector::push_back(&mut user_info.loans, asset)
            }
        };
    }
    
    public(friend) fun remove_user_loans(storage: &mut Storage, asset: u8, user: address) {
        let user_info = table::borrow_mut(&mut storage.user_info, user);
        let (exist, index) = vector::index_of(&user_info.loans, &asset);
        if (exist) {
            _ = vector::remove(&mut user_info.loans, index)
        }
    }

    public(friend) fun update_user_collaterals(storage: &mut Storage, asset: u8, user: address) {
        if (!table::contains(&storage.user_info, user)) {
            let collaterals = vector::empty<u8>();
            vector::push_back(&mut collaterals, asset);

            let user_info = UserInfo {
                collaterals: collaterals,
                loans: vector::empty<u8>(),
            };
            table::add(&mut storage.user_info, user, user_info)
        } else {
            let user_info = table::borrow_mut(&mut storage.user_info, user);
            if (!vector::contains(&user_info.collaterals, &asset)) {
                vector::push_back(&mut user_info.collaterals, asset)
            }
        };
    }

    public(friend) fun remove_user_collaterals(storage: &mut Storage, asset: u8, user: address) {
        let user_info = table::borrow_mut(&mut storage.user_info, user);
        let (exist, index) = vector::index_of(&user_info.collaterals, &asset);
        if (exist) {
            _ = vector::remove(&mut user_info.collaterals, index)
        }
    }

    public fun withdraw_treasury<CoinType>(
        _: &StorageAdminCap,
        pool_admin_cap: &PoolAdminCap,
        storage: &mut Storage,
        asset: u8,
        pool: &mut Pool<CoinType>,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let coin_type = get_coin_type(storage, asset);
        assert!(coin_type == type_name::into_string(type_name::get<CoinType>()), error::invalid_coin_type());

        let (supply_index, _) = get_index(storage, asset);
        let reserve = table::borrow_mut(&mut storage.reserves, asset);

        // Without this conversion, then when typpe 1USDT (decimals is 6), the amount of 0.001 will be withdrawn(protocol decimals is 9)
        let withdraw_amount = pool::normal_amount(pool, amount);

        let scaled_treasury_value = reserve.treasury_balance;
        let treasury_value = ray_math::ray_mul(scaled_treasury_value, supply_index);
        let withdrawable_value = math::safe_math::min((withdraw_amount as u256), treasury_value); // get the smallest one value, which is the amount that can be withdrawn

        {
            // decrease treasury balance
            let scaled_withdrawable_value = ray_math::ray_div(withdrawable_value, supply_index);
            reserve.treasury_balance = scaled_treasury_value - scaled_withdrawable_value;
            decrease_total_supply_balance(storage, asset, scaled_withdrawable_value);
        };

        let withdrawable_amount = pool::unnormal_amount(pool, (withdrawable_value as u64));

        pool::withdraw_reserve_balance<CoinType>(
            pool_admin_cap,
            pool,
            withdrawable_amount,
            recipient,
            ctx
        );

        let scaled_treasury_value_after_withdraw = get_treasury_balance(storage, asset);
        emit(WithdrawTreasuryEvent {
            sender: tx_context::sender(ctx),
            recipient: recipient,
            asset: asset,
            amount: withdrawable_value,
            poolId: object::uid_to_address(pool::uid(pool)),
            before: scaled_treasury_value,
            after: scaled_treasury_value_after_withdraw,
            index: supply_index,
        })
    }

    public fun destory_user(_: &StorageAdminCap, _storage: &mut Storage) {
        abort 0
    }

    public(friend) fun decrease_total_supply_balance(storage: &mut Storage, asset: u8, amount: u256) {
        let reserve = table::borrow_mut(&mut storage.reserves, asset);
        let total_supply_balance = &mut reserve.supply_balance;

        total_supply_balance.total_supply = total_supply_balance.total_supply - amount;
    }

    fun percentage_ray_validation(value: u256) {
        assert!(value <= ray_math::ray(), error::invalid_value());
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    //                           The methods required for unit testing                          //
    //////////////////////////////////////////////////////////////////////////////////////////////
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }

    #[test_only]
    public fun init_reserve_for_testing<CoinType>(
        cap: &StorageAdminCap,
        pool_admin_cap: &PoolAdminCap,
        clock: &Clock,
        storage: &mut Storage,
        oracle_id: u8,
        is_isolated: bool,
        supply_cap_ceiling: u256,
        borrow_cap_ceiling: u256,
        base_rate: u256,
        optimal_utilization: u256,
        multiplier: u256,
        jump_rate_multiplier: u256,
        reserve_factor: u256,
        ltv: u256,
        treasury_factor: u256,
        liquidation_ratio: u256,
        liquidation_bonus: u256,
        liquidation_threshold: u256,
        coin_metadata: &CoinMetadata<CoinType>,
        ctx: &mut TxContext
    ) {
        init_reserve<CoinType>(
            cap,
            pool_admin_cap,
            clock,
            storage,
            oracle_id,
            is_isolated,
            supply_cap_ceiling,
            borrow_cap_ceiling,
            base_rate,
            optimal_utilization,
            multiplier,
            jump_rate_multiplier,
            reserve_factor,
            ltv,
            treasury_factor,
            liquidation_ratio,
            liquidation_bonus,
            liquidation_threshold,
            coin_metadata,
            ctx
        )
    }

    #[test_only]
    public fun update_state_for_testing(
        storage: &mut Storage,
        asset: u8,
        new_borrow_index: u256,
        new_supply_index: u256,
        last_update_timestamp: u64,
        scaled_treasury_amount: u256
    ) {
        update_state(storage, asset, new_borrow_index, new_supply_index, last_update_timestamp, scaled_treasury_amount)
    }

    #[test_only]
    public fun update_interest_rate_for_testing(storage: &mut Storage, asset: u8, new_borrow_rate: u256, new_supply_rate: u256) {
        update_interest_rate(storage, asset, new_borrow_rate, new_supply_rate)
    }

    #[test_only]
    public fun increase_supply_balance_for_testing(storage: &mut Storage, asset: u8, user: address, amount: u256) {
        increase_supply_balance(storage, asset, user, amount)
    }

    #[test_only]
    public fun decrease_supply_balance_for_testing(storage: &mut Storage, asset: u8, user: address, amount: u256) {
        decrease_supply_balance(storage, asset, user, amount)
    }

    #[test_only]
    public fun increase_borrow_balance_for_testing(storage: &mut Storage, asset: u8, user: address, amount: u256) {
        increase_borrow_balance(storage, asset, user, amount)
    }

    #[test_only]
    public fun decrease_borrow_balance_for_testing(storage: &mut Storage, asset: u8, user: address, amount: u256) {
        decrease_borrow_balance(storage, asset, user, amount)
    }

    #[test_only]
    public fun update_user_loans_for_testing(storage: &mut Storage, asset: u8, user: address) {
        update_user_loans(storage, asset, user)
    }

    #[test_only]
    public fun remove_user_loans_for_testing(storage: &mut Storage, asset: u8, user: address) {
        remove_user_loans(storage, asset, user)
    }

    #[test_only]
    public fun update_user_collaterals_for_testing(storage: &mut Storage, asset: u8, user: address) {
        update_user_collaterals(storage, asset, user)
    }

    #[test_only]
    public fun remove_user_collaterals_for_testing(storage: &mut Storage, asset: u8, user: address) {
        remove_user_collaterals(storage, asset, user)
    }

    #[test_only]
    public fun get_storage_info_for_testing(storage: &Storage): (bool, u8) {
        (
            storage.paused,
            storage.reserves_count,
        )
    }

    #[test_only]
    public fun get_reserve_info_for_testing(storage: &Storage, asset: u8): (bool) {
        let reserve = table::borrow(&storage.reserves, asset);
        (
            reserve.is_isolated
        )
    }

    public fun get_reserve_for_testing(storage: &Storage, asset: u8): (&ReserveData) {
        table::borrow(&storage.reserves, asset)
    }

    #[test_only]
    public fun get_pool(storage: &Storage, asset: u8): &ReserveData {
        table::borrow(&storage.reserves, asset)
    }

    #[test_only]
    public fun increase_balance_for_pool_for_testing(storage: &mut Storage, asset: u8, in_supply: u256, in_borrow: u256) {
        increase_balance_for_pool(storage, asset, in_supply, in_borrow);
    }

    #[test_only]
    public fun increase_treasury_balance_for_testing(storage: &mut Storage, asset: u8, amount: u256) {
        increase_treasury_balance(storage, asset, amount);
    }

    #[test_only]
    public fun increase_total_supply_balance_for_testing(storage: &mut Storage, asset: u8, amount: u256) {
        increase_total_supply_balance(storage, asset, amount);
    }
}