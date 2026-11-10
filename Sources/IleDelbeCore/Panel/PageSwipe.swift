import CoreGraphics

public enum PageStep: Sendable { case next, previous }

/// Turns horizontal scroll events into at most one page step per gesture.
public struct PageSwipe: Sendable {
    public enum Phase: Sendable { case began, changed, ended, none }

    public static let threshold: CGFloat = 24

    private var accX: CGFloat = 0
    private var accY: CGFloat = 0
    private var locked = false

    public init() {}

    public mutating func feed(deltaX: CGFloat, deltaY: CGFloat, phase: Phase, isMomentum: Bool) -> PageStep? {
        if isMomentum { return nil }
        switch phase {
        case .began:
            reset()
            return nil
        case .ended:
            reset()
            return nil
        case .changed:
            if locked { return nil }
            accX += deltaX
            accY += deltaY
            if abs(accX) >= Self.threshold && abs(accX) > abs(accY) {
                locked = true
                return accX < 0 ? .next : .previous
            }
            return nil
        case .none:
            if abs(deltaX) >= Self.threshold && abs(deltaX) > abs(deltaY) {
                return deltaX < 0 ? .next : .previous
            }
            return nil
        }
    }

    private mutating func reset() { accX = 0; accY = 0; locked = false }
}
