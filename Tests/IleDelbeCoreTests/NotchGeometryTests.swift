import CoreGraphics
import Testing
@testable import IleDelbeCore

@Suite struct NotchGeometryTests {
    private func make(originX: CGFloat = 0) -> NotchGeometry? {
        NotchGeometry.make(
            screenFrame: CGRect(x: originX, y: 0, width: 1512, height: 982),
            safeAreaTop: 32,
            auxiliaryTopLeft: CGRect(x: originX, y: 950, width: 662, height: 32),
            auxiliaryTopRight: CGRect(x: originX + 850, y: 950, width: 662, height: 32))
    }

    @Test func notchRect() {
        #expect(make()?.notch == CGRect(x: 662, y: 950, width: 188, height: 32))
    }

    @Test func closedRects() {
        let g = make()!
        #expect(g.closedRect(.standard) == CGRect(x: 626, y: 950, width: 260, height: 32))
        #expect(g.closedRect(.alert) == CGRect(x: 552, y: 950, width: 408, height: 32))
        #expect(g.closedRect(.title) == CGRect(x: 626, y: 950, width: 344, height: 32))
        #expect(g.closedRect(.none) == g.notch)
    }

    @Test func openRect() {
        #expect(make()!.openRect(size: CGSize(width: 548, height: 236)) == CGRect(x: 482, y: 746, width: 548, height: 236))
    }

    @Test func bubbleFollowsActualWing() {
        let g = make()!
        #expect(g.bubbleRect(after: g.closedRect(.standard)) == CGRect(x: 894, y: 950, width: 76, height: 32))
        #expect(g.bubbleRect(after: g.closedRect(.title)).minX == 978)
    }

    @Test func nonZeroOrigin() {
        #expect(make(originX: 1512)?.notch == CGRect(x: 2174, y: 950, width: 188, height: 32))
        #expect(make(originX: 1512)?.openRect(size: CGSize(width: 548, height: 236)) == CGRect(x: 1994, y: 746, width: 548, height: 236))
    }

    @Test func noNotch() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let right = CGRect(x: 850, y: 950, width: 662, height: 32)
        #expect(NotchGeometry.make(screenFrame: screen, safeAreaTop: 32,
                                   auxiliaryTopLeft: nil, auxiliaryTopRight: right) == nil)
        #expect(NotchGeometry.make(screenFrame: screen, safeAreaTop: 32,
                                   auxiliaryTopLeft: right, auxiliaryTopRight: nil) == nil)
        #expect(NotchGeometry.make(screenFrame: screen, safeAreaTop: 0,
                                   auxiliaryTopLeft: right, auxiliaryTopRight: right) == nil)
    }

    @Test func closedOffsetFollowsAsymmetricWings() {
        let g = NotchGeometry(notch: CGRect(x: 662, y: 950, width: 188, height: 32), screenMaxY: 982)
        #expect(g.closedOffsetX(.title) == 42)
        #expect(g.closedOffsetX(.standard) == 0)
        #expect(g.closedOffsetX(.none) == 0)
        #expect(g.closedOffsetX(.alert) == 0)
        // The offset shape coincides with closedRect.
        #expect(g.notch.midX + g.closedOffsetX(.title) == g.closedRect(.title).midX)
    }

    // Notch 188 wide centred at x 756; open halo margin 35 sides / 48 bottom, closed halo 11.
    // Widest closed footprint: title wing + bubble = 94 + 120 + 8 + 76 = 298 (+11) right of centre.
    let wg = NotchGeometry(notch: CGRect(x: 662, y: 950, width: 188, height: 32), screenMaxY: 982)
    func frame(_ size: CGSize) -> CGRect {
        wg.windowFrame(openSize: size, openMargin: (horizontal: 35, bottom: 48), closedMargin: 11)
    }

    @Test func windowFrameCoversClosedAlertWhenOpenIsSmall() {
        // All modules hidden: open 300 wide (185 per side with margin) < alert 204 + 11.
        let f = frame(CGSize(width: 300, height: 112))
        #expect(f == CGRect(x: 756 - 309, y: 982 - 112 - 48, width: 618, height: 112 + 48))
        #expect(f.minX <= wg.closedRect(.alert).minX - 11 && f.maxX >= wg.closedRect(.alert).maxX + 11)
    }

    @Test func windowFrameCoversTitleBubble() {
        // Compact Onglets: 482 + 70 = 552 (276 per side) < 298 + 11 for the title bubble.
        let f = frame(CGSize(width: 482, height: 212))
        #expect(f.maxX >= wg.bubbleRect(after: wg.closedRect(.title)).maxX + 11)
        #expect(f.midX == wg.notch.midX)
        #expect(f == CGRect(x: 447, y: 722, width: 618, height: 260))
    }

    @Test func windowFrameIsOpenRectPlusMarginWhenWider() {
        let size = CGSize(width: 640, height: 268)
        let o = wg.openRect(size: size)
        #expect(frame(size) == CGRect(x: o.minX - 35, y: o.minY - 48, width: o.width + 70, height: o.height + 48))
    }

    private let ext = NotchGeometry.virtual(screenFrame: CGRect(x: 1512, y: 0, width: 2560, height: 1440), menuBarHeight: 24)

    @Test func virtualNotch() {
        #expect(ext.isVirtual)
        #expect(ext.notch == CGRect(x: 2702, y: 1416, width: 180, height: 24))
    }
    @Test func idleBar() {
        #expect(ext.idleBarRect == CGRect(x: 2732, y: 1436, width: 120, height: 4))
        #expect(ext.closedShapeRect(.none) == ext.idleBarRect)
        #expect(ext.closedShapeRect(.standard) == ext.closedRect(.standard))
    }
    @Test func idleTrigger() {
        #expect(ext.closedTriggerRect(.none) == CGRect(x: 2732, y: 1430, width: 120, height: 10))
    }
    @Test func hardwareNotchUnchanged() {
        let g = make()!
        #expect(!g.isVirtual && g.closedShapeRect(.none) == g.notch && g.closedTriggerRect(.none) == g.notch)
    }
    @Test func menuBarHeightFallback() {
        let s = CGRect(x: 0, y: 0, width: 100, height: 100)
        #expect(NotchGeometry.menuBarHeight(screenFrame: s, visibleFrame: CGRect(x: 0, y: 0, width: 100, height: 76), fallback: 24) == 24)
        #expect(NotchGeometry.menuBarHeight(screenFrame: s, visibleFrame: s, fallback: 24) == 24)
        #expect(NotchGeometry.menuBarHeight(screenFrame: s, visibleFrame: CGRect(x: 0, y: 0, width: 100, height: 70), fallback: 24) == 30)
    }
    @Test func virtualWindowFrameCoversPill() {
        let w = ext.windowFrame(openSize: CGSize(width: 460, height: 120), openMargin: (horizontal: 35, bottom: 48), closedMargin: 11)
        #expect(w.contains(ext.closedRect(.alert)) && w.contains(ext.idleBarRect))
    }
}
