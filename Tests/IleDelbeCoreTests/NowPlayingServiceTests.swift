import Foundation
import Testing
@testable import IleDelbeCore

@MainActor
struct NowPlayingServiceTests {
    private func makeScript(_ body: String) throws -> (AdapterPaths, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let script = dir.appendingPathComponent("fake.sh")
        try body.write(to: script, atomically: true, encoding: .utf8)
        return (AdapterPaths(script: script, framework: dir.appendingPathComponent("F.framework")), dir)
    }

    private func wait(_ seconds: Double, until cond: () -> Bool) async throws {
        let end = Date().addingTimeInterval(seconds)
        while !cond() && Date() < end { try await Task.sleep(for: .milliseconds(20)) }
    }

    @Test func decodesStreamLines() async throws {
        let line = #"{"type":"data","diff":false,"payload":{"bundleIdentifier":"com.spotify.client","title":"Song","playing":true}}"#
        let (paths, _) = try makeScript("echo '\(line)'\nsleep 5\n")
        let s = NowPlayingService(executable: URL(fileURLWithPath: "/bin/sh"), paths: paths)
        s.start()
        try await wait(2) { s.info?.title == "Song" }
        #expect(s.info?.title == "Song")
        #expect(s.status == .running)
        s.stop()
        try await wait(2) { s.status == .idle }
        #expect(s.status == .idle)
    }

    @Test func failureIsUnavailableAndNotRelaunched() async throws {
        let (paths, dir) = try makeScript("echo run >> \"$(dirname \"$0\")/count\"\nexit 3\n")
        let s = NowPlayingService(executable: URL(fileURLWithPath: "/bin/sh"), paths: paths)
        s.start()
        try await wait(2) { if case .unavailable = s.status { true } else { false } }
        guard case .unavailable = s.status else { Issue.record("status \(s.status)"); return }
        try await Task.sleep(for: .seconds(1))
        let count = try String(contentsOf: dir.appendingPathComponent("count"), encoding: .utf8)
        #expect(count.split(separator: "\n").count == 1)
    }

    @Test func nilPathsIsUnavailable() {
        let s = NowPlayingService(paths: nil)
        s.start()
        guard case .unavailable = s.status else { Issue.record("status \(s.status)"); return }
    }
}
