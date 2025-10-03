#[allow(lint(self_transfer))]
module oracle::oracle {
    use std::vector;
    use sui::transfer;
    use sui::event::emit;
    use sui::object::{Self, UID};
    use sui::table::{Self, Table};
    use sui::clock::{Self, Clock};
    use sui::tx_context::{Self, TxContext};

    use oracle::oracle_error::{Self as error};
    use oracle::oracle_version::{Self as version};
    use oracle::oracle_constants::{Self as constants};

    friend oracle::oracle_pro;
    friend oracle::oracle_manage;

    struct OracleAdminCap has key, store {
        id: UID,
    }

    struct OracleFeederCap has key, store {
        id: UID,
    }

    struct PriceOracle has key {
        id: UID,
        version: u64,
        update_interval: u64,
        price_oracles: Table<u8, Price>,
    }

    struct Price has store {
        value: u256,
        decimal: u8,
        timestamp: u64
    }

    // Events
    struct PriceUpdated has copy, drop {
        price_oracle: address,
        id: u8,
        price: u256,
        last_price: u256,
        update_at: u64,
        last_update_at: u64,
    }

    fun init(ctx: &mut TxContext) {
        transfer::public_transfer(OracleAdminCap {id: object::new(ctx)}, tx_context::sender(ctx));
        transfer::public_transfer(OracleFeederCap {id: object::new(ctx)}, tx_context::sender(ctx));

        transfer::share_object(PriceOracle {
            id: object::new(ctx),
            version: version::this_version(),
            price_oracles: table::new(ctx),
            update_interval: constants::default_update_interval(),
        });
    }

    public fun create_feeder(_: &OracleAdminCap, ctx: &mut TxContext) {
        transfer::public_transfer(OracleFeederCap {id: object::new(ctx)}, tx_context::sender(ctx));
    }

    fun version_verification(oracle: &PriceOracle) {
        version::pre_check_version(oracle.version)
    }

    #[allow(unused_variable, unused_mut_parameter)]
    entry fun version_migrate(_: &OracleAdminCap, oracle: &mut PriceOracle) {
        abort 0
    }

    public(friend) fun oracle_version_migrate(_: &OracleAdminCap, oracle: &mut PriceOracle) {
        assert!(oracle.version <= version::this_version(), error::not_available_version());
        oracle.version = version::this_version();
    }


    public entry fun set_update_interval(
        _: &OracleAdminCap,
        price_oracle: &mut PriceOracle,
        update_interval: u64,
    ) {
        version_verification(price_oracle);
        assert!(update_interval > 0, error::invalid_value());
        price_oracle.update_interval = update_interval;
    }

    public entry fun register_token_price(
        _: &OracleAdminCap,
        clock: &Clock,
        price_oracle: &mut PriceOracle,
        oracle_id: u8,
        token_price: u256,
        price_decimal: u8,
    ) {
        version_verification(price_oracle);
        
        // default limit = 16
        // prices from providers are u64 and u128
        //  -> will be converted to u256 that allows max 78 digits
        // 16 decimals will not cause overflow 
        assert!(price_decimal <= constants::default_decimal_limit() && price_decimal > 0, error::invalid_value());
        let price_oracles = &mut price_oracle.price_oracles;
        assert!(!table::contains(price_oracles, oracle_id), error::oracle_already_exist());
        table::add(price_oracles, oracle_id, Price {
            value: token_price,
            decimal: price_decimal,
            timestamp: clock::timestamp_ms(clock)
        })
    }

    // function to internally update prices by oracle_pro 
    public(friend) fun update_price(clock: &Clock, price_oracle: &mut PriceOracle, oracle_id: u8, token_price: u256) {
        // TODO: update_token_price can be merged into update_price
        version_verification(price_oracle);

        let price_oracles = &mut price_oracle.price_oracles;
        assert!(table::contains(price_oracles, oracle_id), error::non_existent_oracle());

        let price = table::borrow_mut(price_oracles, oracle_id);
        let now = clock::timestamp_ms(clock);
        emit(PriceUpdated {
            price_oracle: object::uid_to_address(&price_oracle.id),
            id: oracle_id,
            price: token_price,
            last_price: price.value,
            update_at: now,
            last_update_at: price.timestamp,
        });

        price.value = token_price;
        price.timestamp = now;
    }

    // function to externally update prices by the feeder 
    public entry fun update_token_price(
        _: &OracleFeederCap,
        clock: &Clock,
        price_oracle: &mut PriceOracle,
        oracle_id: u8,
        token_price: u256,
    ) {
        version_verification(price_oracle);

        let price_oracles = &mut price_oracle.price_oracles;
        assert!(table::contains(price_oracles, oracle_id), error::non_existent_oracle());
        let price = table::borrow_mut(price_oracles, oracle_id);
        price.value = token_price;
        price.timestamp = clock::timestamp_ms(clock);
    }

    public entry fun update_token_price_batch(
        cap: &OracleFeederCap,
        clock: &Clock,
        price_oracle: &mut PriceOracle,
        oracle_ids: vector<u8>,
        token_prices: vector<u256>,
    ) {
        version_verification(price_oracle);

        let len = vector::length(&oracle_ids);
        assert!(len == vector::length(&token_prices), error::price_length_not_match());

        let i = 0;
        while (i < len) {
            let oracle_id = vector::borrow(&oracle_ids, i);
            update_token_price(
                cap,
                clock,
                price_oracle,
                *oracle_id,
                *vector::borrow(&token_prices, i),
            );
            i = i + 1;
        }
    }

    public fun get_token_price(
        clock: &Clock,
        price_oracle: &PriceOracle,
        oracle_id: u8
    ): (bool, u256, u8) {
        version_verification(price_oracle);

        let price_oracles = &price_oracle.price_oracles;
        assert!(table::contains(price_oracles, oracle_id), error::non_existent_oracle());

        let token_price = table::borrow(price_oracles, oracle_id);
        let current_ts = clock::timestamp_ms(clock);

        let valid = false;
        if (token_price.value > 0 && current_ts - token_price.timestamp <= price_oracle.update_interval) {
            valid = true;
        };
        (valid, token_price.value, token_price.decimal)
    }

    public fun price_object(price_oracle: &PriceOracle, oracle_id: u8): &Price {
        assert!(table::contains(&price_oracle.price_oracles, oracle_id), error::price_oracle_not_found());

        table::borrow(&price_oracle.price_oracles, oracle_id)
    }

    public fun decimal(price_oracle: &mut PriceOracle, oracle_id: u8): u8 {
        let price = price_object(price_oracle, oracle_id);

        price.decimal
    }

    public fun safe_decimal(price_oracle: &PriceOracle, oracle_id: u8): u8 {
        let price = price_object(price_oracle, oracle_id);

        price.decimal
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        transfer::public_transfer(OracleAdminCap {id: object::new(ctx)}, tx_context::sender(ctx));
        transfer::public_transfer(OracleFeederCap {id: object::new(ctx)}, tx_context::sender(ctx));


        transfer::share_object(PriceOracle {
            id: object::new(ctx),
            version: version::this_version(),
            price_oracles: table::new(ctx),
            update_interval: constants::default_update_interval()
        });
    }

    #[test_only]
    public fun version_verification_for_testing(oracle: &PriceOracle) {
        version::pre_check_version(oracle.version)
    }
}