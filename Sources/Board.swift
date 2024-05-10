/// Uses a 64-bit integer to represent a board. Each 4-bit sequence represents a single square on the board.
/// This limits the board to representing at most the 32,768 tile.
///
/// Each nibble stores the log2 value of the tile. Eg if the tile has a value of `2`, we store `1 = 0b0001`, or 2^1 = 2.
/// If the tile's value was `8` we store `3 = 0b0011` or  2^3 = 8.
///
/// ```
/// Tile |  0  | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9  | 10 | 11 | 12 | 13 | 14 | 15 |
/// Row  |  0                 | 1                 | 2                 | 3                 |
/// Col  |  0  | 1  | 2  | 3  | 0  | 1  | 2  | 3  | 0  | 1  | 2  | 3  | 0  | 1  | 2  | 3  |
/// Bits | 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000
/// ```
///
/// This representation is not unique, and was first seen in Robert Xiao's 2048 AI.
/// - https://github.com/nneonneo/2048-ai/tree/master
/// - https://stackoverflow.com/questions/22342854/what-is-the-optimal-algorithm-for-the-game-2048/22498940#22498940
///
/// However the implementation differs in multiple ways, including not treating rows and columns and individual entities
/// for heuristics. As well as several novel methods for extracting information quickly from the board representation.
struct Board: Hashable, Equatable, Sendable, CustomStringConvertible {
    init() {
        self.board = 0
        self.score = 0
    }

    init(_ board: UInt64, score: UInt = 0) {
        self.board = board
        self.score = score
    }

    init(_ board: Board) {
        self.board = board.board
        self.score = board.score
    }

    static let zero = Board(0x0)
    static func random() -> Board {
        Board(UInt64.random(in: 0..<UInt64.max))
    }

    /// The private board representation
    var board: UInt64
    var score: UInt

    // MARK: - Get, Set

    @inlinable
    func get(row: UInt, col: UInt) -> UInt {
        // Row shift offset is row * 16, col offset is 12 - col * 4
        let shiftOffset = ((3 - row) << 4) + ((3 - col) << 2)
        let boardShift = UInt64(board >> shiftOffset)
        // We then mask it to a single tile
        return UInt(boardShift & 0xF)
    }

    @inlinable
    mutating func set(row: UInt, col: UInt, newValue: UInt) {
        // Right shift 1 bit (our board only needs to store the 2^x value) and make it a UInt64
        // Row shift offset is row * 16, col offset is col * 4
        let shiftOffset = UInt64(((3 - row) << 4) + ((3 - col) << 2))
        let mask: UInt64 = 0xF << shiftOffset
        self.board = (self.board & ~mask) | (UInt64(newValue) << shiftOffset)
    }

    @inlinable
    subscript(row: UInt, col: UInt) -> UInt {
        get {
            get(row: row, col: col)
        }
        set {
            set(row: row, col: col, newValue: newValue)
        }
    }

    @inlinable
    subscript(row: Int, col: Int) -> Int {
        get {
            Int(get(row: UInt(row), col: UInt(col)))
        }
        set {
            set(row: UInt(row), col: UInt(col), newValue: UInt(newValue))
        }
    }

    // MARK: - Rotate

    /// Rotates the board clockwise.
    /// - Returns: The new, rotated board.
    func rotateClockwise() -> Board {
        var result = Board(0, score: score)
        var board = self.board
        var idx: UInt = 16
        while board > 0 {
            idx -= 1
            let row = idx >> 2 // idx / 4
            let col = idx & 3  // idx % 4
            result[col, 3 - row] = UInt(board & 0xF) // Grab only the last nibble
            board >>= 4
        }
        return result
    }

    /// Rotates the board counter-clockwise.
    /// - Returns: The new, rotated board.
    func rotateCounterClockwise() -> Board {
        var result = Board(0, score: score)
        var board = self.board
        var idx: UInt = 16
        while board > 0 {
            idx -= 1
            let row = idx >> 2 // idx / 4
            let col = idx & 3  // idx % 4
            result[3 - col, row] = UInt(board & 0xF) // Grab only the last nibble
            board >>= 4
        }
        return result
    }

    /// Inverts the board horizontally.
    /// - Returns: The new, inverted board.
    func invert() -> Board {
        var result = Board(0, score: score)
        var board = self.board
        var idx: UInt = 16
        while board > 0 {
            idx -= 1
            let row = idx >> 2 // idx / 4
            let col = idx & 3  // idx % 4
            result[row, 3 - col] = UInt(board & 0xF) // Grab only the last nibble
            board >>= 4
        }
        return result
    }

    // MARK: - Moves

    /// Performs a move on the board.
    /// - Note: Does not check if the move is 'valid'.
    /// - Parameter move: The move to perform.
    /// - Returns: The new board after the move.
    func move(_ move: Move) -> Board {
        switch move {
        case .left:
            return left()
        case .right:
            return right()
        case .up:
            return up()
        case .down:
            return down()
        }
    }

    /// Performs the left move on the board.
    /// - Returns: The new board after the move.
    func left() -> Board {
        invert().right().invert()
    }

    /// Performs the right move on the board.
    /// - Returns: The new board after the move.
    func right() -> Board {
        var result = Board(0, score: score)
        var rowValueBufferIndex = 0
        let rowValues = UnsafeMutablePointer<Int>.allocate(capacity: 4) // Swift needs a fixed size array PLEASE
        var canMergeLast = false
        var board = self.board
        for row in UInt(0)..<4 {
            for _ in 0..<4 {
                let tile = UInt(board & 0xF)
                // Loop through each tile in the row.
                // For each, check if we can merge with the last value found.
                // - If we can, merge it and mark it as unmergable.
                // Otherwise, check if the tile is > 0.
                // - If it is, we save it and mark it as mergable.
                if tile > 0 {
                    if rowValueBufferIndex > 0 && tile == rowValues[rowValueBufferIndex - 1] && canMergeLast {
                        result.score += 1 << rowValues[rowValueBufferIndex - 1]
                        rowValues[rowValueBufferIndex - 1] += 1
                        canMergeLast = false
                    } else {
                        rowValues[rowValueBufferIndex] = Int(tile)
                        rowValueBufferIndex += 1
                        canMergeLast = true
                    }
                }
                board >>= 4
            }
            for idx in UInt(0)..<4 {
                result[3 - row, 3 - idx] = UInt(rowValues[Int(idx)])
                rowValues[Int(idx)] = 0
            }
            rowValueBufferIndex = 0
            canMergeLast = false
        }
        rowValues.deallocate()
        return result
    }

    /// Performs the up move on the board.
    /// - Returns: The new board after the move.
    func up() -> Board {
        rotateClockwise().right().rotateCounterClockwise()
    }

    /// Performs the down move on the board.
    /// - Returns: The new board after the move.
    func down() -> Board {
        rotateCounterClockwise().right().rotateClockwise()
    }

    /// Finds all available moves for this board.
    /// - Note: Avoid this function if possible, it's really slow.
    /// - Returns: A set of available moves.
    func availableMoves() -> MoveSet {
        var moves = MoveSet()
        // Rotate around the clock to save time by reducing extra rotations.
        var newBoard = self.right()
        if newBoard != self {
            moves.right = true
        }

        newBoard = self.rotateClockwise()
        if newBoard.right() != newBoard {
            moves.up = true
        }

        newBoard = newBoard.rotateClockwise()
        if newBoard.right() != newBoard {
            moves.left = true
        }

        newBoard = newBoard.rotateClockwise()
        if newBoard.right() != newBoard {
            moves.down = true
        }

        return moves
    }

    // MARK: - Score

    /// Finds the sum of the tiles on this board.
    func sum() -> Int {
        var result: UInt64 = 0
        var board = self.board
        while board > 0 {
            result += board & 0xF
            board >>= 4
        }
        return Int(result)
    }

    /// Finds the indexes of all the tiles on this board.
    /// - Returns: The empty tile indexes.
    func getEmpty() -> [Int] {
        var result: [Int] = []
        var board = self.board
        var idx = 16
        while idx > 0 {
            idx -= 1
            if (board & 0xF) == 0 {
                result.append(idx)
            }
            board >>= 4
        }
        return result
    }

    /// Counts the number of empty tiles on the board.
    /// - Note: Much faster than `Board.getEmpty().count`.
    /// - Returns: The number of empty tiles.
    func countEmpty() -> Int {
        var board = self.board
        board |= (board >> 2) & 0x3333333333333333
        board |= (board >> 1)
        board = ~board & 0x1111111111111111
        return board.nonzeroBitCount
    }

    // MARK: - Hashable, Equatable

    static func == (lhs: Board, rhs: Board) -> Bool {
        lhs.board == rhs.board
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(board)
    }

    // MARK: - Display

    func display(showHex: Bool = true) {
        if showHex {
            let boardHex = String(self.board, radix: 16, uppercase: true)
            print(
                "Hex: 0x"
                + (
                    String(repeatElement("0", count: 16 - boardHex.count)) + boardHex
                ).inserting(separator: " ", every: 4)
            )
        }
        for row in 0..<4 {
            for col in 0..<4 {
                let str = String(self[row, col] == 0 ? 0 : pow(2, self[row, col]))
                print(str + String(repeatElement(" ", count: 6 - str.count)), terminator: "")
            }
            print("")
        }
    }

    var description: String {
        let boardHex = String(self.board, radix: 16, uppercase: true)
        return "0x" + (String(repeatElement("0", count: 16 - boardHex.count)) + boardHex)
            .inserting(separator: " ", every: 4)
    }
}
