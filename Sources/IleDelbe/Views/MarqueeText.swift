import SwiftUI

/// One-line text that scrolls back and forth when it is wider than its frame and `isActive`.
/// Otherwise it is truncated with a tail ellipsis. The timeline runs at 15 fps at most and
/// exists only while scrolling (no work when inactive or when the text fits).
struct MarqueeText: View {
    var text: String
    var isActive: Bool
    var font: Font = .system(size: 11, weight: .medium)

    /// Pixels per second, and the wait at each end.
    private static let speed: Double = 22
    private static let pause: Double = 1.5

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var start = Date()

    private var overflow: CGFloat { max(0, textWidth - containerWidth) }
    private var scrolls: Bool { isActive && overflow > 0.5 }

    var body: some View {
        Group {
            if scrolls {
                TimelineView(.animation(minimumInterval: 1.0 / 15, paused: false)) { context in
                    label.fixedSize().offset(x: -Self.offset(overflow: overflow,
                                                              elapsed: context.date.timeIntervalSince(start)))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                label.truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: overflow > 0 ? .leading : .center)
            }
        }
        .clipped()
        .background(GeometryReader { g in
            Color.clear.onAppear { containerWidth = g.size.width }
                .onChange(of: g.size.width) { _, w in containerWidth = w }
        })
        .background(
            // Natural (unconstrained) width of the text.
            label.fixedSize().hidden()
                .background(GeometryReader { g in
                    Color.clear.onAppear { textWidth = g.size.width }
                        .onChange(of: g.size.width) { _, w in textWidth = w }
                })
        )
        .onChange(of: scrolls) { _, _ in start = Date() }
        .onChange(of: text) { _, _ in start = Date() }
        .accessibilityLabel(text)
    }

    private var label: some View {
        Text(text).font(font).lineLimit(1)
    }

    /// Ping-pong: wait, travel to the end, wait, travel back.
    static func offset(overflow: CGFloat, elapsed: TimeInterval) -> CGFloat {
        let travel = Double(overflow) / speed
        let cycle = 2 * (pause + travel)
        let t = elapsed.truncatingRemainder(dividingBy: cycle)
        if t < pause { return 0 }
        if t < pause + travel { return CGFloat((t - pause) * speed) }
        if t < 2 * pause + travel { return overflow }
        return overflow - CGFloat((t - 2 * pause - travel) * speed)
    }
}

#if DEBUG
#Preview("Marquee") {
    VStack(spacing: 8) {
        MarqueeText(text: "Titre court · Artiste", isActive: true)
        MarqueeText(text: "Un titre vraiment très long qui dépasse · Un artiste", isActive: true)
        MarqueeText(text: "Un titre vraiment très long qui dépasse · Un artiste", isActive: false)
    }
    .foregroundStyle(.white)
    .frame(width: 120).padding().background(.black)
}
#endif
