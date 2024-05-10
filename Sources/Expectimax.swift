#if os(Linux)
import Glibc.ncurses
#else
import Darwin.ncurses
#endif

/// The ``Expectimax`` struct defines a player for the 2048 game.
/// This player uses the expectimax algorithm to choose the best possible move for a given board.
struct Expectimax {
    /// How many max/chance nodes to limit the search to.
    /// One depth increment is equal to both a max and chance node.
    private let depthLimit: Int
    /// The limit for how unlikely nodes can be before they are not explored.
    private let nodeChanceLimit: Float = 0.0001
    /// Cache boards and their `(eval, Depth)` for pruning.
    private var boardLookupMap: [UInt64: (Float, Int)] = [:]
    /// The maximum score a board can evaluate to. Used to prune trees using the alpha-beta technique.
    /// Updated when queried for available moves to prune move moves at lower scoring boards.
    private var maxScore: Float = 100_000
    /// The score assigned to losses.
    private let lossScore: Float = -5_000

    // swiftlint:disable comma
    private let snakeMatrix: [[Float]] = [
        [0,  1,  2,  3],
        [7,  6,  5,  4],
        [8,  9,  10, 11],
        [12, 13, 14, 15]
    ]
    // swiftlint:enable comma

    // Stats

    private var cacheHits = 0
    private var cacheMisses = 0

    /// Create a new expectimax player.
    /// - Parameter depthLimit: The limit to search to.
    init(depthLimit: Int) {
        self.depthLimit = depthLimit
        boardLookupMap.reserveCapacity(500_000)
    }

    /// The optimal weights found using the CMA-ES algorithm.
    var weights: [Float] = [
        1.0, // sum
        1.0, // openSpaces
        1.0, // largeTowardsCorner
        1.0, // mergableSquares
        1.0, // monotonic
        1.0, // score
        2.0, // monotonic power weight
    ]

    mutating func chooseMove(game: State) -> Move {
        var availableMoves = game.availableMoves()
        var bestScore: Float = -.infinity
        var bestMove: Move = availableMoves.first
        while let move = availableMoves.pop() {
            let value = max(board: game.currentBoard.move(move), depth: 0, nodeChance: 1.0, alpha: bestScore)
            if value > bestScore {
                bestMove = move
                bestScore = value
            }
        }

        cacheHits = 0
        cacheMisses = 0
        boardLookupMap.removeAll(keepingCapacity: true)
        return bestMove
    }

    /// Find the maximum value possible from a given board position.
    ///
    /// Assuming the player will always play optimal moves, finds the maximum value that can be found beginning at the
    /// given board.
    ///
    /// - Parameters:
    ///   - board: The board to look for.
    ///   - depth: The depth this function is being called at.
    ///   - nodeChance: The cumulative chance of the given node.
    /// - Returns: The maximum evaluation score for this given position.
    mutating func max(board: Board, depth: Int, nodeChance: Float, alpha: Float) -> Float {
        if let cachedScore = boardLookup(board, depth: depth) {
            return cachedScore
        } else if depth >= depthLimit {
            let value = eval(board)
            cacheBoard(board, value: value, depth: depth)
            return value
        }

        var maxValue: Float = -.infinity
        var board = board
        // Rotate through all the moves, only searching them if they're available moves.
        for _ in 0..<4 {
            let right = board.right()
            if right != board {
                let score = chance(
                    board: right,
                    depth: depth + 1,
                    nodeChance: nodeChance,
                    alpha: Swift.max(alpha, maxValue)
                )
                maxValue = Swift.max(score, maxValue)
            }
            board = board.rotateClockwise()
        }
        if maxValue == -.infinity {
            maxValue = eval(board)
        }
        cacheBoard(board, value: maxValue, depth: depth)
        return maxValue
    }

    /// Finds the expected value of the given board for any move.
    /// - Parameters:
    ///   - board: The board to search from.
    ///   - depth: The depth this function is being called at.
    ///   - nodeChance: The cumulative chance of the given node.
    /// - Returns: The expected value of the board for all possible moves.
    mutating func chance(board: Board, depth: Int, nodeChance: Float, alpha: Float) -> Float {
        // If this is a terminal board, return 0.
        if board.availableMoves().isEmpty {
            return lossScore
        }

        let chances = Stochastic.chances(board)
        let chanceCount = Float(chances.count / 2)
        var expectedValue: Float = 0
        var expectedChanceRemaining: Float = 1.0

        for chance in chances {
            let relativeChance = ((chance.isTwo ? 0.9 : 0.1) / chanceCount)
            var resultingBoard = board
            resultingBoard[chance.row, chance.col] = chance.isTwo ? 1 : 2

            let value: Float
            if relativeChance * nodeChance < nodeChanceLimit {
                value = eval(resultingBoard)
            } else {
                value = max(
                    board: resultingBoard,
                    depth: depth,
                    nodeChance: relativeChance * nodeChance,
                    alpha: alpha
                )
            }

            expectedValue += relativeChance * value
            expectedChanceRemaining -= relativeChance

            // If the maximum possible score is less than a value already found, we don't need to explore anything else.
            if expectedValue + (expectedChanceRemaining * maxScore) <= alpha {
                return expectedValue + (expectedChanceRemaining * maxScore)
            }
        }
        return expectedValue
    }

    // MARK: - Cache Table

    /// Lookup a board at the given depth and return the cached evaluation value if available at the given depth.
    /// - Parameters:
    ///   - board: The board to look up.
    ///   - depth: The depth this function is being called at.
    /// - Returns: The cached evaluation value if available at the given depth.
    private mutating func boardLookup(_ board: Board, depth: Int) -> Float? {
        if let (cachedValue, cachedDepth) = boardLookupMap[board.board], cachedDepth <= depth {
            cacheHits += 1
            return cachedValue
        } else {
            cacheMisses += 1
            return nil
        }
    }

    /// Cache a board's value at a depth.
    /// - Parameters:
    ///   - board: The board to cache.
    ///   - value: The calculated evaluation of the board.
    ///   - depth: The depth this function is being called at.
    private mutating func cacheBoard(_ board: Board, value: Float, depth: Int) {
        boardLookupMap[board.board] = (value, depth)
    }

    // MARK: - Heuristics

    public func eval(_ board: Board) -> Float {
        let sum = Float(board.sum()) * weights[0]
        let openSpaces = openSpaces(board) * weights[1]
        let largeTowardsCorner = snake(board) * weights[2]
        let mergableSquares = mergableSquares(board) * weights[3]
        let monotonic = monotonic(board) * weights[4]
        let score = Float(board.score) * weights[5]

        let evalScore = sum + openSpaces + largeTowardsCorner + mergableSquares + monotonic + score

        if evalScore > maxScore {
            endwin()
            print("Eval score \(evalScore) > max score (\(maxScore))")
            exit(1)
        }

        return evalScore
    }

    /// Finds the number of open spaces in a board.
    /// - Parameter board: The board to score.
    /// - Returns: A float value for this heuristic.
    func openSpaces(_ board: Board) -> Float {
        return Float(board.countEmpty())
    }

    /// Scores a board according to the weights defined in the snake matrix.
    ///
    /// Biases towards boards that increase in value in a snake-like pattern towards a corner.
    /// First published by Yulin Zhou in his 2019 [paper](https://www.cse.msu.edu/~zhaoxi35/DRL4KDD/2.pdf).
    ///
    /// - Parameter board: The board to score.
    /// - Returns: A float value for this heuristic.
    func snake(_ board: Board) -> Float {
        var score: Float = 0
        var board = board.board
        var idx = 16
        while board > 0 {
            idx -= 1
            let row = idx >> 2
            let col = idx & 0b11
            let tile = Float(board & 0xF)
            score += snakeMatrix[row][col] * tile
            board >>= 4
        }
        return score
    }

    /// Finds the number of mergable tiles in a board.
    /// - Parameter board: The board to score.
    /// - Returns: A float value for this heuristic.
    func mergableSquares(_ board: Board) -> Float {
        var score: Float = 0
        var vertical = board.board
        var horizontal = board.board
        for _ in 0..<4 {
            for _ in 1..<4 {
                if vertical & 0xF == (vertical >> 4) & 0xF {
                    score += Float(vertical & 0xF)
                }
                if horizontal & 0xF == (horizontal >> 4) & 0xF {
                    score += Float(horizontal & 0xF)
                }
                vertical >>= 4
                horizontal >>= 4
            }
            vertical >>= 4
            horizontal >>= 4
        }
        return score
    }

    /// Scores boards higher if they have rows of monotonically increasing values.
    ///
    /// From: Xiao, Robert
    /// - https://github.com/nneonneo/2048-ai/tree/master
    /// - https://stackoverflow.com/questions/22342854/what-is-the-optimal-algorithm-for-the-game-2048/22498940#22498940
    ///
    /// - Parameter board: The board to score.
    /// - Returns: A float value for this heuristic.
    func monotonic(_ board: Board) -> Float {
        var score: Float = 0.0
        var board = board.board
        for _ in 0..<4 {
            for _ in 0..<3 {
                let lastCol = Float(board & 0xF)
                let thisCol = Float(board >> 4 & 0xF)
                score += abs(pow(lastCol, weights[6]) - pow(thisCol, weights[6]))
                board >>= 4
            }
            board >>= 4
        }
        return score
    }
}
