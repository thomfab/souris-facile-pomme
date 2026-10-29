import CoreGraphics
import Foundation

// A direction on screen, in global display coordinates (y going down).
enum Direction: Equatable {
    case left, right, up, down

    // The main direction of a movement.
    init(dx: CGFloat, dy: CGFloat) {
        if abs(dx) >= abs(dy) {
            self = dx > 0 ? .right : .left
        } else {
            self = dy > 0 ? .down : .up
        }
    }

    init?(arrowKeyCode: Int64) {
        switch arrowKeyCode {
        case 123: self = .left
        case 124: self = .right
        case 125: self = .down
        case 126: self = .up
        default: return nil
        }
    }

    var vector: CGPoint {
        switch self {
        case .left: return CGPoint(x: -1, y: 0)
        case .right: return CGPoint(x: 1, y: 0)
        case .up: return CGPoint(x: 0, y: -1)
        case .down: return CGPoint(x: 0, y: 1)
        }
    }
}

// The phases of a trackpad or Magic Mouse scroll (CGScrollPhase values).
enum ScrollPhase {
    static let began: Int64 = 1
    static let ended: Int64 = 4
    static let cancelled: Int64 = 8
    static let mayBegin: Int64 = 128
}

// Turns a swipe, a stream of small scroll events from a trackpad or a Magic
// Mouse, into a single direction once the fingers have travelled far enough.
struct SwipeTracker {
    static let distance: CGFloat = 60
    // Events further apart than this belong to separate swipes, for devices
    // that don't report phases.
    static let pause: TimeInterval = 0.3

    private var dx: CGFloat = 0
    private var dy: CGFloat = 0
    private var fired = false
    private var lastTime: TimeInterval = -.infinity

    // `dx` and `dy` follow the fingers. Returns a direction at most once per swipe.
    mutating func feed(phase: Int64, momentum: Bool, dx: CGFloat, dy: CGFloat,
                       time: TimeInterval) -> Direction? {
        // The inertia after the fingers lift isn't part of the swipe.
        if momentum { return nil }
        if phase == ScrollPhase.ended || phase == ScrollPhase.cancelled {
            reset()
            return nil
        }
        if phase == ScrollPhase.began || phase == ScrollPhase.mayBegin || time - lastTime > Self.pause {
            reset()
        }
        lastTime = time

        guard !fired else { return nil }
        self.dx += dx
        self.dy += dy
        guard hypot(self.dx, self.dy) >= Self.distance else { return nil }
        fired = true
        return Direction(dx: self.dx, dy: self.dy)
    }

    mutating func reset() {
        dx = 0
        dy = 0
        fired = false
        lastTime = -.infinity
    }
}
