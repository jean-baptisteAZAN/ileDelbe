import IleDelbeCore
import SwiftUI

enum AgendaText {
    /// « en cours », « dans 12 min », « dans 2 h », « dans 2 h 15 ».
    static func relative(_ event: AgendaEvent, now: Date) -> String {
        if event.start <= now { return "en cours" }
        let minutes = minutesUntil(event, now: now)
        if minutes < 60 { return "dans \(minutes) min" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "dans \(h) h" : "dans \(h) h \(m)"
    }

    /// Whole minutes until the start, rounded up, at least 1.
    static func minutesUntil(_ event: AgendaEvent, now: Date) -> Int {
        max(1, Int((event.start.timeIntervalSince(now) / 60).rounded(.up)))
    }

    /// « 14:30 – 15:00 ».
    static func span(_ event: AgendaEvent) -> String {
        "\(ClockText.string(from: event.start)) – \(ClockText.string(from: event.end))"
    }
}

extension AgendaEvent {
    /// The calendar's color, or the 0.2 light blue.
    var displayColor: Color { Color(hex: colorHex) ?? Color(red: 0.39, green: 0.82, blue: 1) }
}

/// The calendar access states shared by every Agenda view: asks for access on appear (the
/// module is shown), shows the 0.2 denied message and button, nothing while undetermined, the
/// empty message without events, and `content` with the upcoming events otherwise.
struct AgendaAccessView<Content: View>: View {
    enum Layout {
        /// Message above the button, centered (pane).
        case stacked
        /// Message and button on one line (row, card).
        case inline
    }

    var access: CalendarService.Access
    var events: [AgendaEvent]
    var layout: Layout = .stacked
    var onAppear: () -> Void
    var onOpenSettings: () -> Void
    @ViewBuilder var content: ([AgendaEvent]) -> Content

    var body: some View {
        Group {
            switch access {
            case .denied: denied
            case .notDetermined: Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
            case .granted:
                if events.isEmpty {
                    ModuleEmptyText("Aucun événement dans les prochaines 24 h", size: layout == .stacked ? 13 : 12.5)
                } else {
                    content(events)
                }
            }
        }
        .onAppear(perform: onAppear)
    }

    @ViewBuilder
    private var denied: some View {
        let message = Text("Accès au calendrier refusé").font(.system(size: 13)).foregroundStyle(.secondary)
        switch layout {
        case .stacked:
            VStack(spacing: 10) {
                message
                PillButton("Ouvrir les Réglages", kind: .light, action: onOpenSettings)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .inline:
            let button = PillButton("Ouvrir les Réglages", kind: .light, size: .small, action: onOpenSettings)
            // One line when it fits; a narrow card stacks them, or truncates the message if too short.
            ViewThatFits {
                HStack(spacing: 10) {
                    message.lineLimit(1).fixedSize()
                    Spacer(minLength: 0)
                    button
                }
                VStack(alignment: .leading, spacing: 6) {
                    message.lineLimit(1).fixedSize()
                    button
                }
                HStack(spacing: 8) {
                    message.lineLimit(1)
                    Spacer(minLength: 0)
                    button
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}
