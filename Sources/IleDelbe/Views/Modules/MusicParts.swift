import IleDelbeCore
import SwiftUI

/// Previous, play/pause, next. Shared by the player (pane and card) and the compact row.
struct TransportControls: View {
    var isPlaying: Bool
    var onCommand: (AdapterCommand) -> Void

    var body: some View {
        HStack(spacing: 14) {
            button("backward.fill", size: 14, help: "Précédent") { onCommand(.previous) }
            button(isPlaying ? "pause.fill" : "play.fill", size: 20, help: isPlaying ? "Pause" : "Lecture") {
                onCommand(.togglePlayPause)
            }
            button("forward.fill", size: 14, help: "Suivant") { onCommand(.next) }
        }
    }

    private func button(_ symbol: String, size: CGFloat, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(help)
    }
}

extension View {
    /// Accent glow under the artwork, scaled by the halo intensity (none without an accent).
    func artworkGlow(_ glow: Color?, haloScale: Double, radius: CGFloat = 35, y: CGFloat = 13) -> some View {
        shadow(color: glow?.opacity(min(0.8 * haloScale, 1)) ?? .clear, radius: radius, y: y)
    }
}

/// Title and artist, stacked and truncated.
struct TrackTitleView: View {
    var info: NowPlayingInfo
    var titleSize: CGFloat = 14
    var artistSize: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(info.title)
                .font(.system(size: titleSize, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
            if let artist = info.artist, !artist.isEmpty {
                Text(artist)
                    .font(.system(size: artistSize))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
