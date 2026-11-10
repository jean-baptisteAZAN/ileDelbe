import Testing
import CoreGraphics
@testable import IleDelbeCore

@Suite struct PanelSizingTests {
    let all: [PanelTab] = [.music, .timer, .agenda, .files]
    func size(_ s: PanelStyle, _ m: [PanelTab], all showsAll: Bool = false, _ d: PanelDensity = .normal) -> CGSize {
        PanelSizing.size(style: s, showsAll: showsAll, modules: m, density: d, notchHeight: 32)
    }
    @Test func tabs() { #expect(size(.tabs, all) == CGSize(width: 548, height: 236)) }
    @Test func island() { #expect(size(.island, all) == CGSize(width: 460, height: 128)) }
    @Test func islandShowsAllIsGrid() { #expect(size(.island, all, all: true) == size(.grid, all)) }
    @Test func gridWithMusic() { #expect(size(.grid, all) == CGSize(width: 640, height: 268)) }
    @Test func gridMusicOnly() { #expect(size(.grid, [.music]) == CGSize(width: 380, height: 268)) }
    @Test func gridNoMusic() {
        #expect(size(.grid, [.timer]) == CGSize(width: 520, height: 160))
        #expect(size(.grid, [.timer, .agenda, .files]) == CGSize(width: 520, height: 266))
    }
    @Test func emptySize() {
        for s in PanelStyle.allCases { #expect(size(s, []) == CGSize(width: 300, height: 112)) }
    }
    @Test func compactKeepsNotchBand() {
        #expect(size(.island, all, .compact) == CGSize(width: 405, height: 116))
        #expect(size(.tabs, all, .compact) == CGSize(width: 482, height: 212))
    }
    @Test func maxSizeIslandCoversShowsAll() {
        let m = PanelSizing.maxSize(style: .island, modules: all, density: .normal, notchHeight: 32)
        #expect(m == CGSize(width: 640, height: 268))
    }
    @Test func windowFrameCoversEveryStateOfStyle() {
        let subsets: [[PanelTab]] = [[], [.music], [.timer], [.music, .timer, .agenda, .files], [.timer, .agenda, .files]]
        for style in PanelStyle.allCases {
            for d in PanelDensity.allCases {
                for m in subsets {
                    let max = PanelSizing.maxSize(style: style, modules: m, density: d, notchHeight: 32)
                    for showsAll in [false, true] {
                        let s = PanelSizing.size(style: style, showsAll: showsAll && style == .island, modules: m, density: d, notchHeight: 32)
                        #expect(s.width <= max.width && s.height <= max.height)
                    }
                }
            }
        }
    }
}
