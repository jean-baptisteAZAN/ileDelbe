public enum PanelTab: String, CaseIterable, Codable, Sendable { case music, timer, agenda, files }

public enum ClosedLayout: Equatable, Sendable { case plain, media, timer, mediaAndBubble, alert }

public enum PanelRules {
    public static func defaultTab(timerRingingUnseen: Bool, isPlaying: Bool, lastUsed: PanelTab,
                                  forced: PanelTab?, available: [PanelTab]) -> PanelTab? {
        if timerRingingUnseen, available.contains(.timer) { return .timer }
        if let forced, available.contains(forced) { return forced }
        if isPlaying, available.contains(.music) { return .music }
        if available.contains(lastUsed) { return lastUsed }
        return available.first
    }

    /// Visible modules in order; a hidden timer is shown while it rings.
    public static func effectiveModules(_ entries: [ModuleEntry], timerRinging: Bool) -> [PanelTab] {
        entries.filter { $0.visible || ($0.module == .timer && timerRinging) }.map(\.module)
    }

    /// alert if ringing; mediaAndBubble if playing && timerActive; media if playing; timer if timerActive; else plain
    public static func closedLayout(isPlaying: Bool, timerActive: Bool, timerRinging: Bool) -> ClosedLayout {
        if timerRinging { return .alert }
        if isPlaying && timerActive { return .mediaAndBubble }
        if isPlaying { return .media }
        if timerActive { return .timer }
        return .plain
    }
}
