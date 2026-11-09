import Foundation
import Testing
@testable import IleDelbeCore

@Suite struct RelativeTimeTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func s(_ ago: TimeInterval) -> String { RelativeTime.string(from: now.addingTimeInterval(-ago), now: now) }

    @Test func buckets() {
        #expect(s(10) == "à l'instant")
        #expect(s(4 * 60) == "il y a 4 min")
        #expect(s(2 * 3600) == "il y a 2 h")
        #expect(s(30 * 3600) == "hier")
        #expect(s(6 * 86400).hasPrefix("le "))
    }
}
