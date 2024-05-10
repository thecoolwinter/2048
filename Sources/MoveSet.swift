/// A set of moves stored in a single int, faster to allocate and use than a Swift array.
struct MoveSet: Equatable, Hashable {
    var value: UInt8 = 0

    var left: Bool {
        get {
            value & 0b0001 > 0
        }
        set {
            if newValue {
                value |= 0b0001
            } else {
                value &= 0b1110
            }
        }
    }

    var right: Bool {
        get {
            value & 0b0010 > 0
        }
        set {
            if newValue {
                value |= 0b0010
            } else {
                value &= 0b1101
            }
        }
    }

    var up: Bool {
        get {
            value & 0b0100 > 0
        }
        set {
            if newValue {
                value |= 0b0100
            } else {
                value &= 0b1011
            }
        }
    }

    var down: Bool {
        get {
            value & 0b1000 > 0
        }
        set {
            if newValue {
                value |= 0b1000
            } else {
                value &= 0b0111
            }
        }
    }

    var isEmpty: Bool {
        value == 0
    }

    var first: Move {
        if left {
            return .left
        } else if right {
            return .right
        } else if up {
            return .up
        } else {
            return .down
        }
    }

    func contains(_ move: Move) -> Bool {
        switch move {
        case .left:
            return left
        case .right:
            return right
        case .up:
            return up
        case .down:
            return down
        }
    }

    func all() -> [Move] {
        var moves: [Move] = []
        if left {
            moves.append(.left)
        }
        if right {
            moves.append(.right)
        }
        if up {
            moves.append(.up)
        }
        if down {
            moves.append(.down)
        }
        return moves
    }

    mutating func pop() -> Move? {
        if value == 0 {
            return nil
        } else {
            for idx in 0..<4 where value & (0b1 << idx) > 0 {
                value &= ~(0b1 << idx)
                switch idx {
                case 0:
                    return .left
                case 1:
                    return .right
                case 2:
                    return .up
                case 3:
                    return .down
                default:
                    return nil
                }
            }
        }
        return nil
    }

    static func == (lhs: MoveSet, rhs: MoveSet) -> Bool {
        lhs.value == rhs.value
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}
