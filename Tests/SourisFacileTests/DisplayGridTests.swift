import XCTest
@testable import SourisFacile

final class DisplayGridTests: XCTestCase {
    private let office = "37D8832A-2D66-02CA-B9F7-8F30A301B230"
    private let ultrawide = CGSize(width: 3440, height: 1440)

    private func settings(_ grids: [String: DisplayGrid]) -> Settings {
        Settings(enabled: true, moveFlags: [], resizeFlags: [], raiseWindow: false,
                 resizeNearestCorner: true, snapThreshold: 16, snapToWindows: true,
                 displayGrids: grids, showGrid: true, dimWindows: true,
                 sendWithScroll: true, sendWithArrows: true, rememberFrames: true)
    }

    private func size(_ settings: Settings, _ uuid: String?, _ display: CGSize) -> [Int] {
        let grid = settings.grid(forDisplay: uuid, size: display)
        return [grid.columns, grid.rows]
    }

    private func sensible(_ width: CGFloat, _ height: CGFloat) -> [Int] {
        let grid = sensibleGrid(for: CGSize(width: width, height: height))
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
        XCTAssertEqual(size(s, office, ultrawide), [6, 2])
    }

    func testOtherDisplaysGetAGridSuitingTheirSize() {
        let s = settings([office: DisplayGrid(name: "DELL U3421WE", columns: 6, rows: 2)])
        XCTAssertEqual(size(s, "another display", ultrawide), [8, 4])
        XCTAssertEqual(size(s, nil, CGSize(width: 1512, height: 982)), [2, 2])
    }

    func testSensibleGrids() {
        XCTAssertEqual(sensible(1470, 956), [2, 2])    // MacBook Air 13″
        XCTAssertEqual(sensible(1512, 982), [2, 2])    // MacBook Pro 14″
        XCTAssertEqual(sensible(1728, 1117), [3, 2])   // MacBook Pro 16″
        XCTAssertEqual(sensible(1920, 1080), [3, 2])
        XCTAssertEqual(sensible(2560, 1440), [4, 3])
        XCTAssertEqual(sensible(3440, 1440), [8, 4])   // 21:9
        XCTAssertEqual(sensible(5120, 1440), [8, 4])   // 32:9
        XCTAssertEqual(sensible(1440, 2560), [2, 3])   // Portrait
        XCTAssertEqual(sensible(0, 0), [4, 3])
    }

    func testSensibleGridsAreAmongThePresets() {
        for size in [(1512, 982), (1728, 1117), (2560, 1440), (3440, 1440), (1440, 2560)] {
            let grid = sensibleGrid(for: CGSize(width: size.0, height: size.1))
            XCTAssertTrue(gridPresets.contains { $0.columns == grid.columns && $0.rows == grid.rows })
        }
    }

    func testGridsFromVersion03StillLoad() {
        let saved = Data(#"{"\#(office)":{"name":"DELL U3421WE","columns":6,"rows":2,"enabled":false}}"#.utf8)
        XCTAssertEqual(DisplayGrid.decode(saved)[office], DisplayGrid(name: "DELL U3421WE", columns: 6, rows: 2))
    }

    func testStoredSizesAreClamped() {
        let s = settings([office: DisplayGrid(name: "Broken", columns: 0, rows: 500)])
        XCTAssertEqual(size(s, office, ultrawide), [1, 48])
    }
}
