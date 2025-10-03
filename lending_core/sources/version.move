module lending_core::version {
    use lending_core::error::{Self};
    use lending_core::constants::{Self};

    public fun this_version(): u64 {
        constants::version()
    }

    public fun next_version(): u64 {
        constants::version() + 1
    }

    public fun pre_check_version(v: u64) {
        assert!(v == constants::version(), error::incorrect_version())
    }
}