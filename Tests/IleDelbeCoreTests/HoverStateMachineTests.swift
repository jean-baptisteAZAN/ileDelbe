import Foundation
import Testing
@testable import IleDelbeCore

@Suite struct HoverStateMachineTests {
    @Test func opensAfterDelay() {
        var m = HoverStateMachine()
        m.update(inTrigger: true, now: 0)
        m.update(inTrigger: true, now: 0.10)
        #expect(!m.isOpen)
        m.update(inTrigger: true, now: 0.16)
        #expect(m.isOpen)
    }

    @Test func quickPassStaysClosed() {
        var m = HoverStateMachine()
        m.update(inTrigger: true, now: 0)
        m.update(inTrigger: false, now: 0.08)
        m.update(inTrigger: false, now: 0.30)
        #expect(!m.isOpen)
        #expect(m.nextDeadline == nil)
    }

    @Test func closesAfterDelay() {
        var m = openMachine()
        m.update(inTrigger: false, now: 1.0)
        m.update(inTrigger: false, now: 1.2)
        #expect(m.isOpen)
        m.update(inTrigger: false, now: 1.31)
        #expect(!m.isOpen)
    }

    @Test func reenterCancelsClose() {
        var m = openMachine()
        m.update(inTrigger: false, now: 1.0)
        m.update(inTrigger: true, now: 1.2)
        m.update(inTrigger: true, now: 2.0)
        #expect(m.isOpen)
        #expect(m.nextDeadline == nil)
    }

    @Test func deadlines() {
        var m = HoverStateMachine()
        #expect(m.nextDeadline == nil)
        m.update(inTrigger: true, now: 0)
        #expect(m.nextDeadline == 0.15)
        m.update(inTrigger: true, now: 0.2)
        #expect(m.nextDeadline == nil)
        m.update(inTrigger: false, now: 1.0)
        #expect(m.nextDeadline == 1.30)
    }

    private func openMachine() -> HoverStateMachine {
        var m = HoverStateMachine()
        m.update(inTrigger: true, now: 0)
        m.update(inTrigger: true, now: 0.2)
        return m
    }
}
