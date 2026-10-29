import AppKit
import Combine
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage(Key.moveModifiers) private var moveModifiers = Defaults.moveModifiers
    @AppStorage(Key.resizeModifiers) private var resizeModifiers = Defaults.resizeModifiers
    @AppStorage(Key.raiseWindow) private var raiseWindow = false
    @AppStorage(Key.resizeNearestCorner) private var resizeNearestCorner = true
    @AppStorage(Key.snapThreshold) private var snapThreshold = Defaults.snapThreshold
    @AppStorage(Key.snapToWindows) private var snapToWindows = true
    @AppStorage(Key.gridEnabled) private var gridEnabled = false
    @AppStorage(Key.gridColumns) private var gridColumns = Defaults.gridColumns
    @AppStorage(Key.gridRows) private var gridRows = Defaults.gridRows
    @AppStorage(Key.displayGrids) private var displayGridsData = Data()
    @AppStorage(Key.showGrid) private var showGrid = true
    @AppStorage(Key.dimWindows) private var dimWindows = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var accessGranted = isAccessibilityTrusted()
    @State private var displays = ConnectedDisplay.all()
    @State private var preview = GridPreview()
    private let accessCheck = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            if !accessGranted {
                Section {
                    LabeledContent {
                        Button("Open System Settings…", action: openAccessibilitySettings)
                    } label: {
                        Label("Accessibility access needed", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                } footer: {
                    Text("Turn on Souris facile pomme in Privacy & Security → Accessibility so it can see the keys you hold and move other apps' windows.")
                }
            }

            Section {
                ModifierToggles(value: $moveModifiers)
            } header: {
                Text("Move")
            } footer: {
                Text("Hold these keys and move the mouse to move the window under the pointer. Turn all off to disable.")
            }

            Section {
                ModifierToggles(value: $resizeModifiers)
            } header: {
                Text("Resize")
            } footer: {
                Text("Hold these keys and move the mouse to resize the window under the pointer. Turn all off to disable.")
            }

            let warnings = Modifier.warnings(move: moveModifiers, resize: resizeModifiers)
            if !warnings.isEmpty {
                Section {
                    ForEach(warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section("Behavior") {
                Toggle("Raise window", isOn: $raiseWindow)
                Toggle("Resize from nearest corner", isOn: $resizeNearestCorner)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }

            Section {
                Stepper(value: $snapThreshold, in: 0...200) {
                    Text("Snap distance: \(snapThreshold) pt")
                }
                Toggle("Snap to other windows", isOn: $snapToWindows)
            } header: {
                Text("Edge Snapping")
            } footer: {
                Text("Window edges snap to screen edges when they come close. 0 turns edge snapping off. Not used while the grid is on.")
            }
            .disabled(gridEnabled)

            Section {
                Toggle("Snap to grid", isOn: $gridEnabled)
                Group {
                    GridSizeFields(title: "Default grid size", columns: $gridColumns, rows: $gridRows)
                    Toggle("Show grid", isOn: $showGrid)
                    Toggle("Dim other windows", isOn: $dimWindows)
                }
                .disabled(!gridEnabled)
            } header: {
                Text("Grid")
            } footer: {
                Text("Divide each screen into a grid. Moved and resized edges always snap to its lines. Displays without their own grid size use the default one.")
            }

            ForEach(displays) { display in
                Section {
                    Toggle(isOn: hasOwnGrid(display)) {
                        Text("Own grid size")
                        Text("Otherwise uses the default, \(gridColumns) × \(gridRows).")
                    }
                    if displayGrids[display.uuid] != nil {
                        GridSizeFields(title: "Grid size",
                                       columns: displayGridSize(display, \.columns),
                                       rows: displayGridSize(display, \.rows))
                    }
                    Button("Preview Grid") { previewGrid(on: display) }
                } header: {
                    Text(display.name)
                }
                .disabled(!gridEnabled)
            }

            let unplugged = displayGrids
                .filter { entry in !displays.contains { $0.uuid == entry.key } }
                .sorted { $0.value.name < $1.value.name }
            if !unplugged.isEmpty {
                Section {
                    ForEach(unplugged, id: \.key) { entry in
                        LabeledContent {
                            Button("Forget") { setDisplayGrid(nil, for: entry.key) }
                        } label: {
                            Text(entry.value.name)
                            Text("\(entry.value.columns) × \(entry.value.rows)")
                        }
                    }
                } header: {
                    Text("Other Displays")
                } footer: {
                    Text("Remembered grid sizes of displays that aren't plugged in. They apply again as soon as the display is.")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 720)
        .onReceive(accessCheck) { _ in
            accessGranted = isAccessibilityTrusted()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            displays = ConnectedDisplay.all()
        }
    }

    private var displayGrids: [String: DisplayGrid] {
        DisplayGrid.decode(displayGridsData)
    }

    private func setDisplayGrid(_ grid: DisplayGrid?, for uuid: String) {
        var grids = displayGrids
        grids[uuid] = grid
        displayGridsData = DisplayGrid.encode(grids)
    }

    private func hasOwnGrid(_ display: ConnectedDisplay) -> Binding<Bool> {
        Binding(
            get: { displayGrids[display.uuid] != nil },
            set: { isOn in
                let grid = isOn ? DisplayGrid(name: display.name, columns: gridColumns, rows: gridRows) : nil
                setDisplayGrid(grid, for: display.uuid)
            }
        )
    }

    private func displayGridSize(_ display: ConnectedDisplay,
                                 _ keyPath: WritableKeyPath<DisplayGrid, Int>) -> Binding<Int> {
        Binding(
            get: { displayGrids[display.uuid]?[keyPath: keyPath] ?? 1 },
            set: { value in
                guard var grid = displayGrids[display.uuid] else { return }
                grid[keyPath: keyPath] = value
                grid.name = display.name
                setDisplayGrid(grid, for: display.uuid)
                previewGrid(on: display)
            }
        )
    }

    // Briefly shows the display's grid on it, to tell displays apart.
    private func previewGrid(on display: ConnectedDisplay) {
        guard let screen = NSScreen.screens.first(where: { $0.displayUUID == display.uuid }) else { return }
        let grid = displayGrids[display.uuid]
        preview.show(over: screen.globalVisibleFrame,
                     columns: grid?.columns ?? gridColumns, rows: grid?.rows ?? gridRows)
    }
}

private struct ConnectedDisplay: Identifiable {
    let uuid: String
    let name: String
    var id: String { uuid }

    static func all() -> [ConnectedDisplay] {
        NSScreen.screens.compactMap { screen in
            screen.displayUUID.map { ConnectedDisplay(uuid: $0, name: screen.localizedName) }
        }
    }
}

private final class GridPreview {
    private let overlays = Overlays()
    private var shownAt = Date.distantPast

    func show(over area: CGRect, columns: Int, rows: Int) {
        overlays.showGrid(over: area, columns: columns, rows: rows)
        let shownAt = Date()
        self.shownAt = shownAt
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            // Showing it again keeps it up for another 2 seconds.
            guard let self, self.shownAt == shownAt else { return }
            self.overlays.hideGrid()
        }
    }
}

private struct GridSizeFields: View {
    let title: String
    @Binding var columns: Int
    @Binding var rows: Int

    var body: some View {
        Picker(title, selection: presetSelection) {
            ForEach(gridPresets.indices, id: \.self) { index in
                Text(gridPresets[index].label).tag(index)
            }
            Text("Custom").tag(-1)
        }
        Stepper(value: $columns, in: Defaults.gridRange) {
            Text("Columns: \(columns)")
        }
        Stepper(value: $rows, in: Defaults.gridRange) {
            Text("Rows: \(rows)")
        }
    }

    // The preset matching the current size, or -1 for "Custom".
    private var presetSelection: Binding<Int> {
        Binding(
            get: {
                gridPresets.firstIndex { $0.columns == columns && $0.rows == rows } ?? -1
            },
            set: { index in
                guard gridPresets.indices.contains(index) else { return }
                columns = gridPresets[index].columns
                rows = gridPresets[index].rows
            }
        )
    }
}

private struct ModifierToggles: View {
    @Binding var value: String

    var body: some View {
        ForEach(Modifier.allCases) { modifier in
            Toggle(modifier.label, isOn: Binding(
                get: { Modifier.parse(value).contains(modifier) },
                set: { isOn in
                    var modifiers = Modifier.parse(value)
                    if isOn {
                        modifiers.insert(modifier)
                    } else {
                        modifiers.remove(modifier)
                    }
                    value = Modifier.format(modifiers)
                }
            ))
        }
    }
}
