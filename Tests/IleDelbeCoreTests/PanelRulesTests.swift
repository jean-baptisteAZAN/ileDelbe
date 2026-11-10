import Testing
@testable import IleDelbeCore

@Suite struct PanelRulesTests {
    @Test func defaultTabRules() {
        let all: [PanelTab] = [.music, .timer, .agenda, .files]
        #expect(PanelRules.defaultTab(timerRingingUnseen: true, isPlaying: true, lastUsed: .files, forced: .agenda, available: all) == .timer)
        #expect(PanelRules.defaultTab(timerRingingUnseen: false, isPlaying: true, lastUsed: .files, forced: .agenda, available: all) == .agenda)
        #expect(PanelRules.defaultTab(timerRingingUnseen: false, isPlaying: true, lastUsed: .agenda, forced: nil, available: all) == .music)
        #expect(PanelRules.defaultTab(timerRingingUnseen: false, isPlaying: false, lastUsed: .agenda, forced: nil, available: all) == .agenda)
        #expect(PanelRules.defaultTab(timerRingingUnseen: false, isPlaying: false, lastUsed: .agenda, forced: nil, available: []) == nil)
    }

    @Test func defaultTabFallsBackWhenLastUsedHidden() {
        #expect(PanelRules.defaultTab(timerRingingUnseen: false, isPlaying: true, lastUsed: .agenda, forced: nil, available: [.files, .agenda].filter { $0 != .agenda }) == .files)
    }

    @Test func effectiveModulesAddsRingingHiddenTimer() {
        let entries = [ModuleEntry(module: .music, visible: true), ModuleEntry(module: .timer, visible: false),
                       ModuleEntry(module: .agenda, visible: true), ModuleEntry(module: .files, visible: false)]
        #expect(PanelRules.effectiveModules(entries, timerRinging: false) == [.music, .agenda])
        #expect(PanelRules.effectiveModules(entries, timerRinging: true) == [.music, .timer, .agenda])
    }

    @Test func closedLayoutBasics() {
        #expect(PanelRules.closedLayout(isPlaying: true, timerActive: true, timerRinging: true, showsMusic: true, showsTimer: true) == .alert)
        #expect(PanelRules.closedLayout(isPlaying: false, timerActive: false, timerRinging: true, showsMusic: true, showsTimer: true) == .alert)
        #expect(PanelRules.closedLayout(isPlaying: true, timerActive: true, timerRinging: false, showsMusic: true, showsTimer: true) == .mediaAndBubble)
        #expect(PanelRules.closedLayout(isPlaying: true, timerActive: false, timerRinging: false, showsMusic: true, showsTimer: true) == .media)
        #expect(PanelRules.closedLayout(isPlaying: false, timerActive: true, timerRinging: false, showsMusic: true, showsTimer: true) == .timer)
        #expect(PanelRules.closedLayout(isPlaying: false, timerActive: false, timerRinging: false, showsMusic: true, showsTimer: true) == .plain)
    }

    @Test func closedLayoutHiddenModules() {
        #expect(PanelRules.closedLayout(isPlaying: true, timerActive: true, timerRinging: false, showsMusic: false, showsTimer: true) == .timer)
        #expect(PanelRules.closedLayout(isPlaying: true, timerActive: true, timerRinging: false, showsMusic: true, showsTimer: false) == .media)
        #expect(PanelRules.closedLayout(isPlaying: true, timerActive: true, timerRinging: true, showsMusic: false, showsTimer: false) == .alert)
        #expect(PanelRules.closedLayout(isPlaying: true, timerActive: false, timerRinging: false, showsMusic: false, showsTimer: false) == .plain)
    }

    @Test func closedWings() {
        #expect(PanelRules.closedWings(.media, closedStyle: .title) == .title)
        #expect(PanelRules.closedWings(.mediaAndBubble, closedStyle: .artworkEqualizer) == .standard)
        #expect(PanelRules.closedWings(.alert, closedStyle: .title) == .alert)
        #expect(PanelRules.closedWings(.plain, closedStyle: .title) == .none)
    }
}
