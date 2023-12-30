import XCTest
@testable import Game

class ChanceTests: XCTestCase {
    func test_chance() {
        let chance = Chance(row: 2, col: 3, isTwo: false)
        XCTAssertEqual(chance.row, 2)
        XCTAssertEqual(chance.col, 3)
        XCTAssertFalse(chance.isTwo)
    }
}
