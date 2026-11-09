import Testing
@testable import IleDelbeCore

@Suite struct PanelRulesTests {
    @Test func defaultTab() {
        #expect(PanelRules.defaultTab(timerRingingUnseen: true, isPlaying: true, lastUsed: .files) == .timer)
        #expect(PanelRules.defaultTab(timerRingingUnseen: false, isPlaying: true, lastUsed: .agenda) == .music)
        #expect(PanelRules.defaultTab(timerRingingUnseen: false, isPlaying: false, lastUsed: .agenda) == .agenda)
    }

    @Test func closedLayout() {
        #expect(PanelRules.closedLayout(isPlaying: true, timerActive: true, timerRinging: true) == .alert)
        #expect(PanelRules.closedLayout(isPlaying: false, timerActive: false, timerRinging: true) == .alert)
        #expect(PanelRules.closedLayout(isPlaying: true, timerActive: true, timerRinging: false) == .mediaAndBubble)
        #expect(PanelRules.closedLayout(isPlaying: true, timerActive: false, timerRinging: false) == .media)
        #expect(PanelRules.closedLayout(isPlaying: false, timerActive: true, timerRinging: false) == .timer)
        #expect(PanelRules.closedLayout(isPlaying: false, timerActive: false, timerRinging: false) == .plain)
    }
}
