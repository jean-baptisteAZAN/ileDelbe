import Foundation

public struct AgendaEvent: Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let colorHex: String?
    public let meetingURL: URL?

    public init(id: String, title: String, start: Date, end: Date,
                isAllDay: Bool, colorHex: String?, meetingURL: URL?) {
        self.id = id; self.title = title; self.start = start; self.end = end
        self.isAllDay = isAllDay; self.colorHex = colorHex; self.meetingURL = meetingURL
    }
}

public enum Agenda {
    public static let window: TimeInterval = 86_400
    public static let limit = 2
    public static let soonThreshold: TimeInterval = 3_600

    public static func upcoming(_ events: [AgendaEvent], now: Date) -> [AgendaEvent] {
        let horizon = now.addingTimeInterval(window)
        return Array(events
            .filter { !$0.isAllDay && $0.end > now && $0.start < horizon }
            .sorted { $0.start < $1.start }
            .prefix(limit))
    }

    public static func infoLine(_ upcoming: [AgendaEvent], now: Date) -> String? {
        guard let first = upcoming.first else { return nil }
        let delta = first.start.timeIntervalSince(now)
        guard delta > 0, delta <= soonThreshold else { return nil }
        let minutes = max(1, Int((delta / 60).rounded(.up)))
        return "\(first.title) dans \(minutes) min"
    }
}
