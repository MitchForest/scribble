import XCTest
@testable import scribble

final class StartPointGateTests: XCTestCase {
    func testValidStartWithinTolerance() {
        let start = CGPoint(x: 10, y: 10)
        let expected = CGPoint(x: 14, y: 13)
        XCTAssertTrue(StartPointGate.isStartValid(startPoint: start,
                                                  expectedStart: expected,
                                                  tolerance: 6))
    }

    func testInvalidStartOutsideTolerance() {
        let start = CGPoint(x: 0, y: 0)
        let expected = CGPoint(x: 50, y: 0)
        XCTAssertFalse(StartPointGate.isStartValid(startPoint: start,
                                                   expectedStart: expected,
                                                   tolerance: 10))
    }
}
