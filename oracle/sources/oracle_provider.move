module oracle::oracle_provider {
    use std::ascii::{Self, String};

    friend oracle::config;

    struct OracleProviderConfig has store {
        provider: OracleProvider,
        enable: bool,
        pair_id: vector<u8>,
    }

    struct OracleProvider has copy, store, drop {
        name: String
    }

    public(friend) fun new_oracle_provider_config(provider: OracleProvider, enable: bool, pair_id: vector<u8>): OracleProviderConfig {
        OracleProviderConfig {
            provider: provider,
            enable: enable,
            pair_id: pair_id,
        }
    }

    public(friend) fun set_pair_id_to_oracle_provider_config(provider_config: &mut OracleProviderConfig, pair_id: vector<u8>) {
        provider_config.pair_id = pair_id
    }

    public(friend) fun set_enable_to_oracle_provider_config(provider_config: &mut OracleProviderConfig, enable: bool) {
        provider_config.enable = enable
    }

    public fun get_pair_id_from_oracle_provider_config(provider_config: &OracleProviderConfig): vector<u8>{
        provider_config.pair_id
    }

    public fun is_oracle_provider_config_enable(provider_config: &OracleProviderConfig): bool {
        provider_config.enable
    }

    public fun get_provider_from_oracle_provider_config(provider_config: &OracleProviderConfig): OracleProvider {
        provider_config.provider
    }

    public fun supra_provider(): OracleProvider {
        OracleProvider {
            name: ascii::string(b"SupraOracleProvider"),
        }
    }

    public fun pyth_provider(): OracleProvider {
        OracleProvider {
            name: ascii::string(b"PythOracleProvider"),
        }
    }

    public fun new_empty_provider(): OracleProvider {
        OracleProvider {
            name: ascii::string(b""),
        }
    }

    public fun to_string(f: &OracleProvider): String {
        f.name
    }

    public fun is_empty(f: &OracleProvider): bool {
        ascii::length(&f.name) == 0
    }

    #[test_only]
    public fun test_provider(): OracleProvider {
        OracleProvider {
            name: ascii::string(b"Test"),
        }
    }
}