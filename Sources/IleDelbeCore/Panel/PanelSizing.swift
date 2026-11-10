import CoreGraphics

/// Open-panel size per style, module set and density. Single source of truth for window geometry.
public enum PanelSizing {
    public static let compactScale: CGFloat = 0.88

    public static func size(style: PanelStyle, showsAll: Bool, modules: [PanelTab],
                            density: PanelDensity, notchHeight h: CGFloat) -> CGSize {
        let base: CGSize
        if modules.isEmpty {
            base = CGSize(width: 300, height: h + 80)
        } else {
            switch style {
            case .tabs:
                base = CGSize(width: 548, height: 236)
            case .island where !showsAll:
                base = CGSize(width: 460, height: h + 96)
            case .grid, .island:
                base = gridSize(modules: modules, h: h)
            }
        }
        guard density == .compact else { return base }
        let width = (base.width * compactScale).rounded()
        let height = h + ((base.height - h) * compactScale).rounded()
        return CGSize(width: width, height: height)
    }

    public static func maxSize(style: PanelStyle, modules: [PanelTab],
                               density: PanelDensity, notchHeight: CGFloat) -> CGSize {
        let own = size(style: style, showsAll: false, modules: modules, density: density, notchHeight: notchHeight)
        guard style == .island else { return own }
        let grid = size(style: .island, showsAll: true, modules: modules, density: density, notchHeight: notchHeight)
        return CGSize(width: max(own.width, grid.width), height: max(own.height, grid.height))
    }

    /// Grille (and « Tout voir ») heights below the notch band, constants per case:
    /// 6 pt top inset, the cards, an 8 + 20 pt footer row with the gear, 10 pt bottom inset.
    public static let gridChrome: CGFloat = 44
    /// With Musique: the side column stacks up to 3 cards (Minuteur ~64, Agenda without
    /// access ~86, five files ~79) and 2 gaps of 10 pt; the Musique card needs ~191.
    public static let gridMusicContent: CGFloat = 250
    /// Without Musique: rows of 2 cards, the tallest card (Agenda without access) included.
    public static let gridRowHeight: CGFloat = 86
    public static let gridRowSpacing: CGFloat = 10

    private static func gridSize(modules: [PanelTab], h: CGFloat) -> CGSize {
        if modules.contains(.music) {
            let width: CGFloat = modules.count > 1 ? 640 : 380
            return CGSize(width: width, height: h + gridChrome + gridMusicContent)
        }
        let n = CGFloat((modules.count + 1) / 2)
        return CGSize(width: 520, height: h + gridChrome + n * gridRowHeight + (n - 1) * gridRowSpacing)
    }
}
