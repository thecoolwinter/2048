import XCTest
@testable import Game

class MoveSetTests: XCTestCase {
    func test_init() {
        var set = MoveSet()
        set.right = true
        set.down = true
        XCTAssertEqual(set.pop(), .right)
        XCTAssertEqual(set.pop(), .down)
        XCTAssertEqual(set.pop(), nil)
    }

    func test_b() {
        print(15 & 0b11)
    }
}
