import AppKit
import IleDelbeCore
import SwiftUI
import UniformTypeIdentifiers

/// Hidden CLI mode used to regenerate the README images:
///
///     IleDelbe --render-readme-assets docs/assets
///
/// Renders the real SwiftUI views with fictional sample data on a fake desktop + menu bar,
/// writes PNGs (scale 2) and returns a process exit code. Never touches the user's media,
/// calendars or files.
@MainActor
enum ReadmeAssets {
    static let flag = "--render-readme-assets"

    /// Returns the output directory if the flag is present (default `docs/assets`).
    static func outputDirectory(in arguments: [String]) -> URL? {
        guard let i = arguments.firstIndex(of: flag) else { return nil }
        let path = i + 1 < arguments.count ? arguments[i + 1] : "docs/assets"
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    static func render(to directory: URL) -> Int32 {
        _ = NSApplication.shared  // fonts and SF Symbols resolve through AppKit
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let s = Sample()
            let small = CGSize(width: 900, height: 120)
            let panel = CGSize(width: 900, height: 330)
            let jobs: [(String, CGSize, Scene.Mode)] = [
                ("closed-playing", small, .closed(.media)),
                ("closed-bubble", small, .closed(.mediaAndBubble)),
                ("open-music", panel, .open(.music)),
                ("open-timer", panel, .open(.timer)),
                ("open-agenda", panel, .open(.agenda)),
                ("open-files", panel, .open(.files)),
                ("hero", CGSize(width: 1200, height: 360), .open(.music)),
            ]
            for (name, size, mode) in jobs {
                let url = directory.appendingPathComponent("\(name).png")
                try write(Scene(mode: mode, canvas: size, sample: s), size: size, to: url)
                print("wrote \(url.path)")
            }
            return 0
        } catch {
            FileHandle.standardError.write(Data("render-readme-assets: \(error)\n".utf8))
            return 1
        }
    }

    private struct RenderError: Error, CustomStringConvertible {
        var description: String
    }

    private static func write(_ view: some View, size: CGSize, to url: URL) throws {
        let renderer = ImageRenderer(content: view
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .dark)
            .environment(\.isStaticSnapshot, true))
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(size)
        guard let cg = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
        else { throw RenderError(description: "could not render \(url.lastPathComponent)") }
        try png.write(to: url)
    }
}

// MARK: - Sample data (fictional)

@MainActor
private struct Sample {
    /// Fake screen: notch 185 x 32 pt, centered.
    static let notchSize = CGSize(width: 185, height: 32)

    let now: Date
    let info: NowPlayingInfo
    let glow: Color?
    let history: [ListeningEntry]
    let timer: CountdownTimer
    let events: [AgendaEvent]
    let infoLine: String?
    let home = URL(fileURLWithPath: "/Users/demo")
    let files: [RecentFile]

    init() {
        var parts = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        parts.hour = 9
        parts.minute = 48
        let now = Calendar.current.date(from: parts) ?? Date()
        self.now = now

        let art = Self.artwork(top: NSColor(red: 0.98, green: 0.45, blue: 0.38, alpha: 1),
                               bottom: NSColor(red: 0.42, green: 0.16, blue: 0.52, alpha: 1),
                               sun: NSColor(red: 1, green: 0.86, blue: 0.55, alpha: 1))
        // ScrubberView interpolates against the real clock, so the timestamp is "now" for real.
        info = NowPlayingInfo(bundleIdentifier: "com.apple.Music", title: "Marée basse",
                              artist: "Les Rochers Blancs", album: "Grandes marées", isPlaying: true,
                              duration: 214, elapsed: 83, timestamp: Date(), artworkData: art)
        glow = HaloService.computeGlow(from: art)

        history = [
            ListeningEntry(title: "Vent du large", artist: "Les Rochers Blancs",
                           startedAt: now.addingTimeInterval(-6 * 60),
                           thumbnail: Self.artwork(top: .systemTeal, bottom: NSColor(red: 0.05, green: 0.2, blue: 0.4, alpha: 1), sun: nil, size: 96)),
            ListeningEntry(title: "Phare au loin", artist: "Nuit Polaire",
                           startedAt: now.addingTimeInterval(-19 * 60),
                           thumbnail: Self.artwork(top: NSColor(red: 0.2, green: 0.25, blue: 0.6, alpha: 1), bottom: .black, sun: .white, size: 96)),
            ListeningEntry(title: "Sable chaud", artist: "Duo Cabestan",
                           startedAt: now.addingTimeInterval(-34 * 60),
                           thumbnail: Self.artwork(top: .systemYellow, bottom: .systemOrange, sun: nil, size: 96)),
        ]

        var t = CountdownTimer()
        t.start(duration: 1500, now: now.addingTimeInterval(-448))  // 17:32 left
        timer = t

        let events = [
            AgendaEvent(id: "1", title: "Point d'équipe", start: now.addingTimeInterval(12 * 60),
                        end: now.addingTimeInterval(42 * 60), isAllDay: false, colorHex: "#64D2FF",
                        meetingURL: URL(string: "https://meet.google.com/abc-defg-hij")),
            AgendaEvent(id: "2", title: "Déjeuner au port", start: now.addingTimeInterval(162 * 60),
                        end: now.addingTimeInterval(222 * 60), isAllDay: false, colorHex: "#30D158",
                        meetingURL: nil),
        ]
        self.events = events
        infoLine = Agenda.infoLine(events, now: now)

        files = [
            RecentFile(url: home.appendingPathComponent("Documents/Rapport.pdf"),
                       lastUsed: now.addingTimeInterval(-4 * 60), isDirectory: false),
            RecentFile(url: home.appendingPathComponent("Desktop/Capture.png"),
                       lastUsed: now.addingTimeInterval(-50 * 60), isDirectory: false),
            RecentFile(url: home.appendingPathComponent("Downloads/Idées.txt"),
                       lastUsed: now.addingTimeInterval(-3 * 3600), isDirectory: false),
        ]
    }

    func icon(_ file: RecentFile) -> NSImage {
        NSWorkspace.shared.icon(for: UTType(filenameExtension: file.url.pathExtension) ?? .data)
    }

    func geometry(canvasWidth: CGFloat, canvasHeight: CGFloat) -> NotchGeometry? {
        let n = Self.notchSize
        let screen = CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)
        let left = CGRect(x: 0, y: canvasHeight - n.height, width: (canvasWidth - n.width) / 2, height: n.height)
        let right = CGRect(x: (canvasWidth + n.width) / 2, y: canvasHeight - n.height,
                           width: (canvasWidth - n.width) / 2, height: n.height)
        return NotchGeometry.make(screenFrame: screen, safeAreaTop: n.height,
                                  auxiliaryTopLeft: left, auxiliaryTopRight: right)
    }

    /// Sunset-over-the-sea cover drawn in code: gradient sky, sun disc, wave bands.
    static func artwork(top: NSColor, bottom: NSColor, sun: NSColor?, size: CGFloat = 600) -> Data {
        let px = Int(size)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: rep)
        else { return Data() }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        NSGradient(starting: bottom, ending: top)?.draw(in: rect, angle: 90)
        if let sun {
            let d = size * 0.34
            sun.setFill()
            NSBezierPath(ovalIn: NSRect(x: (size - d) / 2, y: size * 0.42, width: d, height: d)).fill()
        }
        for i in 0..<4 {
            let y = size * (0.42 - CGFloat(i) * 0.1)
            let wave = NSBezierPath()
            wave.move(to: NSPoint(x: 0, y: y))
            let step = size / 4
            for k in 0..<4 {
                let x0 = CGFloat(k) * step
                wave.curve(to: NSPoint(x: x0 + step, y: y),
                           controlPoint1: NSPoint(x: x0 + step * 0.3, y: y + size * 0.035),
                           controlPoint2: NSPoint(x: x0 + step * 0.7, y: y - size * 0.035))
            }
            wave.line(to: NSPoint(x: size, y: 0))
            wave.line(to: NSPoint(x: 0, y: 0))
            wave.close()
            bottom.blended(withFraction: 0.25 * CGFloat(i), of: .black)?.withAlphaComponent(0.55).setFill()
            wave.fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:]) ?? Data()
    }
}

// MARK: - Scene

/// Fake desktop + menu bar with the notch composed like `NotchRootView`, from plain values.
@MainActor
private struct Scene: View {
    enum Mode { case closed(ClosedLayout), open(PanelTab) }

    var mode: Mode
    var canvas: CGSize
    var sample: Sample

    var body: some View {
        ZStack(alignment: .top) {
            desktop
            menuBar
            if let g = sample.geometry(canvasWidth: canvas.width, canvasHeight: canvas.height) {
                notch(g)
            }
        }
        .frame(width: canvas.width, height: canvas.height)
        .clipped()
    }

    /// Vertical-only gradient: every row is uniform, which keeps the PNGs small.
    private var desktop: some View {
        LinearGradient(colors: [Color(red: 0.07, green: 0.08, blue: 0.2),
                                Color(red: 0.2, green: 0.1, blue: 0.3),
                                Color(red: 0.42, green: 0.2, blue: 0.32)],
                       startPoint: .top, endPoint: .bottom)
    }

    private var menuBar: some View {
        HStack(spacing: 18) {
            Text("Éditeur").fontWeight(.bold)
            Text("Fichier")
            Spacer()
            Image(systemName: "wifi")
            Image(systemName: "battery.75percent")
            Text("lun. 09:48")
        }
        .font(.system(size: 13))
        .foregroundStyle(.white.opacity(0.92))
        .padding(.horizontal, 18)
        .frame(height: Sample.notchSize.height)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.28))
    }

    private var state: (isOpen: Bool, layout: ClosedLayout) {
        switch mode {
        case .open: (true, .mediaAndBubble)
        case let .closed(layout): (false, layout)
        }
    }

    @ViewBuilder
    private func notch(_ g: NotchGeometry) -> some View {
        let (isOpen, layout) = state
        let size: CGSize = isOpen ? g.expanded.size
            : layout == .plain ? g.notch.size
            : layout == .alert ? g.closedAlert.size : g.closedActive.size
        let shape = NotchShape(bottomRadius: isOpen ? NotchShape.openRadius : NotchShape.closedRadius)
        let style = isOpen ? HaloStyle.open : HaloStyle.closed
        ZStack(alignment: .top) {
            shape.fill(Color.black)
                .frame(width: size.width, height: size.height)
                .shadow(color: sample.glow?.opacity(style.opacity) ?? .clear, radius: style.radius, y: style.y)
            shape.fill(Color.black)
                .overlay(alignment: .top) { content(g, isOpen: isOpen, layout: layout) }
                .frame(width: size.width, height: size.height)
                .clipShape(shape)
            if !isOpen && layout == .mediaAndBubble {
                BubbleView(timer: sample.timer, now: sample.now)
                    .offset(x: g.bubble.midX - g.expanded.midX)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func content(_ g: NotchGeometry, isOpen: Bool, layout: ClosedLayout) -> some View {
        if case let .open(tab) = mode {
            VStack(alignment: .leading, spacing: 12) {
                TabBarView(selected: tab, timerActive: sample.timer.isActive, infoLine: sample.infoLine,
                           onSelect: { _ in })
                pane(tab)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(.top, g.notch.height + 6)
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        } else {
            ClosedActivityView(layout: layout, artworkData: sample.info.artworkData, isPlaying: true,
                               timer: sample.timer, now: sample.now, glow: sample.glow)
                .frame(height: g.notch.height)
        }
    }

    @ViewBuilder
    private func pane(_ tab: PanelTab) -> some View {
        switch tab {
        case .music:
            MusicPaneView(info: sample.info, history: sample.history, glow: sample.glow, volume: 0.6,
                          isVolumeSettable: true, onCommand: { _ in }, onVolume: { _ in })
        case .timer:
            TimerPaneView(timer: sample.timer, now: sample.now, onStart: { _ in }, onAddMinute: {},
                          onPause: {}, onResume: {}, onStop: {}, onAcknowledge: {})
        case .agenda:
            AgendaPaneView(access: .granted, events: sample.events, now: sample.now, onAppear: {},
                           onJoin: { _ in }, onOpenSettings: {})
        case .files:
            FilesPaneView(files: sample.files, home: sample.home, icon: { sample.icon($0) }, now: sample.now,
                          onOpen: { _ in }, onDragStart: {})
        }
    }
}
