import IleDelbeCore
import SwiftUI

struct AgendaPaneView: View {
    var access: CalendarService.Access
    var events: [AgendaEvent]
    var now: Date
    var onAppear: () -> Void
    var onJoin: (URL) -> Void
    var onOpenSettings: () -> Void

    private static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        Group {
            switch access {
            case .denied:
                VStack(spacing: 10) {
                    Text("Accès au calendrier refusé")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                    capsuleButton("Ouvrir les Réglages", action: onOpenSettings)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .notDetermined:
                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
            case .granted:
                if events.isEmpty {
                    Text("Aucun événement dans les prochaines 24 h")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 8) {
                        ForEach(Array(events.prefix(2).enumerated()), id: \.element.id) { index, event in
                            card(event, isNext: index == 0)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .onAppear(perform: onAppear)
    }

    private func card(_ event: AgendaEvent, isNext: Bool) -> some View {
        let color = Color(hex: event.colorHex) ?? Color(red: 0.39, green: 0.82, blue: 1)
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(.white).lineLimit(1)
                Text("\(Self.time.string(from: event.start)) – \(Self.time.string(from: event.end)) · \(relative(event))")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            if let url = event.meetingURL {
                capsuleButton("Rejoindre") { onJoin(url) }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(isNext ? color.opacity(0.14) : Color.white.opacity(0.06)))
    }

    private func relative(_ event: AgendaEvent) -> String {
        if event.start <= now { return "en cours" }
        let minutes = max(1, Int((event.start.timeIntervalSince(now) / 60).rounded(.up)))
        if minutes < 60 { return "dans \(minutes) min" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "dans \(h) h" : "dans \(h) h \(m)"
    }

    private func capsuleButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.14)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
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
        .padding(18).frame(width: 548, height: 160).background(Color.black)
}

#Preview("Agenda denied") { agendaPreview(.denied, []) }
#Preview("Agenda empty") { agendaPreview(.granted, []) }
#Preview("Agenda two events") {
    agendaPreview(.granted, [
        AgendaEvent(id: "1", title: "Standup équipe", start: .now.addingTimeInterval(720),
                    end: .now.addingTimeInterval(2520), isAllDay: false, colorHex: "#64D2FF",
                    meetingURL: URL(string: "https://meet.example.com/x")),
        AgendaEvent(id: "2", title: "Déjeuner", start: .now.addingTimeInterval(9000),
                    end: .now.addingTimeInterval(12600), isAllDay: false, colorHex: "#30D158", meetingURL: nil),
    ])
}
#endif
