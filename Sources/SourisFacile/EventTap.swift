import CoreGraphics
import Foundation

// Sees input events before any app does, and can swallow them. Can only
// start once the app has Accessibility access.
final class EventTap {
    // Returns true to swallow the event.
    typealias Handler = (CGEventType, CGEvent) -> Bool

    private let types: [CGEventType]
    private let handler: Handler
    private var port: CFMachPort?
    private var source: CFRunLoopSource?

    init(types: [CGEventType], handler: @escaping Handler) {
        self.types = types
        self.handler = handler
    }

    var isRunning: Bool { port != nil }

    // Returns false if the tap can't be created yet (no Accessibility access).
    func start() -> Bool {
        guard port == nil else { return true }
        let mask = types.reduce(CGEventMask(0)) { $0 | CGEventMask(1) << CGEventMask($1.rawValue) }
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, info in
                let tap = Unmanaged<EventTap>.fromOpaque(info!).takeUnretainedValue()
                return tap.handle(type, event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(nil, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        self.port = port
        self.source = source
        return true
    }

    func stop() {
        if let port {
            CGEvent.tapEnable(tap: port, enable: false)
            CFMachPortInvalidate(port)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        port = nil
        source = nil
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        // macOS turns off a tap that is too slow to answer: turn it back on.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let port {
                CGEvent.tapEnable(tap: port, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }
        return handler(type, event) ? nil : Unmanaged.passUnretained(event)
    }
}
