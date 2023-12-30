func pow(_ base: Int, _ exp: Int) -> Int {
    var result = 1
    var exp = exp
    var base = base
    while exp != 0 {
        if (exp & 1) == 1 {
            result *= base
        }
        exp >>= 1
        base *= base
    }
    return result
}

func pow(_ base: UInt, _ exp: UInt) -> UInt {
    var result: UInt = 1
    var exp = exp
    var base = base
    while exp != 0 {
        if (exp & 1) == 1 {
            result *= base
        }
        exp >>= 1
        base *= base
    }
    return result
}
