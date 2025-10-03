// Wrapper for arithmetic operations
module math::safe_math {
    // Error Code
    const SAFE_MATH_ADDITION_OVERFLOW: u64 = 1001;
    const SAFE_MATH_SUBTRACTION_OVERFLOW: u64 = 1002;
    const SAFE_MATH_MULTIPLICATION_OVERFLOW: u64 = 1003;
    const SAFE_MATH_DIVISION_BY_ZERO: u64 = 1004;
    const SAFE_MATH_MODULO_BY_ZERO: u64 = 1005;

    // return: Returns the addition of two unsigned integers
    public fun add(a: u256, b: u256): u256 {
        let c = a + b;
        assert!(c >= a, SAFE_MATH_ADDITION_OVERFLOW);
        return c
    }

    // return: Returns the subtraction of two unsigned integers
    public fun sub(a: u256, b: u256): u256 {
        assert!(b <= a, SAFE_MATH_SUBTRACTION_OVERFLOW);
        let c = a - b;
        return c
    }

    // return: Returns the multiplication of two unsigned integers
    public fun mul(a: u256, b: u256): u256 {
        if (a == 0) {
            return 0
        };

        let c = a * b;
        assert!(c / a == b, SAFE_MATH_MULTIPLICATION_OVERFLOW);

        return c
    }

    // return: Returns the integer division of two unsigned integers
    public fun div(a: u256, b: u256): u256 {
         assert!(b > 0, SAFE_MATH_DIVISION_BY_ZERO);
         let c = a / b;
         return c
    }

    // return: Returns the remainder of dividing two unsigned integers.
    public fun mod(a: u256, b: u256): u256 {
        assert!(b != 0, SAFE_MATH_MODULO_BY_ZERO);
        return a % b
    }

    /// Return the smaller of `x` and `y`
    public fun min(x: u256, y: u256): u256 {
        if (x < y) {
            x
        } else {
            y
        }
    }
}