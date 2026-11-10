import IleDelbeCore
import SwiftUI

/// The open panel's content below the notch band, laid out at the Normale size (the root view
/// scales it for Compacte). Picks the layout from the style and « Tout voir »; with no module
/// visible, every style shows « Aucun module affiché » and the gear.
struct PanelContentView: View {
    let model: NotchViewModel

    var body: some View {
        if let selected = model.shownTab {
            switch model.settings.settings.style {
            case .tabs:
                TabsStyleView(model: model, selected: selected)
            case .grid:
                grid(onShowPages: nil)
            case .island:
                if model.showsAll {
                    grid(onShowPages: { toggleShowsAll() })
                        .transition(.opacity)
                } else {
                    IslandStyleView(modules: model.modules, selected: selected, onSelect: { model.select($0) },
                                    onShowAll: { toggleShowsAll() }, onSettings: { model.openSettings() }) {
                        ModuleView(module: $0, size: .compact, model: model)
                    }
                    .transition(.opacity)
                }
            }
        } else {
            EmptyPanelView(onSettings: { model.openSettings() })
        }
    }

    private func grid(onShowPages: (() -> Void)?) -> some View {
        GridStyleView(modules: model.modules, onShowPages: onShowPages, onSettings: { model.openSettings() }) {
            ModuleView(module: $0, size: .card, model: model)
        }
    }

    /// Pages ⇄ grid in the same panel; the root view springs the size along.
    private func toggleShowsAll() {
        withAnimation(IslandStyleView<EmptyView>.pageSpring) { model.showsAll.toggle() }
    }
}
