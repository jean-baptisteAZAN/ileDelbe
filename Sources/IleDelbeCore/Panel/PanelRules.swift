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

    /// alert if ringing; else, counting only visible modules: mediaAndBubble if playing && timerActive;
    /// media if playing; timer if timerActive; else plain
    public static func closedLayout(isPlaying: Bool, timerActive: Bool, timerRinging: Bool,
                                    showsMusic: Bool, showsTimer: Bool) -> ClosedLayout {
        if timerRinging { return .alert }
        let music = isPlaying && showsMusic
        let timer = timerActive && showsTimer
        if music && timer { return .mediaAndBubble }
        if music { return .media }
        if timer { return .timer }
        return .plain
    }

    public static func closedWings(_ layout: ClosedLayout, closedStyle: ClosedStyle) -> ClosedWings {
        switch layout {
        case .plain: return .none
        case .media, .mediaAndBubble: return closedStyle == .title ? .title : .standard
        case .timer: return .standard
        case .alert: return .alert
        }
    }
}
