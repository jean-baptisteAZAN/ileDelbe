import IleDelbeCore
import SwiftUI

/// Île: one compact page at a time, the pagination dots, « Tout voir » and the gear.
/// Lays out the area below the notch band. Only the current page is built, so a page that is
/// not on screen runs no timeline and never asks for calendar access.
struct IslandStyleView<Page: View>: View {
    var modules: [PanelTab]
    var selected: PanelTab
    var onSelect: (PanelTab) -> Void
    var onShowAll: () -> Void
    var onSettings: () -> Void
    @ViewBuilder var page: (PanelTab) -> Page

    static var pageSpring: Animation { .spring(response: 0.38, dampingFraction: 0.86) }

    /// The page on screen. Lags `selected` by one update so the slide direction is in place
    /// on the outgoing page before it is removed (a removed view keeps its last transition).
    @State private var displayed: PanelTab
    @State private var forward = true

    init(modules: [PanelTab], selected: PanelTab, onSelect: @escaping (PanelTab) -> Void,
         onShowAll: @escaping () -> Void, onSettings: @escaping () -> Void,
         @ViewBuilder page: @escaping (PanelTab) -> Page) {
        self.modules = modules
        self.selected = selected
        self.onSelect = onSelect
        self.onShowAll = onShowAll
        self.onSettings = onSettings
        self.page = page
        _displayed = State(initialValue: selected)
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                page(displayed)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(displayed)
                    .transition(.push(from: forward ? .trailing : .leading))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            ZStack {
                if modules.count > 1 { dots }
                HStack(spacing: IslandMetrics.buttonSpacing) {
                    Spacer(minLength: 0)
                    ShowAllButton(isOn: false, action: onShowAll)
                    SettingsButton(action: onSettings)
                }
            }
            .frame(height: IslandMetrics.rowHeight)
        }
        .padding(.top, 2)
        .padding(.horizontal, IslandMetrics.horizontalInset)
        .padding(.bottom, IslandMetrics.bottomInset)
        .onChange(of: selected) { _, new in
            let from = modules.firstIndex(of: displayed) ?? 0
            forward = (modules.firstIndex(of: new) ?? 0) >= from
            Task { @MainActor in
                withAnimation(Self.pageSpring) { displayed = new }
            }
        }
    }

    private var dots: some View {
        HStack(spacing: 0) {
            ForEach(modules, id: \.self) { module in
                let on = module == selected
                Button { onSelect(module) } label: {
                    Capsule()
                        .fill(Color.white.opacity(on ? 0.9 : 0.28))
                        .frame(width: on ? 18 : 6, height: 6)
                        // Hit area of at least 20 × 22 pt around a 6 pt dot.
                        .frame(minWidth: 20, minHeight: IslandMetrics.rowHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(module.title)
                .accessibilityLabel(module.title)
            }
        }
        .animation(Self.pageSpring, value: selected)
    }
}

/// Île control row geometry, shared with the « Tout voir » Grille so its return button sits
/// on the very spot of the Île's « Tout voir » button: when the panel shrinks back to the
/// pages, the pointer is still on that button, inside the Île.
@MainActor enum IslandMetrics {
    static let horizontalInset: CGFloat = 16
    static let bottomInset: CGFloat = 6
    static let rowHeight: CGFloat = 22
    static let buttonSpacing: CGFloat = 6

    /// Center of the « Tout voir » button, from the top center of the area below the notch band
    /// (layout points, before the Compacte scale, which both styles share).
    static var showAllCenter: CGPoint {
        CGPoint(x: PanelSizing.islandWidth / 2 - horizontalInset - PanelIconButton.size - buttonSpacing
                    - PanelIconButton.size / 2,
                y: PanelSizing.islandContentHeight - bottomInset - rowHeight / 2)
    }
}

extension PanelTab {
    /// Module name, as in the tab bar and the settings.
    var title: String {
        switch self {
        case .music: "Musique"
        case .timer: "Minuteur"
        case .agenda: "Agenda"
        case .files: "Fichiers"
        }
    }
}

#if DEBUG
@MainActor private struct IslandPreview: View {
    var modules: [PanelTab] = PanelTab.allCases
    @State var selected: PanelTab
    var notchHeight: CGFloat = 32
    var timer: CountdownTimer = PreviewSamples.runningTimer
    var timerNow: Date = PreviewSamples.runningNow

    var body: some View {
        IslandStyleView(modules: modules, selected: selected, onSelect: { selected = $0 }, onShowAll: {},
                        onSettings: {}) { module in
            PreviewSamples.compactPage(module, timer: timer, now: timerNow)
        }
        .frame(width: 460, height: 96)
        .padding(.top, notchHeight)
        .background(NotchShape(bottomRadius: NotchShape.openRadius).fill(.black))
        .environment(\.colorScheme, .dark)
    }
}

#Preview("Île, virtual notch 24") { IslandPreview(selected: .music, notchHeight: 24) }
#Preview("Île, Musique") { IslandPreview(selected: .music) }
#Preview("Île, Minuteur") { IslandPreview(selected: .timer) }
#Preview("Île, Agenda") { IslandPreview(selected: .agenda) }
#Preview("Île, Fichiers") { IslandPreview(selected: .files) }
#Preview("Île, one module") { IslandPreview(modules: [.agenda], selected: .agenda) }
#Preview("Île, ringing") {
    IslandPreview(selected: .timer, timer: PreviewSamples.ringingTimer, timerNow: PreviewSamples.ringingNow)
}
#endif
