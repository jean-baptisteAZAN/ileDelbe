import Foundation

public struct NowPlayingInfo: Equatable, Sendable {
    public var bundleIdentifier: String
    public var title: String
    public var artist: String?
    public var album: String?
    public var isPlaying: Bool
    /// Seconds; nil if absent or <= 0.
    public var duration: TimeInterval?
    /// Seconds at `timestamp`.
    public var elapsed: TimeInterval?
    public var timestamp: Date?
    public var playbackRate: Double
    public var artworkData: Data?

    public init(
        bundleIdentifier: String,
        title: String,
        artist: String? = nil,
        album: String? = nil,
        isPlaying: Bool,
        duration: TimeInterval? = nil,
        elapsed: TimeInterval? = nil,
        timestamp: Date? = nil,
        playbackRate: Double = 1.0,
        artworkData: Data? = nil
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.title = title
        self.artist = artist
        self.album = album
        self.isPlaying = isPlaying
        self.duration = duration
        self.elapsed = elapsed
        self.timestamp = timestamp
        self.playbackRate = playbackRate
        self.artworkData = artworkData
    }
}
