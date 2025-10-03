module oracle::oracle_pro {
    use sui::event::emit;
    use std::ascii::{String};
    use sui::clock::{Self, Clock};
    use oracle::oracle_provider::{Self as provider, OracleProviderConfig};
    use oracle::oracle_error::{Self as error};
    use oracle::oracle::{Self, PriceOracle};
    use oracle::config::{Self, OracleConfig};
    use oracle::strategy::{Self};
    use oracle::oracle_constants::{Self as constants};
    use SupraOracle::SupraSValueFeed::{OracleHolder};
    use pyth::price_info::{PriceInfoObject};

    #[test_only]
    use std::vector::{Self};

    // Events
    struct PriceRegulation has copy, drop {
        level: u8,
        config_address: address,
        feed_address: address,
        price_diff_threshold1: u64,
        price_diff_threshold2: u64,
        current_time: u64,
        diff_threshold2_timer: u64,
        max_duration_within_thresholds: u64,
        primary_price: u256,
        secondary_price: u256,
    }

    struct InvalidOraclePrice has copy, drop {
        config_address: address,
        feed_address: address,
        provider: String,
        price: u256,
        maximum_effective_price: u256,
        minimum_effective_price: u256,
        maximum_allowed_span: u64,
        current_timestamp: u64,
        historical_price_ttl: u64,
        historical_price: u256,
        historical_updated_time: u64,
    }

    struct OracleUnavailable has copy, drop {
        type: u8,
        config_address: address,
        feed_address: address,
        provider: String,
        price: u256,
        updated_time: u64,
    }

    public fun update_single_price(clock: &Clock, oracle_config: &mut OracleConfig, price_oracle: &mut PriceOracle, supra_oracle_holder: &OracleHolder, pyth_price_info: &PriceInfoObject, feed_address: address) {
        config::version_verification(oracle_config);
        assert!(!config::is_paused(oracle_config), error::paused());

        let config_address = config::get_config_id_to_address(oracle_config);
        let price_feed = config::get_price_feed_mut(oracle_config, feed_address);
        if (!config::is_price_feed_enable(price_feed)) {
            return
        };

        // get timestamp ms from clock
        let current_timestamp = clock::timestamp_ms(clock);
        // get max timestamp diff from price feed
        let max_timestamp_diff = config::get_max_timestamp_diff_from_feed(price_feed);
        // get oracle id from price feed
        let oracle_id = config::get_oracle_id_from_feed(price_feed);
        // get coin decimal from oracle id
        let decimal = oracle::decimal(price_oracle, oracle_id);

        // Core Logic
        let primary_oracle_provider = config::get_primary_oracle_provider(price_feed);
        if (provider::is_empty(primary_oracle_provider)) {
            return
        };
        let primary_oracle_provider_config = config::get_primary_oracle_provider_config(price_feed);
        if (!provider::is_oracle_provider_config_enable(primary_oracle_provider_config)) {
            // the administrator should shut it down before reaching here. No event or error is required at this time, it was confirmed by the administrator
            return
        };
        let (primary_price, primary_updated_time) = get_price_from_adaptor(primary_oracle_provider_config, decimal, supra_oracle_holder, pyth_price_info);
        let is_primary_price_fresh = strategy::is_oracle_price_fresh(current_timestamp, primary_updated_time, max_timestamp_diff);

        // retrieve secondary price and status
        let is_secondary_price_fresh = false;
        let is_secondary_oracle_available = config::is_secondary_oracle_available(price_feed);
        let secondary_price = 0;
        let secondary_updated_time = 0;
        if (is_secondary_oracle_available) {
            let secondary_source_config = config::get_secondary_source_config(price_feed);
            (secondary_price, secondary_updated_time) = get_price_from_adaptor(secondary_source_config, decimal, supra_oracle_holder, pyth_price_info);
            is_secondary_price_fresh = strategy::is_oracle_price_fresh(current_timestamp, secondary_updated_time, max_timestamp_diff);
        };

        // filter primary price and secondary price to get the final price
        let start_or_continue_diff_threshold2_timer = false;
        let final_price = primary_price;
        if (is_primary_price_fresh && is_secondary_price_fresh) { // if 2 price sources are fresh, validate price diff
            let (price_diff_threshold1, price_diff_threshold2) = (config::get_price_diff_threshold1_from_feed(price_feed), config::get_price_diff_threshold2_from_feed(price_feed));
            let max_duration_within_thresholds = config::get_max_duration_within_thresholds_from_feed(price_feed);
            let diff_threshold2_timer = config::get_diff_threshold2_timer_from_feed(price_feed);
            let severity = strategy::validate_price_difference(primary_price, secondary_price, price_diff_threshold1, price_diff_threshold2, current_timestamp, max_duration_within_thresholds, diff_threshold2_timer);
            if (severity != constants::level_normal()) {
                emit (PriceRegulation {
                    level: severity,
                    config_address: config_address,
                    feed_address: feed_address,
                    price_diff_threshold1: price_diff_threshold1,
                    price_diff_threshold2: price_diff_threshold2,
                    current_time: current_timestamp,
                    diff_threshold2_timer: diff_threshold2_timer,
                    max_duration_within_thresholds: max_duration_within_thresholds,
                    primary_price: primary_price,
                    secondary_price: secondary_price,
                });
                if (severity != constants::level_warning()) { return };
                start_or_continue_diff_threshold2_timer = true;
            };
        } else if (is_primary_price_fresh) { // if secondary price not fresh and primary price fresh
            if (is_secondary_oracle_available) { // prevent single source mode from keeping emitting event
                emit(OracleUnavailable {type: constants::secondary_type(), config_address, feed_address, provider: provider::to_string(config::get_secondary_oracle_provider(price_feed)), price: secondary_price, updated_time: secondary_updated_time});
            };
        } else if (is_secondary_price_fresh) { // if primary price not fresh and secondary price fresh
            emit(OracleUnavailable {type: constants::primary_type(), config_address, feed_address, provider: provider::to_string(primary_oracle_provider), price: primary_price, updated_time: primary_updated_time});
            final_price = secondary_price;
        } else { // no fresh price, terminate price feed
            emit(OracleUnavailable {type: constants::both_type(), config_address, feed_address, provider: provider::to_string(primary_oracle_provider), price: primary_price, updated_time: primary_updated_time});
            return
        };

        // validate final price 
        let (maximum_effective_price, minimum_effective_price) = (config::get_maximum_effective_price_from_feed(price_feed), config::get_minimum_effective_price_from_feed(price_feed));
        let maximum_allowed_span_percentage = config::get_maximum_allowed_span_percentage_from_feed(price_feed);
        let historical_price_ttl = config::get_historical_price_ttl(price_feed);
        let (historical_price, historical_updated_time) = config::get_history_price_data_from_feed(price_feed);

        if (!strategy::validate_price_range_and_history(final_price, maximum_effective_price, minimum_effective_price, maximum_allowed_span_percentage, current_timestamp, historical_price_ttl, historical_price, historical_updated_time)) {
            emit(InvalidOraclePrice {
                config_address: config_address,
                feed_address: feed_address,
                provider: provider::to_string(primary_oracle_provider),
                price: final_price,
                maximum_effective_price: maximum_effective_price,
                minimum_effective_price: minimum_effective_price,
                maximum_allowed_span: maximum_allowed_span_percentage,
                current_timestamp: current_timestamp,
                historical_price_ttl: historical_price_ttl,
                historical_price: historical_price,
                historical_updated_time: historical_updated_time,
            });
            return
        };

        if (start_or_continue_diff_threshold2_timer) {
            config::start_or_continue_diff_threshold2_timer(price_feed, current_timestamp)
        } else {
            config::reset_diff_threshold2_timer(price_feed)
        };
        // update the history price to price feed
        config::keep_history_update(price_feed, final_price, clock::timestamp_ms(clock)); 
        // update the final price to PriceOracle
        oracle::update_price(clock, price_oracle, oracle_id, final_price); 
    }

    public fun get_price_from_adaptor(oracle_provider_config: &OracleProviderConfig, target_decimal: u8, supra_oracle_holder: &OracleHolder, pyth_price_info: &PriceInfoObject): (u256, u64) {
        let (provider, pair_id) = (provider::get_provider_from_oracle_provider_config(oracle_provider_config), config::get_pair_id_from_oracle_provider_config(oracle_provider_config));
        if (provider == provider::supra_provider()) {
            let supra_pair_id = oracle::adaptor_supra::vector_to_pair_id(pair_id);
            let (price, timestamp) = oracle::adaptor_supra::get_price_to_target_decimal(supra_oracle_holder, supra_pair_id, target_decimal);
            return (price, timestamp)
        };

        if (provider == provider::pyth_provider()) {
            let pyth_pair_id = oracle::adaptor_pyth::get_identifier_to_vector(pyth_price_info);
            assert!(sui::address::from_bytes(pyth_pair_id) == sui::address::from_bytes(pair_id), error::pair_not_match());
            let (price, timestamp) = oracle::adaptor_pyth::get_price_unsafe_to_target_decimal(pyth_price_info, target_decimal);
            return (price, timestamp)
        };

        abort error::invalid_oracle_provider()
    }

    #[test_only]
    public fun update_single_price_for_testing(clock: &Clock, oracle_config: &mut OracleConfig, price_oracle: &mut PriceOracle, in_primary_price: u256, in_primary_updated_time: u64, in_secondary_price: u256, in_secondary_updated_time: u64, feed_address: address) {
        config::version_verification(oracle_config);
        assert!(!config::is_paused(oracle_config), error::paused());

        let config_address = config::get_config_id_to_address(oracle_config);
        let price_feed = config::get_price_feed_mut(oracle_config, feed_address);
        if (!config::is_price_feed_enable(price_feed)) {
            return
        };

        // get timestamp ms from clock
        let current_timestamp = clock::timestamp_ms(clock);
        // get max timestamp diff from price feed
        let max_timestamp_diff = config::get_max_timestamp_diff_from_feed(price_feed);
        // get oracle id from price feed
        let oracle_id = config::get_oracle_id_from_feed(price_feed);
        // get coin decimal from oracle id
        // let decimal = oracle::decimal(price_oracle, oracle_id);

        // Core Logic
        let primary_oracle_provider = config::get_primary_oracle_provider(price_feed);
        if (provider::is_empty(primary_oracle_provider)) {
            abort 1
        };
        // let primary_oracle_provider_config = config::get_primary_oracle_provider_config(price_feed);
        let (primary_price, primary_updated_time) = (in_primary_price, in_primary_updated_time);
        // let (primary_price, primary_updated_time) = get_price_from_adaptor(clock, primary_oracle_provider_config, decimal, supra_oracle_holder, pyth_state, pyth_price_info);
        let is_primary_price_fresh = strategy::is_oracle_price_fresh(current_timestamp, primary_updated_time, max_timestamp_diff);

        // retrieve secondary price and status
        let is_secondary_price_fresh = false;
        let is_secondary_oracle_available = config::is_secondary_oracle_available(price_feed);
        let secondary_price = 0;
        if (is_secondary_oracle_available) {
            // let secondary_source_config = config::get_secondary_source_config(price_feed);
            let secondary_updated_time;
            (secondary_price, secondary_updated_time) = (in_secondary_price, in_secondary_updated_time);
            // (secondary_price, secondary_updated_time) = get_price_from_adaptor(clock, secondary_source_config, decimal, supra_oracle_holder, pyth_state, pyth_price_info);
            is_secondary_price_fresh = strategy::is_oracle_price_fresh(current_timestamp, secondary_updated_time, max_timestamp_diff);
        };

        // filter primary price and secondary price to get the final price
        let start_or_continue_diff_threshold2_timer = false;
        let final_price = primary_price;
        if (is_primary_price_fresh && is_secondary_price_fresh) { // if 2 price sources are fresh, validate price diff
            let (price_diff_threshold1, price_diff_threshold2) = (config::get_price_diff_threshold1_from_feed(price_feed), config::get_price_diff_threshold2_from_feed(price_feed));
            let max_duration_within_thresholds = config::get_max_duration_within_thresholds_from_feed(price_feed);
            let diff_threshold2_timer = config::get_diff_threshold2_timer_from_feed(price_feed);
            let severity = strategy::validate_price_difference(primary_price, secondary_price, price_diff_threshold1, price_diff_threshold2, current_timestamp, max_duration_within_thresholds, diff_threshold2_timer);
            if (severity != constants::level_normal()) {
                if (severity != constants::level_warning()) { abort 2 };
                start_or_continue_diff_threshold2_timer = true;
            };
        } else if (is_primary_price_fresh) { // if secondary price not fresh and primary price fresh
            if (is_secondary_oracle_available) { // prevent single source mode from keeping emitting event
            };
        } else if (is_secondary_price_fresh) { // if primary price not fresh and secondary price fresh
            final_price = secondary_price;
        } else { // no fresh price, terminate price feed
            abort 3
        };

        // validate final price 
        let (maximum_effective_price, minimum_effective_price) = (config::get_maximum_effective_price_from_feed(price_feed), config::get_minimum_effective_price_from_feed(price_feed));
        let maximum_allowed_span_percentage = config::get_maximum_allowed_span_percentage_from_feed(price_feed);
        let historical_price_ttl = config::get_historical_price_ttl(price_feed);
        let (historycal_price, historycal_updated_time) = config::get_history_price_data_from_feed(price_feed);

        if (!strategy::validate_price_range_and_history(final_price, maximum_effective_price, minimum_effective_price, maximum_allowed_span_percentage, current_timestamp, historical_price_ttl, historycal_price, historycal_updated_time)) {
            abort 4
        };

        if (start_or_continue_diff_threshold2_timer) {
            config::start_or_continue_diff_threshold2_timer(price_feed, current_timestamp)
        } else {
            config::reset_diff_threshold2_timer(price_feed)
        };
        // update the history price to price feed
        config::keep_history_update(price_feed, final_price, clock::timestamp_ms(clock)); 
        // update the final price to PriceOracle
        oracle::update_price(clock, price_oracle, oracle_id, final_price); 
    }

    #[test_only]
    public fun update_prices_for_testing(clock: &Clock, oracle_config: &mut OracleConfig, price_oracle: &mut PriceOracle, in_primary_prices: &vector<u256>, in_primary_updated_times: &vector<u64>, in_secondary_prices: &vector<u256>, in_secondary_updated_times: &vector<u64>) {
        let feeds = config::get_vec_feeds(oracle_config);
        let len = vector::length(&feeds);
        let i = 0;
        while (i < len) {
            let feed_id = *vector::borrow(&feeds, i);
            let in_primary_price = *vector::borrow(in_primary_prices, i);
            let in_primary_updated_time = *vector::borrow(in_primary_updated_times, i);
            let in_secondary_price = *vector::borrow(in_secondary_prices, i);
            let in_secondary_updated_time = *vector::borrow(in_secondary_updated_times, i);
            update_single_price_for_testing_non_abort(clock, oracle_config, price_oracle, in_primary_price, in_primary_updated_time, in_secondary_price, in_secondary_updated_time, feed_id);

            i = i + 1;
        };
    }

    #[test_only]
    public fun update_single_price_for_testing_non_abort(clock: &Clock, oracle_config: &mut OracleConfig, price_oracle: &mut PriceOracle, in_primary_price: u256, in_primary_updated_time: u64, in_secondary_price: u256, in_secondary_updated_time: u64, feed_address: address): u8 {
        config::version_verification(oracle_config);
        assert!(!config::is_paused(oracle_config), error::paused());

        let _config_address = config::get_config_id_to_address(oracle_config);
        let price_feed = config::get_price_feed_mut(oracle_config, feed_address);
        if (!config::is_price_feed_enable(price_feed)) {
            return 1
        };

        // get timestamp ms from clock
        let current_timestamp = clock::timestamp_ms(clock);
        // get max timestamp diff from price feed
        let max_timestamp_diff = config::get_max_timestamp_diff_from_feed(price_feed);
        // get oracle id from price feed
        let oracle_id = config::get_oracle_id_from_feed(price_feed);
        // get coin decimal from oracle id
        // let decimal = oracle::decimal(price_oracle, oracle_id);

        // Core Logic
        let primary_oracle_provider = config::get_primary_oracle_provider(price_feed);
        if (provider::is_empty(primary_oracle_provider)) {
            return 2
        };
        // let primary_oracle_provider_config = config::get_primary_oracle_provider_config(price_feed);
        let (primary_price, primary_updated_time) = (in_primary_price, in_primary_updated_time);
        // let (primary_price, primary_updated_time) = get_price_from_adaptor(clock, primary_oracle_provider_config, decimal, supra_oracle_holder, pyth_state, pyth_price_info);
        let is_primary_price_fresh = strategy::is_oracle_price_fresh(current_timestamp, primary_updated_time, max_timestamp_diff);

        // retrieve secondary price and status
        let is_secondary_price_fresh = false;
        let is_secondary_oracle_available = config::is_secondary_oracle_available(price_feed);
        let secondary_price = 0;
        if (is_secondary_oracle_available) {
            // let secondary_source_config = config::get_secondary_source_config(price_feed);
            let secondary_updated_time;
            (secondary_price, secondary_updated_time) = (in_secondary_price, in_secondary_updated_time);
            // (secondary_price, secondary_updated_time) = get_price_from_adaptor(clock, secondary_source_config, decimal, supra_oracle_holder, pyth_state, pyth_price_info);
            is_secondary_price_fresh = strategy::is_oracle_price_fresh(current_timestamp, secondary_updated_time, max_timestamp_diff);
        };

        // filter primary price and secondary price to get the final price
        let start_or_continue_diff_threshold2_timer = false;
        let final_price = primary_price;
        if (is_primary_price_fresh && is_secondary_price_fresh) { // if 2 price sources are fresh, validate price diff
            let (price_diff_threshold1, price_diff_threshold2) = (config::get_price_diff_threshold1_from_feed(price_feed), config::get_price_diff_threshold2_from_feed(price_feed));
            let max_duration_within_thresholds = config::get_max_duration_within_thresholds_from_feed(price_feed);
            let diff_threshold2_timer = config::get_diff_threshold2_timer_from_feed(price_feed);
            let severity = strategy::validate_price_difference(primary_price, secondary_price, price_diff_threshold1, price_diff_threshold2, current_timestamp, max_duration_within_thresholds, diff_threshold2_timer);
            if (severity != constants::level_normal()) {
                if (severity != constants::level_warning()) { return (severity + 10)};
                start_or_continue_diff_threshold2_timer = true;
            };
        } else if (is_primary_price_fresh) { // if secondary price not fresh and primary price fresh
            if (is_secondary_oracle_available) { // prevent single source mode from keeping emitting event
            };
        } else if (is_secondary_price_fresh) { // if primary price not fresh and secondary price fresh
            final_price = secondary_price;
        } else { // no fresh price, terminate price feed
            return 4
        };

        // validate final price 
        let (maximum_effective_price, minimum_effective_price) = (config::get_maximum_effective_price_from_feed(price_feed), config::get_minimum_effective_price_from_feed(price_feed));
        let maximum_allowed_span_percentage = config::get_maximum_allowed_span_percentage_from_feed(price_feed);
        let historical_price_ttl = config::get_historical_price_ttl(price_feed);
        let (historycal_price, historycal_updated_time) = config::get_history_price_data_from_feed(price_feed);

        if (!strategy::validate_price_range_and_history(final_price, maximum_effective_price, minimum_effective_price, maximum_allowed_span_percentage, current_timestamp, historical_price_ttl, historycal_price, historycal_updated_time)) {
            return 5
        };

        if (start_or_continue_diff_threshold2_timer) {
            config::start_or_continue_diff_threshold2_timer(price_feed, current_timestamp)
        } else {
            config::reset_diff_threshold2_timer(price_feed)
        };
        // update the history price to price feed
        config::keep_history_update(price_feed, final_price, clock::timestamp_ms(clock)); 
        // update the final price to PriceOracle
        oracle::update_price(clock, price_oracle, oracle_id, final_price); 
        return 0
    }
}