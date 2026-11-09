import Foundation

public struct ListeningEntry: Equatable, Codable, Sendable {
    public let title: String
    public let artist: String?
    public let startedAt: Date
    public let thumbnail: Data?

    public init(title: String, artist: String?, startedAt: Date, thumbnail: Data?) {
        self.title = title
        self.artist = artist
        self.startedAt = startedAt
        self.thumbnail = thumbnail
    }
}

public struct ListeningHistory: Equatable, Codable, Sendable {
    public static let maxEntries = 20
    /// Newest first.
    public private(set) var entries: [ListeningEntry]

    public init(entries: [ListeningEntry] = []) { self.entries = entries }

    /// Records a track when it starts playing. Same title+artist as entries[0] → no new entry.
    public mutating func record(title: String, artist: String?, thumbnail: Data?, at: Date) {
        if let first = entries.first, first.title == title, first.artist == artist { return }
        entries.insert(ListeningEntry(title: title, artist: artist, startedAt: at, thumbnail: thumbnail), at: 0)
        if entries.count > Self.maxEntries { entries.removeLast(entries.count - Self.maxEntries) }
    }

    /// Artwork often arrives after title metadata: fills entries[0].thumbnail if title+artist match and it is nil.
    public mutating func setThumbnailIfMissing(title: String, artist: String?, thumbnail: Data) {
        guard let first = entries.first, first.title == title, first.artist == artist, first.thumbnail == nil else { return }
        entries[0] = ListeningEntry(title: first.title, artist: first.artist, startedAt: first.startedAt, thumbnail: thumbnail)
    }

    /// Newest first, skipping an entry matching `current` (title+artist), at most `limit`.
    public func recent(excluding current: NowPlayingInfo?, limit: Int = 3) -> [ListeningEntry] {
        let filtered = entries.filter { e in
            guard let c = current else { return true }
            return !(e.title == c.title && e.artist == c.artist)
        }
        return Array(filtered.prefix(limit))
    }
}
