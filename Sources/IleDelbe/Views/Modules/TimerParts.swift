import IleDelbeCore
import SwiftUI

extension CountdownTimer {
    /// What the timer views draw.
    enum Phase: Equatable { case idle, active(paused: Bool), ringing }

    var phase: Phase {
        switch state {
        case .idle: .idle
        case .running: .active(paused: false)
        case .paused: .active(paused: true)
        case .ringing: .ringing
        }
    }
}

extension TimerText {
    /// « Fin à HH:mm » while running, « En pause » while paused, nil otherwise.
    static func endLine(_ timer: CountdownTimer) -> String? {
        switch timer.state {
        case let .running(end, _): "Fin à \(ClockText.string(from: end))"
        case .paused: "En pause"
        case .idle, .ringing: nil
        }
    }
}

/// The three durations from the settings, as orange pills.
struct TimerPresetButtons: View {
    var presetsMinutes: [Int]
    var size: PillButton.Size = .regular
    var onStart: (TimeInterval) -> Void

    var body: some View {
        HStack(spacing: size == .regular ? 8 : 6) {
            // Offsets as ids: two presets may hold the same duration.
            ForEach(Array(presetsMinutes.enumerated()), id: \.offset) { _, minutes in
                PillButton("\(minutes) min", kind: .timer, size: size) { onStart(TimeInterval(minutes * 60)) }
            }
        }
    }
}

/// +1 min, Pause/Reprendre, Arrêter in one row (Île page, Grille card). When the row does not
/// fit, Pause/Reprendre and Arrêter become icon buttons.
struct TimerActiveButtons: View {
    var paused: Bool
    var onAddMinute: () -> Void
    var onPause: () -> Void
    var onResume: () -> Void
    var onStop: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                PillButton("+1 min", kind: .timer, size: .small, action: onAddMinute)
                PillButton(pauseTitle, size: .small, action: pauseAction)
                PillButton("Arrêter", size: .small, action: onStop)
            }
            HStack(spacing: 6) {
                PillButton("+1 min", kind: .timer, size: .small, action: onAddMinute)
                PillIconButton(systemName: paused ? "play.fill" : "pause.fill", help: pauseTitle, action: pauseAction)
                PillIconButton(systemName: "stop.fill", help: "Arrêter", action: onStop)
            }
        }
    }

    private var pauseTitle: String { paused ? "Reprendre" : "Pause" }
    private var pauseAction: () -> Void { paused ? onResume : onPause }
}

/// Time left in orange, monospaced digits.
struct TimerRemainingText: View {
    var timer: CountdownTimer
    var now: Date
    var size: CGFloat

    var body: some View {
        Text(TimerText.string(timer.remaining(at: now)))
            .font(.system(size: size, weight: .semibold).monospacedDigit())
            .foregroundStyle(Color.timerOrange)
            .lineLimit(1)
            .fixedSize()
    }
}
