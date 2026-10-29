import AppKit
import Combine
import ServiceManagement
import SwiftUI

private enum Page: Hashable {
    case general, move, resize, snapping, send
    case display(String)
    case unplugged
}

struct SettingsView: View {
    @AppStorage(Key.enabled) private var enabled = true
    @AppStorage(Key.moveModifiers) private var moveModifiers = Defaults.moveModifiers
    @AppStorage(Key.resizeModifiers) private var resizeModifiers = Defaults.resizeModifiers
    @AppStorage(Key.raiseWindow) private var raiseWindow = false
    @AppStorage(Key.resizeNearestCorner) private var resizeNearestCorner = true
    @AppStorage(Key.snapThreshold) private var snapThreshold = Defaults.snapThreshold
    @AppStorage(Key.snapToWindows) private var snapToWindows = true
    @AppStorage(Key.displayGrids) private var displayGridsData = Data()
    @AppStorage(Key.showGrid) private var showGrid = true
    @AppStorage(Key.dimWindows) private var dimWindows = true
    @AppStorage(Key.sendWithScroll) private var sendWithScroll = true
    @AppStorage(Key.sendWithArrows) private var sendWithArrows = true
    @AppStorage(Key.rememberFrames) private var rememberFrames = true
    @AppStorage(Key.windowFrames) private var windowFramesData = Data()
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var accessGranted = isAccessibilityTrusted()
    @State private var displays = ConnectedDisplay.all()
    @State private var preview = GridPreview()
    @State private var page: Page? = .general
    private let accessCheck = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationSplitView {
            List(selection: $page) {
                Section {
                    Label("General", systemImage: "gearshape").tag(Page.general)
                    Label("Move", systemImage: "arrow.up.and.down.and.arrow.left.and.right").tag(Page.move)
                    Label("Resize", systemImage: "arrow.up.left.and.arrow.down.right").tag(Page.resize)
                    Label("Snapping", systemImage: "square.grid.3x3").tag(Page.snapping)
                    Label("Send to Display", systemImage: "rectangle.on.rectangle").tag(Page.send)
                }
                Section("Displays") {
                    ForEach(displays) { display in
                        Label(display.name, systemImage: display.isBuiltIn ? "laptopcomputer" : "display")
                            .tag(Page.display(display.uuid))
                    }
                    if !unplugged.isEmpty {
                        Label("Unplugged Displays", systemImage: "powerplug").tag(Page.unplugged)
                    }
                }
            }
            .navigationSplitViewColumnWidth(210)
        } detail: {
            Form {
                if !accessGranted {
                    accessSection
                }
                switch page ?? .general {
                case .general: generalPage
                case .move: movePage
                case .resize: resizePage
                case .snapping: snappingPage
                case .send: sendPage
                case .display(let uuid):
                    if let display = displays.first(where: { $0.uuid == uuid }) {
                        displayPage(display)
                    } else {
                        Text("This display isn't plugged in anymore.")
                    }
                case .unplugged: unpluggedPage
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 720, height: 520)
        .onReceive(accessCheck) { _ in
            accessGranted = isAccessibilityTrusted()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            displays = ConnectedDisplay.all()
        }
    }

    // MARK: Pages

    private var accessSection: some View {
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

    @ViewBuilder private var generalPage: some View {
        Section {
            Toggle("Enabled", isOn: $enabled)
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
            Toggle(isOn: $raiseWindow) {
                Text("Raise window")
                Text("Bring the window to the front when you start moving or resizing it.")
            }
        }
    }

    @ViewBuilder private var movePage: some View {
        Section {
            ModifierToggles(value: $moveModifiers)
        } header: {
            Text("Keys")
        } footer: {
            Text("Hold these keys and move the mouse to move the window under the pointer. Turn all off to disable.")
        }
        warningsSection
    }

    @ViewBuilder private var resizePage: some View {
        Section {
            ModifierToggles(value: $resizeModifiers)
        } header: {
            Text("Keys")
        } footer: {
            Text("Hold these keys and move the mouse to resize the window under the pointer. Turn all off to disable.")
        }
        warningsSection
        Section {
            Toggle(isOn: $resizeNearestCorner) {
                Text("Resize from nearest corner")
                Text("Otherwise always from the bottom-right corner.")
            }
        }
    }

    @ViewBuilder private var warningsSection: some View {
        let warnings = Modifier.warnings(move: moveModifiers, resize: resizeModifiers)
        if !warnings.isEmpty {
            Section {
                ForEach(warnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    @ViewBuilder private var snappingPage: some View {
        Section {
            Stepper(value: $snapThreshold, in: 0...200) {
                Text("Snap distance: \(snapThreshold) pt")
            }
            Toggle("Snap to other windows", isOn: $snapToWindows)
        } header: {
            Text("Edge Snapping")
        } footer: {
            Text("Window edges snap to screen edges when they come close. 0 turns edge snapping off.")
        }

        Section {
            Toggle("Show grid", isOn: $showGrid)
            Toggle("Dim other windows", isOn: $dimWindows)
        } header: {
            Text("Grid")
        } footer: {
            Text("While moving or resizing, press and hold the click (with the keys still held) to snap window edges to the grid of the display under the pointer. Each display's grid is set on its own page.")
        }
    }

    @ViewBuilder private var sendPage: some View {
        Section {
            Toggle(isOn: $sendWithScroll) {
                Text("Swipe or scroll")
                Text("Swipe two fingers on a trackpad or Magic Mouse toward a display. A mouse wheel goes to the next or previous display.")
            }
            Toggle(isOn: $sendWithArrows) {
                Text("Arrow keys")
                Text("Press an arrow key to go to the display in that direction.")
            }
        } footer: {
            Text("Hold the move keys over a window and swipe, scroll or press an arrow key. The pointer goes with the window.")
        }
        .disabled(Modifier.parse(moveModifiers).isEmpty)

        Section {
            Toggle(isOn: $rememberFrames) {
                Text("Remember window sizes per display")
                Text("A window sent or dragged to a display gets the size and place its app's windows last had there. Otherwise it keeps its relative place and size.")
            }
            Button("Forget All Remembered Sizes") {
                windowFramesData = Data()
            }
            .disabled(windowMemory.isEmpty)
        } header: {
            Text("Window Sizes")
        }
    }

    @ViewBuilder private func displayPage(_ display: ConnectedDisplay) -> some View {
        Section {
            GridSizeFields(title: "Grid size",
                           columns: gridSizeBinding(display, \.columns),
                           rows: gridSizeBinding(display, \.rows))
            Button("Preview Grid") { previewGrid(on: display) }
        } header: {
            Text("Grid")
        } footer: {
            Text("Windows snap to it while you hold the click. Remembered for this display, and used again whenever it's plugged in. A new display gets a grid suiting its size.")
        }

        Section {
            let count = windowMemory.count(on: display.uuid)
            LabeledContent {
                Button("Forget") {
                    var memory = windowMemory
                    memory.forget(display: display.uuid)
                    windowFramesData = memory.data
                }
                .disabled(count == 0)
            } label: {
                Text(count == 1 ? "1 app" : "\(count) apps")
            }
        } header: {
            Text("Remembered Window Sizes")
        } footer: {
            Text("Where apps' windows last were on this display, used when a window is sent or dragged here.")
        }
    }

    @ViewBuilder private var unpluggedPage: some View {
        Section {
            ForEach(unplugged, id: \.key) { entry in
                LabeledContent {
                    Button("Forget") {
                        setDisplayGrid(nil, for: entry.key)
                        var memory = windowMemory
                        memory.forget(display: entry.key)
                        windowFramesData = memory.data
                    }
                } label: {
                    Text(entry.value.name)
                    Text(gridSummary(entry.value))
                }
            }
        } footer: {
            Text("Settings of displays that aren't plugged in. They apply again as soon as the display is. Forgetting a display also forgets its remembered window sizes.")
        }
    }

    // MARK: Display settings

    private var displayGrids: [String: DisplayGrid] {
        DisplayGrid.decode(displayGridsData)
    }

    private var windowMemory: WindowMemory {
        WindowMemory(data: windowFramesData)
    }

    private var unplugged: [(key: String, value: DisplayGrid)] {
        displayGrids
            .filter { entry in !displays.contains { $0.uuid == entry.key } }
            .sorted { $0.value.name < $1.value.name }
    }

    private func gridSummary(_ grid: DisplayGrid) -> String {
        "Grid \(grid.columns) × \(grid.rows)"
    }

    // The display's grid, or one suiting its size if it was never set.
    private func grid(of display: ConnectedDisplay) -> DisplayGrid {
        if let grid = displayGrids[display.uuid] {
            return grid
        }
        let size = sensibleGrid(for: display.size)
        return DisplayGrid(name: display.name, columns: size.columns, rows: size.rows)
    }

    private func setDisplayGrid(_ grid: DisplayGrid?, for uuid: String) {
        var grids = displayGrids
        grids[uuid] = grid
        displayGridsData = DisplayGrid.encode(grids)
    }

    private func updateGrid(_ display: ConnectedDisplay, _ change: (inout DisplayGrid) -> Void) {
        var grid = grid(of: display)
        grid.name = display.name
        change(&grid)
        setDisplayGrid(grid, for: display.uuid)
    }

    private func gridSizeBinding(_ display: ConnectedDisplay,
                                 _ keyPath: WritableKeyPath<DisplayGrid, Int>) -> Binding<Int> {
        Binding(
            get: { grid(of: display)[keyPath: keyPath] },
            set: { value in
                updateGrid(display) { $0[keyPath: keyPath] = value }
                previewGrid(on: display)
            }
        )
    }

    // Briefly shows the display's grid on it, to tell displays apart.
    private func previewGrid(on display: ConnectedDisplay) {
        guard let screen = NSScreen.screens.first(where: { $0.displayUUID == display.uuid }) else { return }
        let grid = grid(of: display)
        preview.show(over: screen.globalVisibleFrame, columns: grid.columns, rows: grid.rows)
    }
}

private struct ConnectedDisplay: Identifiable {
    let uuid: String
    let name: String
    let isBuiltIn: Bool
    let size: CGSize
    var id: String { uuid }

    static func all() -> [ConnectedDisplay] {
        NSScreen.screens.compactMap { screen in
            screen.displayUUID.map {
                ConnectedDisplay(uuid: $0, name: screen.localizedName, isBuiltIn: screen.isBuiltIn,
                                 size: screen.globalFrame.size)
            }
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
