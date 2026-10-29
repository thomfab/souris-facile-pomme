import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let mover = WindowMover()
    private var monitors: [Any] = []
    private var accessTimer: Timer?
    private var statusItem: NSStatusItem!
    private var enabledItem: NSMenuItem!
    private var accessItem: NSMenuItem!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Defaults.register()
        setUpStatusItem()
        installMonitors()

        if !isAccessibilityTrusted(prompt: true) {
            showSettings()
            watchAccessibility()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        removeMonitors()
        accessTimer?.invalidate()
        mover.stop()
    }

    private func installMonitors() {
        removeMonitors()
        let events: NSEvent.EventTypeMask = [
            .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .flagsChanged,
        ]
        let mover = mover
        // Global monitors miss events sent to this app (e.g. over the
        // settings window), so watch those locally too.
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { _ in
            mover.scheduleUpdate()
        }) {
            monitors.append(monitor)
        }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: events, handler: { event in
            mover.scheduleUpdate()
            return event
        }) {
            monitors.append(monitor)
        }
    }

    private func removeMonitors() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
    }

    // Global monitors installed before access was granted don't see key
    // events, so install them again once it is.
    private func watchAccessibility() {
        accessTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            guard isAccessibilityTrusted() else { return }
            timer.invalidate()
            self?.accessTimer = nil
            self?.installMonitors()
        }
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "computermouse",
                                           accessibilityDescription: "Souris Facile")

        let menu = NSMenu()
        menu.delegate = self

        menu.addItem(item("About Souris Facile", #selector(showAbout)))
        menu.addItem(.separator())

        enabledItem = item("Enabled", #selector(toggleEnabled))
        menu.addItem(enabledItem)

        accessItem = item("Grant Accessibility Access…", #selector(grantAccess))
        menu.addItem(accessItem)

        menu.addItem(.separator())
        menu.addItem(item("Settings…", #selector(showSettings), key: ","))

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Souris Facile",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        enabledItem.state = UserDefaults.standard.bool(forKey: Key.enabled) ? .on : .off
        accessItem.isHidden = isAccessibilityTrusted()
    }

    @objc private func toggleEnabled() {
        let enabled = !UserDefaults.standard.bool(forKey: Key.enabled)
        UserDefaults.standard.set(enabled, forKey: Key.enabled)
        if !enabled {
            mover.stop()
        }
    }

    @objc private func grantAccess() {
        if !isAccessibilityTrusted(prompt: true) {
            openAccessibilitySettings()
            if accessTimer == nil {
                watchAccessibility()
            }
        }
    }

    @objc private func showAbout() {
        let credits = NSMutableAttributedString(
            string: "Move and resize windows by holding modifier keys.\n",
            attributes: [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)]
        )
        let url = "https://github.com/thomfab/souris-facile-pomme"
        credits.append(NSAttributedString(string: url, attributes: [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .link: URL(string: url)!,
        ]))
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        credits.addAttribute(.paragraphStyle, value: centered,
                             range: NSRange(location: 0, length: credits.length))

        activate()
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            window.title = "Souris Facile Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    // A menu bar app isn't active by default: bring its windows to the front.
    private func activate() {
        if #available(macOS 14, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
