import Foundation

public enum AdapterCommand: Equatable, Sendable {
    case togglePlayPause, next, previous
    case seek(to: TimeInterval)

    /// Arguments appended after the script and framework paths.
    public var arguments: [String] {
        switch self {
        case .togglePlayPause: ["send", "2"]
        case .next: ["send", "4"]
        case .previous: ["send", "5"]
        case .seek(let t):
            ["seek", String(Int((max(0, t) * 1_000_000).rounded()))]
        }
    }
}

public struct AdapterPaths: Sendable {
    public let script: URL
    public let framework: URL

    public init(script: URL, framework: URL) {
        self.script = script
        self.framework = framework
    }

    public static func inBundle(_ bundle: Bundle) -> AdapterPaths? {
        guard let script = bundle.url(forResource: "mediaremote-adapter", withExtension: "pl"),
              let framework = bundle.url(forResource: "MediaRemoteAdapter", withExtension: "framework")
        else { return nil }
        return AdapterPaths(script: script, framework: framework)
    }

    public func streamArguments() -> [String] {
        [script.path, framework.path, "stream", "--micros", "--debounce=50"]
    }

    public func arguments(for command: AdapterCommand) -> [String] {
        [script.path, framework.path] + command.arguments
    }
}
