#if os(Linux)
import Glibc.ncurses
#else
import Darwin.ncurses
#endif

struct Expectimax {
    private let depthLimit: Int
    private let nodeChanceLimit: Float = 0.00001
//    private var maxScore: Float = 300_000
    private var boardLookupMap: [UInt64: (Float, Int)] = [:]
    private let moveLookup: [Move] = [.right, .up, .left, .down]

    // swiftlint:disable comma
    private let largeCornerMatrix: [[Float]] = [
        [0,  1,  2,  3],
        [7,  6,  5,  4],
        [8,  9,  10, 11],
        [12, 13, 14, 15]
    ]
    // swiftlint:enable comma

    // Stats

    private var cacheHits = 0
    private var cacheMisses = 0

    init(depthLimit: Int) {
        self.depthLimit = depthLimit
        boardLookupMap.reserveCapacity(500_000)
    }

    static var weights: [Float] = [
        1.0, // sum
        1.0, // openSpaces
        1.0, // largeTowardsCorner
        1.0, // mergableSquares
        1.0, // monotonic
        1.0, // score
        2.0, // monotonic power weight
        2.0, // score power weight
        2.0, // sum power weight
        2.0  // total eval power weight
    ]

    mutating func chooseMove(game: State) -> Move {
        var availableMoves = game.availableMoves()
        var bestScore: Float = -.infinity
        var bestMove: Move = availableMoves.first
        while let move = availableMoves.pop() {
            let value = max(board: game.currentBoard.move(move), depth: 0, nodeChance: 1.0)
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

    mutating func max(board: Board, depth: Int, nodeChance: Float) -> Float {
        if let cachedScore = boardLookup(board, depth: depth) {
            return cachedScore
        } else if depth >= depthLimit {
            let value = eval(board)
            cacheBoard(board, value: value, depth: depth)
            return value
        }

        var maxValue: Float = -.infinity
        var board = board
        for idx in 0..<4 {
            let move = moveLookup[idx]
            let right = board.right()
            if right != board {
                let score = chance(board: right, move: move, depth: depth + 1, nodeChance: nodeChance)
                maxValue = Swift.max(score, maxValue)
            }
            board = board.rotateClockwise()
        }
        if maxValue == -.infinity {
            return eval(board)
        }
        cacheBoard(board, value: maxValue, depth: depth)
        return maxValue
    }

    mutating func chance(board: Board, move: Move, depth: Int, nodeChance: Float) -> Float {
//        let board = board.right()

        // If this is a terminal board, return a big negative number.
        if board.availableMoves().isEmpty {
            return -20_000
        }

        // Find the maximum value at this chance node. Pruning if possible
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
                    nodeChance: relativeChance * nodeChance
                )
            }

            expectedValue += relativeChance * value
            expectedChanceRemaining -= relativeChance
        }
        return expectedValue
    }

    // MARK: - Cache Table

    private mutating func boardLookup(_ board: Board, depth: Int) -> Float? {
        if let (cachedValue, cachedDepth) = boardLookupMap[board.board], cachedDepth <= depth {
            cacheHits += 1
            return cachedValue
        } else {
            cacheMisses += 1
            return nil
        }
    }

    private mutating func cacheBoard(_ board: Board, value: Float, depth: Int) {
        boardLookupMap[board.board] = (value, depth)
    }

    // MARK: - Heuristics

    private func eval(_ board: Board) -> Float {
        let sum = pow(Float(board.sum()), Expectimax.weights[8]) * Expectimax.weights[0]
        let openSpaces = pow(openSpaces(board), 2) * Expectimax.weights[1]
        let largeTowardsCorner = largeTowardsCorner(board) * Expectimax.weights[2]
        let mergableSquares = mergableSquares(board) * Expectimax.weights[3]
        let monotonic = monotonic(board) * Expectimax.weights[4]
        let score = pow(Float(board.score), Expectimax.weights[7]) * Expectimax.weights[5]

        let evalScore = sum + openSpaces + largeTowardsCorner + mergableSquares + monotonic + score

//        if evalScore > maxScore {
//            endwin()
//            print("Eval score \(evalScore) > max score (\(maxScore))")
//            exit(1)
//        }

        return pow(evalScore, Expectimax.weights[9])
    }

    private func openSpaces(_ board: Board) -> Float {
        return Float(board.countEmpty())
    }

    private func largeTowardsCorner(_ board: Board) -> Float {
        var score: Float = 0
        var board = board.board
        var idx = 16
        while board > 0 {
            idx -= 1
            let row = idx >> 2
            let col = idx & 0b11
            let tile = Float(board & 0xF)
            score += largeCornerMatrix[row][col] * tile
            board >>= 4
        }
        return score
    }

    private func mergableSquares(_ board: Board) -> Float {
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

    private func monotonic(_ board: Board) -> Float {
        var left: Float = 0
        var right: Float = 0
        var board = board.board
        for _ in 0..<4 {
            let tiles = [
                Float(board & 0xF),
                Float(board >> 4 & 0xF),
                Float(board >> 8 & 0xF),
                Float(board >> 12 & 0xF)
            ]

            for col in 1..<4 {
                if tiles[col - 1] > tiles[col] {
                    left += pow(tiles[col - 1], Expectimax.weights[6]) - pow(tiles[col], Expectimax.weights[6])
                } else {
                    right += pow(tiles[col], Expectimax.weights[6]) - pow(tiles[col - 1], Expectimax.weights[6])
                }
            }

            board >>= 16
        }
        return min(left, right)
    }
}
