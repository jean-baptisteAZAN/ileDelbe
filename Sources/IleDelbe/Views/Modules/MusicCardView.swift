import IleDelbeCore
import SwiftUI

/// Grille card: the full player (artwork, title, artist, progress, transport, volume)
/// and the last 3 tracks as thumbnails in a row.
struct MusicCardView: View {
    var info: NowPlayingInfo?
    var history: [ListeningEntry]
    var glow: Color?
    var haloScale: Double = 1
    var volume: Float
    var isVolumeSettable: Bool
    var onCommand: (AdapterCommand) -> Void
    var onVolume: (Float) -> Void

    var body: some View {
        ModuleCard {
            ExpandedPlayerView(info: info, isOpen: true, volume: volume, isVolumeSettable: isVolumeSettable,
                               glow: glow, haloScale: haloScale, onCommand: onCommand, onVolume: onVolume)
                .frame(maxHeight: info == nil ? .infinity : nil)
            if !history.isEmpty {
                Spacer(minLength: 0)
                ModuleLabel("Écoutés récemment")
                HStack(spacing: 8) {
                    ForEach(Array(history.prefix(3).enumerated()), id: \.offset) { _, entry in
                        thumbnail(entry)
                    }
                }
            }
        }
    }

    private func thumbnail(_ entry: ListeningEntry) -> some View {
        HStack(spacing: 6) {
            ArtworkView(data: entry.thumbnail, size: 24, cornerRadius: 5)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.title)
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
                Text(ClockText.string(from: entry.startedAt))
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview("Music card, playing") {
    MusicCardView(info: PreviewSamples.nowPlaying, history: PreviewSamples.history, glow: PreviewSamples.glow,
                  volume: 0.6, isVolumeSettable: true, onCommand: { _ in }, onVolume: { _ in })
        .previewCard(width: 360, height: 210)
}

#Preview("Music card, nothing") {
    MusicCardView(info: nil, history: PreviewSamples.history, glow: nil, volume: 0.6, isVolumeSettable: true,
                  onCommand: { _ in }, onVolume: { _ in })
        .previewCard(width: 360, height: 210)
}
#endif
