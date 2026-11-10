import AppKit
import IleDelbeCore
import SwiftUI

/// Halo shadow parameters, shared with the window controller so the window is large enough
/// for the open glow tail (the window edge would otherwise cut it).
enum HaloStyle {
    static let closed = (radius: CGFloat(11), y: CGFloat(0), opacity: 0.9)
    static let open = (radius: CGFloat(35), y: CGFloat(13), opacity: 0.8)
    /// Transparent window margin around the largest open panel: the blur reaches ~radius beyond the shape,
    /// shifted down by `y`.
    static let windowMargin = (horizontal: open.radius, bottom: open.radius + open.y)
}

/// Fills the panel window (the largest open panel or closed pill, plus a transparent glow
/// margin); everything is pinned top-center, so the shape is sized from the model, never the window.
struct NotchRootView: View {
    let model: NotchViewModel

    private static let spring = Animation.spring(response: 0.35, dampingFraction: 0.8)

    init(model: NotchViewModel) { self.model = model }

    var body: some View {
        if let geometry = model.geometry {
            let layout = model.closedLayout
            let wings = model.closedWings
            let isOpen = model.isOpen
            let size = isOpen ? model.panelSize : geometry.closedRect(wings).size
            // Asymmetric wings (title mode): shift the closed pill so it is drawn exactly on
            // `closedRect(wings)`, the hover rect, with the hardware notch staying in place.
            // Animates with the size under the same spring.
            let offsetX = isOpen ? 0 : geometry.closedOffsetX(wings)
            let shape = NotchShape(bottomRadius: isOpen ? NotchShape.openRadius : NotchShape.closedRadius)
            ZStack(alignment: .top) {
                // Halo: an un-clipped copy of the shape carries the shadow, so the `.clipShape`
                // below (needed for the open/close animation) cannot cut it.
                shape
                    .fill(Color.black)
                    .frame(width: size.width, height: size.height)
                    .shadow(color: haloColor(layout: layout, isOpen: isOpen),
                            radius: isOpen ? HaloStyle.open.radius : HaloStyle.closed.radius,
                            y: isOpen ? HaloStyle.open.y : HaloStyle.closed.y)
                    .offset(x: offsetX)
                shape
                    .fill(Color.black)
                    .overlay(alignment: .top) {
                        content(geometry: geometry, layout: layout)
                    }
                    .frame(width: size.width, height: size.height)
                    // Keep content inside the black shape while it shrinks/grows.
                    .clipShape(shape)
                    .offset(x: offsetX)
                    .contextMenu {
                        Button("Réglages…") { model.onOpenSettings?() }
                        Button("Quitter") { NSApp.terminate(nil) }
                    }
                if !isOpen && layout == .mediaAndBubble {
                    BubbleView(timer: model.timer.timer, now: model.timer.now)
                        // Content is centered on the notch: offset from its center.
                        .offset(x: geometry.bubbleRect(after: geometry.closedRect(wings)).midX - geometry.notch.midX)
                        .transition(.scale(scale: 0.6, anchor: .leading)
                            .combined(with: .offset(x: -30))
                            .combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // Always black: `.secondary` text must resolve for a dark background, even in light mode.
            .environment(\.colorScheme, .dark)
            .animation(Self.spring, value: isOpen)
            .animation(Self.spring, value: layout)
            .animation(Self.spring, value: wings)
            .animation(Self.spring, value: size)
        }
    }

    /// Closed: soft glow while media plays. Open: stronger glow under the panel while playing.
    /// No halo without an accent, or with the Musique module hidden.
    private func haloColor(layout: ClosedLayout, isOpen: Bool) -> Color {
        guard model.isPlaying, model.settings.settings.visibleModules.contains(.music),
              let accent = model.accent else { return .clear }
        let scale = model.haloOpacityScale
        if isOpen { return accent.opacity(min(HaloStyle.open.opacity * scale, 1)) }
        return (layout == .media || layout == .mediaAndBubble)
            ? accent.opacity(min(HaloStyle.closed.opacity * scale, 1)) : .clear
    }

    /// « titre · artiste » (just the title when the artist is unknown).
    static func titleLine(_ title: String, _ artist: String?) -> String {
        guard let artist, !artist.isEmpty else { return title }
        return "\(title) · \(artist)"
    }

    @ViewBuilder
    private func content(geometry g: NotchGeometry, layout: ClosedLayout) -> some View {
        if model.isOpen {
            // Laid out at the Normale size below the hardware notch band, then scaled for
            // Compacte: the band itself never shrinks (`PanelSizing`).
            let base = model.unscaledPanelSize
            PanelContentView(model: model)
                .frame(width: base.width, height: base.height - g.notch.height)
                .scaleEffect(model.contentScale, anchor: .top)
                .padding(.top, g.notch.height)
                .transition(.opacity)
        } else if layout != .plain {
            ClosedActivityView(layout: layout, wings: model.closedWings,
                               artworkData: model.nowPlaying.info?.artworkData,
                               isPlaying: model.isPlaying, timer: model.timer.timer, now: model.timer.now,
                               glow: model.isPlaying ? model.accent : nil, haloScale: model.haloOpacityScale,
                               title: model.nowPlaying.info.map { Self.titleLine($0.title, $0.artist) } ?? "",
                               showsTitle: model.settings.settings.closedStyle == .title,
                               motion: model.closedMotion)
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
    ClosedActivityView(layout: .media, wings: .standard, artworkData: nil, isPlaying: true,
                       timer: CountdownTimer(), now: .now, glow: Color(red: 0.9, green: 0.3, blue: 0.5))
        .frame(width: 220, height: 32)
        .background(NotchShape(bottomRadius: 10).fill(.black))
        .padding()
}

#Preview("Closed title, short") {
    ClosedActivityView(layout: .media, wings: .title, artworkData: nil, isPlaying: true,
                       timer: CountdownTimer(), now: .now, glow: nil,
                       title: "Short · Artist", showsTitle: true)
        .frame(width: 36 + 190 + 120, height: 32)
        .background(NotchShape(bottomRadius: 10).fill(.black))
        .padding()
}

#Preview("Closed title, long") {
    ClosedActivityView(layout: .media, wings: .title, artworkData: nil, isPlaying: true,
                       timer: CountdownTimer(), now: .now, glow: nil,
                       title: "Une chanson avec un titre vraiment très long · Un artiste", showsTitle: true)
        .frame(width: 36 + 190 + 120, height: 32)
        .background(NotchShape(bottomRadius: 10).fill(.black))
        .padding()
}

#Preview("Closed none") {
    ClosedActivityView(layout: .plain, wings: .none, artworkData: nil, isPlaying: true,
                       timer: CountdownTimer(), now: .now, glow: nil)
        .frame(width: 190, height: 32)
        .background(NotchShape(bottomRadius: 10).fill(.black))
        .padding()
}

#Preview("Closed static equalizer") {
    ClosedActivityView(layout: .media, wings: .standard, artworkData: nil, isPlaying: true,
                       timer: CountdownTimer(), now: .now, glow: .pink, motion: false)
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
