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
    static let showGrid = "show-grid"
    static let dimWindows = "dim-windows"
}

enum Defaults {
    static let moveModifiers = "control,option"
    static let resizeModifiers = "control,option,command"
    static let snapThreshold = 16
    static let gridColumns = 4
    static let gridRows = 3

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
    GridPreset(name: "Ultrawide, fine", columns: 8, rows: 3),
]

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
    var showGrid: Bool
    var dimWindows: Bool

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
            gridColumns: min(max(d.integer(forKey: Key.gridColumns), 1), 48),
            gridRows: min(max(d.integer(forKey: Key.gridRows), 1), 48),
            showGrid: d.bool(forKey: Key.showGrid),
            dimWindows: d.bool(forKey: Key.dimWindows)
        )
    }
}
