import AppKit
import IleDelbeCore
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = Logger(subsystem: "io.github.ileDelbe", category: "app")
    private var nowPlaying: NowPlayingService?
    private var controller: NotchWindowController?
    private var signalSources: [DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        terminateOnSignals()

        let paths = AdapterPaths.inBundle(.main)
        if paths == nil {
            log.error("mediaremote-adapter not found in bundle; now playing disabled")
        }
        let nowPlaying = NowPlayingService(paths: paths)
        nowPlaying.start()
        self.nowPlaying = nowPlaying

        let model = NotchViewModel(
            nowPlaying: nowPlaying,
            volume: VolumeService(),
            timer: TimerService(),
            history: HistoryService(nowPlaying: nowPlaying),
            halo: HaloService(nowPlaying: nowPlaying),
            calendar: CalendarService(),
            files: RecentFilesService())
        controller = NotchWindowController(model: model)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // deinit does not run at exit; terminate the adapter explicitly so it is not orphaned.
        nowPlaying?.stop()
    }

    /// SIGTERM/SIGINT (`pkill`, Ctrl-C) would kill the process without `applicationWillTerminate`,
    /// orphaning the adapter; route them through a normal termination instead.
    private func terminateOnSignals() {
        for sig in [SIGTERM, SIGINT] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { MainActor.assumeIsolated { NSApp.terminate(nil) } }
            source.resume()
            signalSources.append(source)
        }
    }
}
