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
}
