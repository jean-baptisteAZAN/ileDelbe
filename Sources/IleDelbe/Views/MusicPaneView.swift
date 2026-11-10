import AppKit
import IleDelbeCore
import SwiftUI

/// Music tab: v1 player on the left, "Écoutés récemment" column (190 pt) on the right.
struct MusicPaneView: View {
    var info: NowPlayingInfo?
    var history: [ListeningEntry]
    var glow: Color?
    var haloScale: Double = 1
    var volume: Float
    var isVolumeSettable: Bool
    var onCommand: (AdapterCommand) -> Void
    var onVolume: (Float) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            ExpandedPlayerView(info: info, isOpen: true, volume: volume, isVolumeSettable: isVolumeSettable,
                               glow: glow, haloScale: haloScale, onCommand: onCommand, onVolume: onVolume)
                .frame(maxWidth: .infinity)
            historyColumn
                .frame(width: 190, alignment: .leading)
        }
    }

    private var historyColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            ModuleLabel("Écoutés récemment")
            ForEach(Array(history.prefix(3).enumerated()), id: \.offset) { _, entry in
                HStack(spacing: 8) {
                    ArtworkView(data: entry.thumbnail, size: 28, cornerRadius: 6)
                    Text(entry.title)
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(ClockText.string(from: entry.startedAt))
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 14)
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1)
        }
    }
}

#if DEBUG
#Preview("Music, no glow") {
    MusicPaneView(info: PreviewSamples.nowPlaying, history: PreviewSamples.history, glow: nil, volume: 0.5,
                  isVolumeSettable: true, onCommand: { _ in }, onVolume: { _ in })
        .previewPanel(width: 548, height: 190)
}

#Preview("Music, glow") {
    MusicPaneView(info: PreviewSamples.nowPlaying, history: PreviewSamples.history, glow: PreviewSamples.glow,
                  volume: 0.5, isVolumeSettable: true, onCommand: { _ in }, onVolume: { _ in })
        .previewPanel(width: 548, height: 190)
}
#endif
