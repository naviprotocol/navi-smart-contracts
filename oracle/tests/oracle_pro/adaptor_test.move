#[test_only]
module oracle::adaptor_test {
    use sui::test_scenario;
    use std::vector::{Self};
    use sui::clock::{Self};
    use oracle::oracle::{Self, OracleAdminCap, PriceOracle};
    use oracle::config::{Self, OracleConfig};

    use oracle::oracle_manage;
    use oracle::oracle_global::{Self as global};
    use oracle::oracle_pro;
    use oracle::oracle_lib::{Self as lib};
    use oracle::oracle_provider::{pyth_provider, supra_provider};

    use oracle::oracle_sui_test::{ORACLE_SUI_TEST};

    use oracle::adaptor_supra;

    #[test]
    public fun test_pair_id_to_vector() {
        let i = 1;
        while (i < 100000) {
            let vec = adaptor_supra::pair_id_to_vector(i);
            i = i * 10;
            lib::print(&vec);
        };
    }

    // Should convert vector to id
    // Should convert id to vector
    #[test]
    public fun test_pair_id_vector() {
        let i = 1;
        while (i < 100000) {
            let vec = adaptor_supra::pair_id_to_vector(i);
            assert!(adaptor_supra::vector_to_pair_id(vec) == i, 0);
            i = i * 10;
        };
    }

}