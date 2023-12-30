/// A chance structure that stores it's values in a single int32.
struct Chance {
    var val: UInt32 = 0

    init(row: Int, col: Int, isTwo: Bool) {
        val |= UInt32(row)
        val |= UInt32(col & 0xFF) << 8
        val |= isTwo ? (1 << 17) : 0
    }

    var row: Int {
        Int(val & 0xFF)
    }

    var col: Int {
        Int((val >> 8) & 0xFF)
    }

    var isTwo: Bool {
        val >> 17 > 0 ? true : false
    }
}
