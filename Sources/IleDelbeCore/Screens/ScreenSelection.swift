import Foundation

public struct ScreenInfo: Equatable, Sendable {
    public var id: String
    public var name: String
    public var isBuiltIn: Bool
    public var isMain: Bool
    public var hasNotch: Bool

    public init(id: String, name: String, isBuiltIn: Bool, isMain: Bool, hasNotch: Bool) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.isMain = isMain
        self.hasNotch = hasNotch
    }
}

public enum ScreenMode: String, Codable, CaseIterable, Sendable { case builtIn, main, chosen, all }

public enum ScreenSelection {
    /// Ids of the screens that get a notch, in the order of `screens`.
    public static func targets(_ screens: [ScreenInfo], mode: ScreenMode, chosenID: String?) -> [String] {
        guard !screens.isEmpty else { return [] }
        switch mode {
        case .all:
            return screens.map(\.id)
        case .builtIn:
            return [builtInOrMain(screens).id]
        case .main:
            return [(screens.first(where: \.isMain) ?? screens[0]).id]
        case .chosen:
            if let chosenID, let s = screens.first(where: { $0.id == chosenID }) { return [s.id] }
            return [builtInOrMain(screens).id]
        }
    }

    private static func builtInOrMain(_ screens: [ScreenInfo]) -> ScreenInfo {
        screens.first(where: \.isBuiltIn) ?? screens.first(where: \.isMain) ?? screens[0]
    }
}
