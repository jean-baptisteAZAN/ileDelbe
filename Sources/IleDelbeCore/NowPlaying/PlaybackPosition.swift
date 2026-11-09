import Foundation

extension NowPlayingInfo {
    /// Interpolated playback position at `now`; nil if elapsed or timestamp is unknown.
    public func position(at now: Date) -> TimeInterval? {
        guard let elapsed, let timestamp else { return nil }
        let advance = isPlaying ? max(0, now.timeIntervalSince(timestamp)) * playbackRate : 0
        return min(max(0, elapsed + advance), duration ?? .infinity)
    }

    public var canSeek: Bool { duration != nil }
}
