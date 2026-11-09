import AppKit
import IleDelbeCore
import SwiftUI

/// Fills a window sized to `geometry.expanded`; the black shape is pinned top-center.
struct NotchRootView: View {
    let model: NotchViewModel

    private static let spring = Animation.spring(response: 0.35, dampingFraction: 0.8)

    init(model: NotchViewModel) { self.model = model }

    var body: some View {
        if let geometry = model.geometry {
            let info = model.nowPlaying.info
            let isPlaying = info?.isPlaying == true
            let size = shapeSize(geometry, isPlaying: isPlaying)
            ZStack(alignment: .top) {
                NotchShape(bottomRadius: model.isOpen ? NotchShape.openRadius : NotchShape.closedRadius)
                    .fill(Color.black)
                    .overlay(alignment: .top) {
                        content(geometry: geometry, info: info, isPlaying: isPlaying)
                    }
                    .frame(width: size.width, height: size.height)
                    .contextMenu {
                        Button("Quitter") { NSApp.terminate(nil) }
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(Self.spring, value: model.isOpen)
            .animation(Self.spring, value: isPlaying)
        }
    }

    private func shapeSize(_ g: NotchGeometry, isPlaying: Bool) -> CGSize {
        if model.isOpen { return g.expanded.size }
        return isPlaying ? g.closedActive.size : g.notch.size
    }

    @ViewBuilder
    private func content(geometry g: NotchGeometry, info: NowPlayingInfo?, isPlaying: Bool) -> some View {
        if model.isOpen {
            ExpandedPlayerView(
                info: info,
                isOpen: true,
                volume: model.volume.volume,
                isVolumeSettable: model.volume.isSettable,
                onCommand: { model.nowPlaying.send($0) },
                onVolume: { model.volume.set($0) }
            )
            // Clear the hardware notch band at the top, then pad the rest.
            .padding(.top, g.notch.height + 6)
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
            .transition(.opacity)
        } else if isPlaying {
            ClosedActivityView(artworkData: info?.artworkData, isPlaying: true)
                .frame(height: g.notch.height)
                .transition(.opacity)
        }
    }
}

#if DEBUG
private extension NowPlayingInfo {
    static func sample(playing: Bool = true, duration: TimeInterval? = 215) -> NowPlayingInfo {
        NowPlayingInfo(bundleIdentifier: "com.apple.Music", title: "Une chanson avec un titre assez long",
                       artist: "Artiste", isPlaying: playing, duration: duration,
                       elapsed: 42, timestamp: .now)
    }
}

#Preview("Closed playing") {
    ClosedActivityView(artworkData: nil, isPlaying: true)
        .frame(width: 220, height: 32)
        .background(NotchShape(bottomRadius: 10).fill(.black))
        .padding()
}

#Preview("Open playing") {
    ExpandedPlayerView(info: .sample(), isOpen: true, volume: 0.5, isVolumeSettable: true,
                       onCommand: { _ in }, onVolume: { _ in })
        .padding(20)
        .frame(width: 440, height: 170)
        .background(NotchShape(bottomRadius: 22).fill(.black))
}

#Preview("Open live stream") {
    ExpandedPlayerView(info: .sample(duration: nil), isOpen: true, volume: 0.5, isVolumeSettable: true,
                       onCommand: { _ in }, onVolume: { _ in })
        .padding(20)
        .frame(width: 440, height: 170)
        .background(NotchShape(bottomRadius: 22).fill(.black))
}

#Preview("Open nothing") {
    ExpandedPlayerView(info: nil, isOpen: true, volume: 0.5, isVolumeSettable: false,
                       onCommand: { _ in }, onVolume: { _ in })
        .frame(width: 440, height: 170)
        .background(NotchShape(bottomRadius: 22).fill(.black))
}
#endif
