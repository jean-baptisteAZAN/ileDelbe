import IleDelbeCore
import SwiftUI

/// Grille (and the Île « Tout voir »): the Musique card on the left and the other modules
/// stacked on the right, in settings order; without Musique, the cards go on two columns.
/// The gear sits in the bottom-right corner. Lays out the area below the notch band; the
/// height comes from `PanelSizing`, the cards stretch to fill it.
struct GridStyleView<Card: View>: View {
    var modules: [PanelTab]
    /// Île « Tout voir »: the highlighted grid button, back to the pages. It sits exactly where
    /// the Île's « Tout voir » button is (`IslandMetrics.showAllCenter`), over the cards, so the
    /// pointer stays inside the panel when it shrinks back to the Île.
    var onShowPages: (() -> Void)?
    var onSettings: () -> Void
    @ViewBuilder var card: (PanelTab) -> Card

    private static var spacing: CGFloat { PanelSizing.gridRowSpacing }

    var body: some View {
        VStack(spacing: 8) {
            cards
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 6) {
                Spacer(minLength: 0)
                SettingsButton(action: onSettings)
            }
            .frame(height: 20)
        }
        .padding(.top, 6)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .overlay(alignment: .top) {
            if let onShowPages {
                let c = IslandMetrics.showAllCenter
                ShowAllButton(isOn: true, action: onShowPages)
                    // Black ring: reads over a card.
                    .background(Circle().fill(Color.black).padding(-3))
                    .offset(x: c.x, y: c.y - PanelIconButton.size / 2)
            }
        }
    }

    @ViewBuilder
    private var cards: some View {
        let others = modules.filter { $0 != .music }
        if modules.contains(.music) {
            if others.isEmpty {
                card(.music)
            } else {
                GeometryReader { proxy in
                    // Columns 1.3 : 1, as in the mock-up.
                    let musicWidth = ((proxy.size.width - Self.spacing) * 1.3 / 2.3).rounded()
                    HStack(spacing: Self.spacing) {
                        card(.music).frame(width: musicWidth)
                        CardStack(spacing: Self.spacing) {
                            ForEach(others, id: \.self) { card($0) }
                        }
                    }
                }
            }
        } else {
            CardStack(spacing: Self.spacing) {
                ForEach(Array(stride(from: 0, to: others.count, by: 2)), id: \.self) { i in
                    HStack(spacing: Self.spacing) {
                        card(others[i])
                        if i + 1 < others.count {
                            card(others[i + 1])
                        } else {
                            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
        }
    }
}

/// Vertical stack of cards in a fixed height: each card gets its ideal height, and the space
/// left is shared equally, so a taller card (Agenda without access, five files) is not cut
/// while the panel height stays a constant per case. Squeezes proportionally if it cannot fit.
struct CardStack: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let ideal = idealHeights(width: width, subviews: subviews)
        return CGSize(width: width, height: proposal.height ?? ideal.reduce(0, +) + totalSpacing(subviews))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let ideal = idealHeights(width: bounds.width, subviews: subviews)
        let available = max(0, bounds.height - totalSpacing(subviews))
        let sum = ideal.reduce(0, +)
        let extra = (available - sum) / CGFloat(subviews.count)
        var y = bounds.minY
        for (subview, h) in zip(subviews, ideal) {
            let height = extra >= 0 ? h + extra : (sum > 0 ? h * available / sum : 0)
            subview.place(at: CGPoint(x: bounds.minX, y: y), anchor: .topLeading,
                          proposal: ProposedViewSize(width: bounds.width, height: height))
            y += height + spacing
        }
    }

    private func idealHeights(width: CGFloat, subviews: Subviews) -> [CGFloat] {
        subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }
    }

    private func totalSpacing(_ subviews: Subviews) -> CGFloat {
        spacing * CGFloat(max(0, subviews.count - 1))
    }
}

#if DEBUG
@MainActor private func gridPreview(_ modules: [PanelTab], showsAll: Bool = false, notchHeight: CGFloat = 32) -> some View {
    let size = PanelSizing.size(style: .grid, showsAll: false, modules: modules, density: .normal, notchHeight: notchHeight)
    return GridStyleView(modules: modules, onShowPages: showsAll ? {} : nil, onSettings: {}) {
        PreviewSamples.card($0)
    }
    .frame(width: size.width, height: size.height - notchHeight)
    .padding(.top, notchHeight)
    .background(NotchShape(bottomRadius: NotchShape.openRadius).fill(.black))
    .environment(\.colorScheme, .dark)
}

#Preview("Grille, all") { gridPreview(PanelTab.allCases) }
#Preview("Grille, Tout voir") { gridPreview(PanelTab.allCases, showsAll: true) }
#Preview("Grille, music only") { gridPreview([.music]) }
#Preview("Grille, no music") { gridPreview([.timer, .agenda, .files]) }
#Preview("Grille, virtual notch 24") { gridPreview(PanelTab.allCases, notchHeight: 24) }
@MainActor private func emptyPreview(notchHeight: CGFloat) -> some View {
    EmptyPanelView(onSettings: {})
        .frame(width: 300, height: 80)
        .padding(.top, notchHeight)
        .background(NotchShape(bottomRadius: NotchShape.openRadius).fill(.black))
        .environment(\.colorScheme, .dark)
}

#Preview("Grille, empty") { emptyPreview(notchHeight: 32) }
#Preview("Grille, empty, virtual notch 24") { emptyPreview(notchHeight: 24) }
#endif
