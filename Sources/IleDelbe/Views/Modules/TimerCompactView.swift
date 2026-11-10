import IleDelbeCore
import SwiftUI

/// Île page. At rest: the three durations. Running: ring, time left, end time, +1 min,
/// Pause/Reprendre, Arrêter. Ringing: « OK », also when the module is hidden.
struct TimerCompactView: View {
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
        HStack(spacing: 14) {
            switch timer.phase {
            case .idle:
                titles("Minuteur", "Choisis une durée")
                TimerPresetButtons(presetsMinutes: presetsMinutes, size: .small, onStart: onStart)
            case let .active(paused):
                TimerRingView(progress: timer.progress(at: now), size: 56, lineWidth: 5)
                VStack(alignment: .leading, spacing: 1) {
                    TimerRemainingText(timer: timer, now: now, size: 26)
                    if let line = TimerText.endLine(timer) {
                        Text(line).font(.system(size: 12.5)).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                TimerActiveButtons(paused: paused, onAddMinute: onAddMinute, onPause: onPause,
                                   onResume: onResume, onStop: onStop)
                    .layoutPriority(1)
            case .ringing:
                Image(systemName: "bell.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.timerOrange)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.timerOrange.opacity(0.18)))
                Text("Minuteur terminé")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.timerOrange)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                PillButton("OK", kind: .timer, action: onAcknowledge)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func titles(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            Text(subtitle).font(.system(size: 12.5)).foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
@MainActor private func timerCompactPreview(_ timer: CountdownTimer, now: Date = .now) -> some View {
    TimerCompactView(timer: timer, now: now, onStart: { _ in }, onAddMinute: {}, onPause: {}, onResume: {},
                     onStop: {}, onAcknowledge: {})
        .previewCompactRow()
}

#Preview("Timer compact, idle") { timerCompactPreview(PreviewSamples.idleTimer) }
#Preview("Timer compact, running") { timerCompactPreview(PreviewSamples.runningTimer, now: PreviewSamples.runningNow) }
#Preview("Timer compact, paused") { timerCompactPreview(PreviewSamples.pausedTimer, now: PreviewSamples.runningNow) }
#Preview("Timer compact, ringing") { timerCompactPreview(PreviewSamples.ringingTimer, now: PreviewSamples.ringingNow) }
#endif
