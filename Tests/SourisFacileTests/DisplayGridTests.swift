import XCTest
@testable import SourisFacile

final class DisplayGridTests: XCTestCase {
    private let office = "37D8832A-2D66-02CA-B9F7-8F30A301B230"

    private func settings(_ grids: [String: DisplayGrid]) -> Settings {
        Settings(enabled: true, moveFlags: [], resizeFlags: [], freeResizeFlags: [], raiseWindow: false,
                 resizeNearestCorner: true, snapThreshold: 16, snapToWindows: true,
                 gridEnabled: true, gridColumns: 4, gridRows: 3, displayGrids: grids,
                 showGrid: true, dimWindows: true, sendWithScroll: true, sendWithArrows: true,
                 rememberFrames: true)
    }

    private func size(_ settings: Settings, _ uuid: String?) -> [Int] {
        let grid = settings.grid(forDisplay: uuid)
        return [grid.columns, grid.rows]
    }

    func testEncodingRoundTrips() {
        let grids = [office: DisplayGrid(name: "DELL U3421WE", columns: 6, rows: 2)]
        XCTAssertEqual(DisplayGrid.decode(DisplayGrid.encode(grids)), grids)
    }

    func testDecodingNothingOrGarbageGivesNoGrids() {
        XCTAssertEqual(DisplayGrid.decode(nil), [:])
        XCTAssertEqual(DisplayGrid.decode(Data("not json".utf8)), [:])
    }

    func testADisplayUsesItsOwnGrid() {
        let s = settings([office: DisplayGrid(name: "DELL U3421WE", columns: 6, rows: 2)])
        XCTAssertEqual(size(s, office), [6, 2])
    }

    func testOtherDisplaysUseTheDefaultGrid() {
        let s = settings([office: DisplayGrid(name: "DELL U3421WE", columns: 6, rows: 2)])
        XCTAssertEqual(size(s, "another display"), [4, 3])
        XCTAssertEqual(size(s, nil), [4, 3])
    }

    func testEachDisplayTurnsItsGridOnOrOff() {
        let s = settings([
            office: DisplayGrid(name: "DELL U3421WE", columns: 6, rows: 2, enabled: true),
            "laptop": DisplayGrid(name: "Built-in Retina Display", columns: 2, rows: 2, enabled: false),
        ])
        XCTAssertTrue(s.grid(forDisplay: office).enabled)
        XCTAssertFalse(s.grid(forDisplay: "laptop").enabled)
    }

    func testGridsFromVersion02FollowTheOldGlobalSwitch() {
        let saved = Data(#"{"\#(office)":{"name":"DELL U3421WE","columns":6,"rows":2}}"#.utf8)
        let grids = DisplayGrid.decode(saved)
        XCTAssertEqual(grids[office]?.columns, 6)
        XCTAssertNil(grids[office]?.enabled)
        XCTAssertTrue(settings(grids).grid(forDisplay: office).enabled)
    }

    func testStoredSizesAreClamped() {
        let s = settings([office: DisplayGrid(name: "Broken", columns: 0, rows: 500)])
        XCTAssertEqual(size(s, office), [1, 48])
    }
}
