import Foundation

public struct CountdownTimer: Equatable, Codable, Sendable {
    public enum State: Equatable, Codable, Sendable {
        case idle
        case running(end: Date, total: TimeInterval)
        case paused(remaining: TimeInterval, total: TimeInterval)
        case ringing(since: Date)
    }

    public static let ringingAutoClear: TimeInterval = 60

    public private(set) var state: State

    public init() { state = .idle }

    public mutating func start(duration: TimeInterval, now: Date) {
        state = .running(end: now.addingTimeInterval(duration), total: duration)
    }

    public mutating func addMinute(now: Date) {
        switch state {
        case let .running(end, total):
            state = .running(end: end.addingTimeInterval(60), total: total + 60)
        case let .paused(remaining, total):
            state = .paused(remaining: remaining + 60, total: total + 60)
        default: break
        }
    }

    public mutating func pause(now: Date) {
        if case let .running(end, total) = state {
            state = .paused(remaining: max(0, end.timeIntervalSince(now)), total: total)
        }
    }

    public mutating func resume(now: Date) {
        if case let .paused(remaining, total) = state {
            state = .running(end: now.addingTimeInterval(remaining), total: total)
        }
    }

    public mutating func stop() { state = .idle }

    public mutating func acknowledge() {
        if case .ringing = state { state = .idle }
    }

    @discardableResult
    public mutating func tick(now: Date) -> Bool {
        switch state {
        case let .running(end, _) where now.timeIntervalSince(end) > Self.ringingAutoClear:
            state = .idle  // expired long ago (e.g. after sleep): no ring
            return false
        case let .running(end, _) where now >= end:
            state = .ringing(since: end)
            return true
        case let .ringing(since) where now.timeIntervalSince(since) > Self.ringingAutoClear:
            state = .idle
            return false
        default:
            return false
        }
    }

    public mutating func restoreAfterLaunch(now: Date) {
        switch state {
        case let .running(end, _) where now >= end: state = .idle
        case .ringing: state = .idle
        default: break
        }
    }

    public func remaining(at now: Date) -> TimeInterval {
        switch state {
        case let .running(end, _): return max(0, end.timeIntervalSince(now))
        case let .paused(remaining, _): return remaining
        default: return 0
        }
    }

    public func progress(at now: Date) -> Double {
        switch state {
        case let .running(_, total), let .paused(_, total):
            guard total > 0 else { return 0 }
            return min(1, max(0, remaining(at: now) / total))
        default: return 0
        }
    }

    public var isActive: Bool {
        switch state {
        case .running, .paused: return true
        default: return false
        }
    }

    public var isRinging: Bool {
        if case .ringing = state { return true }
        return false
    }
}
