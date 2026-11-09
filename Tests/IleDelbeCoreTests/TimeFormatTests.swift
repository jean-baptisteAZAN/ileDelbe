import Testing
@testable import IleDelbeCore

@Suite struct TimeFormatTests {
    @Test func formats() {
        #expect(TimeFormat.string(0) == "0:00")
        #expect(TimeFormat.string(65) == "1:05")
        #expect(TimeFormat.string(3600) == "1:00:00")
        #expect(TimeFormat.string(-3) == "0:00")
        #expect(TimeFormat.string(Double.nan) == "0:00")
    }
}
