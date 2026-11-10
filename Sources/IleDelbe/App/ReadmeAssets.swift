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
            let jobs: [(String, CGSize, Scene.Mode)] = [
                ("closed-playing", small, .closed(.media)),
                ("closed-bubble", small, .closed(.mediaAndBubble)),
                ("style-island", CGSize(width: 900, height: 200), .panel(.island)),
                ("style-grid", CGSize(width: 900, height: 380), .panel(.grid)),
                ("style-tabs", CGSize(width: 900, height: 300), .panel(.tabs)),
                ("hero", CGSize(width: 1200, height: 260), .panel(.island)),
            ]
            for (name, size, mode) in jobs {
                let url = directory.appendingPathComponent("\(name).png")
                try write(Scene(mode: mode, canvas: size, sample: s), size: size, to: url)
                print("wrote \(url.path)")
            }
            let external = directory.appendingPathComponent("external-screen.png")
            try write(ExternalScreenScene(sample: s), size: ExternalScreenScene.size, to: external)
            print("wrote \(external.path)")
            let settings = directory.appendingPathComponent("settings.png")
            try write(SettingsSnapshot(), size: SettingsSnapshot.size, to: settings)
            print("wrote \(settings.path)")
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
    enum Mode { case closed(ClosedLayout), panel(PanelStyle) }

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
        case .panel: (true, .mediaAndBubble)
        case let .closed(layout): (false, layout)
        }
    }

    @ViewBuilder
    private func notch(_ g: NotchGeometry) -> some View {
        let (isOpen, layout) = state
        let size: CGSize = isOpen ? g.openRect(size: panelSize(g)).size
            : layout == .plain ? g.notch.size
            : layout == .alert ? g.closedRect(.alert).size : g.closedRect(.standard).size
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
                BubbleView(timer: sample.timer, now: sample.now, height: g.notch.height)
                    .offset(x: g.bubbleRect(after: g.closedRect(.standard)).midX - g.openRect(size: panelSize(g)).midX)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func content(_ g: NotchGeometry, isOpen: Bool, layout: ClosedLayout) -> some View {
        if case let .panel(style) = mode {
            panelContent(style)
                .frame(width: panelSize(g).width, height: panelSize(g).height - g.notch.height)
                .padding(.top, g.notch.height)
        } else {
            ClosedActivityView(layout: layout, wings: PanelRules.closedWings(layout, closedStyle: .artworkEqualizer),
                               artworkData: sample.info.artworkData, isPlaying: true,
                               timer: sample.timer, now: sample.now, glow: sample.glow)
                .frame(height: g.notch.height)
        }
    }

    private var panelStyle: PanelStyle {
        if case let .panel(style) = mode { style } else { .island }
    }

    private func panelSize(_ g: NotchGeometry) -> CGSize {
        PanelSizing.size(style: panelStyle, showsAll: false, modules: PanelTab.allCases,
                         density: .normal, notchHeight: g.notch.height)
    }

    @ViewBuilder
    private func panelContent(_ style: PanelStyle) -> some View {
        switch style {
        case .island:
            IslandStyleView(modules: PanelTab.allCases, selected: .music, onSelect: { _ in },
                            onShowAll: {}, onSettings: {}) { module in
                compact(module)
            }
        case .grid:
            GridStyleView(modules: PanelTab.allCases, onShowPages: nil, onSettings: {}) { module in
                card(module)
            }
        case .tabs:
            VStack(alignment: .leading, spacing: 12) {
                TabBarView(tabs: PanelTab.allCases, selected: .music, timerActive: sample.timer.isActive,
                           infoLine: sample.infoLine, onSelect: { _ in }, onSettings: {})
                MusicPaneView(info: sample.info, history: sample.history, glow: sample.glow, volume: 0.6,
                              isVolumeSettable: true, onCommand: { _ in }, onVolume: { _ in })
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(.top, 6)
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
    }

    @ViewBuilder
    private func compact(_ module: PanelTab) -> some View {
        switch module {
        case .music:
            MusicCompactView(info: sample.info, glow: sample.glow, onCommand: { _ in })
        case .timer:
            TimerCompactView(timer: sample.timer, now: sample.now, onStart: { _ in }, onAddMinute: {},
                             onPause: {}, onResume: {}, onStop: {}, onAcknowledge: {})
        case .agenda:
            AgendaCompactView(access: .granted, events: sample.events, now: sample.now, onAppear: {},
                              onJoin: { _ in }, onOpenSettings: {})
        case .files:
            FilesCompactView(files: sample.files, icon: { sample.icon($0) }, now: sample.now,
                             onOpen: { _ in }, onDragStart: {})
        }
    }

    @ViewBuilder
    private func card(_ module: PanelTab) -> some View {
        switch module {
        case .music:
            MusicCardView(info: sample.info, history: sample.history, glow: sample.glow, volume: 0.6,
                          isVolumeSettable: true, onCommand: { _ in }, onVolume: { _ in })
        case .timer:
            TimerCardView(timer: sample.timer, now: sample.now, onStart: { _ in }, onAddMinute: {},
                          onPause: {}, onResume: {}, onStop: {}, onAcknowledge: {})
        case .agenda:
            AgendaCardView(access: .granted, events: sample.events, now: sample.now, onAppear: {},
                           onJoin: { _ in }, onOpenSettings: {})
        case .files:
            FilesCardView(files: sample.files, icon: { sample.icon($0) }, onOpen: { _ in }, onDragStart: {})
        }
    }
}

// MARK: - External screen

/// Wide external-screen menu bar with the virtual notch, in two stacked states: the thin idle bar,
/// then the media pill. Shapes come from `ClosedDrawing` on a `NotchGeometry.virtual`, like the app.
@MainActor
private struct ExternalScreenScene: View {
    static let size = CGSize(width: 900, height: 120)
    static let menuBarHeight: CGFloat = 24
    let sample: Sample

    var body: some View {
        VStack(spacing: 0) {
            strip(wings: .none, layout: .plain)
            strip(wings: PanelRules.closedWings(.media, closedStyle: .artworkEqualizer), layout: .media)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(LinearGradient(colors: [Color(red: 0.07, green: 0.08, blue: 0.2),
                                            Color(red: 0.42, green: 0.2, blue: 0.32)],
                                   startPoint: .top, endPoint: .bottom))
    }

    private func strip(wings: ClosedWings, layout: ClosedLayout) -> some View {
        let frame = CGRect(x: 0, y: 0, width: Self.size.width, height: Self.size.height / 2)
        let g = NotchGeometry.virtual(screenFrame: frame, menuBarHeight: Self.menuBarHeight)
        let d = ClosedDrawing(geometry: g, wings: wings)
        let shape = NotchShape(bottomRadius: d.radius)
        return ZStack(alignment: .top) {
            HStack(spacing: 16) {
                Text("Éditeur").fontWeight(.bold)
                Text("Fichier")
                Spacer()
                Image(systemName: "wifi")
                Text("lun. 09:48")
            }
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 16)
            .frame(height: Self.menuBarHeight)
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.28))
            shape.fill(Color.black)
                .overlay(alignment: .top) {
                    if layout != .plain {
                        ClosedActivityView(layout: layout, wings: wings, artworkData: sample.info.artworkData,
                                           isPlaying: true, timer: sample.timer, now: sample.now, glow: sample.glow)
                            .frame(height: g.notch.height)
                    }
                }
                .frame(width: d.size.width, height: d.size.height)
                .clipShape(shape)
                .offset(x: d.offsetX)
        }
        .frame(width: Self.size.width, height: Self.size.height / 2, alignment: .top)
    }
}

// MARK: - Settings window

/// Static look-alike of `SettingsView` with the default settings. `ImageRenderer` cannot draw the
/// AppKit-backed Form, pickers, toggles and sliders (the real view renders blank), so this redraws
/// the same rows with the same French labels, in the dark grouped style.
@MainActor
private struct SettingsSnapshot: View {
    static let size = CGSize(width: 520, height: 690)
    private let s = AppSettings.default
    private let blue = Color(red: 0.04, green: 0.52, blue: 1)

    var body: some View {
        VStack(spacing: 14) {
            header("Écrans")
            group {
                row("Afficher l'encoche sur") { menu("Écran intégré") }
            }
            group {
                segmented("Style", ["Île", "Grille", "Onglets"], selected: s.style == .island ? 0 : 1)
                segmented("Couleur", ["Pochette", "Fixe", "Aucune"], selected: 0)
                row("Intensité du halo") { slider(s.haloIntensity, text: "\(Int((s.haloIntensity * 100).rounded())) %") }
            }
            header("Modules")
            group {
                ForEach(s.modules, id: \.module) { entry in
                    row(entry.module.title, leading: AnyView(toggle(entry.visible))) {
                        HStack(spacing: 14) {
                            Image(systemName: "chevron.up"); Image(systemName: "chevron.down")
                        }.foregroundStyle(.secondary)
                    }
                }
                row("À l'ouverture") { menu("Automatique") }
            }
            group {
                row("Encoche fermée pendant la lecture") { menu("Pochette + égaliseur") }
                row("Animer l'encoche fermée", leading: nil) { toggle(s.animateClosed) }
                row("Délai d'ouverture au survol") { slider((s.openDelay - 0.05) / 0.55, text: SettingsView.delayText(s.openDelay)) }
            }
            group {
                row("Durées du minuteur") {
                    HStack(spacing: 10) {
                        ForEach(0..<3, id: \.self) { Text("\(s.timerPresetsMinutes[$0]) min").monospacedDigit() }
                    }
                }
                segmented("Taille du panneau", ["Normale", "Compacte"], selected: 0)
                segmented("Fichiers récents", ["3", "5"], selected: 0)
            }
            group { row("Lancer à l'ouverture de session") { toggle(false) } }
            Spacer(minLength: 0)
        }
        .font(.system(size: 13))
        .foregroundStyle(.white)
        .padding(20)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .top)
        .background(Color(red: 0.16, green: 0.16, blue: 0.17))
    }

    private func header(_ t: String) -> some View {
        Text(t).font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 10).padding(.bottom, -8)
    }

    private func group<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        VStack(spacing: 0) { c() }
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.07)))
    }

    private func row<T: View>(_ title: String, leading: AnyView? = nil, @ViewBuilder _ trailing: () -> T) -> some View {
        HStack(spacing: 10) {
            if let leading { leading }
            Text(title)
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 12).frame(height: 34)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1).padding(.leading, 12) }
    }

    private func segmented(_ title: String, _ items: [String], selected: Int) -> some View {
        row(title) {
            HStack(spacing: 0) {
                ForEach(items.indices, id: \.self) { i in
                    Text(items[i]).padding(.horizontal, 12).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 5).fill(i == selected ? Color.white.opacity(0.22) : .clear))
                }
            }
            .padding(2).background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.08)))
        }
    }

    private func menu(_ t: String) -> some View {
        HStack(spacing: 6) { Text(t); Image(systemName: "chevron.up.chevron.down").font(.system(size: 10)) }
            .padding(.horizontal, 10).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.1)))
    }

    private func toggle(_ on: Bool) -> some View {
        Capsule().fill(on ? blue : Color.white.opacity(0.2)).frame(width: 36, height: 21)
            .overlay(alignment: on ? .trailing : .leading) { Circle().fill(.white).padding(2) }
    }

    private func slider(_ f: Double, text: String) -> some View {
        HStack {
            SnapshotSlider(fraction: f, tint: blue).frame(width: 160)
            Text(text).monospacedDigit().frame(width: 48, alignment: .trailing)
        }
    }
}
