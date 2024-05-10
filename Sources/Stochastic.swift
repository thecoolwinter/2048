/// A single function for finding all the available random positions from a given board post-move.
enum Stochastic {
    static func chances(_ board: Board) -> [Chance] {
        var result: [Chance] = []
        for emptyTile in board.getEmpty() {
            result.append(Chance(row: emptyTile >> 2, col: emptyTile & 0b11, isTwo: true))
            result.append(Chance(row: emptyTile >> 2, col: emptyTile & 0b11, isTwo: false))
        }
        return result
    }
}
