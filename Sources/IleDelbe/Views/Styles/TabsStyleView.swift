import IleDelbeCore
import SwiftUI

/// Onglets: the 0.2 look, a tab bar of the visible modules (gear on the right) over the full pane.
/// Lays out the area below the notch band.
struct TabsStyleView: View {
    let model: NotchViewModel
    var selected: PanelTab

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TabBarView(tabs: model.modules, selected: selected, timerActive: model.timer.timer.isActive,
                       infoLine: model.settings.settings.visibleModules.contains(.agenda)
                           ? model.calendar.infoLine : nil,
                       onSelect: { model.select($0) }, onSettings: { model.openSettings() })
            ModuleView(module: selected, size: .full, model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.top, 6)
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }
}
