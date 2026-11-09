import AppKit
import EventKit
import IleDelbeCore
import Observation
import os

/// Reads the next events from EventKit. Permission is requested lazily; no polling —
/// refreshes on `.EKEventStoreChanged` and via one one-shot work item at the next relevant instant.
@MainActor @Observable
final class CalendarService {
    enum Access: Equatable { case notDetermined, granted, denied }

    private(set) var access: Access
    private(set) var upcoming: [AgendaEvent] = []
    private(set) var infoLine: String?

    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private let log = Logger(subsystem: "io.github.ileDelbe", category: "calendar")
    @ObservationIgnored private var observer: NSObjectProtocol?
    @ObservationIgnored private var scheduled: DispatchWorkItem?

    init() {
        access = Self.currentAccess()
        log.info("calendar access at launch: \(String(describing: self.access))")
        if access == .granted { start() }
    }

    func requestAccessIfNeeded() {
        access = Self.currentAccess()
        guard access == .notDetermined else {
            if access == .granted { start() }
            return
        }
        Task { [store, log] in
            let granted: Bool
            do { granted = try await store.requestFullAccessToEvents() }
            catch { log.error("calendar access request failed: \(error.localizedDescription)"); granted = false }
            self.access = Self.currentAccess()
            log.info("calendar access after request: \(String(describing: self.access)) (granted=\(granted))")
            if self.access == .granted { self.start() }
        }
    }

    func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") else { return }
        NSWorkspace.shared.open(url)
    }

    private static func currentAccess() -> Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    private func start() {
        if observer == nil {
            observer = NotificationCenter.default.addObserver(
                forName: .EKEventStoreChanged, object: store, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
        refresh()
    }

    private func refresh() {
        scheduled?.cancel()
        scheduled = nil
        access = Self.currentAccess()
        guard access == .granted else {
            upcoming = []; infoLine = nil
            return
        }
        let now = Date()
        let predicate = store.predicateForEvents(withStart: now, end: now.addingTimeInterval(Agenda.window), calendars: nil)
        let events = store.events(matching: predicate).map(Self.map)
        upcoming = Agenda.upcoming(events, now: now)
        infoLine = Agenda.infoLine(upcoming, now: now)
        log.info("calendar refresh: \(self.upcoming.count) event(s), info line: \(self.infoLine ?? "none")")
        schedule(now: now)
    }

    /// One-shot: next minute boundary while the line is shown / next start is within 60 min,
    /// the moment the next start enters the 60 min window, and the end of the first event.
    private func schedule(now: Date) {
        var candidates: [Date] = []
        if let next = upcoming.first(where: { $0.start > now }) {
            let untilStart = next.start.timeIntervalSince(now)
            if infoLine != nil || untilStart <= Agenda.soonThreshold {
                let t = now.timeIntervalSince1970
                candidates.append(Date(timeIntervalSince1970: (t / 60).rounded(.down) * 60 + 60))
            } else {
                candidates.append(next.start.addingTimeInterval(-Agenda.soonThreshold))
            }
        }
        if let first = upcoming.first { candidates.append(first.end) }
        guard let fire = candidates.filter({ $0 > now }).min() else { return }
        let item = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.refresh() }
        }
        scheduled = item
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.5, fire.timeIntervalSince(now)), execute: item)
    }

    private nonisolated static func map(_ e: EKEvent) -> AgendaEvent {
        AgendaEvent(
            id: e.eventIdentifier ?? "\(e.title ?? "")-\(e.startDate.timeIntervalSince1970)",
            title: e.title ?? "",
            start: e.startDate, end: e.endDate, isAllDay: e.isAllDay,
            colorHex: e.calendar.flatMap { hex($0.cgColor) },
            meetingURL: MeetingLink.find(in: [e.url?.absoluteString, e.location, e.notes]))
    }

    private nonisolated static func hex(_ color: CGColor?) -> String? {
        guard let rgb = color?.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil),
              let c = rgb.components, c.count >= 3 else { return nil }
        func b(_ v: CGFloat) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", b(c[0]), b(c[1]), b(c[2]))
    }
}
