module oracle::oracle_version {
    use oracle::oracle_error::{Self as error};
    use oracle::oracle_constants::{Self as constants};

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