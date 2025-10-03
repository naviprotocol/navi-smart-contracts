module oracle::oracle_manage {
    use sui::tx_context::{TxContext};

    use oracle::oracle_provider::{Self};
    use oracle::oracle::{Self, OracleAdminCap, PriceOracle};
    use oracle::config::{Self, OracleConfig};
    use oracle::oracle_provider::{OracleProvider};
    use oracle::adaptor_supra::{Self};

    public fun create_config(_: &OracleAdminCap, ctx: &mut TxContext) {
        config::new_config(ctx)
    }

    public fun version_migrate(cap: &OracleAdminCap, oracle_config: &mut OracleConfig, price_oracle: &mut PriceOracle) {
        config::version_migrate(oracle_config);
        oracle::oracle_version_migrate(cap, price_oracle);
    }

    public fun set_pause(_: &OracleAdminCap, oracle_config: &mut OracleConfig, value: bool) {
        config::version_verification(oracle_config);
        config::set_pause(oracle_config, value)
    }

    public fun create_price_feed<CoinType>(
        _: &OracleAdminCap,
        oracle_config: &mut OracleConfig,
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
        config::version_verification(oracle_config);
        config::new_price_feed<CoinType>(oracle_config, oracle_id, max_timestamp_diff, price_diff_threshold1, price_diff_threshold2, max_duration_within_thresholds, maximum_allowed_span_percentage, maximum_effective_price, minimum_effective_price, historical_price_ttl, ctx)
    }

    public fun set_enable_to_price_feed(_: &OracleAdminCap, oracle_config: &mut OracleConfig, feed_id: address, value: bool) {
        config::version_verification(oracle_config);
        config::set_enable_to_price_feed(oracle_config, feed_id, value)
    }

    public fun set_max_timestamp_diff_to_price_feed(_: &OracleAdminCap, oracle_config: &mut OracleConfig, feed_id: address, value: u64) {
        config::version_verification(oracle_config);
        config::set_max_timestamp_diff_to_price_feed(oracle_config, feed_id, value)
    }

    public fun set_price_diff_threshold1_to_price_feed(_: &OracleAdminCap, oracle_config: &mut OracleConfig, feed_id: address, value: u64) {
        config::version_verification(oracle_config);
        config::set_price_diff_threshold1_to_price_feed(oracle_config, feed_id, value)
    }

    public fun set_price_diff_threshold2_to_price_feed(_: &OracleAdminCap, oracle_config: &mut OracleConfig, feed_id: address, value: u64) {
        config::version_verification(oracle_config);
        config::set_price_diff_threshold2_to_price_feed(oracle_config, feed_id, value)
    }

    public fun set_max_duration_within_thresholds_to_price_feed(_: &OracleAdminCap, oracle_config: &mut OracleConfig, feed_id: address, value: u64) {
        config::version_verification(oracle_config);
        config::set_max_duration_within_thresholds_to_price_feed(oracle_config, feed_id, value)
    }

    public fun set_maximum_allowed_span_percentage_to_price_feed(_: &OracleAdminCap, oracle_config: &mut OracleConfig, feed_id: address, value: u64) {
        config::version_verification(oracle_config);
        config::set_maximum_allowed_span_percentage_to_price_feed(oracle_config, feed_id, value)
    }

    public fun set_maximum_effective_price_to_price_feed(_: &OracleAdminCap, oracle_config: &mut OracleConfig, feed_id: address, value: u256) {
        config::version_verification(oracle_config);
        config::set_maximum_effective_price_to_price_feed(oracle_config, feed_id, value)
    }

    public fun set_minimum_effective_price_to_price_feed(_: &OracleAdminCap, oracle_config: &mut OracleConfig, feed_id: address, value: u256) {
        config::version_verification(oracle_config);
        config::set_minimum_effective_price_to_price_feed(oracle_config, feed_id, value)
    }

    public fun set_historical_price_ttl_to_price_feed(_: &OracleAdminCap, oracle_config: &mut OracleConfig, feed_id: address, value: u64) {
        config::version_verification(oracle_config);
        config::set_historical_price_ttl_to_price_feed(oracle_config, feed_id, value)
    }

    public fun create_pyth_oracle_provider_config(_: &OracleAdminCap, oracle_config: &mut OracleConfig, feed_id: address, pair_id: vector<u8>, enable: bool) {
        config::version_verification(oracle_config);
        config::new_oracle_provider_config(oracle_config, feed_id, oracle_provider::pyth_provider(), pair_id, enable)
    }

    public fun set_pyth_price_oracle_provider_pair_id(_: &OracleAdminCap, oracle_config: &mut OracleConfig, feed_id: address, pair_id: vector<u8>) {
        config::version_verification(oracle_config);
        config::set_oracle_provider_config_pair_id(oracle_config, feed_id, oracle_provider::pyth_provider(), pair_id)
    }

    public fun enable_pyth_oracle_provider(_: &OracleAdminCap, oracle_config: &mut OracleConfig, feed_id: address) {
        config::version_verification(oracle_config);
        config::set_oracle_provider_config_enable(oracle_config, feed_id, oracle_provider::pyth_provider(), true)
    }

    public fun disable_pyth_oracle_provider(_: &OracleAdminCap, oracle_config: &mut OracleConfig, feed_id: address) {
        config::version_verification(oracle_config);
        config::set_oracle_provider_config_enable(oracle_config, feed_id, oracle_provider::pyth_provider(), false)
    }

    public fun create_supra_oracle_provider_config(_: &OracleAdminCap, oracle_config: &mut OracleConfig, feed_id: address, pair_id: u32, enable: bool) {
        config::version_verification(oracle_config);
        config::new_oracle_provider_config(oracle_config, feed_id, oracle_provider::supra_provider(), adaptor_supra::pair_id_to_vector(pair_id), enable)
    }

    public fun set_supra_price_source_pair_id(_: &OracleAdminCap, oracle_config: &mut OracleConfig, feed_id: address, pair_id: vector<u8>) {
        config::version_verification(oracle_config);
        config::set_oracle_provider_config_pair_id(oracle_config, feed_id, oracle_provider::supra_provider(), pair_id)
    }

    public fun enable_supra_oracle_provider(_: &OracleAdminCap, oracle_config: &mut OracleConfig, feed_id: address) {
        config::version_verification(oracle_config);
        config::set_oracle_provider_config_enable(oracle_config, feed_id, oracle_provider::supra_provider(), true)
    }

    public fun disable_supra_oracle_provider(_: &OracleAdminCap, oracle_config: &mut OracleConfig, feed_id: address) {
        config::version_verification(oracle_config);
        config::set_oracle_provider_config_enable(oracle_config, feed_id, oracle_provider::supra_provider(), false)
    }

    public fun set_primary_oracle_provider(_: &OracleAdminCap, cfg: &mut OracleConfig, feed_id: address, provider: OracleProvider) {
        config::version_verification(cfg);
        config::set_primary_oracle_provider(cfg, feed_id, provider)
    }

    public fun set_secondary_oracle_provider(_: &OracleAdminCap, cfg: &mut OracleConfig, feed_id: address, provider: OracleProvider) {
        config::version_verification(cfg);
        config::set_secondary_oracle_provider(cfg, feed_id, provider)
    }

    // TODO: integrated creation of config
}