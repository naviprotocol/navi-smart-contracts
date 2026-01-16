#[test_only]
module math::ray_math_test {
    use math::ray_math;

    #[test]
    public fun ray_test() {
        let ray_a: u256 = 1000000000000000000000000000; // 1 * 1e27
        let ray_b: u256 = 2000000000000000000000000000; // 2 * 1e27
        let ray_c: u256 = 3000000000000000000000000000; // 3 * 1e27
        let ray_d: u256 = 6000000000000000000000000000; // 6 * 1e27

        assert!(ray_math::ray() == ray_a, 101); // ray == 1 * 1e27
        assert!(ray_math::half_ray() == ray_a / 2, 102); // half_ray == 0.5 * 1e27
        assert!(ray_math::ray_mul(ray_b, ray_c) == ray_d, 103); // (2 * 1e27) * (3 * 1e27) = (6 * 1e27)
        assert!(ray_math::ray_div(ray_d, ray_c) == ray_b, 104); // (6 * 1e27) / (3 * 1e27) = (2 * 1e27)
    }

    #[test]
    public fun wad_test() {
        let wad_a: u256 = 1000000000000000000; // 1 * 1e18
        let wad_b: u256 = 2000000000000000000; // 2 * 1e18
        let wad_c: u256 = 3000000000000000000; // 3 * 1e18
        let wad_d: u256 = 6000000000000000000; // 6 * 1e18

        assert!(ray_math::wad() == wad_a, 201); // ray == 1 * 1e18
        assert!(ray_math::half_wad() == wad_a / 2, 202); // half_ray == 0.5 * 1e18
        assert!(ray_math::wad_mul(wad_b, wad_c) == wad_d, 203); // (2 * 1e18) * (3 * 1e18) = (6 * 1e18)
        assert!(ray_math::wad_div(wad_d, wad_c) == wad_b, 204); // (6 * 1e18) / (3 * 1e18) = (2 * 1e18)
    }

    #[test]
    public fun wad_and_ray_test() {
        let ray_a: u256 = 1000000000000000000000000000; // 1 * 1e27
        let wad_a: u256 = 1000000000000000000; // 1 * 1e18

        assert!(ray_math::ray_to_wad(ray_a) == wad_a, 301); // (1 * 1e27) -> (1 * 1e18)
        assert!(ray_math::wad_to_ray(wad_a) == ray_a, 302); // (1 * 1e18) -> (1 * 1e27)
    }
}