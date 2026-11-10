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
                HStack(spacing: 6) {
                    Spacer(minLength: 0)
                    ShowAllButton(isOn: false, action: onShowAll)
                    SettingsButton(action: onSettings)
                }
            }
            .frame(height: 22)
        }
        .padding(.top, 2)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
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
                        // Generous hit area around a 6 pt dot.
                        .frame(height: 22)
                        .padding(.horizontal, 3)
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
    var timer: CountdownTimer = PreviewSamples.runningTimer
    var timerNow: Date = PreviewSamples.runningNow

    var body: some View {
        IslandStyleView(modules: modules, selected: selected, onSelect: { selected = $0 }, onShowAll: {},
                        onSettings: {}) { module in
            PreviewSamples.compactPage(module, timer: timer, now: timerNow)
        }
        .frame(width: 460, height: 96)
        .padding(.top, 32)
        .background(NotchShape(bottomRadius: NotchShape.openRadius).fill(.black))
        .environment(\.colorScheme, .dark)
    }
}

#Preview("Île, Musique") { IslandPreview(selected: .music) }
#Preview("Île, Minuteur") { IslandPreview(selected: .timer) }
#Preview("Île, Agenda") { IslandPreview(selected: .agenda) }
#Preview("Île, Fichiers") { IslandPreview(selected: .files) }
#Preview("Île, one module") { IslandPreview(modules: [.agenda], selected: .agenda) }
#Preview("Île, ringing") {
    IslandPreview(selected: .timer, timer: PreviewSamples.ringingTimer, timerNow: PreviewSamples.ringingNow)
}
#endif
