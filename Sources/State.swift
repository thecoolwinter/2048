/// Represents a current state of a game and facilitates moves on the board with random results.
struct State {
    var currentBoard: Board
    var step: Int = 0

    init() {
        self.currentBoard = .zero
        var tiles = (0..<16).map({ $0 })
        for _ in 0..<2 {
            let idx = tiles.remove(at: Int.random(in: 0..<tiles.count))
            let row = idx & 0b11 // idx % 4
            let col = idx / 4    // idx / 4
            currentBoard[row, col] = tileValue()
        }
    }

    // MARK: - Moves

    /// Perform a move. After the move, adds a random tile to the board.
    /// - Parameter move: The move to perform.
    mutating func move(_ move: Move) {
        currentBoard = currentBoard.move(move)
        if let randomTile = currentBoard.getEmpty().randomElement() {
            currentBoard[randomTile >> 2, randomTile & 0b11] = Int.random(in: 0..<10) == 0 ? 2 : 1
        }
        step += 1
    }

    func availableMoves() -> MoveSet {
        currentBoard.availableMoves()
    }

    /// Finds if the game is in a Game Over state.
    func terminalTest() -> Bool {
        currentBoard.availableMoves().isEmpty
    }

    // MARK: - Random

    private func tileValue() -> Int {
        if Int.random(in: 0..<10) == 0 {
            return 2
        } else {
            return 1
        }
    }
}
