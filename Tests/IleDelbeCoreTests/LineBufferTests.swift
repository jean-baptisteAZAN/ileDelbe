import Foundation
import Testing
@testable import IleDelbeCore

struct LineBufferTests {
    @Test func splitsAcrossAppends() {
        var b = LineBuffer()
        #expect(b.append(Data("a\nb".utf8)) == ["a"])
        #expect(b.append(Data("c\n".utf8)) == ["bc"])
    }

    @Test func dropsEmptyLines() {
        var b = LineBuffer()
        #expect(b.append(Data("\n\n".utf8)) == [])
    }

    @Test func reassemblesSplitMultibyte() {
        var b = LineBuffer()
        let bytes = Array("é\n".utf8)  // 0xC3 0xA9 0x0A
        #expect(b.append(Data(bytes[0..<1])) == [])
        #expect(b.append(Data(bytes[1...])) == ["é"])
    }
}
