import Foundation

/// Accumulates raw bytes and yields complete, non-empty UTF-8 lines.
/// Works on bytes so multibyte characters split across chunks reassemble.
public struct LineBuffer: Sendable {
    private var pending = Data()

    public init() {}

    public mutating func append(_ data: Data) -> [String] {
        pending.append(data)
        var lines: [String] = []
        while let nl = pending.firstIndex(of: 0x0A) {
            let lineData = pending[pending.startIndex..<nl]
            pending = Data(pending[pending.index(after: nl)...])
            if !lineData.isEmpty, let s = String(data: lineData, encoding: .utf8), !s.isEmpty {
                lines.append(s)
            }
        }
        return lines
    }
}
