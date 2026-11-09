import Foundation
import IleDelbeCore
import Observation

@MainActor @Observable
final class NotchViewModel {
    var isOpen = false
    var geometry: NotchGeometry?
    /// True from the start of a file drag out of the panel until the mouse button is released.
    var isDraggingFile = false
    private(set) var selectedTab: PanelTab = .music
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

    @ObservationIgnored private let defaults: UserDefaults
    private static let lastTabKey = "panel.lastTab"

    init(nowPlaying: NowPlayingService, volume: VolumeService, timer: TimerService, history: HistoryService,
         halo: HaloService, calendar: CalendarService, files: RecentFilesService, defaults: UserDefaults = .standard) {
        self.nowPlaying = nowPlaying
        self.volume = volume
        self.timer = timer
        self.history = history
        self.halo = halo
        self.calendar = calendar
        self.files = files
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

    var closedLayout: ClosedLayout {
        PanelRules.closedLayout(isPlaying: isPlaying, timerActive: timer.timer.isActive,
                                timerRinging: timer.timer.isRinging)
    }

    /// Called by the window controller just before the panel opens.
    func panelWillOpen(fromBubble: Bool) {
        // An alert that auto-cleared (60 s) no longer forces the Minuteur tab.
        let unseen = timer.ringingUnseen && timer.timer.isRinging
        selectedTab = fromBubble ? .timer
            : PanelRules.defaultTab(timerRingingUnseen: unseen, isPlaying: isPlaying, lastUsed: lastUsedTab)
        markTimerSeenIfShown()
    }

    /// Called by the window controller just after the panel closed. An alert that was shown
    /// in the open panel counts as acknowledged (hover = seen), so the closed notch does not
    /// go back to the orange alert.
    func panelDidClose() {
        if timer.timer.isRinging && !timer.ringingUnseen { timer.acknowledge() }
    }

    func select(_ tab: PanelTab) {
        selectedTab = tab
        lastUsedTab = tab
        markTimerSeenIfShown()
    }

    /// Clears `ringingUnseen` when the Minuteur tab is (about to be) on screen. Callers: panel
    /// opening, tab selection, and `observeRinging` when the timer rings while shown.
    func markTimerSeenIfShown() {
        if selectedTab == .timer, timer.ringingUnseen {
            timer.ringingUnseen = false
        }
    }
}
