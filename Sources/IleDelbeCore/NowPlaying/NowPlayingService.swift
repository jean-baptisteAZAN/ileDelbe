import Foundation
import Observation
import os

/// Runs the mediaremote-adapter `stream` child process and exposes its state.
@MainActor @Observable
public final class NowPlayingService {
    public enum Status: Equatable { case idle, running, unavailable(String) }

    public private(set) var info: NowPlayingInfo?
    public private(set) var status: Status = .idle

    @ObservationIgnored private let executable: URL
    @ObservationIgnored private let paths: AdapterPaths?
    @ObservationIgnored private var decoder = AdapterStreamDecoder()
    @ObservationIgnored private var process: Process?
    @ObservationIgnored private var stoppedByUs = false
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private let log = Logger(subsystem: "io.github.ileDelbe", category: "nowplaying")

    private enum Event: Sendable {
        case line(String)
        case terminated(code: Int32, stderr: String)
    }

    public init(executable: URL = URL(fileURLWithPath: "/usr/bin/perl"), paths: AdapterPaths?) {
        self.executable = executable
        self.paths = paths
    }

    deinit { process?.terminate() }

    public func start() {
        guard process == nil else { return }
        guard let paths else {
            status = .unavailable("adapter not found")
            return
        }
        let p = Process()
        p.executableURL = executable
        p.arguments = paths.streamArguments()
        let out = Pipe(), err = Pipe()
        p.standardOutput = out
        p.standardError = err
        p.standardInput = FileHandle.nullDevice

        // Ordered, thread-safe hand-off from the reader threads to the main actor.
        let (stream, continuation) = AsyncStream<Event>.makeStream()
        do {
            try p.run()
        } catch {
            status = .unavailable("launch failed: \(error.localizedDescription)")
            return
        }
        stoppedByUs = false
        generation += 1
        let gen = generation
        process = p
        status = .running
        decoder = AdapterStreamDecoder()

        let outHandle = out.fileHandleForReading, errHandle = err.fileHandleForReading
        DispatchQueue.global(qos: .utility).async {
            let group = DispatchGroup()
            let errBox = LockedData()
            group.enter()
            DispatchQueue.global(qos: .utility).async {
                while true {
                    let d = errHandle.availableData
                    if d.isEmpty { break }
                    errBox.append(d)
                }
                group.leave()
            }
            var buffer = LineBuffer()
            while true {
                let d = outHandle.availableData
                if d.isEmpty { break }
                for line in buffer.append(d) { continuation.yield(.line(line)) }
            }
            group.wait()
            p.waitUntilExit()
            continuation.yield(.terminated(code: p.terminationStatus, stderr: errBox.string))
            continuation.finish()
        }

        Task { @MainActor [weak self] in
            for await event in stream {
                guard let self, self.generation == gen else { return }
                switch event {
                case .line(let line):
                    if let new = self.decoder.consume(line: line) { self.info = new }
                    else if self.decoder.current == nil { self.info = nil }
                case .terminated(let code, let stderr):
                    self.handleTermination(code: code, stderr: stderr)
                }
            }
        }
    }

    public func stop() {
        guard let process else { return }
        stoppedByUs = true
        process.terminate()
    }

    public func send(_ command: AdapterCommand) {
        guard let paths else { return }
        let p = Process()
        p.executableURL = executable
        p.arguments = paths.arguments(for: command)
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        p.standardInput = FileHandle.nullDevice
        do { try p.run() } catch {
            log.error("send failed: \(error.localizedDescription)")
        }
    }

    private func handleTermination(code: Int32, stderr: String) {
        process = nil
        if stoppedByUs || code == 0 {
            status = .idle
        } else {
            if !stderr.isEmpty { log.error("adapter stderr: \(stderr, privacy: .public)") }
            status = .unavailable("exit \(code)")
        }
        stoppedByUs = false
    }
}

private final class LockedData: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    func append(_ d: Data) { lock.lock(); data.append(d); lock.unlock() }
    var string: String { lock.lock(); defer { lock.unlock() }; return String(decoding: data, as: UTF8.self) }
}
