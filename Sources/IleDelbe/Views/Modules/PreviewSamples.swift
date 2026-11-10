#if DEBUG
import AppKit
import IleDelbeCore
import SwiftUI
import UniformTypeIdentifiers

/// Sample data for the `#Preview` blocks of the panes and the module views.
@MainActor
enum PreviewSamples {
    static let glow = Color(red: 0.9, green: 0.3, blue: 0.5)

    static var nowPlaying: NowPlayingInfo {
        NowPlayingInfo(bundleIdentifier: "com.apple.Music", title: "Une chanson", artist: "Artiste",
                       isPlaying: true, duration: 215, elapsed: 42, timestamp: .now)
    }

    static var history: [ListeningEntry] {
        [
            ListeningEntry(title: "Premier titre", artist: "A", startedAt: .now.addingTimeInterval(-600), thumbnail: nil),
            ListeningEntry(title: "Deuxième titre un peu long", artist: "B", startedAt: .now.addingTimeInterval(-3000),
                           thumbnail: nil),
            ListeningEntry(title: "Troisième", artist: nil, startedAt: .now.addingTimeInterval(-7000), thumbnail: nil),
        ]
    }

    static var idleTimer: CountdownTimer { CountdownTimer() }

    /// Started 10 min ago at `now`, 200 s elapsed at `runningNow`.
    static let timerStart = Date.now
    static var runningTimer: CountdownTimer {
        var t = CountdownTimer()
        t.start(duration: 600, now: timerStart)
        return t
    }
    static var runningNow: Date { timerStart.addingTimeInterval(200) }

    static var pausedTimer: CountdownTimer {
        var t = runningTimer
        t.pause(now: runningNow)
        return t
    }

    static var ringingTimer: CountdownTimer {
        var t = CountdownTimer()
        t.start(duration: 60, now: timerStart)
        _ = t.tick(now: ringingNow)
        return t
    }
    static var ringingNow: Date { timerStart.addingTimeInterval(61) }

    static var events: [AgendaEvent] {
        [
            AgendaEvent(id: "1", title: "Standup équipe", start: .now.addingTimeInterval(720),
                        end: .now.addingTimeInterval(2520), isAllDay: false, colorHex: "#64D2FF",
                        meetingURL: URL(string: "https://meet.example.com/x")),
            AgendaEvent(id: "2", title: "Déjeuner", start: .now.addingTimeInterval(9000),
                        end: .now.addingTimeInterval(12600), isAllDay: false, colorHex: "#30D158", meetingURL: nil),
        ]
    }

    static let home = URL(fileURLWithPath: "/Users/demo")

    static var files: [RecentFile] {
        [
            ("Desktop/Capture.png", -300.0),
            ("Documents/Devis client 2026.pdf", -7200),
            ("Downloads/notes.txt", -90000),
            ("Documents/Budget.numbers", -100_000),
            ("Desktop/Maquette.sketch", -200_000),
        ].map { path, age in
            RecentFile(url: home.appendingPathComponent(path), lastUsed: .now.addingTimeInterval(age), isDirectory: false)
        }
    }

    static func icon(_ file: RecentFile) -> NSImage {
        NSWorkspace.shared.icon(for: UTType(filenameExtension: file.url.pathExtension) ?? .data)
    }

    /// A module at the Île size, with sample data (style previews).
    @ViewBuilder
    static func compactPage(_ module: PanelTab, timer: CountdownTimer = runningTimer,
                            now: Date = runningNow) -> some View {
        switch module {
        case .music:
            MusicCompactView(info: nowPlaying, glow: glow, onCommand: { _ in })
        case .timer:
            TimerCompactView(timer: timer, now: now, onStart: { _ in }, onAddMinute: {}, onPause: {}, onResume: {},
                             onStop: {}, onAcknowledge: {})
        case .agenda:
            AgendaCompactView(access: .granted, events: events, now: .now, onAppear: {}, onJoin: { _ in },
                              onOpenSettings: {})
        case .files:
            FilesCompactView(files: files, count: 5, icon: { icon($0) }, now: .now, onOpen: { _ in },
                             onDragStart: {})
        }
    }

    /// A module at the Grille size, with sample data (style previews).
    @ViewBuilder
    static func card(_ module: PanelTab) -> some View {
        switch module {
        case .music:
            MusicCardView(info: nowPlaying, history: history, glow: glow, volume: 0.6, isVolumeSettable: true,
                          onCommand: { _ in }, onVolume: { _ in })
        case .timer:
            TimerCardView(timer: runningTimer, now: runningNow, onStart: { _ in }, onAddMinute: {}, onPause: {},
                          onResume: {}, onStop: {}, onAcknowledge: {})
        case .agenda:
            AgendaCardView(access: .granted, events: events, now: .now, onAppear: {}, onJoin: { _ in },
                           onOpenSettings: {})
        case .files:
            FilesCardView(files: files, count: 5, icon: { icon($0) }, onOpen: { _ in }, onDragStart: {})
        }
    }
}

extension View {
    /// Black backdrop at a fixed size, like the open panel.
    func previewPanel(width: CGFloat, height: CGFloat, padding: CGFloat = 18) -> some View {
        self.padding(padding).frame(width: width, height: height).background(Color.black)
    }

    /// An Île page: a 428 × 70 row in the 460 pt panel.
    func previewCompactRow() -> some View {
        self.frame(width: 428, height: 70).previewPanel(width: 460, height: 102, padding: 16)
    }

    /// A Grille card at a given size.
    func previewCard(width: CGFloat, height: CGFloat) -> some View {
        self.frame(width: width, height: height).previewPanel(width: width + 20, height: height + 20, padding: 10)
    }
}
#endif
