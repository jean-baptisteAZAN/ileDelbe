import Foundation

public enum PanelStyle: String, Codable, CaseIterable, Sendable { case island, grid, tabs }
public enum AccentSource: String, Codable, CaseIterable, Sendable { case artwork, fixed, none }

public enum FixedTint: String, Codable, CaseIterable, Sendable {
    case blue, green, violet, yellow, white

    public var hex: String {
        switch self {
        case .blue: "#5B8CFF"
        case .green: "#3ECF8E"
        case .violet: "#C06BFF"
        case .yellow: "#F5C542"
        case .white: "#FFFFFF"
        }
    }
}

public enum ClosedStyle: String, Codable, CaseIterable, Sendable { case artworkEqualizer, title, none }
public enum PanelDensity: String, Codable, CaseIterable, Sendable { case normal, compact }

public struct ModuleEntry: Codable, Equatable, Sendable {
    public var module: PanelTab
    public var visible: Bool

    public init(module: PanelTab, visible: Bool) {
        self.module = module
        self.visible = visible
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var style: PanelStyle = .island
    public var accent: AccentSource = .artwork
    public var fixedTint: FixedTint = .blue
    public var haloIntensity: Double = 0.6
    public var modules: [ModuleEntry] = PanelTab.allCases.map { ModuleEntry(module: $0, visible: true) }
    public var forcedModule: PanelTab? = nil
    public var closedStyle: ClosedStyle = .artworkEqualizer
    public var animateClosed: Bool = true
    public var openDelay: Double = 0.15
    public var timerPresetsMinutes: [Int] = AppSettings.defaultPresets
    public var density: PanelDensity = .normal
    public var recentFileCount: Int = 3
    public var screenMode: ScreenMode = .builtIn
    public var chosenScreenID: String? = nil

    public static let `default` = AppSettings()
    public static let storageKey = "settings.v1"
    private static let defaultPresets = [5, 10, 25]

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case style, accent, fixedTint, haloIntensity, modules, forcedModule, closedStyle
        case animateClosed, openDelay, timerPresetsMinutes, density, recentFileCount
        case screenMode, chosenScreenID
    }

    /// Each field falls back to its default on its own, so one bad value never discards the rest.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        style = (try? c.decodeIfPresent(PanelStyle.self, forKey: .style)) ?? d.style
        accent = (try? c.decodeIfPresent(AccentSource.self, forKey: .accent)) ?? d.accent
        fixedTint = (try? c.decodeIfPresent(FixedTint.self, forKey: .fixedTint)) ?? d.fixedTint
        haloIntensity = (try? c.decodeIfPresent(Double.self, forKey: .haloIntensity)) ?? d.haloIntensity
        modules = (try? c.decodeIfPresent([ModuleEntry].self, forKey: .modules)) ?? d.modules
        forcedModule = (try? c.decodeIfPresent(PanelTab.self, forKey: .forcedModule)) ?? d.forcedModule
        closedStyle = (try? c.decodeIfPresent(ClosedStyle.self, forKey: .closedStyle)) ?? d.closedStyle
        animateClosed = (try? c.decodeIfPresent(Bool.self, forKey: .animateClosed)) ?? d.animateClosed
        openDelay = (try? c.decodeIfPresent(Double.self, forKey: .openDelay)) ?? d.openDelay
        timerPresetsMinutes = (try? c.decodeIfPresent([Int].self, forKey: .timerPresetsMinutes)) ?? d.timerPresetsMinutes
        density = (try? c.decodeIfPresent(PanelDensity.self, forKey: .density)) ?? d.density
        recentFileCount = (try? c.decodeIfPresent(Int.self, forKey: .recentFileCount)) ?? d.recentFileCount
        screenMode = (try? c.decodeIfPresent(ScreenMode.self, forKey: .screenMode)) ?? d.screenMode
        chosenScreenID = (try? c.decodeIfPresent(String.self, forKey: .chosenScreenID)) ?? d.chosenScreenID
        self = normalized()
    }

    public static func load(_ data: Data?) -> AppSettings {
        guard let data, let s = try? JSONDecoder().decode(AppSettings.self, from: data) else { return .default }
        return s
    }

    public func encoded() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }

    public func normalized() -> AppSettings {
        var s = self
        s.haloIntensity = min(max(haloIntensity, 0), 1)

        let clampedDelay = min(max(openDelay, 0.05), 0.6)
        s.openDelay = (clampedDelay * 20).rounded() / 20

        let defaults = Self.defaultPresets
        let clamped = timerPresetsMinutes.prefix(3).map { min(max($0, 1), 180) }
        s.timerPresetsMinutes = clamped + defaults.dropFirst(clamped.count)

        if recentFileCount != 3 && recentFileCount != 5 { s.recentFileCount = 3 }

        var seen = Set<PanelTab>()
        var repaired = modules.filter { seen.insert($0.module).inserted }
        for tab in PanelTab.allCases where !seen.contains(tab) {
            repaired.append(ModuleEntry(module: tab, visible: true))
        }
        s.modules = repaired

        if let forced = forcedModule, !repaired.contains(where: { $0.module == forced && $0.visible }) {
            s.forcedModule = nil
        }
        return s
    }

    public var visibleModules: [PanelTab] {
        modules.filter(\.visible).map(\.module)
    }

    public mutating func setVisible(_ module: PanelTab, _ visible: Bool) {
        guard let i = modules.firstIndex(where: { $0.module == module }) else { return }
        modules[i].visible = visible
        if !visible && forcedModule == module { forcedModule = nil }
    }

    public mutating func moveModule(from: Int, to: Int) {
        guard modules.indices.contains(from), modules.indices.contains(to) else { return }
        modules.insert(modules.remove(at: from), at: to)
    }
}
