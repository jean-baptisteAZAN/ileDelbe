import IleDelbeCore
import SwiftUI

/// Segmented pill of panel tabs + right-aligned info line.
struct TabBarView: View {
    var selected: PanelTab
    var timerActive: Bool
    var infoLine: String?
    var onSelect: (PanelTab) -> Void

    private static func title(_ tab: PanelTab) -> String {
        switch tab {
        case .music: "Musique"
        case .timer: "Minuteur"
        case .agenda: "Agenda"
        case .files: "Fichiers"
        }
    }

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(PanelTab.allCases, id: \.self) { tab in
                    Button { onSelect(tab) } label: {
                        HStack(spacing: 6) {
                            Text(Self.title(tab))
                            if tab == .timer && timerActive {
                                Circle().fill(Color.timerOrange).frame(width: 6, height: 6)
                            }
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tab == selected ? Color.white : Color.white.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(tab == selected ? Color.white.opacity(0.16) : .clear))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Capsule().fill(Color.white.opacity(0.07)))
            Spacer(minLength: 8)
            if let infoLine {
                Text(infoLine)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

#if DEBUG
#Preview("Tab bar") {
    VStack(spacing: 12) {
        TabBarView(selected: .music, timerActive: true, infoLine: "Standup dans 12 min", onSelect: { _ in })
        TabBarView(selected: .agenda, timerActive: false, infoLine: nil, onSelect: { _ in })
    }
    .padding(18).frame(width: 548).background(Color.black)
}
#endif
