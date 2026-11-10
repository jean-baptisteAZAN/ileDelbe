import IleDelbeCore
import SwiftUI

struct AgendaPaneView: View {
    var access: CalendarService.Access
    var events: [AgendaEvent]
    var now: Date
    var onAppear: () -> Void
    var onJoin: (URL) -> Void
    var onOpenSettings: () -> Void

    var body: some View {
        AgendaAccessView(access: access, events: events, onAppear: onAppear, onOpenSettings: onOpenSettings) { events in
            VStack(spacing: 8) {
                ForEach(Array(events.prefix(2).enumerated()), id: \.element.id) { index, event in
                    card(event, isNext: index == 0)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func card(_ event: AgendaEvent, isNext: Bool) -> some View {
        let color = event.displayColor
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(.white).lineLimit(1)
                Text("\(AgendaText.span(event)) · \(AgendaText.relative(event, now: now))")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            if let url = event.meetingURL {
                PillButton("Rejoindre", kind: .light) { onJoin(url) }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(isNext ? color.opacity(0.14) : Color.white.opacity(0.06)))
    }
}

extension Color {
    /// "#RRGGBB" (leading # optional); nil if malformed.
    init?(hex: String?) {
        guard let s = hex?.trimmingCharacters(in: CharacterSet(charactersIn: "#")), s.count == 6,
              let v = UInt32(s, radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }
}

#if DEBUG
@MainActor private func agendaPreview(_ access: CalendarService.Access, _ events: [AgendaEvent]) -> some View {
    AgendaPaneView(access: access, events: events, now: .now, onAppear: {}, onJoin: { _ in }, onOpenSettings: {})
        .previewPanel(width: 548, height: 160)
}

#Preview("Agenda denied") { agendaPreview(.denied, []) }
#Preview("Agenda empty") { agendaPreview(.granted, []) }
#Preview("Agenda two events") { agendaPreview(.granted, PreviewSamples.events) }
#endif
