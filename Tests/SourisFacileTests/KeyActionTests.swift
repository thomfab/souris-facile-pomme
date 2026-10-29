import XCTest
@testable import SourisFacile

final class KeyActionTests: XCTestCase {
    private func settings(move: String = Defaults.moveModifiers,
                          resize: String = Defaults.resizeModifiers,
                          free: String = Defaults.freeResizeModifiers) -> Settings {
        Settings(enabled: true, moveFlags: Modifier.flags(move), resizeFlags: Modifier.flags(resize),
                 freeResizeFlags: Modifier.flags(free), raiseWindow: false,
                 resizeNearestCorner: true, snapThreshold: 16, snapToWindows: true,
                 gridEnabled: false, gridColumns: 4, gridRows: 3, displayGrids: [:],
                 showGrid: true, dimWindows: true, sendWithScroll: true, sendWithArrows: true,
                 rememberFrames: true)
    }

    func testDefaults() {
        let s = settings()
        XCTAssertEqual(s.action(for: [.maskControl, .maskAlternate]), .move)
        XCTAssertEqual(s.action(for: [.maskControl, .maskAlternate, .maskCommand]), .resize)
        XCTAssertEqual(s.action(for: [.maskControl, .maskAlternate, .maskCommand, .maskShift]), .freeResize)
        XCTAssertEqual(s.action(for: [.maskControl, .maskAlternate, .maskShift]), .none)
        XCTAssertEqual(s.action(for: [.maskAlternate]), .none)
        XCTAssertEqual(s.action(for: []), .none)
    }

    func testOtherFlagsAreIgnored() {
        XCTAssertEqual(settings().action(for: [.maskControl, .maskAlternate, .maskAlphaShift]), .move)
    }

    func testFreeKeysAlreadyAmongTheResizeKeysAddNothing() {
        let s = settings(free: "command,shift")
        XCTAssertEqual(s.action(for: [.maskControl, .maskAlternate, .maskCommand]), .resize)
        XCTAssertEqual(s.action(for: [.maskControl, .maskAlternate, .maskCommand, .maskShift]), .freeResize)
        XCTAssertEqual(settings(free: "command").action(for: [.maskControl, .maskAlternate, .maskCommand]), .resize)
    }

    func testNoFreeKeysOrNoResizeKeys() {
        XCTAssertEqual(settings(free: "").action(for: [.maskControl, .maskAlternate, .maskCommand, .maskShift]), .none)
        XCTAssertEqual(settings(resize: "").action(for: [.maskShift]), .none)
    }
}
