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

    private static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

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
            Text("Écoutés récemment")
                .font(.system(size: 10.5, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(.secondary)
            ForEach(Array(history.prefix(3).enumerated()), id: \.offset) { _, entry in
                HStack(spacing: 8) {
                    ArtworkView(data: entry.thumbnail, size: 28, cornerRadius: 6)
                    Text(entry.title)
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(Self.time.string(from: entry.startedAt))
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
private extension NowPlayingInfo {
    static var previewSample: NowPlayingInfo {
        NowPlayingInfo(bundleIdentifier: "com.apple.Music", title: "Une chanson", artist: "Artiste",
                       isPlaying: true, duration: 215, elapsed: 42, timestamp: .now)
    }
}

private let previewHistory = [
    ListeningEntry(title: "Premier titre", artist: "A", startedAt: .now.addingTimeInterval(-600), thumbnail: nil),
    ListeningEntry(title: "Deuxième titre un peu long", artist: "B", startedAt: .now.addingTimeInterval(-3000), thumbnail: nil),
    ListeningEntry(title: "Troisième", artist: nil, startedAt: .now.addingTimeInterval(-7000), thumbnail: nil),
]

#Preview("Music, no glow") {
    MusicPaneView(info: .previewSample, history: previewHistory, glow: nil, volume: 0.5,
                  isVolumeSettable: true, onCommand: { _ in }, onVolume: { _ in })
        .padding(18).frame(width: 548, height: 190).background(Color.black)
}

#Preview("Music, glow") {
    MusicPaneView(info: .previewSample, history: previewHistory, glow: Color(red: 0.9, green: 0.3, blue: 0.5),
                  volume: 0.5, isVolumeSettable: true, onCommand: { _ in }, onVolume: { _ in })
        .padding(18).frame(width: 548, height: 190).background(Color.black)
}
#endif
