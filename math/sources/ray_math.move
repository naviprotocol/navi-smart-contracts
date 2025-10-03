// title: WadRayMath module
// Provides mul and div function for wads (decimal numbers with 18 digits precision) and rays (decimals with 27 digits)
module math::ray_math {
    use sui::address; // max(u256) => address::max()

    const WAD: u256 = 1000000000000000000;
    const HALF_WAD: u256 = 1000000000000000000 / 2;

    const RAY: u256 = 1000000000000000000000000000;
    const HALF_RAY: u256 = 1000000000000000000000000000 / 2;

    const WAD_RAY_RATIO: u256 = 1000000000;

    // Error Code
    const RAY_MATH_MULTIPLICATION_OVERFLOW: u64 = 1101;
    const RAY_MATH_ADDITION_OVERFLOW: u64 = 1102;
    const RAY_MATH_DIVISION_BY_ZERO: u64 = 1103;
    

    // return: ray, 1e27 -> 1000000000000000000000000000
    public fun ray(): u256 {
        RAY
    }

    // return wad, 1e18 -> 1000000000000000000
    public fun wad(): u256 {
        WAD
    }

    // return half ray, 1e27 / 2 -> 1000000000000000000000000000 / 2
    public fun half_ray(): u256 {
        HALF_RAY
    }

    // return half wad, 1e18 / 2 -> 1000000000000000000 / 2
    public fun half_wad(): u256 {
        HALF_WAD
    }

    // title: Multiplies two wad, rounding half up to the nearest wad
    // param a: Wad
    // param b: Wad
    // return: The result of a * b, in wad
    public fun wad_mul(a: u256, b: u256): u256 {
        if (a == 0 || b == 0) {
            return 0
        };

        assert!(a <= (address::max() - HALF_WAD) / b, RAY_MATH_MULTIPLICATION_OVERFLOW);

        (a * b + HALF_WAD) / WAD
    }

    // title: Divides two wad, rounding half up to the nearest wad
    // param a: Wad
    // param b: Wad
    // return: The result of a / b, in wad
    public fun wad_div(a: u256, b: u256): u256 {
        assert!(b != 0, RAY_MATH_DIVISION_BY_ZERO);
        let halfB = b / 2;

        assert!(a <= (address::max() - halfB) / WAD, RAY_MATH_MULTIPLICATION_OVERFLOW);

        (a * WAD + halfB) / b
    }

    // title: Multiplies two ray, rounding half up to the nearest ray
    // param a: Ray
    // param b: Ray
    // return: The result of a * b, in ray
    public fun ray_mul(a: u256, b: u256): u256 {
        if (a == 0 || b == 0) {
            return 0
        };

        assert!(a <= (address::max() - HALF_RAY) / b, RAY_MATH_MULTIPLICATION_OVERFLOW);

        (a * b + HALF_RAY) / RAY
    }

    // title: Divides two ray, rounding half up to the nearest ray
    // param a: Ray
    // param b: Ray
    // return: The result of a / b, in ray
    public fun ray_div(a: u256, b: u256): u256 {
        assert!(b != 0, RAY_MATH_DIVISION_BY_ZERO);
        let halfB = b / 2;

        assert!(a <= (address::max() - halfB) / RAY, RAY_MATH_MULTIPLICATION_OVERFLOW);

        (a * RAY + halfB) / b
    }

    // title: Casts ray down to wad
    // param a: Ray
    // return: a casted to wad, rounded half up to the nearest wad
    public fun ray_to_wad(a: u256): u256 {
        let halfRatio = WAD_RAY_RATIO / 2;
        let result = halfRatio + a;
        assert!(result >= halfRatio, RAY_MATH_ADDITION_OVERFLOW);

        result / WAD_RAY_RATIO
    }

    // title: Converts wad up to ray
    // param a: Wad
    // return: a converted in ray
    public fun wad_to_ray(a: u256): u256 {
        let result = a * WAD_RAY_RATIO;
        assert!(result / WAD_RAY_RATIO == a, RAY_MATH_MULTIPLICATION_OVERFLOW);
        result
    }
}
