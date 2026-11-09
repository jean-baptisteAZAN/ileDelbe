import Testing
@testable import IleDelbeCore

@Suite struct HaloColorTests {
    @Test func greyIsNil() {
        #expect(HaloColor.glow(fromAverage: RGBColor(r: 0.5, g: 0.5, b: 0.5)) == nil)
    }
    @Test func nearBlackIsNil() {
        #expect(HaloColor.glow(fromAverage: RGBColor(r: 0.05, g: 0.02, b: 0.02)) == nil)
    }
    @Test func darkRedBoosted() throws {
        let o = try #require(HaloColor.glow(fromAverage: RGBColor(r: 0.4, g: 0.1, b: 0.1)))
        #expect(o.r > o.g)
        #expect(abs(o.g - o.b) < 0.001)
        #expect(abs(o.r - 0.75) < 0.01)
        #expect((o.r - o.g) / o.r >= 0.55 - 0.001)
    }
    @Test func vividUnchanged() throws {
        let i = RGBColor(r: 1.0, g: 0.35, b: 0.3)
        let o = try #require(HaloColor.glow(fromAverage: i))
        #expect(abs(o.r - i.r) < 0.001)
        #expect(abs(o.g - i.g) < 0.001)
        #expect(abs(o.b - i.b) < 0.001)
    }
    @Test func hueKept() throws {
        let o = try #require(HaloColor.glow(fromAverage: RGBColor(r: 0.2, g: 0.6, b: 0.9)))
        #expect(o.b > o.g && o.g > o.r)
    }
}
