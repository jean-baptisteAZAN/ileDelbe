import AppKit
import IleDelbeCore
import Observation
import os

/// Records played tracks into a persisted `ListeningHistory`, observing `NowPlayingService.info` without polling.
@MainActor @Observable
final class HistoryService {
    private(set) var history: ListeningHistory

    @ObservationIgnored private let nowPlaying: NowPlayingService
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let log = Logger(subsystem: "io.github.ileDelbe", category: "history")
    private static let key = "history.v1"

    init(nowPlaying: NowPlayingService, defaults: UserDefaults = .standard) {
        self.nowPlaying = nowPlaying
        self.defaults = defaults
        var restored = ListeningHistory()
        if let data = defaults.data(forKey: Self.key) {
            do { restored = try JSONDecoder().decode(ListeningHistory.self, from: data) }
            catch { log.error("history decode failed, resetting: \(error.localizedDescription)") }
        }
        history = restored
        observe()
    }

    private func observe() {
        let info = withObservationTracking {
            nowPlaying.info
        } onChange: { [weak self] in
            Task { @MainActor in self?.observe() }
        }
        handle(info)
    }

    private func handle(_ info: NowPlayingInfo?) {
        guard let info, info.isPlaying else { return }
        let before = history
        let first = history.entries.first
        let isCurrent = first?.title == info.title && first?.artist == info.artist
        // Decode/encode artwork only when a record would insert, or the current entry lacks a thumbnail.
        guard !isCurrent || first?.thumbnail == nil else { return }
        let thumbnail = info.artworkData.flatMap(Self.thumbnail(from:))
        history.record(title: info.title, artist: info.artist, thumbnail: thumbnail, at: Date())
        if let thumbnail {
            history.setThumbnailIfMissing(title: info.title, artist: info.artist, thumbnail: thumbnail)
        }
        if history != before { persist() }
    }

    private func persist() {
        do { defaults.set(try JSONEncoder().encode(history), forKey: Self.key) }
        catch { log.error("history encode failed: \(error.localizedDescription)") }
    }

    /// Scales artwork to 56x56 and encodes it as PNG.
    private static func thumbnail(from data: Data) -> Data? {
        guard let image = NSImage(data: data),
              let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: 56, pixelsHigh: 56, bitsPerSample: 8,
                samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        ctx.imageInterpolation = .high
        image.draw(in: NSRect(x: 0, y: 0, width: 56, height: 56), from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }
}
