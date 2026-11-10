import SwiftUI

/// Small round icon button of the panel chrome (the gear, « Tout voir »).
struct PanelIconButton: View {
    static let size: CGFloat = 22

    var systemName: String
    var help: String
    /// Highlighted (« Tout voir » while the grid is shown).
    var isOn = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(isOn ? Color.white : Color.white.opacity(0.6))
                .frame(width: Self.size, height: Self.size)
                .background(Circle().fill(Color.white.opacity(isOn ? 0.18 : 0.08)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

/// The gear: opens « Réglages ileDelbe » (the panel closes first).
struct SettingsButton: View {
    var action: () -> Void

    var body: some View {
        PanelIconButton(systemName: "gearshape.fill", help: "Réglages…", action: action)
    }
}

/// « Tout voir »: switches the Île between its pages and the grid. The same button, at the
/// same place on screen, brings the pages back (`isOn`).
struct ShowAllButton: View {
    var isOn: Bool
    var action: () -> Void

    var body: some View {
        PanelIconButton(systemName: "square.grid.2x2.fill", help: isOn ? "Revenir aux pages" : "Tout voir",
                        isOn: isOn, action: action)
    }
}

#if DEBUG
#Preview("Panel buttons") {
    HStack(spacing: 8) {
        ShowAllButton(isOn: false) {}
        ShowAllButton(isOn: true) {}
        SettingsButton {}
    }
    .padding(16)
    .background(Color.black)
}
#endif
