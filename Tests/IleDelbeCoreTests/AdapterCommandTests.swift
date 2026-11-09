import Foundation
import Testing
@testable import IleDelbeCore

@Suite struct AdapterCommandTests {
    @Test func commandArguments() {
        #expect(AdapterCommand.togglePlayPause.arguments == ["send", "2"])
        #expect(AdapterCommand.next.arguments == ["send", "4"])
        #expect(AdapterCommand.previous.arguments == ["send", "5"])
        #expect(AdapterCommand.seek(to: 12.5).arguments == ["seek", "12500000"])
        #expect(AdapterCommand.seek(to: -1).arguments == ["seek", "0"])
    }

    @Test func streamArguments() {
        let p = AdapterPaths(script: URL(fileURLWithPath: "/a/s.pl"), framework: URL(fileURLWithPath: "/a/F.framework"))
        #expect(p.streamArguments() == ["/a/s.pl", "/a/F.framework", "stream", "--micros", "--debounce=50"])
        #expect(p.arguments(for: .next) == ["/a/s.pl", "/a/F.framework", "send", "4"])
    }

    @Test func inBundleMissingResources() {
        #expect(AdapterPaths.inBundle(Bundle.module) == nil)
    }
}
