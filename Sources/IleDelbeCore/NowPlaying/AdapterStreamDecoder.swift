import Foundation

public struct AdapterStreamDecoder {
    public private(set) var current: NowPlayingInfo?
    private var payload: [String: Any] = [:]

    public init() {}

    /// Feed one stdout line. Returns current merged info, or nil when nothing is playing / line ignored.
    @discardableResult
    public mutating func consume(line: String) -> NowPlayingInfo? {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              obj["type"] as? String == "data",
              let incoming = obj["payload"] as? [String: Any]
        else { return current }

        let isDiff = (obj["diff"] as? Bool) ?? false
        if isDiff {
            for (key, value) in incoming {
                if value is NSNull { payload.removeValue(forKey: key) } else { payload[key] = value }
            }
        } else {
            payload = incoming.filter { !($0.value is NSNull) }
        }
        current = Self.map(payload)
        return current
    }

    private static func number(_ v: Any?) -> Double? {
        (v as? NSNumber).map { $0.doubleValue }
    }

    private static func map(_ p: [String: Any]) -> NowPlayingInfo? {
        guard let bundle = p["bundleIdentifier"] as? String,
              let title = p["title"] as? String
        else { return nil }
        let duration = number(p["durationMicros"]).map { $0 / 1_000_000 }.flatMap { $0 > 0 ? $0 : nil }
        return NowPlayingInfo(
            bundleIdentifier: bundle,
            title: title,
            artist: p["artist"] as? String,
            album: p["album"] as? String,
            isPlaying: (p["playing"] as? Bool) ?? false,
            duration: duration,
            elapsed: number(p["elapsedTimeMicros"]).map { $0 / 1_000_000 },
            timestamp: number(p["timestampEpochMicros"]).map { Date(timeIntervalSince1970: $0 / 1_000_000) },
            playbackRate: number(p["playbackRate"]) ?? 1.0,
            artworkData: (p["artworkData"] as? String).flatMap { Data(base64Encoded: $0) }
        )
    }
}
