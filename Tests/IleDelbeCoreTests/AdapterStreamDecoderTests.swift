import Foundation
import Testing
@testable import IleDelbeCore

struct AdapterStreamDecoderTests {
    static let full = #"{"type":"data","diff":false,"payload":{"bundleIdentifier":"com.spotify.client","title":"Song","artist":"Art","playing":true,"durationMicros":200000000,"elapsedTimeMicros":5000000,"timestampEpochMicros":1700000000000000,"playbackRate":1}}"#

    @Test func fullPayloadParses() {
        var d = AdapterStreamDecoder()
        let info = d.consume(line: Self.full)
        #expect(info?.title == "Song")
        #expect(info?.bundleIdentifier == "com.spotify.client")
        #expect(info?.artist == "Art")
        #expect(info?.duration == 200)
        #expect(info?.elapsed == 5)
        #expect(info?.isPlaying == true)
        #expect(info?.playbackRate == 1)
        #expect(info?.timestamp == Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test func diffMergesIntoLast() {
        var d = AdapterStreamDecoder()
        _ = d.consume(line: Self.full)
        let info = d.consume(line: #"{"type":"data","diff":true,"payload":{"playing":false}}"#)
        #expect(info?.isPlaying == false)
        #expect(info?.title == "Song")
    }

    @Test func diffNullRemovesKey() {
        var d = AdapterStreamDecoder()
        _ = d.consume(line: Self.full)
        let info = d.consume(line: #"{"type":"data","diff":true,"payload":{"artist":null}}"#)
        #expect(info?.artist == nil)
        #expect(info?.title == "Song")
    }

    @Test func emptyPayloadMeansNothingPlaying() {
        var d = AdapterStreamDecoder()
        _ = d.consume(line: Self.full)
        let info = d.consume(line: #"{"type":"data","diff":false,"payload":{}}"#)
        #expect(info == nil)
        #expect(d.current == nil)
    }

    @Test func garbageLineIgnored() {
        var d = AdapterStreamDecoder()
        let before = d.consume(line: Self.full)
        #expect(d.consume(line: "not json") == before)
        #expect(d.consume(line: "{\"type\":\"data\"") == before)
        #expect(d.current == before)
    }

    @Test func zeroDurationBecomesNil() {
        var d = AdapterStreamDecoder()
        let info = d.consume(line: #"{"type":"data","diff":false,"payload":{"bundleIdentifier":"a","title":"t","playing":true,"durationMicros":0}}"#)
        #expect(info != nil)
        #expect(info?.duration == nil)
    }

    @Test func artworkDecoded() {
        var d = AdapterStreamDecoder()
        let info = d.consume(line: #"{"type":"data","diff":false,"payload":{"bundleIdentifier":"a","title":"t","playing":true,"artworkData":"AQID"}}"#)
        #expect(info?.artworkData == Data([1, 2, 3]))
    }

    @Test func realFixtureParses() throws {
        let url = try #require(Bundle.module.url(forResource: "get-sample", withExtension: "json", subdirectory: "Fixtures"))
        let payload = try String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        var d = AdapterStreamDecoder()
        let info = d.consume(line: #"{"type":"data","diff":false,"payload":"# + payload + "}")
        #expect(info != nil)
        #expect(info?.title.isEmpty == false)
    }
}
