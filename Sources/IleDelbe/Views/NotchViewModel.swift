import CoreGraphics
import Foundation
import IleDelbeCore
import Observation
import SwiftUI

@MainActor @Observable
final class NotchViewModel {
    var isOpen = false
    var geometry: NotchGeometry?
    /// True from the start of a file drag out of the panel until the mouse button is released.
    var isDraggingFile = false
    /// The page shown in the open panel; nil when no module is visible.
    private(set) var selectedTab: PanelTab?
    /// Île « Tout voir »: the panel shows the grid. Reset when the panel closes.
    var showsAll = false
    private(set) var lastUsedTab: PanelTab {
        didSet { defaults.set(lastUsedTab.rawValue, forKey: Self.lastTabKey) }
    }

    let nowPlaying: NowPlayingService
    let volume: VolumeService
    let timer: TimerService
    let history: HistoryService
    let halo: HaloService
    let calendar: CalendarService
    let files: RecentFilesService
    let settings: SettingsStore

    /// Set by the AppDelegate: close the panel and show the settings window.
    @ObservationIgnored var onOpenSettings: (() -> Void)?

    @ObservationIgnored private let defaults: UserDefaults
    private static let lastTabKey = "panel.lastTab"

    init(nowPlaying: NowPlayingService, volume: VolumeService, timer: TimerService, history: HistoryService,
         halo: HaloService, calendar: CalendarService, files: RecentFilesService, settings: SettingsStore,
         defaults: UserDefaults = .standard) {
        self.nowPlaying = nowPlaying
        self.volume = volume
        self.timer = timer
        self.history = history
        self.halo = halo
        self.calendar = calendar
        self.files = files
        self.settings = settings
        self.defaults = defaults
        lastUsedTab = defaults.string(forKey: Self.lastTabKey).flatMap(PanelTab.init(rawValue:)) ?? .music
        selectedTab = lastUsedTab
        observeRinging()
    }

    /// The timer rang while the open panel showed Minuteur: it has been seen. Re-arms itself.
    private func observeRinging() {
        _ = withObservationTracking {
            timer.ringingUnseen
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.observeRinging()
                if self.isOpen { self.markTimerSeenIfShown() }
            }
        }
    }

    var isPlaying: Bool { nowPlaying.info?.isPlaying == true }

    /// Pages of the open panel, in settings order. A hidden timer is included while it rings.
    var modules: [PanelTab] {
        PanelRules.effectiveModules(settings.settings.modules, timerRinging: timer.timer.isRinging)
    }

    /// The page actually on screen: `selectedTab` if it is still a page, else the first page
    /// (e.g. a hidden timer that was acknowledged while shown).
    var shownTab: PanelTab? {
        if let selectedTab, modules.contains(selectedTab) { return selectedTab }
        return modules.first
    }

    private var notchHeight: CGFloat { geometry?.notch.height ?? 32 }

    /// Size of the open panel shape in the current state.
    var panelSize: CGSize {
        let s = settings.settings
        return PanelSizing.size(style: s.style, showsAll: showsAll, modules: modules, density: s.density,
                                notchHeight: notchHeight)
    }

    /// The open panel at the Normale size: the content is laid out on it, then scaled by
    /// `contentScale` (the notch band excluded), so Compacte is the same layout, smaller.
    var unscaledPanelSize: CGSize {
        let s = settings.settings
        return PanelSizing.size(style: s.style, showsAll: showsAll, modules: modules, density: .normal,
                                notchHeight: notchHeight)
    }

    var contentScale: CGFloat { settings.settings.density == .compact ? PanelSizing.compactScale : 1 }

    /// Largest open size of the current style, density and modules: the window is framed on it
    /// so switching pages or « Tout voir » never resizes the window.
    var maxPanelSize: CGSize {
        let s = settings.settings
        return PanelSizing.maxSize(style: s.style, modules: modules, density: s.density, notchHeight: notchHeight)
    }

    var closedLayout: ClosedLayout {
        let s = settings.settings
        let visible = s.visibleModules
        // « Rien » while playing: bare notch, a running timer goes to the wings (no bubble).
        return PanelRules.closedLayout(isPlaying: isPlaying, timerActive: timer.timer.isActive,
                                       timerRinging: timer.timer.isRinging,
                                       showsMusic: visible.contains(.music) && s.closedStyle != .none,
                                       showsTimer: visible.contains(.timer))
    }

    var closedWings: ClosedWings {
        PanelRules.closedWings(closedLayout, closedStyle: settings.settings.closedStyle)
    }

    /// Accent for the halo, the progress fill and the equalizer. nil = no halo, white controls.
    var accent: Color? {
        let s = settings.settings
        switch s.accent {
        case .artwork: return halo.glow
        case .fixed: return Color(hex: s.fixedTint.hex)
        case .none: return nil
        }
    }

    /// Multiplier on the 0.2 halo opacities: the default intensity (60 %) gives the 0.2 look.
    /// Callers clamp the product to 1.
    var haloOpacityScale: Double { settings.settings.haloIntensity / 0.6 }

    /// Called by the window controller just before the panel opens.
    func panelWillOpen(fromBubble: Bool) {
        // An alert that auto-cleared (60 s) no longer forces the Minuteur tab.
        let unseen = timer.ringingUnseen && timer.timer.isRinging
        let available = modules
        selectedTab = fromBubble && available.contains(.timer) ? .timer
            : PanelRules.defaultTab(timerRingingUnseen: unseen, isPlaying: isPlaying, lastUsed: lastUsedTab,
                                     forced: settings.settings.forcedModule, available: available)
        markTimerSeenIfShown()
    }

    /// Called by the window controller just after the panel closed. An alert that was shown
    /// in the open panel counts as acknowledged (hover = seen), so the closed notch does not
    /// go back to the orange alert.
    func panelDidClose() {
        showsAll = false
        if timer.timer.isRinging && !timer.ringingUnseen { timer.acknowledge() }
    }

    func select(_ tab: PanelTab) {
        selectedTab = tab
        lastUsedTab = tab
        markTimerSeenIfShown()
    }

    /// One page forward or back among the visible modules, clamped at both ends.
    func step(_ step: PageStep) {
        guard let tab = PanelRules.step(from: shownTab, step, in: modules) else { return }
        select(tab)
    }

    func openSettings() {
        onOpenSettings?()
    }

    /// Clears `ringingUnseen` when the Minuteur tab is (about to be) on screen. Callers: panel
    /// opening, tab selection, and `observeRinging` when the timer rings while shown.
    func markTimerSeenIfShown() {
        if shownTab == .timer, timer.ringingUnseen {
            timer.ringingUnseen = false
        }
    }
}
