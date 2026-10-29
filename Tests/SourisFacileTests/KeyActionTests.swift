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
        XCTAssertEqual(s.action(for: [.maskAlternate]), .move)
        XCTAssertEqual(s.action(for: [.maskAlternate, .maskCommand]), .resize)
        XCTAssertEqual(s.action(for: [.maskAlternate, .maskCommand, .maskShift]), .freeResize)
        XCTAssertEqual(s.action(for: [.maskAlternate, .maskShift]), .none)
        XCTAssertEqual(s.action(for: []), .none)
    }

    func testOtherFlagsAreIgnored() {
        XCTAssertEqual(settings().action(for: [.maskAlternate, .maskAlphaShift]), .move)
    }

    func testFreeKeysAlreadyAmongTheResizeKeysAddNothing() {
        let s = settings(free: "command,shift")
        XCTAssertEqual(s.action(for: [.maskAlternate, .maskCommand]), .resize)
        XCTAssertEqual(s.action(for: [.maskAlternate, .maskCommand, .maskShift]), .freeResize)
        XCTAssertEqual(settings(free: "command").action(for: [.maskAlternate, .maskCommand]), .resize)
    }

    func testNoFreeKeysOrNoResizeKeys() {
        XCTAssertEqual(settings(free: "").action(for: [.maskAlternate, .maskCommand, .maskShift]), .none)
        XCTAssertEqual(settings(resize: "").action(for: [.maskShift]), .none)
    }
}
