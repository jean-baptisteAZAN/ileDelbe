import AppKit
import IleDelbeCore
import Observation
import os

/// One `NotchWindowController` per selected screen (`ScreenSelection`), kept in sync with the
/// connected screens and the « Écrans » setting. Controllers whose screen stays are reused.
@MainActor
final class ScreenCoordinator {
    private let model: NotchViewModel
    private let settings: SettingsStore
    private let log = Logger(subsystem: "io.github.ileDelbe", category: "screens")
    private var controllers: [String: NotchWindowController] = [:]
    private var screenObserver: NSObjectProtocol?
    /// The last seen « Écrans » selection: rebuild on a settings change only when it differs.
    private var lastSelection: (mode: ScreenMode, chosenID: String?)?

    init(model: NotchViewModel, settings: SettingsStore) {
        self.model = model
        self.settings = settings
        rebuild(fromScreenChange: false)
        observeSelection()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuild(fromScreenChange: true) }
        }
    }

    /// Closes the open panel, if any (gear / « Réglages… »).
    func closeAll() {
        for controller in controllers.values { controller.closeNow() }
    }

    /// Re-arms itself: the screen mode or the chosen screen changed.
    private func observeSelection() {
        _ = withObservationTracking {
            (settings.settings.screenMode, settings.settings.chosenScreenID)
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.observeSelection()
                let s = self.settings.settings
                if let last = self.lastSelection, last.mode == s.screenMode, last.chosenID == s.chosenScreenID {
                    return  // another setting changed (or the same value was written back)
                }
                self.rebuild(fromScreenChange: false)
            }
        }
    }

    /// `fromScreenChange`: the screen parameters changed (wake, KVM, reconnect): every kept
    /// controller re-frames and re-orders its panel even when its geometry is unchanged.
    private func rebuild(fromScreenChange: Bool) {
        let screens = ScreenProvider.current()
        let s = settings.settings
        lastSelection = (s.screenMode, s.chosenScreenID)
        let targets = ScreenSelection.targets(screens.map(\.info), mode: s.screenMode, chosenID: s.chosenScreenID)
        let wanted = Set(targets)

        for (id, controller) in controllers where !wanted.contains(id) {
            controller.tearDown()
            controllers[id] = nil
            log.info("notch removed from \(id, privacy: .private)")
        }
        // Its screen left (or is no longer selected): nothing is open anymore.
        if let open = model.openScreenID, !wanted.contains(open) {
            model.panelDidClose(on: open)
        }

        for id in targets {
            guard let entry = screens.first(where: { $0.info.id == id }) else { continue }
            let geometry = ScreenProvider.geometry(for: entry.screen)
            if let controller = controllers[id] {
                controller.update(geometry: geometry, fromScreenChange: fromScreenChange)
            } else {
                controllers[id] = NotchWindowController(model: model, screenID: id, geometry: geometry)
                log.info("""
                    notch on \(entry.info.name, privacy: .private) (\(id, privacy: .private)) \
                    screen \(NSStringFromRect(entry.screen.frame), privacy: .public)
                    """)
            }
        }
        log.info("""
            screens=\(screens.count, privacy: .public) mode=\(s.screenMode.rawValue, privacy: .public) \
            notches=\(self.controllers.count, privacy: .public)
            """)
    }
}
