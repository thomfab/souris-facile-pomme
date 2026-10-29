import XCTest
@testable import SourisFacile

final class GeometryTests: XCTestCase {
    func testDivideIncludesBothEnds() {
        XCTAssertEqual(divide(0, 100, 4), [0, 25, 50, 75, 100])
        XCTAssertEqual(divide(10, 90, 1), [10, 100])
    }

    func testDivideRoundsToWholePoints() {
        XCTAssertEqual(divide(0, 100, 3), [0, 33, 67, 100])
    }

    func testSnapDeltaPicksTheClosestLine() {
        XCTAssertEqual(snapDelta([10, 110], [0, 200], threshold: 16), -10)
        XCTAssertEqual(snapDelta([10, 195], [0, 200], threshold: 16), 5)
    }

    func testSnapDeltaIgnoresLinesBeyondTheThreshold() {
        XCTAssertEqual(snapDelta([50], [0, 100], threshold: 16), 0)
        XCTAssertEqual(snapDelta([16], [0], threshold: 16), -16)
    }

    func testFrameDistanceIsTheLargestDifference() {
        let a = CGRect(x: 0, y: 0, width: 100, height: 100)
        XCTAssertEqual(frameDistance(a, a), 0)
        XCTAssertEqual(frameDistance(a, CGRect(x: 1, y: -3, width: 102, height: 100)), 3)
    }
}
