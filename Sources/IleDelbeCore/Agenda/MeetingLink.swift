import Foundation

public enum MeetingLink {
    private static let pattern =
        #"https://(?:meet\.google\.com/[A-Za-z0-9\-]+|(?:[A-Za-z0-9\-]+\.)?zoom\.us/j/\d+|teams\.microsoft\.com/l/meetup-join/|teams\.live\.com/meet/)[^\s<>"']*"#

    /// First https meeting URL across `texts`, in order; nil otherwise.
    public static func find(in texts: [String?]) -> URL? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        for case let text? in texts {
            let range = NSRange(text.startIndex..., in: text)
            guard let match = regex.firstMatch(in: text, range: range),
                  let r = Range(match.range, in: text) else { continue }
            var s = String(text[r])
            while let last = s.last, ").,;:!?]}>".contains(last) { s.removeLast() }
            if let url = URL(string: s) { return url }
        }
        return nil
    }
}
