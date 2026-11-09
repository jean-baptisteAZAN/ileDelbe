public enum PanelTab: String, CaseIterable, Codable, Sendable { case music, timer, agenda, files }

public enum ClosedLayout: Equatable, Sendable { case plain, media, timer, mediaAndBubble, alert }

public enum PanelRules {
    public static func defaultTab(timerRingingUnseen: Bool, isPlaying: Bool, lastUsed: PanelTab) -> PanelTab {
        if timerRingingUnseen { return .timer }
        if isPlaying { return .music }
        return lastUsed
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
