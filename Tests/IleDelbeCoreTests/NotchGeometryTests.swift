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

    @Test func closedActiveRect() {
        #expect(make()?.closedActive == CGRect(x: 626, y: 950, width: 260, height: 32))
    }

    @Test func closedAlertRect() {
        let g = make()
        #expect(g?.closedAlert == CGRect(x: 572, y: 950, width: 368, height: 32))
        #expect(g.map { $0.expanded.contains($0.closedAlert) } == true)
    }

    @Test func expandedRect() {
        #expect(make()?.expanded == CGRect(x: 482, y: 746, width: 548, height: 236))
    }

    @Test func bubbleRect() {
        #expect(make()?.bubble == CGRect(x: 894, y: 950, width: 76, height: 32))
        #expect(make()?.expanded.contains(make()!.bubble) == true)
    }

    @Test func nonZeroOrigin() {
        #expect(make(originX: 1512)?.notch == CGRect(x: 2174, y: 950, width: 188, height: 32))
        #expect(make(originX: 1512)?.expanded == CGRect(x: 1994, y: 746, width: 548, height: 236))
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
