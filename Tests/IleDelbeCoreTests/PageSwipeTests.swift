import Foundation
import Testing
@testable import IleDelbeCore

@Suite struct PageSwipeTests {
    @Test func onePagePerGesture() {
        var s = PageSwipe()
        #expect(s.feed(deltaX: 0, deltaY: 0, phase: .began, isMomentum: false) == nil)
        #expect(s.feed(deltaX: -15, deltaY: 1, phase: .changed, isMomentum: false) == nil)
        #expect(s.feed(deltaX: -15, deltaY: 1, phase: .changed, isMomentum: false) == .next)
        #expect(s.feed(deltaX: -80, deltaY: 0, phase: .changed, isMomentum: false) == nil)
        _ = s.feed(deltaX: 0, deltaY: 0, phase: .ended, isMomentum: false)
        _ = s.feed(deltaX: 0, deltaY: 0, phase: .began, isMomentum: false)
        #expect(s.feed(deltaX: 30, deltaY: 0, phase: .changed, isMomentum: false) == .previous)
    }
    @Test func momentumIgnored() {
        var s = PageSwipe()
        #expect(s.feed(deltaX: -100, deltaY: 0, phase: .changed, isMomentum: true) == nil)
    }
    @Test func verticalScrollIgnored() {
        var s = PageSwipe()
        _ = s.feed(deltaX: 0, deltaY: 0, phase: .began, isMomentum: false)
        #expect(s.feed(deltaX: -30, deltaY: -60, phase: .changed, isMomentum: false) == nil)
    }
    @Test func changedWithoutBeganWorks() {
        var s = PageSwipe()
        #expect(s.feed(deltaX: 30, deltaY: 0, phase: .changed, isMomentum: false) == .previous)
    }
    @Test func legacyWheelDiscrete() {
        var s = PageSwipe()
        #expect(s.feed(deltaX: -30, deltaY: 0, phase: .none, isMomentum: false) == .next)
        #expect(s.feed(deltaX: -10, deltaY: 0, phase: .none, isMomentum: false) == nil)
        #expect(s.feed(deltaX: -10, deltaY: 0, phase: .none, isMomentum: false) == nil)
    }
    @Test func pagingClamps() {
        let p: [PanelTab] = [.music, .timer, .files]
        #expect(PanelRules.step(from: .music, .next, in: p) == .timer)
        #expect(PanelRules.step(from: .files, .next, in: p) == .files)
        #expect(PanelRules.step(from: .music, .previous, in: p) == .music)
        #expect(PanelRules.step(from: nil, .next, in: []) == nil)
    }
    @Test func stepFromHiddenPageGoesToFirst() {
        #expect(PanelRules.step(from: .agenda, .next, in: [.music, .files]) == .music)
    }
}
