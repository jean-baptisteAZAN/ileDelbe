import IleDelbeCore
import SwiftUI

/// Grille card: the next event with its countdown in the title, and « Rejoindre ».
/// Same access states and `onAppear` request as the pane.
struct AgendaCardView: View {
    var access: CalendarService.Access
    var events: [AgendaEvent]
    var now: Date
    /// Countdown color in the title. nil = white.
    var accent: Color?
    var onAppear: () -> Void
    var onJoin: (URL) -> Void
    var onOpenSettings: () -> Void

    var body: some View {
        ModuleCard {
            ModuleLabel {
                if access == .granted, let next = events.first {
                    Text("Agenda · \(Text(AgendaText.relative(next, now: now)).foregroundStyle(accent ?? .white))")
                } else {
                    Text("Agenda")
                }
            }
        } content: {
            AgendaAccessView(access: access, events: events, layout: .inline, onAppear: onAppear,
                             onOpenSettings: onOpenSettings) { events in
                row(events[0])
            }
        }
    }

    private func row(_ event: AgendaEvent) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(event.displayColor).frame(width: 3, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                Text(AgendaText.span(event))
                    .font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            if let url = event.meetingURL {
                PillButton("Rejoindre", kind: .solid, size: .small) { onJoin(url) }
            }
        }
    }
}

#if DEBUG
@MainActor private func agendaCardPreview(_ access: CalendarService.Access, _ events: [AgendaEvent]) -> some View {
    AgendaCardView(access: access, events: events, now: .now, accent: PreviewSamples.glow, onAppear: {},
                   onJoin: { _ in }, onOpenSettings: {})
        .previewCard(width: 260, height: 64)
}

#Preview("Agenda card, granted") { agendaCardPreview(.granted, PreviewSamples.events) }
#Preview("Agenda card, empty") { agendaCardPreview(.granted, []) }
#Preview("Agenda card, denied") { agendaCardPreview(.denied, []) }
#endif
