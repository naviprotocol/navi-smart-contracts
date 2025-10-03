module oracle::oracle_dynamic_getter {
    use sui::clock::{Self, Clock};
    use oracle::oracle::{Self, PriceOracle};
    use oracle::config::{Self, OracleConfig};
    use oracle::strategy::{Self};
    use oracle::oracle_error::{Self as error};
    use oracle::oracle_provider::{Self as provider};
    use oracle::oracle_constants::{Self as constants};
    use oracle::oracle_pro::{Self};
    use SupraOracle::SupraSValueFeed::{OracleHolder};
    use pyth::price_info::{PriceInfoObject};

    /// a dynamic function to fetch a latest price without actually updating the price
    /// return (result, price)
    #[allow(unused_assignment)]
    public fun get_dynamic_single_price(clock: &Clock, oracle_config: &OracleConfig, price_oracle: &PriceOracle, supra_oracle_holder: &OracleHolder, pyth_price_info: &PriceInfoObject, feed_address: address): (u64, u256) {
        config::version_verification(oracle_config);
        if(config::is_paused(oracle_config)) {
            return (error::paused(), 0)
        };

        let price_feed = config::get_price_feed(oracle_config, feed_address);
        if (!config::is_price_feed_enable(price_feed)) {
            return (error::price_feed_not_found(), 0)
        };

        // get timestamp ms from clock
        let current_timestamp = clock::timestamp_ms(clock);
        // get max timestamp diff from price feed
        let max_timestamp_diff = config::get_max_timestamp_diff_from_feed(price_feed);
        // get oracle id from price feed
        let oracle_id = config::get_oracle_id_from_feed(price_feed);
        // get coin decimal from oracle id
        let decimal = oracle::safe_decimal(price_oracle, oracle_id);

        // Core Logic
        let primary_oracle_provider = config::get_primary_oracle_provider(price_feed);
        if (provider::is_empty(primary_oracle_provider)) {
            return (error::invalid_oracle_provider(), 0)
        };
        let primary_oracle_provider_config = config::get_primary_oracle_provider_config(price_feed);
        if (!provider::is_oracle_provider_config_enable(primary_oracle_provider_config)) {
            // the administrator should shut it down before reaching here. No event or error is required at this time, it was confirmed by the administrator
            return (error::oracle_provider_disabled(), 0)
        };
        let (primary_price, primary_updated_time) = oracle_pro::get_price_from_adaptor(primary_oracle_provider_config, decimal, supra_oracle_holder, pyth_price_info);
        let is_primary_price_fresh = strategy::is_oracle_price_fresh(current_timestamp, primary_updated_time, max_timestamp_diff);

        // retrieve secondary price and status
        let is_secondary_price_fresh = false;
        let is_secondary_oracle_available = config::is_secondary_oracle_available(price_feed);
        let secondary_price = 0;
        let secondary_updated_time = 0;
        if (is_secondary_oracle_available) {
            let secondary_source_config = config::get_secondary_source_config(price_feed);
            (secondary_price, secondary_updated_time) = oracle_pro::get_price_from_adaptor(secondary_source_config, decimal, supra_oracle_holder, pyth_price_info);
            is_secondary_price_fresh = strategy::is_oracle_price_fresh(current_timestamp, secondary_updated_time, max_timestamp_diff);
        };

        // filter primary price and secondary price to get the final price
        let final_price = primary_price;
        if (is_primary_price_fresh && is_secondary_price_fresh) { // if 2 price sources are fresh, validate price diff
            let (price_diff_threshold1, price_diff_threshold2) = (config::get_price_diff_threshold1_from_feed(price_feed), config::get_price_diff_threshold2_from_feed(price_feed));
            let max_duration_within_thresholds = config::get_max_duration_within_thresholds_from_feed(price_feed);
            let diff_threshold2_timer = config::get_diff_threshold2_timer_from_feed(price_feed);
            let severity = strategy::validate_price_difference(primary_price, secondary_price, price_diff_threshold1, price_diff_threshold2, current_timestamp, max_duration_within_thresholds, diff_threshold2_timer);
            if (severity != constants::level_normal()) {
                if (severity != constants::level_warning()) { return (error::invalid_price_diff(), 0)};
            };
        } else if (is_primary_price_fresh) { // if secondary price not fresh and primary price fresh
            // do nothing
        } else if (is_secondary_price_fresh) { // if primary price not fresh and secondary price fresh
            final_price = secondary_price;
        } else { // no fresh price, terminate price feed
            return (error::no_available_price(), 0)
        };

        // validate final price 
        let (maximum_effective_price, minimum_effective_price) = (config::get_maximum_effective_price_from_feed(price_feed), config::get_minimum_effective_price_from_feed(price_feed));
        let maximum_allowed_span_percentage = config::get_maximum_allowed_span_percentage_from_feed(price_feed);
        let historical_price_ttl = config::get_historical_price_ttl(price_feed);
        let (historical_price, historical_updated_time) = config::get_history_price_data_from_feed(price_feed);

        if (!strategy::validate_price_range_and_history(final_price, maximum_effective_price, minimum_effective_price, maximum_allowed_span_percentage, current_timestamp, historical_price_ttl, historical_price, historical_updated_time)) {
            return (error::invalid_final_price(), 0)
        };
        (constants::success(), final_price)
    }
}