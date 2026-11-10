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

    init(model: NotchViewModel, settings: SettingsStore) {
        self.model = model
        self.settings = settings
        rebuild()
        observeSelection()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuild() }
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
                self?.observeSelection()
                self?.rebuild()
            }
        }
    }

    private func rebuild() {
        let screens = ScreenProvider.current()
        let s = settings.settings
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
                controller.update(geometry: geometry)
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
