import SwiftUI

/// Building blocks shared by the module views at every size.

enum ClockText {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    /// "HH:mm".
    static func string(from date: Date) -> String { formatter.string(from: date) }
}

/// Small uppercase section title (« Écoutés récemment », « Récents », card titles).
struct ModuleLabel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .font(.system(size: 10.5, weight: .semibold))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}

extension ModuleLabel where Content == Text {
    init(_ title: String) { self.init { Text(title) } }
}

/// Capsule text button used by every module (timer durations, « Rejoindre », « OK »…).
struct PillButton: View {
    enum Kind {
        /// Orange on orange tint (timer).
        case timer
        /// White on a faint white fill.
        case neutral
        /// White on a lighter white fill (Agenda pane).
        case light
        /// Black on white (« Rejoindre » in rows and cards).
        case solid
    }

    enum Size {
        /// The 0.2 panes.
        case regular
        /// Rows and cards.
        case small
    }

    var title: String
    var kind: Kind = .neutral
    var size: Size = .regular
    var action: () -> Void

    init(_ title: String, kind: Kind = .neutral, size: Size = .regular, action: @escaping () -> Void) {
        self.title = title
        self.kind = kind
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: size == .regular ? 12 : 11.5, weight: .semibold))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, size == .regular ? 14 : 10)
                .padding(.vertical, verticalPadding)
                .background(Capsule().fill(background))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var verticalPadding: CGFloat {
        switch (size, kind) {
        case (.small, _): 5
        case (.regular, .light): 6
        case (.regular, _): 7
        }
    }

    private var foreground: Color {
        switch kind {
        case .timer: .timerOrange
        case .neutral, .light: .white
        case .solid: .black
        }
    }

    private var background: Color {
        switch kind {
        case .timer: Color.timerOrange.opacity(0.2)
        case .neutral: Color.white.opacity(0.1)
        case .light: Color.white.opacity(0.14)
        case .solid: .white
        }
    }
}

/// Circular icon button with the same fills as `PillButton` (narrow cards).
struct PillIconButton: View {
    var systemName: String
    var help: String
    var kind: PillButton.Kind = .neutral
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(kind == .timer ? Color.timerOrange : .white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(kind == .timer ? Color.timerOrange.opacity(0.2) : Color.white.opacity(0.1)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

/// Card chrome for the grid: dark rounded tile, optional title on top, content below.
struct ModuleCard<Title: View, Content: View>: View {
    @ViewBuilder var title: Title
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            title
            content
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.cardFill))
    }
}

extension ModuleCard where Title == ModuleLabel<Text> {
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.init(title: { ModuleLabel(title) }, content: content)
    }
}

extension ModuleCard where Title == EmptyView {
    init(@ViewBuilder content: () -> Content) {
        self.init(title: { EmptyView() }, content: content)
    }
}

/// Secondary message centered in the space left (« Rien en lecture », « Aucun fichier récent »…).
struct ModuleEmptyText: View {
    var text: String
    var size: CGFloat = 13

    init(_ text: String, size: CGFloat = 13) {
        self.text = text
        self.size = size
    }

    var body: some View {
        Text(text)
            .font(.system(size: size))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension Color {
    /// Card and tile background (#141418).
    static let cardFill = Color(red: 20 / 255, green: 20 / 255, blue: 24 / 255)
}
