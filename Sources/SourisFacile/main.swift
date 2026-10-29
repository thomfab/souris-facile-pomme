import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// A menu bar app, even when run outside its bundle (e.g. with `swift run`).
app.setActivationPolicy(.accessory)
app.run()
