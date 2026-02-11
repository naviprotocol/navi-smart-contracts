module example::move2024;

use sui::event;
use switchboard::aggregator::Aggregator;

public struct UpdateEvent has copy, drop {
    value: u128,
    timestamp: u64,
}

public fun example_move2024(aggregator: &Aggregator) {
    let current_result = aggregator.current_result();
    let new_result = UpdateEvent {
        value: current_result.result().value(),
        timestamp: current_result.min_timestamp_ms(),
    };
    event::emit(new_result);
}