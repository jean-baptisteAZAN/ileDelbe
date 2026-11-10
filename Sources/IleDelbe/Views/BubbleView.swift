import IleDelbeCore
import SwiftUI

/// Detached timer bubble: black capsule, flat on top, to the right of the closed notch.
struct BubbleView: View {
    var timer: CountdownTimer
    var now: Date

    static let width: CGFloat = 76
    /// The pill's height: the screen's notch (menu bar) height, 32 on hardware.
    var height: CGFloat = 32

    var body: some View {
        HStack(spacing: 6) {
            TimerRingView(progress: timer.progress(at: now), size: 16, lineWidth: 2.5)
            Text(TimerText.string(timer.remaining(at: now)))
                .font(.system(size: 12.5, weight: .semibold).monospacedDigit())
                .foregroundStyle(Color.timerOrange)
        }
        .frame(width: Self.width, height: height)
        .background(NotchShape(bottomRadius: 16).fill(Color.black))
    }
}

#if DEBUG
#Preview("Bubble") {
    var t = CountdownTimer()
    t.start(duration: 600, now: .now)
    return BubbleView(timer: t, now: .now.addingTimeInterval(125))
        .padding().background(Color.gray.opacity(0.3))
}
#endif
