import IleDelbeCore
import SwiftUI

/// Content of the closed pill. The middle (hardware notch) is always left empty.
struct ClosedActivityView: View {
    var layout: ClosedLayout
    /// Widths of the left and right wings actually drawn (independent: title mode is asymmetric).
    var wings: ClosedWings
    var artworkData: Data?
    var isPlaying: Bool
    var timer: CountdownTimer
    var now: Date
    /// Accent while playing (artwork shadow, equalizer); nil = no glow, white equalizer.
    var glow: Color?
    /// Halo intensity multiplier (1 = the 0.2 look).
    var haloScale: Double = 1
    /// « titre · artiste » for the title style.
    var title: String = ""
    var showsTitle = false
    /// False: nothing moves (static equalizer, no scrolling, steady alert).
    var motion = true

    var body: some View {
        switch layout {
        case .plain:
            Color.clear
        case .media, .mediaAndBubble:
            HStack(spacing: 0) {
                ArtworkView(data: artworkData, size: 20, cornerRadius: 4)
                    .shadow(color: glow?.haloOpacity(0.9, scale: haloScale) ?? .clear, radius: 11)
                    .frame(width: wings.left)
                Spacer(minLength: 0)
                if showsTitle {
                    MarqueeText(text: title, isActive: motion && isPlaying)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 8)
                        .frame(width: wings.right)
                } else {
                    EqualizerView(isPlaying: isPlaying, color: glow ?? .white, animated: motion)
                        .frame(width: wings.right)
                }
            }
        case .timer:
            HStack(spacing: 0) {
                Image(systemName: "timer")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.timerOrange)
                    .frame(width: wings.left)
                Spacer(minLength: 0)
                Text(TimerText.string(timer.remaining(at: now)))
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color.timerOrange)
                    .minimumScaleFactor(0.8)
                    .frame(width: wings.right)
            }
        case .alert:
            AlertPulse(wings: wings, pulses: motion)
        }
    }
}

/// "Minuteur terminé" pulse. The animation exists only while this view is in the hierarchy
/// (i.e. while the layout is `.alert`).
private struct AlertPulse: View {
    var wings: ClosedWings
    var pulses: Bool
    @State private var dim = false

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "bell.fill")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: wings.left)
            Spacer(minLength: 0)
            Text("Minuteur terminé")
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(width: wings.right)
        }
        .foregroundStyle(Color.timerOrange)
        .opacity(pulses && dim ? 0.35 : 1)
        .onChange(of: pulses) { _, on in
            if on { withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { dim = true } }
            else { withAnimation(nil) { dim = false } }
        }
        .accessibilityLabel("Minuteur terminé")
        .onAppear { guard pulses else { return }; withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { dim = true } }
    }
}
