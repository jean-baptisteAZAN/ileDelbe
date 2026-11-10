import IleDelbeCore
import SwiftUI

/// Open panel content. Pure function of plain values + closures (services stay in NotchRootView).
struct ExpandedPlayerView: View {
    var info: NowPlayingInfo?
    var isOpen: Bool
    var volume: Float
    var isVolumeSettable: Bool
    /// Accent: artwork shadow and progress fill. nil = no shadow, white fill.
    var glow: Color? = nil
    /// Halo intensity multiplier (1 = the 0.2 look).
    var haloScale: Double = 1
    var onCommand: (AdapterCommand) -> Void
    var onVolume: (Float) -> Void

    @Environment(\.isStaticSnapshot) private var isStaticSnapshot

    var body: some View {
        if let info {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    ArtworkView(data: info.artworkData, size: 64, cornerRadius: 10)
                        .artworkGlow(glow, haloScale: haloScale)
                    TrackTitleView(info: info)
                    Spacer(minLength: 0)
                    TransportControls(isPlaying: info.isPlaying, onCommand: onCommand)
                }
                ScrubberView(info: info, isOpen: isOpen, fill: glow ?? .white) { onCommand(.seek(to: $0)) }
                volumeRow
            }
        } else {
            ModuleEmptyText("Rien en lecture")
        }
    }

    private var volumeRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.fill")
            if isStaticSnapshot {
                SnapshotSlider(fraction: Double(volume), tint: .white)
            } else {
                Slider(
                    value: Binding(get: { Double(volume) }, set: { onVolume(Float($0)) }),
                    in: 0...1
                )
                .controlSize(.mini)
                .tint(.white)
                .disabled(!isVolumeSettable)
            }
            Image(systemName: "speaker.wave.3.fill")
        }
        .font(.system(size: 10))
        .foregroundStyle(.white.opacity(0.6))
    }
}
