import Testing
import Foundation
@testable import IleDelbeCore

@Suite struct CountdownTimerTests {
    let T = Date(timeIntervalSince1970: 1_000_000)

    @Test func startRemainingProgress() {
        var t = CountdownTimer()
        t.start(duration: 300, now: T)
        #expect(t.remaining(at: T + 60) == 240)
        #expect(t.progress(at: T + 60) == 0.8)
        #expect(t.isActive)
    }
    @Test func pauseResume() {
        var t = CountdownTimer()
        t.start(duration: 300, now: T)
        t.pause(now: T + 60)
        t.resume(now: T + 500)
        #expect(t.remaining(at: T + 500) == 240)
    }
    @Test func addMinute() {
        var t = CountdownTimer()
        t.start(duration: 300, now: T)
        t.addMinute(now: T)
        #expect(t.remaining(at: T) == 360)
        #expect(t.progress(at: T) == 1.0)
    }
    @Test func addMinutePaused() {
        var t = CountdownTimer()
        t.start(duration: 300, now: T)
        t.pause(now: T + 100)
        t.addMinute(now: T + 100)
        #expect(t.state == .paused(remaining: 260, total: 360))
    }
    @Test func tickRings() {
        var t = CountdownTimer()
        t.start(duration: 300, now: T)
        #expect(t.tick(now: T + 299) == false)
        #expect(t.isActive)
        #expect(t.tick(now: T + 301) == true)
        #expect(t.state == .ringing(since: T + 300))
        #expect(t.isRinging)
        #expect(t.tick(now: T + 361) == false)
        #expect(t.state == .idle)
    }
    @Test func acknowledgeAndStop() {
        var t = CountdownTimer()
        t.start(duration: 300, now: T)
        _ = t.tick(now: T + 301)
        t.acknowledge()
        #expect(t.state == .idle)
        t.start(duration: 300, now: T)
        t.pause(now: T + 10)
        t.stop()
        #expect(t.state == .idle)
    }
    @Test func sleepWake() {
        var t = CountdownTimer()
        t.start(duration: 300, now: T)
        #expect(t.tick(now: T + 4000) == true)
        #expect(t.state == .ringing(since: T + 300))
        #expect(t.tick(now: T + 4000) == false)
        #expect(t.state == .idle)
    }
    @Test func restoreAfterLaunch() {
        var t = CountdownTimer()
        t.start(duration: 300, now: T)
        t.restoreAfterLaunch(now: T + 400)
        #expect(t.state == .idle)

        t.start(duration: 300, now: T)
        t.pause(now: T + 10)
        let paused = t
        t.restoreAfterLaunch(now: T + 9999)
        #expect(t == paused)

        t.start(duration: 300, now: T)
        let running = t
        t.restoreAfterLaunch(now: T + 100)
        #expect(t == running)

        t.start(duration: 300, now: T)
        _ = t.tick(now: T + 301)
        t.restoreAfterLaunch(now: T + 302)
        #expect(t.state == .idle)
    }
    @Test func codableRoundTrip() throws {
        var t = CountdownTimer()
        t.start(duration: 300, now: T)
        let data = try JSONEncoder().encode(t)
        #expect(try JSONDecoder().decode(CountdownTimer.self, from: data) == t)
    }
}
