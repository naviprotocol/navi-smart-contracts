module lending_core::flash_loan {
    use std::type_name;
    use std::ascii::{Self, String};

    use sui::transfer;
    use sui::event::emit;
    use sui::object::{Self, UID};
    use sui::table::{Self, Table};
    use sui::clock::{Clock};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};

    use math::ray_math;
    use lending_core::error::{Self};
    use lending_core::logic::{Self};
    use lending_core::version::{Self};
    use lending_core::constants::{Self};
    use lending_core::pool::{Self, Pool};
    use lending_core::storage::{Self, Storage, StorageAdminCap};

    friend lending_core::manage;
    friend lending_core::lending;

    struct Config has key, store {
        id: UID,
        version: u64,
        support_assets: Table<vector<u8>, address>, // Table<String, address>, 0x2::sui::SUI -> address
        assets: Table<address, AssetConfig>,
    }

    struct AssetConfig has key, store {
        id: UID,
        asset_id: u8,
        coin_type: String,
        pool_id: address, // lending pool 1000 -> 10
        rate_to_supplier: u64, // x * MultiBy --> 10% == 0.1 * 10000 = 1000, 0.09 -> 0.09 * 80% = supplier
        rate_to_treasury: u64, // x * MultiBy --> 10% == 0.1 * 10000 = 1000
        max: u64,
        min: u64,
    }

    struct Receipt<phantom CoinType> {
        user: address,
        asset: address,
        amount: u64,
        pool: address,
        fee_to_supplier: u64,
        fee_to_treasury: u64,
    }

    public fun version_verification(config: &Config) {
        version::pre_check_version(config.version)
    }

    public fun version_migrate(_: &StorageAdminCap, cfg: &mut Config) {
        assert!(cfg.version < version::this_version(), error::incorrect_version());
        cfg.version = version::this_version();
    }

    // Event
    struct ConfigCreated has copy, drop {
        sender: address,
        id: address,
    }

    struct AssetConfigCreated has copy, drop {
        sender: address,
        config_id: address,
        asset_id: address,
    }

    struct FlashLoan has copy, drop {
        sender: address,
        asset: address,
        amount: u64,
    }

    struct FlashRepay has copy, drop {
        sender: address,
        asset: address,
        amount: u64,
        fee_to_supplier: u64,
        fee_to_treasury: u64,
    }

    // Flash Loan Manage
    public(friend) fun create_config(ctx: &mut TxContext) {
        let new_id = object::new(ctx);
        let new_object_address = object::uid_to_address(&new_id);

        let cfg = Config {
            id: new_id,
            version: version::this_version(),
            assets: table::new<address, AssetConfig>(ctx),
            support_assets: table::new<vector<u8>, address>(ctx),
        };
        emit(ConfigCreated {sender: tx_context::sender(ctx), id: new_object_address});

        transfer::share_object(cfg)
    }

    public(friend) fun create_asset(
        config: &mut Config,
        _asset_id: u8,
        _coin_type: String,
        _pool: address,
        _rate_to_supplier: u64,
        _rate_to_treasury: u64,
        _max: u64,
        _min: u64,
        ctx: &mut TxContext
    ) {
        version_verification(config);
        assert!(!table::contains(&config.support_assets, *ascii::as_bytes(&_coin_type)), error::duplicate_config());

        let new_id = object::new(ctx);
        let new_obj_address = object::uid_to_address(&new_id);

        let asset = AssetConfig {
            id: new_id,
            asset_id: _asset_id,
            coin_type: _coin_type,
            pool_id: _pool,
            rate_to_supplier: _rate_to_supplier,
            rate_to_treasury: _rate_to_treasury,
            max: _max,
            min: _min,
        };
        verify_config(&asset);
        table::add(&mut config.assets, new_obj_address, asset);
        table::add(&mut config.support_assets, *ascii::as_bytes(&_coin_type), new_obj_address);

        emit(AssetConfigCreated {
            sender: tx_context::sender(ctx),
            config_id: object::uid_to_address(&config.id),
            asset_id: new_obj_address,
        })
    }

    // Flash Loan Options
    public(friend) fun loan<CoinType>(config: &Config, _pool: &mut Pool<CoinType>, _user: address, _loan_amount: u64): (Balance<CoinType>, Receipt<CoinType>) {
        version_verification(config);
        let str_type = type_name::into_string(type_name::get<CoinType>());
        assert!(table::contains(&config.support_assets, *ascii::as_bytes(&str_type)), error::reserve_not_found());
        let asset_id = table::borrow(&config.support_assets, *ascii::as_bytes(&str_type));
        let cfg = table::borrow(&config.assets, *asset_id);

        let pool_id = object::uid_to_address(pool::uid(_pool));
        assert!(_loan_amount >= cfg.min && _loan_amount <= cfg.max, error::invalid_amount());
        assert!(cfg.pool_id == pool_id, error::invalid_pool());

        let to_supplier = _loan_amount * cfg.rate_to_supplier / constants::FlashLoanMultiple();
        let to_treasury = _loan_amount * cfg.rate_to_treasury / constants::FlashLoanMultiple();

        let _balance = pool::withdraw_balance(_pool, _loan_amount, _user);
        
        let _receipt = Receipt<CoinType> {
            user: _user,
            asset: *asset_id,
            amount: _loan_amount,
            pool: pool_id,
            fee_to_supplier: to_supplier,
            fee_to_treasury: to_treasury,
        };

        emit(FlashLoan {
            sender: _user,
            asset: *asset_id,
            amount: _loan_amount,
        });

        (_balance, _receipt)
    }

    public(friend) fun repay<CoinType>(clock: &Clock, storage: &mut Storage, _pool: &mut Pool<CoinType>, _receipt: Receipt<CoinType>, _user: address, _repay_balance: Balance<CoinType>): Balance<CoinType> {
        let Receipt {user, asset, amount, pool, fee_to_supplier, fee_to_treasury} = _receipt;
        assert!(user == _user, error::invalid_user());
        assert!(pool == object::uid_to_address(pool::uid(_pool)), error::invalid_pool());

        // handler logic
        {
            logic::update_state_of_all(clock, storage);
            let asset_id = get_storage_asset_id_from_coin_type(storage, type_name::into_string(type_name::get<CoinType>()));

            let normal_amount = pool::normal_amount(_pool, fee_to_supplier);
            let (supply_index, _) = storage::get_index(storage, asset_id);
            let scaled_fee_to_supplier = ray_math::ray_div((normal_amount as u256), supply_index);

            logic::cumulate_to_supply_index(storage, asset_id, scaled_fee_to_supplier);
            logic::update_interest_rate(storage, asset_id);
        };

        let repay_amount = balance::value(&_repay_balance);
        assert!(repay_amount >= amount + fee_to_supplier + fee_to_treasury, error::invalid_amount());

        let repay = balance::split(&mut _repay_balance, amount + fee_to_supplier + fee_to_treasury);
        pool::deposit_balance(_pool, repay, _user);
        pool::deposit_treasury(_pool, fee_to_treasury);

        emit(FlashRepay {
            sender: _user,
            asset: asset,
            amount: amount,
            fee_to_supplier: fee_to_supplier,
            fee_to_treasury: fee_to_treasury,
        });

        _repay_balance
    }

    fun get_storage_asset_id_from_coin_type(s: &Storage, t: String): u8 {
        let count = storage::get_reserves_count(s);

        while (count > 0) {
            let id = count - 1;
            let this_type = storage::get_coin_type(s, id);
            if (this_type == t) {
                return id
            };
            count = count - 1;
        };

        abort error::reserve_not_found() // abort if not found
    }

    public fun parsed_receipt<T>(receipt: &Receipt<T>): (address, address, u64, address, u64, u64) {
        (
            receipt.user,
            receipt.asset,
            receipt.amount,
            receipt.pool,
            receipt.fee_to_supplier,
            receipt.fee_to_treasury,
        )
    }

    public fun get_asset<T>(config: &Config): (address, u8, vector<u8>, address, u64, u64, u64, u64) {
        let str_type = type_name::into_string(type_name::get<T>());
        assert!(table::contains(&config.support_assets, *ascii::as_bytes(&str_type)), error::reserve_not_found());
        let asset_id = table::borrow(&config.support_assets, *ascii::as_bytes(&str_type));
        let cfg = table::borrow(&config.assets, *asset_id);

        (
            object::uid_to_address(&cfg.id),
            cfg.asset_id,
            *ascii::as_bytes(&cfg.coin_type),
            cfg.pool_id,
            cfg.rate_to_supplier,
            cfg.rate_to_treasury,
            cfg.max,
            cfg.min,
        )
    }

    public(friend) fun set_asset_rate_to_supplier(config: &mut Config, _coin_type: String, _value: u64) {
        version_verification(config);
        let cfg = get_asset_config_by_coin_type(config, _coin_type); 
        cfg.rate_to_supplier = _value;  
        verify_config(cfg);
    }

    public(friend) fun set_asset_rate_to_treasury(config: &mut Config, _coin_type: String, _value: u64) {
        version_verification(config);
        let cfg = get_asset_config_by_coin_type(config, _coin_type); 
        cfg.rate_to_treasury = _value;  
        verify_config(cfg);
    }

    public(friend) fun set_asset_min(config: &mut Config, _coin_type: String, _value: u64) {
        version_verification(config);
        let cfg = get_asset_config_by_coin_type(config, _coin_type); 
        cfg.min = _value;  
        verify_config(cfg);
    }

    public(friend) fun set_asset_max(config: &mut Config, _coin_type: String, _value: u64) {
        version_verification(config);
        let cfg = get_asset_config_by_coin_type(config, _coin_type); 
        cfg.max = _value;  
        verify_config(cfg);
    }

    fun get_asset_config_by_coin_type(config: &mut Config, _coin_type: String): &mut AssetConfig{
        assert!(table::contains(&config.support_assets, *ascii::as_bytes(&_coin_type)), error::reserve_not_found());
        let asset_id = table::borrow(&config.support_assets, *ascii::as_bytes(&_coin_type));
        let cfg = table::borrow_mut(&mut config.assets, *asset_id);  
        cfg  
    }

    fun verify_config(cfg: &AssetConfig) {
        assert!(cfg.rate_to_supplier + cfg.rate_to_treasury < constants::FlashLoanMultiple(), error::invalid_amount());
        assert!(cfg.min < cfg.max, error::invalid_amount());
    }
}