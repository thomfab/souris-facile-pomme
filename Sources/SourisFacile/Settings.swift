import CoreGraphics
import Foundation

enum Modifier: String, CaseIterable, Identifiable {
    case shift, control, option, command

    var id: String { rawValue }

    var label: String {
        switch self {
        case .shift: return "⇧ Shift"
        case .control: return "⌃ Control"
        case .option: return "⌥ Option"
        case .command: return "⌘ Command"
        }
    }

    var flag: CGEventFlags {
        switch self {
        case .shift: return .maskShift
        case .control: return .maskControl
        case .option: return .maskAlternate
        case .command: return .maskCommand
        }
    }

    static let relevantFlags: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]

    // Modifier sets are stored as comma-separated names, e.g. "option,command".
    static func parse(_ string: String) -> Set<Modifier> {
        Set(string.split(separator: ",").compactMap { Modifier(rawValue: String($0)) })
    }

    static func format(_ modifiers: Set<Modifier>) -> String {
        allCases.filter(modifiers.contains).map(\.rawValue).joined(separator: ",")
    }

    static func flags(_ string: String) -> CGEventFlags {
        parse(string).reduce(into: CGEventFlags()) { $0.insert($1.flag) }
    }

    // Problems with the move and resize combinations, to show in the settings.
    static func warnings(move: String, resize: String) -> [String] {
        let move = parse(move), resize = parse(resize)
        var warnings: [String] = []
        if !move.isEmpty && move == resize {
            warnings.append("Move and Resize use the same keys, so only resizing works.")
        }
        for (name, modifiers) in [("Move", move), ("Resize", resize)] where modifiers.count == 1 {
            warnings.append("\(name) uses \(modifiers.first!.label) alone, which is held for ordinary shortcuts and typing. Add another key.")
        }
        return warnings
    }
}

enum Key {
    static let enabled = "enabled"
    static let moveModifiers = "move-modifiers"
    static let resizeModifiers = "resize-modifiers"
    static let raiseWindow = "raise-window"
    static let resizeNearestCorner = "resize-nearest-corner"
    static let snapThreshold = "snap-threshold"
    static let snapToWindows = "snap-to-windows"
    static let gridEnabled = "grid-enabled"
    static let gridColumns = "grid-columns"
    static let gridRows = "grid-rows"
    static let displayGrids = "display-grids"
    static let showGrid = "show-grid"
    static let dimWindows = "dim-windows"
    static let sendWithScroll = "send-with-scroll"
    static let sendWithArrows = "send-with-arrows"
    static let rememberFrames = "remember-window-frames"
    static let windowFrames = "window-frames"
}

enum Defaults {
    static let moveModifiers = "control,option"
    static let resizeModifiers = "control,option,command"
    static let snapThreshold = 16
    static let gridColumns = 4
    static let gridRows = 3
    static let gridRange = 1...48

    static func register() {
        UserDefaults.standard.register(defaults: [
            Key.enabled: true,
            Key.moveModifiers: moveModifiers,
            Key.resizeModifiers: resizeModifiers,
            Key.raiseWindow: false,
            Key.resizeNearestCorner: true,
            Key.snapThreshold: snapThreshold,
            Key.snapToWindows: true,
            Key.gridEnabled: false,
            Key.gridColumns: gridColumns,
            Key.gridRows: gridRows,
            Key.showGrid: true,
            Key.dimWindows: true,
            Key.sendWithScroll: true,
            Key.sendWithArrows: true,
            Key.rememberFrames: true,
        ])
    }
}

struct GridPreset {
    let name: String
    let columns: Int
    let rows: Int

    var label: String { "\(name) — \(columns) × \(rows)" }
}

let gridPresets = [
    GridPreset(name: "Laptop 13–14″", columns: 2, rows: 2),
    GridPreset(name: "Laptop 15–16″", columns: 3, rows: 2),
    GridPreset(name: "24–27″", columns: 4, rows: 3),
    GridPreset(name: "Ultrawide", columns: 6, rows: 2),
    GridPreset(name: "Ultrawide, fine", columns: 8, rows: 4),
]

// The grid of one display, remembered by the display's UUID so it applies
// again whenever that display is plugged back in.
struct DisplayGrid: Codable, Equatable {
    // The display's name, to list it in the settings while it's unplugged.
    var name: String
    var columns: Int
    var rows: Int
    // Whether windows snap to it. Missing in grids saved by version 0.2,
    // when the grid was turned on for all displays at once.
    var enabled: Bool? = nil

    // All of them are stored as JSON, keyed by display UUID.
    static func decode(_ data: Data?) -> [String: DisplayGrid] {
        guard let data, let grids = try? JSONDecoder().decode([String: DisplayGrid].self, from: data) else {
            return [:]
        }
        return grids
    }

    static func encode(_ grids: [String: DisplayGrid]) -> Data {
        (try? JSONEncoder().encode(grids)) ?? Data()
    }
}

private func clampGrid(_ count: Int) -> Int {
    min(max(count, Defaults.gridRange.lowerBound), Defaults.gridRange.upperBound)
}

// A snapshot of the settings, read when no operation is running.
struct Settings {
    var enabled: Bool
    var moveFlags: CGEventFlags
    var resizeFlags: CGEventFlags
    var raiseWindow: Bool
    var resizeNearestCorner: Bool
    var snapThreshold: CGFloat
    var snapToWindows: Bool
    var gridEnabled: Bool
    var gridColumns: Int
    var gridRows: Int
    var displayGrids: [String: DisplayGrid]
    var showGrid: Bool
    var dimWindows: Bool
    var sendWithScroll: Bool
    var sendWithArrows: Bool
    var rememberFrames: Bool

    static func load() -> Settings {
        let d = UserDefaults.standard
        return Settings(
            enabled: d.bool(forKey: Key.enabled),
            moveFlags: Modifier.flags(d.string(forKey: Key.moveModifiers) ?? ""),
            resizeFlags: Modifier.flags(d.string(forKey: Key.resizeModifiers) ?? ""),
            raiseWindow: d.bool(forKey: Key.raiseWindow),
            resizeNearestCorner: d.bool(forKey: Key.resizeNearestCorner),
            snapThreshold: CGFloat(d.integer(forKey: Key.snapThreshold)),
            snapToWindows: d.bool(forKey: Key.snapToWindows),
            gridEnabled: d.bool(forKey: Key.gridEnabled),
            gridColumns: clampGrid(d.integer(forKey: Key.gridColumns)),
            gridRows: clampGrid(d.integer(forKey: Key.gridRows)),
            displayGrids: DisplayGrid.decode(d.data(forKey: Key.displayGrids)),
            showGrid: d.bool(forKey: Key.showGrid),
            dimWindows: d.bool(forKey: Key.dimWindows),
            sendWithScroll: d.bool(forKey: Key.sendWithScroll),
            sendWithArrows: d.bool(forKey: Key.sendWithArrows),
            rememberFrames: d.bool(forKey: Key.rememberFrames)
        )
    }

    // The display's grid. A display never set up uses the settings from
    // before grids were per display (the grid-* keys), off by default.
    func grid(forDisplay uuid: String?) -> (enabled: Bool, columns: Int, rows: Int) {
        guard let uuid, let grid = displayGrids[uuid] else { return (gridEnabled, gridColumns, gridRows) }
        return (grid.enabled ?? gridEnabled, clampGrid(grid.columns), clampGrid(grid.rows))
    }
}
