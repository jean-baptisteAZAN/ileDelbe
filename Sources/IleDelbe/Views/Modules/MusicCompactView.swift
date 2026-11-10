import IleDelbeCore
import SwiftUI

/// Île page: artwork, title, artist, progress and transport. No volume, no history (« Tout voir »).
struct MusicCompactView: View {
    var info: NowPlayingInfo?
    var glow: Color?
    var haloScale: Double = 1
    var onCommand: (AdapterCommand) -> Void

    var body: some View {
        if let info {
            HStack(spacing: 14) {
                ArtworkView(data: info.artworkData, size: 58, cornerRadius: 13)
                    .artworkGlow(glow, haloScale: haloScale, radius: 16, y: 6)
                VStack(alignment: .leading, spacing: 6) {
                    TrackTitleView(info: info, titleSize: 14, artistSize: 12.5)
                    ScrubberView(info: info, isOpen: true, fill: glow ?? .white) { onCommand(.seek(to: $0)) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                TransportControls(isPlaying: info.isPlaying, onCommand: onCommand)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ModuleEmptyText("Rien en lecture")
        }
    }
}

#if DEBUG
#Preview("Music compact, playing") {
    MusicCompactView(info: PreviewSamples.nowPlaying, glow: PreviewSamples.glow, onCommand: { _ in })
        .previewCompactRow()
}

#Preview("Music compact, nothing") {
    MusicCompactView(info: nil, glow: nil, onCommand: { _ in })
        .previewCompactRow()
}
#endif
