import IleDelbeCore
import SwiftUI

/// Timer tab. `now` is supplied by the caller; the view owns no timers.
struct TimerPaneView: View {
    var timer: CountdownTimer
    var now: Date
    /// The three durations offered at rest, in minutes (from the settings).
    var presetsMinutes: [Int] = AppSettings.default.timerPresetsMinutes
    var onStart: (TimeInterval) -> Void
    var onAddMinute: () -> Void
    var onPause: () -> Void
    var onResume: () -> Void
    var onStop: () -> Void
    var onAcknowledge: () -> Void

    var body: some View {
        switch timer.phase {
        case .idle: idle
        case let .active(paused): active(paused: paused)
        case .ringing: ringing
        }
    }

    private var idle: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lancer un minuteur")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            TimerPresetButtons(presetsMinutes: presetsMinutes, onStart: onStart)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.leading, 6)
    }

    private func active(paused: Bool) -> some View {
        HStack(spacing: 20) {
            ZStack {
                TimerRingView(progress: timer.progress(at: now), size: 104, lineWidth: 7)
                TimerRemainingText(timer: timer, now: now, size: 24)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    PillButton("+1 min", kind: .timer, action: onAddMinute)
                    PillButton(paused ? "Reprendre" : "Pause", action: paused ? onResume : onPause)
                }
                PillButton("Arrêter", action: onStop)
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
    }

    private var ringing: some View {
        VStack(spacing: 12) {
            Text("Minuteur terminé")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.timerOrange)
            PillButton("OK", kind: .timer, action: onAcknowledge)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if DEBUG
@MainActor private func previewPane(_ timer: CountdownTimer, now: Date = .now) -> some View {
    TimerPaneView(timer: timer, now: now, onStart: { _ in }, onAddMinute: {}, onPause: {},
                  onResume: {}, onStop: {}, onAcknowledge: {})
        .previewPanel(width: 548, height: 160)
}

#Preview("Timer idle") { previewPane(PreviewSamples.idleTimer) }
#Preview("Timer active") { previewPane(PreviewSamples.runningTimer, now: PreviewSamples.runningNow) }
#Preview("Timer ringing") { previewPane(PreviewSamples.ringingTimer, now: PreviewSamples.ringingNow) }
#endif
