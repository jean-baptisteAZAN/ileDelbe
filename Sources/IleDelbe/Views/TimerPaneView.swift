import IleDelbeCore
import SwiftUI

/// Timer tab. `now` is supplied by the caller; the view owns no timers.
struct TimerPaneView: View {
    var timer: CountdownTimer
    var now: Date
    var onStart: (TimeInterval) -> Void
    var onAddMinute: () -> Void
    var onPause: () -> Void
    var onResume: () -> Void
    var onStop: () -> Void
    var onAcknowledge: () -> Void

    var body: some View {
        switch timer.state {
        case .idle: idle
        case .running: active(paused: false)
        case .paused: active(paused: true)
        case .ringing: ringing
        }
    }

    private var idle: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lancer un minuteur")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(CountdownTimer.presets, id: \.self) { preset in
                    pill("\(Int(preset / 60)) min", highlighted: true) { onStart(preset) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.leading, 6)
    }

    private func active(paused: Bool) -> some View {
        HStack(spacing: 20) {
            ZStack {
                TimerRingView(progress: timer.progress(at: now), size: 104, lineWidth: 7)
                Text(TimerText.string(timer.remaining(at: now)))
                    .font(.system(size: 24, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color.timerOrange)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    pill("+1 min", highlighted: true, action: onAddMinute)
                    pill(paused ? "Reprendre" : "Pause", highlighted: false, action: paused ? onResume : onPause)
                }
                pill("Arrêter", highlighted: false, action: onStop)
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
            pill("OK", highlighted: true, action: onAcknowledge)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func pill(_ title: String, highlighted: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(highlighted ? Color.timerOrange : Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(highlighted ? Color.timerOrange.opacity(0.2) : Color.white.opacity(0.1)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
@MainActor private func previewPane(_ timer: CountdownTimer, now: Date = .now) -> some View {
    TimerPaneView(timer: timer, now: now, onStart: { _ in }, onAddMinute: {}, onPause: {},
                  onResume: {}, onStop: {}, onAcknowledge: {})
        .padding(18).frame(width: 548, height: 160).background(Color.black)
}

#Preview("Timer idle") { previewPane(CountdownTimer()) }

#Preview("Timer active") {
    var t = CountdownTimer()
    let now = Date.now
    t.start(duration: 600, now: now)
    return previewPane(t, now: now.addingTimeInterval(200))
}

#Preview("Timer ringing") {
    var t = CountdownTimer()
    let now = Date.now
    t.start(duration: 60, now: now)
    t.tick(now: now.addingTimeInterval(61))
    return previewPane(t, now: now.addingTimeInterval(61))
}
#endif
