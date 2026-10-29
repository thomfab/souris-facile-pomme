import AppKit
import ApplicationServices

func isAccessibilityTrusted(prompt: Bool = false) -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): prompt] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}

func openAccessibilitySettings() {
    let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
    NSWorkspace.shared.open(url)
}

private let manageableSubroles: Set<String> = [
    kAXStandardWindowSubrole,
    kAXDialogSubrole,
    kAXFloatingWindowSubrole,
    kAXSystemDialogSubrole,
]

private extension AXUIElement {
    func attribute(_ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, name as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    func element(_ name: String) -> AXUIElement? {
        guard let value = attribute(name), CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return (value as! AXUIElement)
    }

    func axValue<T>(_ name: String, _ type: AXValueType, _ empty: T) -> T? {
        guard let value = attribute(name), CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        var result = empty
        return AXValueGetValue(value as! AXValue, type, &result) ? result : nil
    }

    func isSettable(_ name: String) -> Bool {
        var settable: DarwinBoolean = false
        return AXUIElementIsAttributeSettable(self, name as CFString, &settable) == .success
            && settable.boolValue
    }

    func set<T>(_ name: String, _ type: AXValueType, _ value: T) -> Bool {
        var value = value
        guard let axValue = AXValueCreate(type, &value) else { return false }
        return AXUIElementSetAttributeValue(self, name as CFString, axValue) == .success
    }
}

struct ManagedWindow {
    let element: AXUIElement
    let pid: pid_t

    private static let systemWide: AXUIElement = {
        let element = AXUIElementCreateSystemWide()
        // Don't hang on an unresponsive app.
        AXUIElementSetMessagingTimeout(element, 0.25)
        return element
    }()

    // The window whose content is under `point`, if it can be managed.
    static func at(_ point: CGPoint) -> ManagedWindow? {
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &hit) == .success,
              let hit
        else { return nil }

        let role = hit.attribute(kAXRoleAttribute) as? String
        guard let element = role == kAXWindowRole ? hit : hit.element(kAXWindowAttribute) else {
            return nil
        }

        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        let window = ManagedWindow(element: element, pid: pid)
        return window.isManageable ? window : nil
    }

    private var isManageable: Bool {
        guard pid != ProcessInfo.processInfo.processIdentifier,
              let subrole = element.attribute(kAXSubroleAttribute) as? String,
              manageableSubroles.contains(subrole)
        else { return false }
        // Fullscreen windows live in their own Space and can't be moved.
        let fullscreen = element.attribute("AXFullScreen") as? Bool ?? false
        let minimized = element.attribute(kAXMinimizedAttribute) as? Bool ?? false
        return !fullscreen && !minimized
    }

    var canMove: Bool { element.isSettable(kAXPositionAttribute) }
    var canResize: Bool { element.isSettable(kAXSizeAttribute) }

    var frame: CGRect? {
        guard let origin = element.axValue(kAXPositionAttribute, .cgPoint, CGPoint.zero),
              let size = element.axValue(kAXSizeAttribute, .cgSize, CGSize.zero)
        else { return nil }
        return CGRect(origin: origin, size: size)
    }

    // Each returns false once the window is gone.
    func setOrigin(_ origin: CGPoint) -> Bool {
        element.set(kAXPositionAttribute, .cgPoint, origin)
    }

    func setFrame(_ frame: CGRect) -> Bool {
        // Position first so a window growing up or left isn't clamped by the screen edge.
        element.set(kAXPositionAttribute, .cgPoint, frame.origin)
            && element.set(kAXSizeAttribute, .cgSize, frame.size)
    }

    func raise() {
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
        guard let app = NSRunningApplication(processIdentifier: pid) else { return }
        if #available(macOS 14, *) {
            app.activate()
        } else {
            app.activate(options: [])
        }
    }
}

struct WindowInfo {
    let id: CGWindowID
    let pid: pid_t
    let frame: CGRect
}

// The visible, regular windows on screen, frontmost first.
func onScreenWindows() -> [WindowInfo] {
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
        return []
    }
    return list.compactMap { info in
        guard info[kCGWindowLayer as String] as? Int == 0,
              (info[kCGWindowAlpha as String] as? Double ?? 1) > 0,
              let id = info[kCGWindowNumber as String] as? Int,
              let pid = info[kCGWindowOwnerPID as String] as? Int,
              let bounds = info[kCGWindowBounds as String] as? NSDictionary,
              let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary)
        else { return nil }
        return WindowInfo(id: CGWindowID(id), pid: pid_t(pid), frame: frame)
    }
}
