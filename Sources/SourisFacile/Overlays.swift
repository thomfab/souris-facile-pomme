import AppKit

private let gridLineWidth: CGFloat = 2
private let gridLineColor = NSColor(white: 1, alpha: 0.35)
private let dimColor = NSColor(white: 0, alpha: 0.5)

// A borderless, click-through window on every Space.
private func makeOverlayWindow(globalFrame: CGRect) -> NSWindow {
    let window = NSWindow(contentRect: flipped(globalFrame), styleMask: .borderless,
                          backing: .buffered, defer: false)
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = false
    window.ignoresMouseEvents = true
    window.isReleasedWhenClosed = false
    window.animationBehavior = .none
    window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
    return window
}

private final class GridView: NSView {
    let columns: Int
    let rows: Int

    init(size: CGSize, columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
        super.init(frame: CGRect(origin: .zero, size: size))
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // Top-down like global coordinates, so the lines land where windows snap.
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        gridLineColor.setFill()
        let half = gridLineWidth / 2
        for x in divide(0, bounds.width, columns).dropFirst().dropLast() {
            CGRect(x: x - half, y: 0, width: gridLineWidth, height: bounds.height).fill()
        }
        for y in divide(0, bounds.height, rows).dropFirst().dropLast() {
            CGRect(x: 0, y: y - half, width: bounds.width, height: gridLineWidth).fill()
        }
    }
}

final class Overlays {
    private var grid: NSWindow?
    private var gridShown: (area: CGRect, columns: Int, rows: Int)?
    private var dimmers: [NSWindow] = []

    // Shows the grid lines over `area` (a screen's visible frame).
    func showGrid(over area: CGRect, columns: Int, rows: Int) {
        if let shown = gridShown, shown.area == area, shown.columns == columns, shown.rows == rows {
            return
        }
        hideGrid()

        let window = makeOverlayWindow(globalFrame: area)
        window.contentView = GridView(size: area.size, columns: columns, rows: rows)
        window.level = .statusBar
        window.orderFrontRegardless()
        grid = window
        gridShown = (area, columns, rows)
    }

    func hideGrid() {
        grid?.orderOut(nil)
        grid = nil
        gridShown = nil
    }

    // Darkens every screen, right below the given window so it stays bright.
    // Windows stacked above it stay bright too: macOS has no way to draw
    // between other apps' windows, so raise the window to avoid that.
    func showDimmer(below windowID: CGWindowID) {
        hideDimmer()
        dimmers = NSScreen.screens.map { screen in
            let window = makeOverlayWindow(globalFrame: screen.globalFrame)
            window.backgroundColor = dimColor
            window.level = .normal
            window.order(.below, relativeTo: Int(windowID))
            return window
        }
    }

    func hideDimmer() {
        dimmers.forEach { $0.orderOut(nil) }
        dimmers = []
    }

    func hideAll() {
        hideGrid()
        hideDimmer()
    }
}
