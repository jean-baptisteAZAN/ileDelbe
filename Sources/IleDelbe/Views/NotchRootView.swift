import AppKit
import IleDelbeCore
import SwiftUI

/// Halo shadow parameters, shared with the window controller so the window is large enough
/// for the open glow tail (the window edge would otherwise cut it).
enum HaloStyle {
    static let closed = (radius: CGFloat(11), y: CGFloat(0), opacity: 0.9)
    static let open = (radius: CGFloat(35), y: CGFloat(13), opacity: 0.8)
    /// Transparent window margin around `expanded`: the blur reaches ~radius beyond the shape,
    /// shifted down by `y`.
    static let windowMargin = (horizontal: open.radius, bottom: open.radius + open.y)
}

/// Fills the panel window (`expanded` plus a transparent glow margin); everything is pinned top-center.
struct NotchRootView: View {
    let model: NotchViewModel

    private static let spring = Animation.spring(response: 0.35, dampingFraction: 0.8)

    init(model: NotchViewModel) { self.model = model }

    var body: some View {
        if let geometry = model.geometry {
            let layout = model.closedLayout
            let isOpen = model.isOpen
            let size = shapeSize(geometry, layout: layout)
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
                shape
                    .fill(Color.black)
                    .overlay(alignment: .top) {
                        content(geometry: geometry, layout: layout)
                    }
                    .frame(width: size.width, height: size.height)
                    // Keep content inside the black shape while it shrinks/grows.
                    .clipShape(shape)
                    .contextMenu {
                        Button("Quitter") { NSApp.terminate(nil) }
                    }
                if !isOpen && layout == .mediaAndBubble {
                    BubbleView(timer: model.timer.timer, now: model.timer.now)
                        .offset(x: geometry.bubble.midX - geometry.expanded.midX)
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
        }
    }

    private func shapeSize(_ g: NotchGeometry, layout: ClosedLayout) -> CGSize {
        if model.isOpen { return g.expanded.size }
        switch layout {
        case .plain: return g.notch.size
        case .media, .mediaAndBubble, .timer: return g.closedActive.size
        case .alert: return g.closedAlert.size
        }
    }

    /// Closed: soft glow while media plays. Open: stronger glow under the panel while playing.
    private func haloColor(layout: ClosedLayout, isOpen: Bool) -> Color {
        guard model.isPlaying, let glow = model.halo.glow else { return .clear }
        if isOpen { return glow.opacity(HaloStyle.open.opacity) }
        return (layout == .media || layout == .mediaAndBubble) ? glow.opacity(HaloStyle.closed.opacity) : .clear
    }

    @ViewBuilder
    private func content(geometry g: NotchGeometry, layout: ClosedLayout) -> some View {
        if model.isOpen {
            VStack(alignment: .leading, spacing: 12) {
                TabBarView(selected: model.selectedTab, timerActive: model.timer.timer.isActive,
                           infoLine: model.calendar.infoLine, onSelect: { model.select($0) })
                pane(model.selectedTab)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            // Clear the hardware notch band at the top, then pad the rest.
            .padding(.top, g.notch.height + 6)
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
            .transition(.opacity)
        } else if layout != .plain {
            ClosedActivityView(layout: layout, artworkData: model.nowPlaying.info?.artworkData,
                               isPlaying: model.isPlaying, timer: model.timer.timer, now: model.timer.now,
                               glow: model.isPlaying ? model.halo.glow : nil)
                .frame(height: g.notch.height)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private func pane(_ tab: PanelTab) -> some View {
        switch tab {
        case .music:
            MusicPaneView(
                info: model.nowPlaying.info,
                history: model.history.history.recent(excluding: model.nowPlaying.info),
                glow: model.halo.glow,
                volume: model.volume.volume,
                isVolumeSettable: model.volume.isSettable,
                onCommand: { model.nowPlaying.send($0) },
                onVolume: { model.volume.set($0) })
        case .timer:
            let timer = model.timer
            TimerPaneView(
                timer: timer.timer, now: timer.now,
                onStart: { timer.start($0) }, onAddMinute: { timer.addMinute() },
                onPause: { timer.pause() }, onResume: { timer.resume() },
                onStop: { timer.stop() }, onAcknowledge: { timer.acknowledge() })
        case .agenda:
            let calendar = model.calendar
            AgendaPaneView(
                access: calendar.access, events: calendar.upcoming, now: Date(),
                onAppear: { calendar.requestAccessIfNeeded() },
                onJoin: { NSWorkspace.shared.open($0) },
                onOpenSettings: { calendar.openPrivacySettings() })
        case .files:
            let files = model.files
            FilesPaneView(
                files: files.files, home: FileManager.default.homeDirectoryForCurrentUser,
                icon: { files.icon(for: $0) }, now: Date(),
                onOpen: { files.open($0) },
                onDragStart: { model.isDraggingFile = true })
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
    ClosedActivityView(layout: .media, artworkData: nil, isPlaying: true,
                       timer: CountdownTimer(), now: .now, glow: Color(red: 0.9, green: 0.3, blue: 0.5))
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
