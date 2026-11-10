import IleDelbeCore
import SwiftUI

/// Grille card. Same states and actions as the Île page, in a smaller card.
struct TimerCardView: View {
    var timer: CountdownTimer
    var now: Date
    var presetsMinutes: [Int] = AppSettings.default.timerPresetsMinutes
    var onStart: (TimeInterval) -> Void
    var onAddMinute: () -> Void
    var onPause: () -> Void
    var onResume: () -> Void
    var onStop: () -> Void
    var onAcknowledge: () -> Void

    var body: some View {
        ModuleCard {
            ModuleLabel {
                if let line = TimerText.endLine(timer) {
                    Text("Minuteur · \(line)")
                } else {
                    Text("Minuteur")
                }
            }
        } content: {
            HStack(spacing: 8) {
                switch timer.phase {
                case .idle:
                    TimerPresetButtons(presetsMinutes: presetsMinutes, size: .small, onStart: onStart)
                    Spacer(minLength: 0)
                case let .active(paused):
                    TimerRingView(progress: timer.progress(at: now), size: 24, lineWidth: 3)
                    TimerRemainingText(timer: timer, now: now, size: 17)
                    Spacer(minLength: 0)
                    TimerActiveButtons(paused: paused, onAddMinute: onAddMinute, onPause: onPause,
                                       onResume: onResume, onStop: onStop)
                        .layoutPriority(1)
                case .ringing:
                    Image(systemName: "bell.fill").foregroundStyle(Color.timerOrange)
                    Text("Minuteur terminé")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.timerOrange)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    PillButton("OK", kind: .timer, size: .small, action: onAcknowledge)
                }
            }
        }
    }
}

#if DEBUG
@MainActor private func timerCardPreview(_ timer: CountdownTimer, now: Date = .now) -> some View {
    TimerCardView(timer: timer, now: now, onStart: { _ in }, onAddMinute: {}, onPause: {}, onResume: {},
                  onStop: {}, onAcknowledge: {})
        .previewCard(width: 260, height: 64)
}

#Preview("Timer card, idle") { timerCardPreview(PreviewSamples.idleTimer) }
#Preview("Timer card, running") { timerCardPreview(PreviewSamples.runningTimer, now: PreviewSamples.runningNow) }
#Preview("Timer card, ringing") { timerCardPreview(PreviewSamples.ringingTimer, now: PreviewSamples.ringingNow) }
#endif
