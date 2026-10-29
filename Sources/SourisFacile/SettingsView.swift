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
    @AppStorage(Key.showGrid) private var showGrid = true
    @AppStorage(Key.dimWindows) private var dimWindows = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var accessGranted = isAccessibilityTrusted()
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
                    Text("Turn on Souris Facile in Privacy & Security → Accessibility so it can see the keys you hold and move other apps' windows.")
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
                    Picker("Grid size", selection: presetSelection) {
                        ForEach(gridPresets.indices, id: \.self) { index in
                            Text(gridPresets[index].label).tag(index)
                        }
                        Text("Custom").tag(-1)
                    }
                    Stepper(value: $gridColumns, in: 1...48) {
                        Text("Columns: \(gridColumns)")
                    }
                    Stepper(value: $gridRows, in: 1...48) {
                        Text("Rows: \(gridRows)")
                    }
                    Toggle("Show grid", isOn: $showGrid)
                    Toggle("Dim other windows", isOn: $dimWindows)
                }
                .disabled(!gridEnabled)
            } header: {
                Text("Grid")
            } footer: {
                Text("Divide each screen into a grid. Moved and resized edges always snap to its lines.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 640)
        .onReceive(accessCheck) { _ in
            accessGranted = isAccessibilityTrusted()
        }
    }

    // The preset matching the current size, or -1 for "Custom".
    private var presetSelection: Binding<Int> {
        Binding(
            get: {
                gridPresets.firstIndex { $0.columns == gridColumns && $0.rows == gridRows } ?? -1
            },
            set: { index in
                guard gridPresets.indices.contains(index) else { return }
                gridColumns = gridPresets[index].columns
                gridRows = gridPresets[index].rows
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
