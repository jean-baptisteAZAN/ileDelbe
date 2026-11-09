import IleDelbeCore
import SwiftUI

/// Open panel content. Pure function of plain values + closures (services stay in NotchRootView).
struct ExpandedPlayerView: View {
    var info: NowPlayingInfo?
    var isOpen: Bool
    var volume: Float
    var isVolumeSettable: Bool
    var glow: Color? = nil
    var onCommand: (AdapterCommand) -> Void
    var onVolume: (Float) -> Void

    var body: some View {
        if let info {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    ArtworkView(data: info.artworkData, size: 64, cornerRadius: 10)
                        .shadow(color: glow?.opacity(0.8) ?? .clear, radius: 35, y: 13)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(info.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        if let artist = info.artist, !artist.isEmpty {
                            Text(artist)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    controls(isPlaying: info.isPlaying)
                }
                ScrubberView(info: info, isOpen: isOpen, fill: glow ?? .white) { onCommand(.seek(to: $0)) }
                volumeRow
            }
        } else {
            Text("Rien en lecture")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func controls(isPlaying: Bool) -> some View {
        HStack(spacing: 14) {
            button("backward.fill", size: 14) { onCommand(.previous) }
            button(isPlaying ? "pause.fill" : "play.fill", size: 20) { onCommand(.togglePlayPause) }
            button("forward.fill", size: 14) { onCommand(.next) }
        }
    }

    private func button(_ symbol: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var volumeRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.fill")
            Slider(
                value: Binding(get: { Double(volume) }, set: { onVolume(Float($0)) }),
                in: 0...1
            )
            .controlSize(.mini)
            .tint(.white)
            .disabled(!isVolumeSettable)
            Image(systemName: "speaker.wave.3.fill")
        }
        .font(.system(size: 10))
        .foregroundStyle(.white.opacity(0.6))
    }
}
