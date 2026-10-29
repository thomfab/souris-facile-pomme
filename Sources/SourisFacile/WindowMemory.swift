import Foundation

// Where an app's windows last were on a display, with the display's visible
// frame at the time, to adapt the frame if the display changed since (a
// new resolution, the Dock moved).
struct RememberedFrame: Codable, Equatable {
    var frame: CGRect
    var area: CGRect

    // The frame on the same display, whose visible frame is now `area`.
    func restored(in area: CGRect, keepSize: Bool) -> CGRect {
        transfer(frame, from: self.area, to: area, keepSize: keepSize)
    }
}

// The remembered frames, by display UUID then by app bundle ID. macOS gives
// windows no ID that survives an app restart, so they're per app.
struct WindowMemory: Equatable {
    private(set) var frames: [String: [String: RememberedFrame]] = [:]

    init() {}

    init(data: Data?) {
        if let data, let frames = try? JSONDecoder().decode([String: [String: RememberedFrame]].self, from: data) {
            self.frames = frames
        }
    }

    var data: Data {
        (try? JSONEncoder().encode(frames)) ?? Data()
    }

    var isEmpty: Bool {
        frames.values.allSatisfy(\.isEmpty)
    }

    func frame(app: String, display: String) -> RememberedFrame? {
        frames[display]?[app]
    }

    // How many apps have a remembered frame on the display.
    func count(on display: String) -> Int {
        frames[display]?.count ?? 0
    }

    mutating func forget(display: String) {
        frames[display] = nil
    }

    mutating func remember(_ frame: CGRect, area: CGRect, app: String, display: String) {
        frames[display, default: [:]][app] = RememberedFrame(frame: frame, area: area)
    }

    static func load() -> WindowMemory {
        WindowMemory(data: UserDefaults.standard.data(forKey: Key.windowFrames))
    }

    func save() {
        UserDefaults.standard.set(data, forKey: Key.windowFrames)
    }
}
