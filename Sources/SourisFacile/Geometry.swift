import AppKit
import ApplicationServices

// Everything works in global display coordinates, as used by Quartz and the
// Accessibility API: origin at the top-left of the main display, y going down.
// AppKit (NSScreen, NSWindow) puts the origin at the bottom-left instead.

// Converts a rect between AppKit and global display coordinates (both ways).
func flipped(_ rect: CGRect) -> CGRect {
    let height = NSScreen.screens.first?.frame.height ?? 0
    return CGRect(x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height)
}

extension NSScreen {
    var globalFrame: CGRect { flipped(frame) }
    // The frame minus the menu bar and the Dock.
    var globalVisibleFrame: CGRect { flipped(visibleFrame) }

    // Identifies the physical display, and stays the same when it's
    // unplugged and plugged back in, or after a restart.
    var displayUUID: String? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue()
        else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }

    static func containing(_ point: CGPoint) -> NSScreen? {
        screens.first { $0.globalFrame.contains(point) } ?? main
    }
}

// Evenly spaced positions from start to start + length, both included.
func divide(_ start: CGFloat, _ length: CGFloat, _ count: Int) -> [CGFloat] {
    (0...count).map { (start + CGFloat($0) * length / CGFloat(count)).rounded() }
}

// How far apart two frames are: the largest difference of any edge or size.
func frameDistance(_ a: CGRect, _ b: CGRect) -> CGFloat {
    max(abs(a.minX - b.minX), abs(a.minY - b.minY), abs(a.width - b.width), abs(a.height - b.height))
}

// The shift that brings the closest of `edges` onto one of `lines`,
// or 0 if none is within `threshold`.
func snapDelta(_ edges: [CGFloat], _ lines: [CGFloat], threshold: CGFloat) -> CGFloat {
    var best: CGFloat = 0
    var bestDist = threshold
    for edge in edges {
        for line in lines {
            let dist = abs(line - edge)
            if dist <= bestDist {
                best = line - edge
                bestDist = dist
            }
        }
    }
    return best
}
