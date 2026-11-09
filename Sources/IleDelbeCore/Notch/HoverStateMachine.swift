import Foundation

/// Debounced hover open/close logic. Call `update` on every mouse move and at `nextDeadline`.
public struct HoverStateMachine: Sendable {
    public static let openDelay: TimeInterval = 0.15
    public static let closeDelay: TimeInterval = 0.30

    public private(set) var isOpen: Bool = false
    private var pendingSince: TimeInterval?

    public init() {}

    /// `inTrigger`: pointer inside notch rect when closed, inside expanded rect when open.
    public mutating func update(inTrigger: Bool, now: TimeInterval) {
        // Closed: pending means "inside, waiting to open". Open: pending means "outside, waiting to close".
        let wantsChange = isOpen ? !inTrigger : inTrigger
        guard wantsChange else {
            pendingSince = nil
            return
        }
        let since = pendingSince ?? now
        pendingSince = since
        let delay = isOpen ? Self.closeDelay : Self.openDelay
        if now - since >= delay {
            isOpen.toggle()
            pendingSince = nil
        }
    }

    /// Next time `update` must be called even without mouse movement, nil if none.
    public var nextDeadline: TimeInterval? {
        guard let since = pendingSince else { return nil }
        return since + (isOpen ? Self.closeDelay : Self.openDelay)
    }
}
