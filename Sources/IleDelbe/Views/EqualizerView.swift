import SwiftUI

/// Four-bar equalizer. Animates only while `isPlaying`; the timeline is paused otherwise (no idle CPU).
struct EqualizerView: View {
    var isPlaying: Bool
    var color: Color = .white

    private let barCount = 4
    private let maxHeight: CGFloat = 14
    private let minHeight: CGFloat = 3

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15, paused: !isPlaying)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<barCount, id: \.self) { i in
                    Capsule()
                        .fill(color)
                        .frame(width: 2.5, height: height(for: i, at: t))
                        .animation(.linear(duration: 1.0 / 15), value: height(for: i, at: t))
                }
            }
            .frame(height: maxHeight)
        }
        .accessibilityHidden(true)
    }

    private func height(for index: Int, at t: TimeInterval) -> CGFloat {
        guard isPlaying else { return minHeight + 2 }
        let speed = 4.0 + Double(index) * 1.3
        let phase = Double(index) * 1.7
        let v = (sin(t * speed + phase) + 1) / 2
        return minHeight + CGFloat(v) * (maxHeight - minHeight)
    }
}
