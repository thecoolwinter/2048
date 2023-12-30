import XCTest
@testable import Game

@_optimize(none)
func blackHole<T>(_ val: T) {}

class BoardTests: XCTestCase {
    func test_setValue() throws {
        for row in UInt(0)..<4 {
            for col in UInt(0)..<4 {
                for val in UInt(0)...15 {
                    var board = Board()
                    board[row, col] = val
                    if board[row, col] != val {
                        board.display()
                    }
                    XCTAssertEqual(board[row, col], val, "Value set at \(row):\(col) did not set or retrieve correctly")
                }
                let val: UInt = 16
                var board = Board()
                board[row, col] = val
                XCTAssertFalse(
                    board[row, col] == val,
                    "Value (\(val)) set at \(row):\(col) should not be able to save (exponent too large)"
                )
            }
        }
    }

    func test_getValue() throws {
        let board = Board(0x0123012301230123)
        for row in UInt(0)..<4 {
            for col in UInt(0)..<4 {
                XCTAssertEqual(board[row, col], col)
            }
        }
    }

    func test_rotate() throws {
        let board = Board(0x37BF_26AE_159D_048C).rotateClockwise()
        XCTAssertEqual(board, Board(0x0123_4567_89AB_CDEF))
    }

    func test_rotateCounter() throws {
        let board = Board(0xC840_D951_EA62_FB73).rotateCounterClockwise()
        XCTAssertEqual(board, Board(0x0123_4567_89AB_CDEF))
    }

    func test_invert() {
        let board = Board(0x0123_4567_89AB_CEDF).invert()
        XCTAssertEqual(board, Board(0x3210_7654_BA98_FDEC))
    }

    func test_left() throws {
        var board = Board()
        board[0, 0] = 1
        board[0, 1] = 0
        board[0, 2] = 2
        board[0, 3] = 1

        board[1, 0] = 1
        board[1, 1] = 1
        board[1, 2] = 0
        board[1, 3] = 0

        board[2, 0] = 1
        board[2, 1] = 0
        board[2, 2] = 1
        board[2, 3] = 1

        board[3, 0] = 1
        board[3, 1] = 0
        board[3, 2] = 0
        board[3, 3] = 1

        board = board.left()
        XCTAssertEqual(board, Board(0x1210_2000_2100_2000))

        board = Board()
        board[0, 0] = 0
        board[0, 1] = 1
        board[0, 2] = 0
        board[0, 3] = 1

        board[1, 0] = 0
        board[1, 1] = 1
        board[1, 2] = 1
        board[1, 3] = 1

        board[2, 0] = 0
        board[2, 1] = 0
        board[2, 2] = 0
        board[2, 3] = 0

        board[3, 0] = 1
        board[3, 1] = 2
        board[3, 2] = 3
        board[3, 3] = 4

        board = board.left()
        XCTAssertEqual(board, Board(0x2000_2100_0000_1234))
    }

    func test_up() throws {
        var board = Board()
        board[0, 0] = 0
        board[1, 0] = 1
        board[2, 0] = 0
        board[3, 0] = 1
        board = board.up()

        XCTAssertEqual(board, Board(0x2000_0000_0000_0000))
    }

    func test_down() throws {
        var board = Board()
        board[0, 0] = 0
        board[1, 0] = 1
        board[2, 0] = 0
        board[3, 0] = 1
        board = board.down()

        XCTAssertEqual(board, Board(0x0000_0000_0000_2000))
    }

    func test_right() throws {
        var board = Board()
        board[0, 0] = 0
        board[0, 1] = 1
        board[0, 2] = 0
        board[0, 3] = 1
        board = board.right()

        XCTAssertEqual(board, Board(0x0002_0000_0000_0000))
    }

    func test_countEmpty() {
        var board = Board()
        board[0, 1] = 1
        board[0, 3] = 1
        XCTAssertEqual(board.countEmpty(), 14)
        board[1, 2] = 1
        board[3, 3] = 1
        XCTAssertEqual(board.countEmpty(), 12)
    }

    func test_availableMoves() {
        var board = Board()
        board[1, 2] = 1
        XCTAssertEqual(board.availableMoves(), MoveSet(value: 0b1111))

        board = Board()
        board[0, 2] = 1
        XCTAssertEqual(board.availableMoves(), MoveSet(value: 0b1011))
    }

    func test_measureRight() {
        measure {
            // 0.230s   10% STDDEV
            // 0.226s   ...
            for _ in 0..<10_000 {
                blackHole(Board(UInt64.random(in: 0..<UInt64.max)).right())
            }
        }
    }

    func test_measureAvailableMoves() {
        measure {
            for _ in 0..<1000 {
                blackHole(Board(UInt64.random(in: 0..<UInt64.max)).availableMoves())
            }
        }
    }
}
