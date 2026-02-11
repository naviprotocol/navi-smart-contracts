module example::legacy {
    use sui::event;
    use switchboard::aggregator::{Self, Aggregator};
    use switchboard::decimal;

    struct UpdateEvent has copy, drop {
        value: u128,
        timestamp: u64,
    }

    public fun example_legacy(aggregator: &Aggregator) {
        let current_result = aggregator::current_result(aggregator);
        let new_result = UpdateEvent {
            value: decimal::value(aggregator::result(current_result)),
            timestamp: aggregator::min_timestamp_ms(current_result),
        };
        event::emit(new_result);
    }
}
