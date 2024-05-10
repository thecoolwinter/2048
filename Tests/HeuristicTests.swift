import XCTest
@testable import Game

class HeuristicTests: XCTestCase {
    lazy var expectimax = {
        var exp = Expectimax(depthLimit: 4)
        exp.weights = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
        return exp
    }()

    func test_monotonic() {
        XCTAssertEqual(expectimax.monotonic(Board(0x1234_0000_0000_0000)), 15.0)
    }
}
