import SwiftUI

extension Color {
    /// Timer accent (iOS orange).
    static let timerOrange = Color(red: 1, green: 0.62, blue: 0.04)
}

enum TimerText {
    /// "mm:ss", rounding up so the display never shows 00:00 while still running.
    static func string(_ remaining: TimeInterval) -> String {
        let total = max(0, Int(remaining.rounded(.up)))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

/// Circular progress ring (remaining fraction). Static: no animation or timer of its own.
struct TimerRingView: View {
    var progress: Double
    var size: CGFloat
    var lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(Color.timerOrange.opacity(0.22), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(Color.timerOrange, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}
