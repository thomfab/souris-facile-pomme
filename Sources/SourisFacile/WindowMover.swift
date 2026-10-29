import AppKit

private let minWidth: CGFloat = 100
private let minHeight: CGFloat = 60

// Moves or resizes the window under the pointer while modifier keys are held.
final class WindowMover {
    private enum Op {
        case none, move, resize
    }

    private enum SendTarget {
        case toward(Direction)
        // The next (1) or previous (-1) display.
        case cycle(Int)
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
    // Whether the resize keys are held with the free resize keys.
    private var ignoreGrid = false
    private var lastFrame = CGRect.null
    // The window's app, to remember where its windows were on each display.
    private var app: String?
    private var resizable = false
    // The frame when the operation began, until the window is dragged to
    // another display, when it's remembered as its frame on the first one.
    private var beginFrame: CGRect?
    // The display under the pointer while moving.
    private var moveDisplay: String?
    private var workAreas: [CGRect] = []
    private var otherRects: [CGRect] = []
    private let overlays = Overlays()
    private var updatePending = false
    private var swipe = SwipeTracker()
    private var lastWheelSend = Date.distantPast
    // Arrow keys whose key down was swallowed, so their key up is too.
    private var swallowedKeys: Set<Int64> = []

    // Called by the event tap for every event it sees. Returns true to
    // swallow the event, so the app under the pointer doesn't get it.
    func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        switch type {
        case .scrollWheel:
            return handleScroll(event)
        case .keyDown, .keyUp:
            return handleKey(type, event)
        default:
            scheduleUpdate()
            return false
        }
    }

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
        let action = settings.enabled
            ? settings.action(for: CGEventSource.flagsState(.combinedSessionState))
            : .none
        let newOp: Op
        switch action {
        case .none: newOp = .none
        case .move: newOp = .move
        case .resize, .freeResize: newOp = .resize
        }
        // Switching between them keeps the resize going.
        ignoreGrid = action == .freeResize

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

    private func beginOperation(_ newOp: Op, at point: CGPoint, window: ManagedWindow? = nil) {
        guard let window = window ?? ManagedWindow.at(point),
              newOp == .move ? window.canMove : window.canResize,
              let rect = window.frame, rect.width > 0, rect.height > 0
        else { return }

        op = newOp
        self.window = window
        start = point
        startRect = rect
        lastFrame = rect
        app = bundleID(of: window)
        resizable = window.canResize
        beginFrame = rect
        moveDisplay = NSScreen.containing(point)?.displayUUID
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

        if settings.dimWindows && currentGrid(point) != nil, let windowID {
            overlays.showDimmer(below: windowID)
        }
    }

    private func endOperation() {
        if op != .none, let window, lastFrame != beginFrame, let frame = window.frame {
            remember(frame, of: app)
        }
        op = .none
        window = nil
        app = nil
        beginFrame = nil
        moveDisplay = nil
        workAreas = []
        otherRects = []
        overlays.hideAll()
    }

    private func updateMove(_ point: CGPoint) {
        guard let window else { return }
        enterDisplay(at: point)
        let size = startRect.size
        var x = (point.x - grabRatio.x * size.width).rounded()
        var y = (point.y - grabRatio.y * size.height).rounded()

        let grid = currentGrid(point)
        x += snap([x, x + size.width], snapLinesX(top: y, height: size.height, grid), grid)
        y += snap([y, y + size.height], snapLinesY(left: x, width: size.width, grid), grid)

        let frame = CGRect(origin: CGPoint(x: x, y: y), size: size)
        guard frame != lastFrame else { return }
        let resized = frame.size != lastFrame.size
        lastFrame = frame
        if !(resized ? window.setFrame(frame) : window.setOrigin(frame.origin)) {
            endOperation()
        }
    }

    // When a drag crosses onto another display, takes the size its app's
    // windows last had there, keeping the pointer at the same spot in it.
    private func enterDisplay(at point: CGPoint) {
        guard let screen = NSScreen.containing(point), let display = screen.displayUUID,
              display != moveDisplay
        else { return }
        moveDisplay = display
        if let beginFrame {
            remember(beginFrame, of: app)
            self.beginFrame = nil
        }
        if resizable, let remembered = remembered(app, on: screen) {
            startRect.size = remembered.restored(in: screen.globalVisibleFrame, keepSize: false).size
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

        let grid = ignoreGrid ? nil : currentGrid(point)
        if ignoreGrid {
            overlays.hideGrid()
        }
        let linesX = snapLinesX(top: top, height: bottom - top, grid)
        if resizeDirX > 0 {
            right += snap([right], linesX, grid)
        } else {
            left += snap([left], linesX, grid)
        }

        let linesY = snapLinesY(left: left, width: right - left, grid)
        if resizeDirY > 0 {
            bottom += snap([bottom], linesY, grid)
        } else {
            top += snap([top], linesY, grid)
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

    // MARK: Sending to another display

    private func holdsMoveKeys(_ event: CGEvent) -> Bool {
        if op == .none {
            settings = Settings.load()
        }
        return settings.enabled && !settings.moveFlags.isEmpty
            && event.flags.intersection(Modifier.relevantFlags) == settings.moveFlags
    }

    private func handleScroll(_ event: CGEvent) -> Bool {
        guard holdsMoveKeys(event), settings.sendWithScroll else {
            swipe.reset()
            return false
        }
        // Undo natural scrolling, so the deltas follow the fingers or the
        // wheel: x going right, y going down.
        let inverted = NSEvent(cgEvent: event)?.isDirectionInvertedFromDevice ?? false
        let sign: CGFloat = inverted ? 1 : -1
        let dx = sign * event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)
        let dy = sign * event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)

        if event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0 {
            // A trackpad or Magic Mouse swipe goes toward a display.
            let direction = swipe.feed(
                phase: event.getIntegerValueField(.scrollWheelEventScrollPhase),
                momentum: event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0,
                dx: dx, dy: dy,
                time: ProcessInfo.processInfo.systemUptime
            )
            if let direction {
                sendLater(.toward(direction))
            }
        } else if dx != 0 || dy != 0, Date().timeIntervalSince(lastWheelSend) > 0.25 {
            // A wheel notch goes to the next or previous display. A fast
            // spin sends a burst of events: only the first one counts.
            lastWheelSend = Date()
            let forward = abs(dy) >= abs(dx) ? dy > 0 : dx > 0
            sendLater(.cycle(forward ? 1 : -1))
        }
        return true
    }

    private func handleKey(_ type: CGEventType, _ event: CGEvent) -> Bool {
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        if type == .keyUp {
            return swallowedKeys.remove(code) != nil
        }
        guard let direction = Direction(arrowKeyCode: code),
              holdsMoveKeys(event), settings.sendWithArrows
        else { return false }
        swallowedKeys.insert(code)
        // Holding the key down doesn't keep sending.
        if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
            sendLater(.toward(direction))
        }
        return true
    }

    // Out of the event tap, which must answer quickly.
    private func sendLater(_ target: SendTarget) {
        DispatchQueue.main.async { [self] in
            send(target)
        }
    }

    // Sends the window under the pointer (or the one being moved) to another
    // display, at the same relative place and size, and the pointer with it.
    private func send(_ target: SendTarget) {
        let point = CGEvent(source: nil)?.location ?? .zero
        let moving = op == .move
        guard let window = moving ? self.window : ManagedWindow.at(point),
              window.canMove, let frame = window.frame, frame.width > 0, frame.height > 0
        else { return }

        let screens = NSScreen.screens
        let source = NSScreen.containing(CGPoint(x: frame.midX, y: frame.midY))
        guard let source, let from = screens.firstIndex(of: source) else { return }
        let frames = screens.map(\.globalFrame)
        let to: Int?
        switch target {
        case .toward(let direction): to = display(toward: direction, from: from, among: frames)
        case .cycle(let step): to = display(after: from, by: step, among: frames)
        }
        guard let to else { return }

        let area = screens[to].globalVisibleFrame
        let resizable = window.canResize
        let app = bundleID(of: window)
        remember(frame, of: app)
        // Where its app's windows last were on that display, or the same
        // relative place and size as here.
        var newFrame = remembered(app, on: screens[to])?.restored(in: area, keepSize: !resizable)
            ?? transfer(frame, from: source.globalVisibleFrame, to: area, keepSize: !resizable)
        let grid = settings.grid(forDisplay: screens[to].displayUUID)
        if grid.enabled && resizable {
            newFrame = fitToGrid(newFrame, area: area, columns: grid.columns, rows: grid.rows)
        }

        endOperation()
        if resizable {
            guard window.setFrame(newFrame) else { return }
            // Some apps adjust the size to the display they land on: insist once.
            if window.frame != newFrame {
                _ = window.setFrame(newFrame)
            }
        } else {
            guard window.setOrigin(newFrame.origin) else { return }
        }

        // The pointer follows, at the same spot in the window.
        let landed = window.frame ?? newFrame
        let ratioX = min(max((point.x - frame.minX) / frame.width, 0), 1)
        let ratioY = min(max((point.y - frame.minY) / frame.height, 0), 1)
        let newPoint = CGPoint(x: (landed.minX + ratioX * landed.width).rounded(),
                               y: (landed.minY + ratioY * landed.height).rounded())
        CGWarpMouseCursorPosition(newPoint)
        // Otherwise the pointer stays stuck for a moment after a warp.
        CGAssociateMouseAndMouseCursorPosition(1)

        // Carry on moving it from there, even if other windows cover that spot.
        if moving {
            beginOperation(.move, at: newPoint, window: window)
        }
    }

    // MARK: Remembering frames per display

    private func bundleID(of window: ManagedWindow) -> String? {
        NSRunningApplication(processIdentifier: window.pid)?.bundleIdentifier
    }

    // Records `frame` as where the app's windows last were on the display
    // that holds most of it (the one under its center).
    private func remember(_ frame: CGRect, of app: String?) {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        guard settings.rememberFrames, let app,
              let screen = NSScreen.screens.first(where: { $0.globalFrame.contains(center) }),
              let display = screen.displayUUID
        else { return }
        var memory = WindowMemory.load()
        memory.remember(frame, area: screen.globalVisibleFrame, app: app, display: display)
        memory.save()
    }

    private func remembered(_ app: String?, on screen: NSScreen) -> RememberedFrame? {
        guard settings.rememberFrames, let app, let display = screen.displayUUID else { return nil }
        return WindowMemory.load().frame(app: app, display: display)
    }

    // MARK: Snapping

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

    private func snap(_ edges: [CGFloat], _ lines: [CGFloat], _ grid: Grid?) -> CGFloat {
        // The grid always snaps; edge snapping only within the threshold.
        let threshold = grid != nil ? .infinity : settings.snapThreshold
        guard threshold > 0 else { return 0 }
        return snapDelta(edges, lines, threshold: threshold)
    }

    // Vertical lines a window spanning [top, top + height] can snap to.
    private func snapLinesX(top: CGFloat, height: CGFloat, _ grid: Grid?) -> [CGFloat] {
        if let grid {
            return divide(grid.area.minX, grid.area.width, grid.columns)
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
    private func snapLinesY(left: CGFloat, width: CGFloat, _ grid: Grid?) -> [CGFloat] {
        if let grid {
            return divide(grid.area.minY, grid.area.height, grid.rows)
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

    private typealias Grid = (area: CGRect, columns: Int, rows: Int)

    // The grid of the screen under the pointer, or nil if that screen has
    // none (edge snapping then applies).
    private func currentGrid(_ point: CGPoint) -> Grid? {
        let screen = NSScreen.containing(point)
        let grid = settings.grid(forDisplay: screen?.displayUUID)
        guard grid.enabled else {
            overlays.hideGrid()
            return nil
        }
        let area = screen?.globalVisibleFrame ?? workAreas.first ?? .zero
        if settings.showGrid {
            overlays.showGrid(over: area, columns: grid.columns, rows: grid.rows)
        }
        return (area, grid.columns, grid.rows)
    }
}
