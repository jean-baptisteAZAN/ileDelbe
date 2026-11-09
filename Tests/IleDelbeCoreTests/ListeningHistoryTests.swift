import Testing
import Foundation
@testable import IleDelbeCore

@Suite struct ListeningHistoryTests {
    let T = Date(timeIntervalSince1970: 1_000_000)

    func rec(_ h: inout ListeningHistory, _ title: String, _ i: Int = 0) {
        h.record(title: title, artist: "X", thumbnail: nil, at: T + Double(i))
    }
    func np(_ title: String) -> NowPlayingInfo {
        NowPlayingInfo(bundleIdentifier: "b", title: title, artist: "X", isPlaying: true)
    }

    @Test func recordOrderAndDedup() {
        var h = ListeningHistory()
        rec(&h, "A"); rec(&h, "B"); rec(&h, "C")
        #expect(h.entries.map(\.title) == ["C", "B", "A"])
        rec(&h, "C")
        #expect(h.entries.count == 3)
        rec(&h, "A")
        #expect(h.entries.map(\.title) == ["A", "C", "B", "A"])
    }
    @Test func cap() {
        var h = ListeningHistory()
        for i in 0..<25 { rec(&h, "T\(i)", i) }
        #expect(h.entries.count == 20)
        #expect(h.entries.first?.title == "T24")
    }
    @Test func recentExcludesCurrent() {
        var h = ListeningHistory()
        rec(&h, "A"); rec(&h, "B"); rec(&h, "C")
        #expect(h.recent(excluding: np("C")).map(\.title) == ["B", "A"])
        #expect(h.recent(excluding: nil, limit: 2).map(\.title) == ["C", "B"])
    }
    @Test func limitRespected() {
        var h = ListeningHistory()
        for t in ["A", "B", "C", "D", "E"] { rec(&h, t) }
        #expect(h.recent(excluding: nil).count == 3)
    }
    @Test func codable() throws {
        var h = ListeningHistory()
        rec(&h, "A"); rec(&h, "B")
        let d = try JSONEncoder().encode(h)
        #expect(try JSONDecoder().decode(ListeningHistory.self, from: d) == h)
    }
}
