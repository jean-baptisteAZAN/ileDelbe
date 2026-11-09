import IleDelbeCore
import SwiftUI

/// Content of the closed pill. The middle (hardware notch) is always left empty.
struct ClosedActivityView: View {
    var layout: ClosedLayout
    var artworkData: Data?
    var isPlaying: Bool
    var timer: CountdownTimer
    var now: Date
    var glow: Color?

    var body: some View {
        switch layout {
        case .plain:
            Color.clear
        case .media, .mediaAndBubble:
            HStack(spacing: 0) {
                ArtworkView(data: artworkData, size: 20, cornerRadius: 4)
                    .shadow(color: glow?.opacity(0.9) ?? .clear, radius: 11)
                    .frame(width: NotchGeometry.closedActiveWing)
                Spacer(minLength: 0)
                EqualizerView(isPlaying: isPlaying)
                    .frame(width: NotchGeometry.closedActiveWing)
            }
        case .timer:
            HStack(spacing: 0) {
                Image(systemName: "timer")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.timerOrange)
                    .frame(width: NotchGeometry.closedActiveWing)
                Spacer(minLength: 0)
                Text(TimerText.string(timer.remaining(at: now)))
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color.timerOrange)
                    .minimumScaleFactor(0.8)
                    .frame(width: NotchGeometry.closedActiveWing)
            }
        case .alert:
            AlertPulse()
        }
    }
}

/// "Minuteur terminé" pulse. The animation exists only while this view is in the hierarchy
/// (i.e. while the layout is `.alert`).
private struct AlertPulse: View {
    @State private var dim = false

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "bell.fill")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: NotchGeometry.alertWing)
            Spacer(minLength: 0)
            Text("Minuteur terminé")
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(width: NotchGeometry.alertWing)
        }
        .foregroundStyle(Color.timerOrange)
        .opacity(dim ? 0.35 : 1)
        .accessibilityLabel("Minuteur terminé")
        .onAppear { withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { dim = true } }
    }
}
