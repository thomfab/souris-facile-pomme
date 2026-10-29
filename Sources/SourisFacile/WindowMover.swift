import AppKit

private let minWidth: CGFloat = 100
private let minHeight: CGFloat = 60

// Moves or resizes the window under the pointer while modifier keys are held.
final class WindowMover {
    private enum Op {
        case none, move, resize
    }

    private var settings = Settings.load()
    private var op = Op.none
    private var window: ManagedWindow?
    private var start = CGPoint.zero
    private var startRect = CGRect.zero
    // Where the pointer sits inside the window, as a fraction of its size.
    private var grabRatio = CGPoint.zero
    // Which edges a resize moves: -1 for left/top, 1 for right/bottom.
    private var resizeDirX: CGFloat = 1
    private var resizeDirY: CGFloat = 1
    private var lastFrame = CGRect.null
    private var workAreas: [CGRect] = []
    private var otherRects: [CGRect] = []
    private let overlays = Overlays()
    private var updatePending = false

    // Called for every pointer or modifier change. Bursts of events are
    // coalesced into one update, so a slow app doesn't make the pointer lag.
    func scheduleUpdate() {
        guard !updatePending else { return }
        updatePending = true
        DispatchQueue.main.async { [self] in
            updatePending = false
            update()
        }
    }

    func stop() {
        endOperation()
    }

    private func update() {
        if op == .none {
            settings = Settings.load()
        }

        let point = CGEvent(source: nil)?.location ?? .zero
        let newOp = settings.enabled ? opForModifiers() : .none

        if newOp != op {
            endOperation()
            if newOp != .none {
                beginOperation(newOp, at: point)
            }
            return
        }

        switch op {
        case .move: updateMove(point)
        case .resize: updateResize(point)
        case .none: break
        }
    }

    private func opForModifiers() -> Op {
        let flags = CGEventSource.flagsState(.combinedSessionState)
            .intersection(Modifier.relevantFlags)
        if !settings.resizeFlags.isEmpty && flags == settings.resizeFlags {
            return .resize
        }
        if !settings.moveFlags.isEmpty && flags == settings.moveFlags {
            return .move
        }
        return .none
    }

    private func beginOperation(_ newOp: Op, at point: CGPoint) {
        guard let window = ManagedWindow.at(point),
              newOp == .move ? window.canMove : window.canResize,
              let rect = window.frame, rect.width > 0, rect.height > 0
        else { return }

        op = newOp
        self.window = window
        start = point
        startRect = rect
        lastFrame = rect
        grabRatio = CGPoint(x: (point.x - rect.minX) / rect.width,
                            y: (point.y - rect.minY) / rect.height)

        if settings.resizeNearestCorner {
            resizeDirX = grabRatio.x < 0.5 ? -1 : 1
            resizeDirY = grabRatio.y < 0.5 ? -1 : 1
        } else {
            resizeDirX = 1
            resizeDirY = 1
        }

        let windowID = collectSnapTargets(for: window, frame: rect)

        if settings.raiseWindow {
            window.raise()
        }

        if settings.gridEnabled && settings.dimWindows, let windowID {
            overlays.showDimmer(below: windowID)
        }
    }

    private func endOperation() {
        op = .none
        window = nil
        workAreas = []
        otherRects = []
        overlays.hideAll()
    }

    private func updateMove(_ point: CGPoint) {
        guard let window else { return }
        let size = startRect.size
        var x = (point.x - grabRatio.x * size.width).rounded()
        var y = (point.y - grabRatio.y * size.height).rounded()

        x += snap([x, x + size.width], snapLinesX(top: y, height: size.height, point))
        y += snap([y, y + size.height], snapLinesY(left: x, width: size.width, point))

        let frame = CGRect(origin: CGPoint(x: x, y: y), size: size)
        guard frame != lastFrame else { return }
        lastFrame = frame
        if !window.setOrigin(frame.origin) {
            endOperation()
        }
    }

    private func updateResize(_ point: CGPoint) {
        guard let window else { return }
        let dx = point.x - start.x
        let dy = point.y - start.y

        var left = startRect.minX, right = startRect.maxX
        var top = startRect.minY, bottom = startRect.maxY

        if resizeDirX > 0 { right += dx } else { left += dx }
        if resizeDirY > 0 { bottom += dy } else { top += dy }

        let linesX = snapLinesX(top: top, height: bottom - top, point)
        if resizeDirX > 0 {
            right += snap([right], linesX)
        } else {
            left += snap([left], linesX)
        }

        let linesY = snapLinesY(left: left, width: right - left, point)
        if resizeDirY > 0 {
            bottom += snap([bottom], linesY)
        } else {
            top += snap([top], linesY)
        }

        if right - left < minWidth {
            if resizeDirX > 0 { right = left + minWidth } else { left = right - minWidth }
        }
        if bottom - top < minHeight {
            if resizeDirY > 0 { bottom = top + minHeight } else { top = bottom - minHeight }
        }

        let frame = CGRect(x: left.rounded(), y: top.rounded(),
                           width: (right - left).rounded(), height: (bottom - top).rounded())
        guard frame != lastFrame else { return }
        lastFrame = frame
        if !window.setFrame(frame) {
            endOperation()
            return
        }

        // An app can refuse a size (below its minimum, above its maximum).
        // The position was set first, so put back the edges that shouldn't move.
        guard resizeDirX < 0 || resizeDirY < 0,
              let actual = window.frame, actual.size != frame.size
        else { return }
        let origin = CGPoint(x: resizeDirX < 0 ? frame.maxX - actual.width : frame.minX,
                             y: resizeDirY < 0 ? frame.maxY - actual.height : frame.minY)
        if origin != actual.origin {
            _ = window.setOrigin(origin)
        }
    }

    // Records the screen work areas and the other windows' frames, and
    // returns the window server ID of the window being handled, if found.
    private func collectSnapTargets(for window: ManagedWindow, frame: CGRect) -> CGWindowID? {
        workAreas = NSScreen.screens.map(\.globalVisibleFrame)

        // The Accessibility API doesn't give window IDs: match on owner and
        // the closest frame, as the two APIs can disagree by a few points.
        let windows = onScreenWindows()
            .filter { $0.pid != ProcessInfo.processInfo.processIdentifier }
        let target = windows
            .filter { $0.pid == window.pid }
            .min { frameDistance($0.frame, frame) < frameDistance($1.frame, frame) }
            .flatMap { frameDistance($0.frame, frame) <= 8 ? $0 : nil }
        // Never snap to the window's own starting frame, even if unmatched.
        otherRects = windows
            .filter { $0.id != target?.id && frameDistance($0.frame, frame) > 1 }
            .map(\.frame)
        return target?.id
    }

    private func snap(_ edges: [CGFloat], _ lines: [CGFloat]) -> CGFloat {
        // The grid always snaps; edge snapping only within the threshold.
        let threshold = settings.gridEnabled ? .infinity : settings.snapThreshold
        guard threshold > 0 else { return 0 }
        return snapDelta(edges, lines, threshold: threshold)
    }

    // Vertical lines a window spanning [top, top + height] can snap to.
    private func snapLinesX(top: CGFloat, height: CGFloat, _ point: CGPoint) -> [CGFloat] {
        if settings.gridEnabled {
            let area = currentGridArea(point)
            return divide(area.minX, area.width, settings.gridColumns)
        }

        var lines = workAreas.flatMap { [$0.minX, $0.maxX] }
        if settings.snapToWindows {
            let t = settings.snapThreshold
            for r in otherRects where r.minY - t < top + height && r.maxY + t > top {
                lines += [r.minX, r.maxX]
            }
        }
        return lines
    }

    // Horizontal lines a window spanning [left, left + width] can snap to.
    private func snapLinesY(left: CGFloat, width: CGFloat, _ point: CGPoint) -> [CGFloat] {
        if settings.gridEnabled {
            let area = currentGridArea(point)
            return divide(area.minY, area.height, settings.gridRows)
        }

        var lines = workAreas.flatMap { [$0.minY, $0.maxY] }
        if settings.snapToWindows {
            let t = settings.snapThreshold
            for r in otherRects where r.minX - t < left + width && r.maxX + t > left {
                lines += [r.minY, r.maxY]
            }
        }
        return lines
    }

    // The grid follows the screen under the pointer.
    private func currentGridArea(_ point: CGPoint) -> CGRect {
        let area = NSScreen.containing(point)?.globalVisibleFrame ?? workAreas.first ?? .zero
        if settings.showGrid {
            overlays.showGrid(over: area, columns: settings.gridColumns, rows: settings.gridRows)
        }
        return area
    }
}
