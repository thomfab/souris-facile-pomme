import XCTest
@testable import SourisFacile

final class WindowMemoryTests: XCTestCase {
    private let laptop = "laptop-uuid"
    private let office = "office-uuid"
    private let area = CGRect(x: 0, y: 25, width: 1512, height: 900)

    func testRemembersPerAppAndDisplay() {
        var memory = WindowMemory()
        XCTAssertTrue(memory.isEmpty)
        let frame = CGRect(x: 0, y: 25, width: 756, height: 900)
        memory.remember(frame, area: area, app: "com.apple.Safari", display: laptop)
        XCTAssertFalse(memory.isEmpty)
        XCTAssertEqual(memory.frame(app: "com.apple.Safari", display: laptop),
                       RememberedFrame(frame: frame, area: area))
        XCTAssertNil(memory.frame(app: "com.apple.Safari", display: office))
        XCTAssertNil(memory.frame(app: "com.apple.mail", display: laptop))
    }

    func testTheLastFrameWins() {
        var memory = WindowMemory()
        memory.remember(CGRect(x: 0, y: 25, width: 100, height: 100), area: area, app: "app", display: laptop)
        memory.remember(CGRect(x: 50, y: 75, width: 200, height: 200), area: area, app: "app", display: laptop)
        XCTAssertEqual(memory.frame(app: "app", display: laptop)?.frame, CGRect(x: 50, y: 75, width: 200, height: 200))
    }

    func testEncodingRoundTrips() {
        var memory = WindowMemory()
        memory.remember(CGRect(x: 10, y: 35, width: 700, height: 500), area: area, app: "app", display: office)
        XCTAssertEqual(WindowMemory(data: memory.data), memory)
        XCTAssertEqual(WindowMemory(data: nil), WindowMemory())
        XCTAssertEqual(WindowMemory(data: Data("garbage".utf8)), WindowMemory())
    }

    func testRestoringOnAnUnchangedDisplayGivesTheSameFrame() {
        let remembered = RememberedFrame(frame: CGRect(x: 100, y: 125, width: 700, height: 500), area: area)
        XCTAssertEqual(remembered.restored(in: area, keepSize: false), remembered.frame)
    }

    func testRestoringFollowsAChangedDisplay() {
        // The Dock went from the bottom (900 pt high) to the left (76 pt wide).
        let remembered = RememberedFrame(frame: CGRect(x: 0, y: 25, width: 756, height: 900), area: area)
        let now = CGRect(x: 76, y: 25, width: 1436, height: 957)
        let restored = remembered.restored(in: now, keepSize: false)
        XCTAssertEqual(restored.minX, 76)
        XCTAssertEqual(restored.width, 718)
        XCTAssertEqual(restored.height, 957)
    }
}
