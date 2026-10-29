import XCTest
@testable import SourisFacile

final class KeyActionTests: XCTestCase {
    private func settings(move: String = Defaults.moveModifiers,
                          resize: String = Defaults.resizeModifiers) -> Settings {
        Settings(enabled: true, moveFlags: Modifier.flags(move), resizeFlags: Modifier.flags(resize),
                 raiseWindow: false, resizeNearestCorner: true, snapThreshold: 16, snapToWindows: true,
                 displayGrids: [:], showGrid: true, dimWindows: true,
                 sendWithScroll: true, sendWithArrows: true, rememberFrames: true)
    }

    func testDefaults() {
        let s = settings()
        XCTAssertEqual(s.action(for: [.maskControl, .maskAlternate]), .move)
        XCTAssertEqual(s.action(for: [.maskControl, .maskAlternate, .maskCommand]), .resize)
        XCTAssertEqual(s.action(for: [.maskControl, .maskAlternate, .maskShift]), .none)
        XCTAssertEqual(s.action(for: [.maskAlternate]), .none)
        XCTAssertEqual(s.action(for: []), .none)
    }

    func testOtherFlagsAreIgnored() {
        XCTAssertEqual(settings().action(for: [.maskControl, .maskAlternate, .maskAlphaShift]), .move)
    }

    func testTurnedOffCombinationsNeverMatch() {
        XCTAssertEqual(settings(move: "", resize: "").action(for: []), .none)
        XCTAssertEqual(settings(resize: "").action(for: [.maskControl, .maskAlternate]), .move)
    }
}
