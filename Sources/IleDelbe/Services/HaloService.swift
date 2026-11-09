import CoreImage
import CoreImage.CIFilterBuiltins
import IleDelbeCore
import Observation
import SwiftUI

/// Derives a glow color from the current artwork's average color. nil = no halo.
@MainActor @Observable
final class HaloService {
    private(set) var glow: Color?

    @ObservationIgnored private let nowPlaying: NowPlayingService
    @ObservationIgnored private var currentArtwork: Data?
    @ObservationIgnored private var cache: (hash: Int, glow: Color?)?
    @ObservationIgnored private var task: Task<Void, Never>?

    private nonisolated static let context = CIContext(options: [.workingColorSpace: NSNull()])

    init(nowPlaying: NowPlayingService) {
        self.nowPlaying = nowPlaying
        observe()
    }

    private func observe() {
        let artwork = withObservationTracking {
            nowPlaying.info?.artworkData
        } onChange: { [weak self] in
            Task { @MainActor in self?.observe() }
        }
        update(artwork)
    }

    private func update(_ artwork: Data?) {
        guard artwork != currentArtwork else { return }
        currentArtwork = artwork
        task?.cancel()
        task = nil
        guard let artwork else { glow = nil; return }
        let hash = artwork.hashValue
        if let cache, cache.hash == hash {
            glow = cache.glow
            return
        }
        glow = nil
        task = Task { [weak self] in
            let result = await Task.detached(priority: .utility) { Self.computeGlow(from: artwork) }.value
            guard let self, !Task.isCancelled, self.currentArtwork == artwork else { return } // stale
            self.cache = (hash, result)
            self.glow = result
        }
    }

    private nonisolated static func computeGlow(from data: Data) -> Color? {
        guard let image = CIImage(data: data), !image.extent.isEmpty, !image.extent.isInfinite else { return nil }
        let filter = CIFilter.areaAverage()
        filter.inputImage = image
        filter.extent = image.extent
        guard let output = filter.outputImage else { return nil }
        var px = [UInt8](repeating: 0, count: 4)
        context.render(output, toBitmap: &px, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        // `RGBColor` is ambiguous with a CoreServices type here, so rely on inference.
        return HaloColor.glow(fromAverage: .init(r: Double(px[0]) / 255, g: Double(px[1]) / 255, b: Double(px[2]) / 255))
            .map { Color(red: $0.r, green: $0.g, blue: $0.b) }
    }
}
