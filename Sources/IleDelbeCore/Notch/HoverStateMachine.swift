import Foundation

/// Debounced hover open/close logic. Call `update` on every mouse move and at `nextDeadline`.
public struct HoverStateMachine: Sendable {
    public static let closeDelay: TimeInterval = 0.30

    public private(set) var isOpen: Bool = false
    public var openDelay: TimeInterval
    private var pendingSince: TimeInterval?
    /// Set by `forceClose`: ignore the trigger until the pointer has been seen outside once.
    private var needsExit = false

    public init(openDelay: TimeInterval = 0.15) { self.openDelay = openDelay }

    /// Closes immediately; reopening requires the pointer to leave the trigger first.
    public mutating func forceClose() {
        isOpen = false
        pendingSince = nil
        needsExit = true
    }

    /// `inTrigger`: pointer inside notch rect when closed, inside expanded rect when open.
    public mutating func update(inTrigger: Bool, now: TimeInterval) {
        if needsExit {
            if inTrigger { pendingSince = nil; return }
            needsExit = false
        }
        // Closed: pending means "inside, waiting to open". Open: pending means "outside, waiting to close".
        let wantsChange = isOpen ? !inTrigger : inTrigger
        guard wantsChange else {
            pendingSince = nil
            return
        }
        let since = pendingSince ?? now
        pendingSince = since
        let delay = isOpen ? Self.closeDelay : openDelay
        if now - since >= delay {
            isOpen.toggle()
            pendingSince = nil
        }
    }

    /// Next time `update` must be called even without mouse movement, nil if none.
    public var nextDeadline: TimeInterval? {
        guard let since = pendingSince else { return nil }
        return since + (isOpen ? Self.closeDelay : openDelay)
    }
}
