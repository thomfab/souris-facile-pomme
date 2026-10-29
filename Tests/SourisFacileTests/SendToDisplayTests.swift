import XCTest
@testable import SourisFacile

final class SendToDisplayTests: XCTestCase {
    // A laptop, a wide monitor to its right, and a monitor above it.
    private let laptop = CGRect(x: 0, y: 0, width: 1512, height: 982)
    private let wide = CGRect(x: 1512, y: -400, width: 3440, height: 1440)
    private let above = CGRect(x: 0, y: -1080, width: 1512, height: 1080)
    private var displays: [CGRect] { [laptop, wide, above] }

    func testDirectionFollowsTheMainAxis() {
        XCTAssertEqual(Direction(dx: 50, dy: -20), .right)
        XCTAssertEqual(Direction(dx: -10, dy: 40), .down)
        XCTAssertEqual(Direction(arrowKeyCode: 126), .up)
        XCTAssertNil(Direction(arrowKeyCode: 0))
    }

    func testDisplayTowardADirection() {
        XCTAssertEqual(display(toward: .right, from: 0, among: displays), 1)
        XCTAssertEqual(display(toward: .up, from: 0, among: displays), 2)
        XCTAssertNil(display(toward: .left, from: 0, among: displays))
        XCTAssertEqual(display(toward: .left, from: 1, among: displays), 0)
        XCTAssertEqual(display(toward: .down, from: 2, among: displays), 0)
    }

    func testNextAndPreviousDisplaysWrapAround() {
        // Left to right, then top to bottom: above, laptop, wide.
        XCTAssertEqual(display(after: 0, by: 1, among: displays), 1)
        XCTAssertEqual(display(after: 1, by: 1, among: displays), 2)
        XCTAssertEqual(display(after: 0, by: -1, among: displays), 2)
        XCTAssertNil(display(after: 0, by: 1, among: [laptop]))
    }

    func testTransferKeepsTheRelativePlaceAndSize() {
        let from = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let to = CGRect(x: 1000, y: 0, width: 2000, height: 1000)
        let leftHalf = CGRect(x: 0, y: 0, width: 500, height: 800)
        XCTAssertEqual(transfer(leftHalf, from: from, to: to, keepSize: false),
                       CGRect(x: 1000, y: 0, width: 1000, height: 1000))
    }

    func testTransferCanKeepTheSize() {
        let from = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let to = CGRect(x: 1000, y: 0, width: 2000, height: 1000)
        XCTAssertEqual(transfer(CGRect(x: 100, y: 100, width: 300, height: 200), from: from, to: to, keepSize: true),
                       CGRect(x: 1350, y: 150, width: 300, height: 200))
    }

    func testTransferKeepsTheTopLeftOfAWindowTooBigToFit() {
        let from = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let small = CGRect(x: 1000, y: 0, width: 500, height: 400)
        XCTAssertEqual(transfer(from, from: from, to: small, keepSize: true),
                       CGRect(x: 1000, y: 0, width: 1000, height: 800))
    }

    func testFitToGridMovesEdgesToTheNearestLines() {
        let area = CGRect(x: 0, y: 0, width: 1200, height: 900)
        XCTAssertEqual(fitToGrid(CGRect(x: 290, y: 10, width: 320, height: 580), area: area, columns: 4, rows: 3),
                       CGRect(x: 300, y: 0, width: 300, height: 600))
    }

    func testFitToGridKeepsAtLeastOneCell() {
        let area = CGRect(x: 0, y: 0, width: 1200, height: 900)
        XCTAssertEqual(fitToGrid(CGRect(x: 310, y: 310, width: 20, height: 20), area: area, columns: 4, rows: 3),
                       CGRect(x: 300, y: 300, width: 300, height: 300))
        XCTAssertEqual(fitToGrid(CGRect(x: 1190, y: 890, width: 5, height: 5), area: area, columns: 4, rows: 3),
                       CGRect(x: 900, y: 600, width: 300, height: 300))
    }

    func testASwipeGivesOneDirectionOnceFarEnough() {
        var swipe = SwipeTracker()
        XCTAssertNil(swipe.feed(phase: ScrollPhase.began, momentum: false, dx: 5, dy: 0, time: 0))
        XCTAssertNil(swipe.feed(phase: 2, momentum: false, dx: 30, dy: 10, time: 0.01))
        XCTAssertEqual(swipe.feed(phase: 2, momentum: false, dx: 40, dy: 0, time: 0.02), .right)
        // The rest of the same swipe does nothing.
        XCTAssertNil(swipe.feed(phase: 2, momentum: false, dx: 100, dy: 0, time: 0.03))
        XCTAssertNil(swipe.feed(phase: ScrollPhase.ended, momentum: false, dx: 0, dy: 0, time: 0.04))
        // Nor does the inertia after it.
        XCTAssertNil(swipe.feed(phase: 0, momentum: true, dx: 100, dy: 0, time: 0.05))
        // A new swipe counts again.
        XCTAssertNil(swipe.feed(phase: ScrollPhase.began, momentum: false, dx: 0, dy: -30, time: 1))
        XCTAssertEqual(swipe.feed(phase: 2, momentum: false, dx: 0, dy: -40, time: 1.01), .up)
    }

    func testSwipesWithoutPhasesAreSeparatedByAPause() {
        var swipe = SwipeTracker()
        XCTAssertEqual(swipe.feed(phase: 0, momentum: false, dx: -70, dy: 0, time: 0), .left)
        XCTAssertNil(swipe.feed(phase: 0, momentum: false, dx: -70, dy: 0, time: 0.1))
        XCTAssertEqual(swipe.feed(phase: 0, momentum: false, dx: -70, dy: 0, time: 1), .left)
    }
}
