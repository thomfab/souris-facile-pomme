import XCTest
@testable import SourisFacile

final class ModifierTests: XCTestCase {
    func testParseIgnoresUnknownNames() {
        XCTAssertEqual(Modifier.parse("control,bogus,option"), [.control, .option])
        XCTAssertEqual(Modifier.parse(""), [])
    }

    func testFormatUsesAStableOrder() {
        XCTAssertEqual(Modifier.format([.command, .control, .option]), "control,option,command")
        XCTAssertEqual(Modifier.format([]), "")
    }

    func testFlags() {
        XCTAssertEqual(Modifier.flags("control,option"), [.maskControl, .maskAlternate])
    }

    func testDefaultsAreControlOptionToMove() {
        XCTAssertEqual(Modifier.parse(Defaults.moveModifiers), [.control, .option])
        XCTAssertEqual(Modifier.parse(Defaults.resizeModifiers), [.control, .option, .command])
        XCTAssertEqual(Modifier.warnings(move: Defaults.moveModifiers, resize: Defaults.resizeModifiers), [])
    }

    func testWarnsAboutIdenticalCombinations() {
        XCTAssertEqual(Modifier.warnings(move: "control,option", resize: "option,control").count, 1)
        // Both turned off is a way to disable the feature, not a conflict.
        XCTAssertEqual(Modifier.warnings(move: "", resize: ""), [])
    }

    func testWarnsAboutASingleKey() {
        XCTAssertEqual(Modifier.warnings(move: "command", resize: "control,option,command").count, 1)
        XCTAssertEqual(Modifier.warnings(move: "shift", resize: "shift").count, 3)
    }
}
