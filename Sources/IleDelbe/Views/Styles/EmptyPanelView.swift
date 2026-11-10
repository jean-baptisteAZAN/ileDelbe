import SwiftUI

/// Every module hidden: the message, and the gear to bring some back. Any style.
struct EmptyPanelView: View {
    var onSettings: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text("Aucun module affiché")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            SettingsButton(action: onSettings)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 8)
    }
}

#if DEBUG
#Preview("Empty panel") {
    EmptyPanelView(onSettings: {})
        .frame(width: 300, height: 80)
        .background(Color.black)
}
#endif
