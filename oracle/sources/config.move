module oracle::config {
    use std::vector;
    use std::type_name;
    use std::ascii::{String};
    use sui::object::{Self, UID};
    use sui::transfer::{Self};
    use sui::tx_context::{Self, TxContext};
    use sui::event::emit;
    use sui::table::{Self, Table};

    use oracle::oracle_error::{Self as error};
    use oracle::oracle_version::{Self as version};
    use oracle::oracle_provider::{Self, OracleProvider, OracleProviderConfig};

    friend oracle::oracle_pro;
    friend oracle::oracle_manage;
    friend oracle::oracle_dynamic_getter;

    // Structs
    struct OracleConfig has key, store {
        id: UID,
        version: u64,
        paused: bool, // when the decentralized price goes wrong, it can be pause
        vec_feeds: vector<address>,
        feeds: Table<address, PriceFeed>,
    }

    struct PriceFeed has store {
        id: UID,
        enable: bool, // when the decentralized price of a certain token goes wrong, it can be disable
        max_timestamp_diff: u64, // the expected difference between the current time and the oracle time
        price_diff_threshold1: u64,  // x1
        price_diff_threshold2: u64,  // x2
        max_duration_within_thresholds: u64,        // the maximum allowed usage time between ratio1(x1) and ratio2(x2), ms
        diff_threshold2_timer: u64,             // timestamp: save the first time the price difference ratio was used between ratio1 and ratio2
        maximum_allowed_span_percentage: u64,   // the current price cannot exceed this value compared to the last price range, must (x * 10000) --> 10% == 0.1 * 10000 = 1000
        maximum_effective_price: u256,          // the price cannot be greater than this value
        minimum_effective_price: u256,          // the price cannot be lower than this value
        oracle_id: u8,
        coin_type: String,
        primary: OracleProvider,
        secondary: OracleProvider,
        oracle_provider_configs: Table<OracleProvider, OracleProviderConfig>,
        historical_price_ttl: u64, // Is there any ambiguity about TTL(Time-To-Live)?
        history: History,
    }

    struct History has copy, store {
        price: u256,
        updated_time: u64,
    }

    // Events
    struct ConfigCreated has copy, drop {
        sender: address,
        id: address,
    }

    struct ConfigSetPaused has copy, drop {
        config: address,
        value: bool,
        before_value: bool,
    }

    struct PriceFeedCreated has copy, drop {
        sender: address,
        config: address,
        feed_id: address,
    }

    struct PriceFeedSetEnable has copy, drop {
        config: address,
        feed_id: address,
        value: bool,
        before_value: bool,
    }

    struct PriceFeedSetMaxTimestampDiff has copy, drop {
        config: address,
        feed_id: address,
        value: u64,
        before_value: u64,
    }

    struct PriceFeedSetPriceDiffThreshold1 has copy, drop {
        config: address,
        feed_id: address,
        value: u64,
        before_value: u64,
    }

    struct PriceFeedSetPriceDiffThreshold2 has copy, drop {
        config: address,
        feed_id: address,
        value: u64,
        before_value: u64,
    }

    struct PriceFeedSetMaxDurationWithinThresholds has copy, drop {
        config: address,
        feed_id: address,
        value: u64,
        before_value: u64,
    }
    
    struct PriceFeedSetMaximumAllowedSpanPercentage has copy, drop {
        config: address,
        feed_id: address,
        value: u64,
        before_value: u64,
    }

    struct PriceFeedSetMaximumEffectivePrice has copy, drop {
        config: address,
        feed_id: address,
        value: u256,
        before_value: u256,
    }

    struct PriceFeedSetMinimumEffectivePrice has copy, drop {
        config: address,
        feed_id: address,
        value: u256,
        before_value: u256,
    }

    struct PriceFeedSetOracleId has copy, drop {
        config: address,
        feed_id: address,
        value: u8,
        before_value: u8,
    }

    struct SetOracleProvider has copy, drop {
        config: address,
        feed_id: address,
        is_primary: bool, // primary: true, secondary: false
        provider: String,
        before_provider: String,
    }

    struct OracleProviderConfigCreated has copy, drop {
        config: address,
        feed_id: address,
        provider: String,
        pair_id: vector<u8>,
    }

    struct OracleProviderConfigSetPairId has copy, drop {
        config: address,
        feed_id: address,
        provider: String,
        value: vector<u8>,
        before_value: vector<u8>,
    }

    struct OracleProviderConfigSetEnable has copy, drop {
        config: address,
        feed_id: address,
        provider: String,
        value: bool,
        before_value: bool,
    }

    struct PriceFeedSetHistoricalPriceTTL has copy, drop {
        config: address,
        feed_id: address,
        value: u64,
        before_value: u64,
    }

    struct PriceFeedDiffThreshold2TimerUpdated has copy, drop {
        feed_id: address,
        updated_at: u64,
    }

    struct PriceFeedDiffThreshold2TimerReset has copy, drop {
        feed_id: address,
        started_at: u64,
    }

    // Friend Functions()
    public fun version_verification(cfg: &OracleConfig) {
        version::pre_check_version(cfg.version)
    }

    public(friend) fun version_migrate(cfg: &mut OracleConfig) {
        assert!(cfg.version <= version::this_version(), error::not_available_version());
        cfg.version = version::this_version();
    }

    public(friend) fun new_config(ctx: &mut TxContext) {
        let uid = object::new(ctx);
        let object_address = object::uid_to_address(&uid);

        let cfg = OracleConfig {
            id: uid,
            version: version::this_version(),
            paused: false, // default is false
            vec_feeds: vector::empty<address>(),
            feeds: table::new<address, PriceFeed>(ctx),
        };
        transfer::share_object(cfg);

        emit(ConfigCreated {sender: tx_context::sender(ctx), id: object_address})
    }

    public(friend) fun set_pause(cfg: &mut OracleConfig, value: bool) {
        let before_value = cfg.paused;

        cfg.paused = value;
        emit(ConfigSetPaused {config: object::uid_to_address(&cfg.id), value: value, before_value: before_value})
    }

    public(friend) fun new_price_feed<CoinType>(
        cfg: &mut OracleConfig,
        oracle_id: u8,
        max_timestamp_diff: u64,
        price_diff_threshold1: u64,
        price_diff_threshold2: u64,
        max_duration_within_thresholds: u64,
        maximum_allowed_span_percentage: u64,
        maximum_effective_price: u256,
        minimum_effective_price: u256,
        historical_price_ttl: u64,
        ctx: &mut TxContext,
    ) {
        assert!(!is_price_feed_exists<CoinType>(cfg, oracle_id), error::price_feed_already_exists());

        let uid = object::new(ctx);
        let object_address = object::uid_to_address(&uid);
        let feed = PriceFeed {
            id: uid,
            enable: true, // default is true
            max_timestamp_diff: max_timestamp_diff,
            price_diff_threshold1: price_diff_threshold1,
            price_diff_threshold2: price_diff_threshold2,
            max_duration_within_thresholds: max_duration_within_thresholds,
            diff_threshold2_timer: 0, // default is 0
            maximum_allowed_span_percentage: maximum_allowed_span_percentage,
            maximum_effective_price: maximum_effective_price,
            minimum_effective_price: minimum_effective_price,
            oracle_id: oracle_id,
            coin_type: type_name::into_string(type_name::get<CoinType>()),
            primary: oracle_provider::new_empty_provider(), // default empty provider
            secondary: oracle_provider::new_empty_provider(), // default empty provider
            oracle_provider_configs: table::new<OracleProvider, OracleProviderConfig>(ctx), // default empty
            historical_price_ttl: historical_price_ttl,
            history: History { price: 0, updated_time: 0 }, // both default 0
        };

        table::add(&mut cfg.feeds, object_address, feed);
        vector::push_back(&mut cfg.vec_feeds, object_address);

        emit(PriceFeedCreated {sender: tx_context::sender(ctx), config: object::uid_to_address(&cfg.id), feed_id: object_address})
    }

    public fun is_price_feed_exists<CoinType>(cfg: &OracleConfig, oracle_id: u8): bool {
        let coin_type = type_name::into_string(type_name::get<CoinType>());

        let feed_length = vector::length(&cfg.vec_feeds);
        let i = 0;
        while (i < feed_length) {
            let feed_id = vector::borrow(&cfg.vec_feeds, i);
            let price_feed = table::borrow(&cfg.feeds, *feed_id);
            if (price_feed.coin_type == coin_type) {
                return true
            };
            if (price_feed.oracle_id == oracle_id) {
                return true
            };
            i = i + 1;
        };

        false
    }

    public(friend) fun set_enable_to_price_feed(cfg: &mut OracleConfig, feed_id: address, value: bool) {
        assert!(table::contains(&cfg.feeds, feed_id), error::price_feed_not_found());
        let price_feed = table::borrow_mut(&mut cfg.feeds, feed_id);
        let before_value = price_feed.enable;

        price_feed.enable = value;
        emit(PriceFeedSetEnable {config: object::uid_to_address(&cfg.id), feed_id: feed_id, value: value, before_value: before_value})
    }

    public(friend) fun set_max_timestamp_diff_to_price_feed(cfg: &mut OracleConfig, feed_id: address, value: u64) {
        assert!(table::contains(&cfg.feeds, feed_id), error::price_feed_not_found());
        let price_feed = table::borrow_mut(&mut cfg.feeds, feed_id);
        let before_value = price_feed.max_timestamp_diff;

        price_feed.max_timestamp_diff = value;
        emit(PriceFeedSetMaxTimestampDiff {config: object::uid_to_address(&cfg.id), feed_id: feed_id, value: value, before_value: before_value})
    }

    public(friend) fun set_price_diff_threshold1_to_price_feed(cfg: &mut OracleConfig, feed_id: address, value: u64) {
        assert!(table::contains(&cfg.feeds, feed_id), error::price_feed_not_found());
        let price_feed = table::borrow_mut(&mut cfg.feeds, feed_id);
        let before_value = price_feed.price_diff_threshold1;
        if (price_feed.price_diff_threshold2 > 0) {
            assert!(value <= price_feed.price_diff_threshold2, error::invalid_value());
        };

        price_feed.price_diff_threshold1 = value;
        emit(PriceFeedSetPriceDiffThreshold1 {config: object::uid_to_address(&cfg.id), feed_id: feed_id, value: value, before_value: before_value})
    }

    public(friend) fun set_price_diff_threshold2_to_price_feed(cfg: &mut OracleConfig, feed_id: address, value: u64) {
        assert!(table::contains(&cfg.feeds, feed_id), error::price_feed_not_found());
        let price_feed = table::borrow_mut(&mut cfg.feeds, feed_id);
        let before_value = price_feed.price_diff_threshold2;
        assert!(value >= price_feed.price_diff_threshold1, error::invalid_value());

        price_feed.price_diff_threshold2 = value;
        emit(PriceFeedSetPriceDiffThreshold2 {config: object::uid_to_address(&cfg.id), feed_id: feed_id, value: value, before_value: before_value})
    }

    public(friend) fun set_max_duration_within_thresholds_to_price_feed(cfg: &mut OracleConfig, feed_id: address, value: u64) {
        assert!(table::contains(&cfg.feeds, feed_id), error::price_feed_not_found());
        let price_feed = table::borrow_mut(&mut cfg.feeds, feed_id);
        let before_value = price_feed.max_duration_within_thresholds;

        price_feed.max_duration_within_thresholds = value;
        emit(PriceFeedSetMaxDurationWithinThresholds {config: object::uid_to_address(&cfg.id), feed_id: feed_id, value: value, before_value: before_value})
    }

    public(friend) fun set_maximum_allowed_span_percentage_to_price_feed(cfg: &mut OracleConfig, feed_id: address, value: u64) {
        assert!(table::contains(&cfg.feeds, feed_id), error::price_feed_not_found());
        let price_feed = table::borrow_mut(&mut cfg.feeds, feed_id);
        let before_value = price_feed.maximum_allowed_span_percentage;

        price_feed.maximum_allowed_span_percentage = value;
        emit(PriceFeedSetMaximumAllowedSpanPercentage {config: object::uid_to_address(&cfg.id), feed_id: feed_id, value: value, before_value: before_value})
    }

    public(friend) fun set_maximum_effective_price_to_price_feed(cfg: &mut OracleConfig, feed_id: address, value: u256) {
        assert!(table::contains(&cfg.feeds, feed_id), error::price_feed_not_found());
        let price_feed = table::borrow_mut(&mut cfg.feeds, feed_id);
        let before_value = price_feed.maximum_effective_price;
        assert!(value >= price_feed.minimum_effective_price, error::invalid_value());

        price_feed.maximum_effective_price = value;
        emit(PriceFeedSetMaximumEffectivePrice {config: object::uid_to_address(&cfg.id), feed_id: feed_id, value: value, before_value: before_value})
    }

    public(friend) fun set_minimum_effective_price_to_price_feed(cfg: &mut OracleConfig, feed_id: address, value: u256) {
        assert!(table::contains(&cfg.feeds, feed_id), error::price_feed_not_found());
        let price_feed = table::borrow_mut(&mut cfg.feeds, feed_id);
        let before_value = price_feed.minimum_effective_price;
        if (price_feed.maximum_effective_price > 0) {
            assert!(value <= price_feed.maximum_effective_price, error::invalid_value());
        };

        price_feed.minimum_effective_price = value;
        emit(PriceFeedSetMinimumEffectivePrice {config: object::uid_to_address(&cfg.id), feed_id: feed_id, value: value, before_value: before_value})
    }

    public(friend) fun set_oracle_id_to_price_feed(cfg: &mut OracleConfig, feed_id: address, value: u8) {
        // Q: Why is there this function?
        // A: Generally speaking: this value is never allowed to change, and needs to be confirmed again again again when initializing the price feed.
        //    But!!!! The existence of this method prevents incorrect values from being filled in during initialization and is used for later modifications.
        //    In the end, don't worry, a friend function is provided first. The public function is not provided for the time being.
        assert!(table::contains(&cfg.feeds, feed_id), error::price_feed_not_found());

        // gurantee one oracle_id only has most 1 feed 
        let feed_length = vector::length(&cfg.vec_feeds);
        let i = 0;
        while (i < feed_length) {
            let feed_id = vector::borrow(&cfg.vec_feeds, i);
            let price_feed = table::borrow(&cfg.feeds, *feed_id);
            if (price_feed.oracle_id == value) {
                abort error::price_feed_already_exists()
            };
            i = i + 1;
        };

        let price_feed = table::borrow_mut(&mut cfg.feeds, feed_id);
        let before_value = price_feed.oracle_id;

        price_feed.oracle_id = value;
        emit(PriceFeedSetOracleId {config: object::uid_to_address(&cfg.id), feed_id: feed_id, value: value, before_value: before_value})
    }

    public(friend) fun set_primary_oracle_provider(cfg: &mut OracleConfig, feed_id: address, provider: OracleProvider) {
        assert!(table::contains(&cfg.feeds, feed_id), error::price_feed_not_found());
        let price_feed = table::borrow_mut(&mut cfg.feeds, feed_id);
        if (price_feed.primary == provider) {
            return
        };
        let before_provider = price_feed.primary;

        assert!(table::contains(&price_feed.oracle_provider_configs, provider), error::provider_config_not_found());
        let provider_config = table::borrow(&price_feed.oracle_provider_configs, provider);
        assert!(oracle_provider::is_oracle_provider_config_enable(provider_config), error::oracle_provider_disabled());
        price_feed.primary = provider;

        emit(SetOracleProvider {config: object::uid_to_address(&cfg.id), feed_id: feed_id, is_primary: true, provider: oracle_provider::to_string(&provider), before_provider: oracle_provider::to_string(&before_provider)});
    }

    public(friend) fun set_secondary_oracle_provider(cfg: &mut OracleConfig, feed_id: address, provider: OracleProvider) {
        assert!(table::contains(&cfg.feeds, feed_id), error::price_feed_not_found());
        let price_feed = table::borrow_mut(&mut cfg.feeds, feed_id);
        if (price_feed.secondary == provider) {
            return
        };
        let before_provider = price_feed.secondary;

        // assert should be like this
        if (!oracle_provider::is_empty(&provider)) {
            assert!(table::contains(&price_feed.oracle_provider_configs, provider), error::provider_config_not_found());
        };

        price_feed.secondary = provider;

        emit(SetOracleProvider {config: object::uid_to_address(&cfg.id), feed_id: feed_id, is_primary: false, provider: oracle_provider::to_string(&provider), before_provider: oracle_provider::to_string(&before_provider)});
    }

    public(friend) fun new_oracle_provider_config(cfg: &mut OracleConfig, feed_id: address, provider: OracleProvider, pair_id: vector<u8>, enable: bool) {
        assert!(table::contains(&cfg.feeds, feed_id), error::price_feed_not_found());
        let price_feed = table::borrow_mut(&mut cfg.feeds, feed_id);
        assert!(!table::contains(&price_feed.oracle_provider_configs, provider), error::oracle_config_already_exists());

        let oracle_config = oracle_provider::new_oracle_provider_config(provider, enable, pair_id);
        table::add(&mut price_feed.oracle_provider_configs, provider, oracle_config);

        emit(OracleProviderConfigCreated {config: object::uid_to_address(&cfg.id), feed_id: feed_id, provider: oracle_provider::to_string(&provider), pair_id: pair_id})
    }

    public(friend) fun set_oracle_provider_config_pair_id(cfg: &mut OracleConfig, feed_id: address, provider: OracleProvider, value: vector<u8>) {
        assert!(table::contains(&cfg.feeds, feed_id), error::price_feed_not_found());

        let price_feed = table::borrow_mut(&mut cfg.feeds, feed_id);
        assert!(table::contains(&price_feed.oracle_provider_configs, provider), error::oracle_provider_config_not_found());

        let provider_config = table::borrow_mut(&mut price_feed.oracle_provider_configs, provider);
        let before_value = oracle_provider::get_pair_id_from_oracle_provider_config(provider_config);
        
        oracle_provider::set_pair_id_to_oracle_provider_config(provider_config, value);
        emit(OracleProviderConfigSetPairId {config: object::uid_to_address(&cfg.id), feed_id: feed_id, provider: oracle_provider::to_string(&provider), value: value, before_value: before_value});
    }

    public(friend) fun set_oracle_provider_config_enable(cfg: &mut OracleConfig, feed_id: address, provider: OracleProvider, value: bool) {
        assert!(table::contains(&cfg.feeds, feed_id), error::price_feed_not_found());

        let price_feed = table::borrow_mut(&mut cfg.feeds, feed_id);
        assert!(table::contains(&price_feed.oracle_provider_configs, provider), error::oracle_provider_config_not_found());
        assert!(price_feed.primary != provider, error::provider_is_being_used_in_primary());

        let provider_config = table::borrow_mut(&mut price_feed.oracle_provider_configs, provider);
        let before_value = oracle_provider::is_oracle_provider_config_enable(provider_config);
        
        oracle_provider::set_enable_to_oracle_provider_config(provider_config, value);
        emit(OracleProviderConfigSetEnable {config: object::uid_to_address(&cfg.id), feed_id: feed_id, provider: oracle_provider::to_string(&provider), value: value, before_value: before_value});
    }

    public(friend) fun set_historical_price_ttl_to_price_feed(cfg: &mut OracleConfig, feed_id: address, value: u64) {
        assert!(table::contains(&cfg.feeds, feed_id), error::price_feed_not_found());
        let price_feed = table::borrow_mut(&mut cfg.feeds, feed_id);
        let before_value = price_feed.historical_price_ttl;

        price_feed.historical_price_ttl = value;
        emit(PriceFeedSetHistoricalPriceTTL {config: object::uid_to_address(&cfg.id), feed_id: feed_id, value: value, before_value: before_value})
    }

    public(friend) fun start_or_continue_diff_threshold2_timer(price_feed: &mut PriceFeed, timestamp: u64) {
        if (price_feed.diff_threshold2_timer > 0) {
            return
        };

        price_feed.diff_threshold2_timer = timestamp;
        emit(PriceFeedDiffThreshold2TimerUpdated {feed_id: get_price_feed_id_from_feed(price_feed), updated_at: timestamp})
    }

    public(friend) fun reset_diff_threshold2_timer(price_feed: &mut PriceFeed) {
        let started_at = price_feed.diff_threshold2_timer;
        if (started_at == 0) {
            return
        };

        price_feed.diff_threshold2_timer = 0;
        emit(PriceFeedDiffThreshold2TimerReset {feed_id: get_price_feed_id_from_feed(price_feed), started_at: started_at})
    }

    public(friend) fun keep_history_update(price_feed: &mut PriceFeed, price: u256, updated_time: u64) {
        let history = &mut price_feed.history;
        history.price = price;
        history.updated_time = updated_time;
    }

    // GET
    // OracleConfig
    public fun get_config_id_to_address(cfg: &OracleConfig): address {
        object::uid_to_address(&cfg.id)
    }

    public fun is_paused(cfg: &OracleConfig): bool {
        cfg.paused
    }

    public fun get_vec_feeds(cfg: &OracleConfig): vector<address> {
        cfg.vec_feeds
    }

    public fun get_feeds(cfg: &OracleConfig): &Table<address, PriceFeed> {
        &cfg.feeds
    }

    // PriceFeed
    public fun get_price_feed(cfg: &OracleConfig, feed_id: address): &PriceFeed {
        assert!(table::contains(&cfg.feeds, feed_id), error::price_feed_not_found());

        table::borrow(&cfg.feeds, feed_id)
    }

    public(friend) fun get_price_feed_mut(cfg: &mut OracleConfig, feed_id: address): &mut PriceFeed {
        assert!(table::contains(&cfg.feeds, feed_id), error::price_feed_not_found());

        table::borrow_mut(&mut cfg.feeds, feed_id)
    }

    public fun get_price_feed_id(cfg: &OracleConfig, feed_id: address): address {
        let price_feed = get_price_feed(cfg, feed_id);

        object::uid_to_address(&price_feed.id)
    }

    public fun get_price_feed_id_from_feed(price_feed: &PriceFeed): address {
        object::uid_to_address(&price_feed.id)
    }

    public fun is_price_feed_enable(price_feed: &PriceFeed): bool {
        price_feed.enable
    }

    public fun get_max_timestamp_diff(cfg: &OracleConfig, feed_id: address): u64 {
        let price_feed = get_price_feed(cfg, feed_id);

        price_feed.max_timestamp_diff
    }

    public fun get_max_timestamp_diff_from_feed(price_feed: &PriceFeed): u64 {
        price_feed.max_timestamp_diff
    }

    public fun get_price_diff_threshold1(cfg: &OracleConfig, feed_id: address): u64 {
        let price_feed = get_price_feed(cfg, feed_id);

        price_feed.price_diff_threshold1
    }

    public fun get_price_diff_threshold1_from_feed(price_feed: &PriceFeed): u64 {
        price_feed.price_diff_threshold1
    }

    public fun get_price_diff_threshold2(cfg: &OracleConfig, feed_id: address): u64 {
        let price_feed = get_price_feed(cfg, feed_id);

        price_feed.price_diff_threshold2
    }

    public fun get_price_diff_threshold2_from_feed(price_feed: &PriceFeed): u64 {
        price_feed.price_diff_threshold2
    }

    public fun get_max_duration_within_thresholds(cfg: &OracleConfig, feed_id: address): u64 {
        let price_feed = get_price_feed(cfg, feed_id);

        price_feed.max_duration_within_thresholds
    }

    public fun get_max_duration_within_thresholds_from_feed(price_feed: &PriceFeed): u64 {
        price_feed.max_duration_within_thresholds
    }

    public fun get_diff_threshold2_timer(cfg: &OracleConfig, feed_id: address): u64 {
        let price_feed = get_price_feed(cfg, feed_id);

        price_feed.diff_threshold2_timer
    }

    public fun get_diff_threshold2_timer_from_feed(price_feed: &PriceFeed): u64 {
        price_feed.diff_threshold2_timer
    }

    public fun get_maximum_allowed_span_percentage(cfg: &OracleConfig, feed_id: address): u64 {
        let price_feed = get_price_feed(cfg, feed_id);

        price_feed.maximum_allowed_span_percentage
    }

    public fun get_maximum_allowed_span_percentage_from_feed(price_feed: &PriceFeed): u64 {
        price_feed.maximum_allowed_span_percentage
    }

    public fun get_maximum_effective_price(cfg: &OracleConfig, feed_id: address): u256 {
        let price_feed = get_price_feed(cfg, feed_id);

        price_feed.maximum_effective_price
    }

    public fun get_maximum_effective_price_from_feed(price_feed: &PriceFeed): u256 {
        price_feed.maximum_effective_price
    }

    public fun get_minimum_effective_price(cfg: &OracleConfig, feed_id: address): u256 {
        let price_feed = get_price_feed(cfg, feed_id);

        price_feed.minimum_effective_price
    }

    public fun get_minimum_effective_price_from_feed(price_feed: &PriceFeed): u256 {
        price_feed.minimum_effective_price
    }

    public fun get_oracle_id(cfg: &OracleConfig, feed_id: address): u8 {
        let price_feed = get_price_feed(cfg, feed_id);

        price_feed.oracle_id
    }

    public fun get_oracle_id_from_feed(price_feed: &PriceFeed): u8 {
        price_feed.oracle_id
    }

    public fun get_coin_type(cfg: &OracleConfig, feed_id: address): String {
        let price_feed = get_price_feed(cfg, feed_id);

        price_feed.coin_type
    }

    public fun get_coin_type_from_feed(price_feed: &PriceFeed): String {
        price_feed.coin_type
    }

    public fun get_primary_oracle_provider(price_feed: &PriceFeed): &OracleProvider {
        &price_feed.primary
    }

    public fun get_secondary_oracle_provider(price_feed: &PriceFeed): &OracleProvider {
        &price_feed.secondary
    }

    public fun get_oracle_provider_configs(cfg: &OracleConfig, feed_id: address): &Table<OracleProvider, OracleProviderConfig> {
        let price_feed = get_price_feed(cfg, feed_id);

        &price_feed.oracle_provider_configs
    }

    public fun get_oracle_provider_configs_from_feed(price_feed: &PriceFeed): &Table<OracleProvider, OracleProviderConfig> {
        &price_feed.oracle_provider_configs
    }

    public fun get_primary_oracle_provider_config(price_feed: &PriceFeed): &OracleProviderConfig {
        let provider = price_feed.primary;
        get_oracle_provider_config_from_feed(price_feed, provider)
    }

    public fun get_secondary_source_config(price_feed: &PriceFeed): &OracleProviderConfig {
        let provider = price_feed.secondary;
        get_oracle_provider_config_from_feed(price_feed, provider)
    }

    public fun get_historical_price_ttl(price_feed: &PriceFeed): u64 {
        price_feed.historical_price_ttl
    }

    public fun get_history_price_from_feed(price_feed: &PriceFeed): History {
        price_feed.history
    }

    public fun get_history_price_data_from_feed(price_feed: &PriceFeed): (u256, u64) {
        let history = &price_feed.history;
        (history.price, history.updated_time)
    }

    // SourceConfig
    public fun get_oracle_provider_config(cfg: &OracleConfig, feed_id: address, provider: OracleProvider): &OracleProviderConfig {
        let price_feed = get_price_feed(cfg, feed_id);

        assert!(table::contains(&price_feed.oracle_provider_configs, provider), error::oracle_provider_config_not_found());

        table::borrow(&price_feed.oracle_provider_configs, provider)
    }

    public fun get_oracle_provider_config_from_feed(price_feed: &PriceFeed, provider: OracleProvider): &OracleProviderConfig {
        assert!(table::contains(&price_feed.oracle_provider_configs, provider), error::oracle_provider_config_not_found());
        
        table::borrow(&price_feed.oracle_provider_configs, provider)
    }

    public fun get_pair_id(cfg: &OracleConfig, feed_id: address, provider: OracleProvider): vector<u8> {
        let provider_config = get_oracle_provider_config(cfg, feed_id, provider);

        oracle_provider::get_pair_id_from_oracle_provider_config(provider_config)
    }

    public fun get_pair_id_from_feed(price_feed: &PriceFeed, provider: OracleProvider): vector<u8> {
        let provider_config = get_oracle_provider_config_from_feed(price_feed, provider);

        oracle_provider::get_pair_id_from_oracle_provider_config(provider_config)
    }

    public fun get_pair_id_from_oracle_provider_config(provider_config: &OracleProviderConfig): vector<u8> {
        oracle_provider::get_pair_id_from_oracle_provider_config(provider_config)
    }

    public fun is_oracle_provider_config_enable(provider_config: &OracleProviderConfig): bool {
        oracle_provider::is_oracle_provider_config_enable(provider_config)
    }

    public fun get_oracle_provider_from_oracle_provider_config(provider_config: &OracleProviderConfig): OracleProvider {
        oracle_provider::get_provider_from_oracle_provider_config(provider_config)
    }

    // History
    public fun get_price_from_history(history: &History): u256 {
        history.price
    }

    public fun get_updated_time_from_history(history: &History): u64 {
        history.updated_time
    }

    // 
    public fun is_secondary_oracle_available(price_feed: &PriceFeed): bool {
        let secondary_provider = &price_feed.secondary;
        if (oracle_provider::is_empty(secondary_provider)) {
            return false
        };
        
        if (secondary_provider == &price_feed.primary) {
            return false
        };

        let secondary_provider_config = table::borrow(&price_feed.oracle_provider_configs, *secondary_provider);
        return oracle_provider::is_oracle_provider_config_enable(secondary_provider_config)
    }

    #[test_only]
    public fun get_price_feed_mut_for_testing(cfg: &mut OracleConfig, feed_id: address): &mut PriceFeed {
        get_price_feed_mut(cfg, feed_id)
    }

    #[test_only]
    public fun keep_history_update_for_testing(price_feed: &mut PriceFeed, price: u256, updated_time: u64) {
        keep_history_update(price_feed, price, updated_time);
    }

    #[test_only]
    public fun start_or_continue_diff_threshold2_timer_for_testing(price_feed: &mut PriceFeed, timestamp: u64) {
        start_or_continue_diff_threshold2_timer(price_feed, timestamp);
    }

    #[test_only]
    public fun reset_diff_threshold2_timer_for_testing(price_feed: &mut PriceFeed) {
        reset_diff_threshold2_timer(price_feed);
    }

    #[test_only]
    public fun new_oracle_provider_config_for_testing(cfg: &mut OracleConfig, feed_id: address, provider: OracleProvider, pair_id: vector<u8>, enable: bool) {
        new_oracle_provider_config(cfg, feed_id, provider, pair_id, enable);
    }

    #[test_only]
    public fun set_oracle_provider_config_enable_for_testing(cfg: &mut OracleConfig, feed_id: address, provider: OracleProvider, value: bool) {
        set_oracle_provider_config_enable(cfg, feed_id, provider, value)
    }
}

