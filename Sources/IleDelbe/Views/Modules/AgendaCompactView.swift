import IleDelbeCore
import SwiftUI

/// Île page: the next event, when it starts and « Rejoindre » if it has a meeting link.
/// Without access: the 0.2 message and button. Asks for access on appear, like the pane.
struct AgendaCompactView: View {
    var access: CalendarService.Access
    var events: [AgendaEvent]
    var now: Date
    /// Countdown color. nil = white.
    var accent: Color?
    var onAppear: () -> Void
    var onJoin: (URL) -> Void
    var onOpenSettings: () -> Void

    var body: some View {
        AgendaAccessView(access: access, events: events, layout: .inline, onAppear: onAppear,
                         onOpenSettings: onOpenSettings) { events in
            row(events[0])
        }
    }

    private func row(_ event: AgendaEvent) -> some View {
        HStack(spacing: 14) {
            countdown(event)
                .frame(width: 64)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                Text(AgendaText.span(event))
                    .font(.system(size: 12.5)).foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            if let url = event.meetingURL {
                PillButton("Rejoindre", kind: .solid, size: .small) { onJoin(url) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Minutes left when the event starts within the hour, else its start time.
    private func countdown(_ event: AgendaEvent) -> some View {
        let upcoming = event.start > now
        let minutes = AgendaText.minutesUntil(event, now: now)
        let soon = upcoming && minutes < 60
        return VStack(spacing: 1) {
            Text(soon ? "\(minutes)" : ClockText.string(from: event.start))
                .font(.system(size: soon ? 24 : 19, weight: .bold).monospacedDigit())
                .foregroundStyle(accent ?? event.displayColor)
            Text(soon ? "min" : AgendaText.relative(event, now: now))
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

#if DEBUG
@MainActor private func agendaCompactPreview(_ access: CalendarService.Access, _ events: [AgendaEvent]) -> some View {
    AgendaCompactView(access: access, events: events, now: .now, accent: PreviewSamples.glow, onAppear: {},
                      onJoin: { _ in }, onOpenSettings: {})
        .previewCompactRow()
}

#Preview("Agenda compact, granted") { agendaCompactPreview(.granted, PreviewSamples.events) }
#Preview("Agenda compact, later") { agendaCompactPreview(.granted, Array(PreviewSamples.events.dropFirst())) }
#Preview("Agenda compact, empty") { agendaCompactPreview(.granted, []) }
#Preview("Agenda compact, denied") { agendaCompactPreview(.denied, []) }
#endif
