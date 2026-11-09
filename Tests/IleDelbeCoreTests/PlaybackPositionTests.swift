import Foundation
import Testing
@testable import IleDelbeCore

@Suite struct PlaybackPositionTests {
    let t = Date(timeIntervalSince1970: 1_000_000)

    func info(playing: Bool = true, duration: TimeInterval? = nil, elapsed: TimeInterval? = 10, timestamp: Date? = nil, rate: Double = 1.0) -> NowPlayingInfo {
        NowPlayingInfo(bundleIdentifier: "x", title: "t", isPlaying: playing, duration: duration, elapsed: elapsed, timestamp: timestamp ?? t, playbackRate: rate)
    }

    @Test func playingAdvances() { #expect(info().position(at: t.addingTimeInterval(5)) == 15) }
    @Test func pausedHolds() { #expect(info(playing: false).position(at: t.addingTimeInterval(5)) == 10) }
    @Test func rateScales() { #expect(info(rate: 2).position(at: t.addingTimeInterval(5)) == 20) }
    @Test func clampsToDuration() { #expect(info(duration: 12).position(at: t.addingTimeInterval(5)) == 12) }
    @Test func liveNoUpperClamp() { #expect(info(elapsed: 100).position(at: t.addingTimeInterval(50)) == 150) }
    @Test func nowBeforeTimestamp() { #expect(info().position(at: t.addingTimeInterval(-5)) == 10) }
    @Test func nilWhenMissing() {
        #expect(info(elapsed: nil).position(at: t) == nil)
        let i = NowPlayingInfo(bundleIdentifier: "x", title: "t", isPlaying: true, elapsed: 1)
        #expect(i.position(at: t) == nil)
    }
    @Test func canSeek() {
        #expect(info().canSeek == false)
        #expect(info(duration: 100).canSeek == true)
    }
}
