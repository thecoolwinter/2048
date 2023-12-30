import XCTest
@testable import Game

class StateTests: XCTestCase {
    func test_init() {
        let state = State()
        XCTAssert(state.currentBoard.getEmpty().count == 14)
    }
}
