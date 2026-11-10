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

    private static func gridSize(modules: [PanelTab], h: CGFloat) -> CGSize {
        if modules.contains(.music) {
            let width: CGFloat = modules.count > 1 ? 640 : 380
            return CGSize(width: width, height: h + 236)
        }
        let n = CGFloat((modules.count + 1) / 2)
        return CGSize(width: 520, height: h + 32 + n * 96 + (n - 1) * 10)
    }
}
