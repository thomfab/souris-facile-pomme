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

// The display in `direction` from display `source`, among display frames:
// the closest one that way, preferring those lined up with it.
func display(toward direction: Direction, from source: Int, among displays: [CGRect]) -> Int? {
    let from = displays[source]
    let v = direction.vector
    var best: Int?
    var bestScore = CGFloat.infinity
    for (index, frame) in displays.enumerated() where index != source {
        let dx = frame.midX - from.midX
        let dy = frame.midY - from.midY
        let along = dx * v.x + dy * v.y
        guard along > 0 else { continue }
        let across = abs(dx * v.y - dy * v.x)
        let score = along + 2 * across
        if score < bestScore {
            best = index
            bestScore = score
        }
    }
    return best
}

// The display `step` places after display `index`, going left to right
// (then top to bottom) and wrapping around.
func display(after index: Int, by step: Int, among displays: [CGRect]) -> Int? {
    guard displays.count > 1 else { return nil }
    let order = displays.indices.sorted {
        (displays[$0].minX, displays[$0].minY) < (displays[$1].minX, displays[$1].minY)
    }
    let position = order.firstIndex(of: index)!
    let count = order.count
    return order[((position + step) % count + count) % count]
}

// Where `frame` lands when it goes from area `from` to area `to` (screens'
// visible frames): same relative place and size, fitted inside `to`.
// With `keepSize`, for windows that can't be resized, only the place changes.
func transfer(_ frame: CGRect, from: CGRect, to: CGRect, keepSize: Bool) -> CGRect {
    let sx = to.width / from.width
    let sy = to.height / from.height
    var width = frame.width, height = frame.height
    if !keepSize {
        width = min(width * sx, to.width)
        height = min(height * sy, to.height)
    }
    // The center keeps its relative place.
    var x = to.minX + (frame.midX - from.minX) * sx - width / 2
    var y = to.minY + (frame.midY - from.minY) * sy - height / 2
    x = max(min(x, to.maxX - width), to.minX)
    y = max(min(y, to.maxY - height), to.minY)
    return CGRect(x: x.rounded(), y: y.rounded(), width: width.rounded(), height: height.rounded())
}

// Moves each edge of `frame` to the nearest line of the grid over `area`,
// keeping it at least one cell wide and tall.
func fitToGrid(_ frame: CGRect, area: CGRect, columns: Int, rows: Int) -> CGRect {
    func nearest(_ value: CGFloat, _ lines: [CGFloat]) -> Int {
        lines.indices.min { abs(lines[$0] - value) < abs(lines[$1] - value) }!
    }
    func span(_ low: CGFloat, _ high: CGFloat, _ lines: [CGFloat]) -> (CGFloat, CGFloat) {
        var first = nearest(low, lines), last = nearest(high, lines)
        if first == last {
            if last < lines.count - 1 { last += 1 } else { first -= 1 }
        }
        return (lines[first], lines[last])
    }
    let (left, right) = span(frame.minX, frame.maxX, divide(area.minX, area.width, columns))
    let (top, bottom) = span(frame.minY, frame.maxY, divide(area.minY, area.height, rows))
    return CGRect(x: left, y: top, width: right - left, height: bottom - top)
}
