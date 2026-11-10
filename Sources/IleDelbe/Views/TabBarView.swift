import IleDelbeCore
import SwiftUI

/// Segmented pill of the visible modules, in settings order, + right-aligned info line and the gear.
struct TabBarView: View {
    var tabs: [PanelTab]
    var selected: PanelTab?
    var timerActive: Bool
    var infoLine: String?
    var onSelect: (PanelTab) -> Void
    var onSettings: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(tabs, id: \.self) { tab in
                    Button { onSelect(tab) } label: {
                        HStack(spacing: 6) {
                            Text(tab.title)
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
            SettingsButton(action: onSettings)
        }
    }
}

#if DEBUG
#Preview("Tab bar") {
    VStack(spacing: 12) {
        TabBarView(tabs: PanelTab.allCases, selected: .music, timerActive: true, infoLine: "Standup dans 12 min",
                   onSelect: { _ in }, onSettings: {})
        TabBarView(tabs: [.agenda, .files], selected: .agenda, timerActive: false, infoLine: nil, onSelect: { _ in },
                   onSettings: {})
    }
    .padding(18).frame(width: 548).background(Color.black)
}
#endif
