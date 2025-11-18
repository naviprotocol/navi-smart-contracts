module liquid_staking::manage {

    const EIncompatibleVersion: u64 = 50001;
    const EIncompatiblePaused: u64 = 50002;

    public struct Manage has store {
        version: u64,
        paused: bool,
    }

    const VERSION: u64 = 1;

    public(package) fun new(): Manage {
        Manage { version: current_version(), paused: true }
    }

    public fun current_version(): u64 {
        VERSION
    }

    public fun check_version(self: &Manage) {
        assert!(self.version == VERSION, EIncompatibleVersion)
    }

    public fun check_not_paused(self: &Manage) {
        assert!(!self.paused, EIncompatiblePaused)
    }

    public(package) fun migrate_version(self: &mut Manage) {
        assert!(self.version <= VERSION, EIncompatibleVersion);
        self.version = VERSION;
    }

    public(package) fun set_paused(self: &mut Manage, paused: bool) {
        self.paused = paused;
    }
}