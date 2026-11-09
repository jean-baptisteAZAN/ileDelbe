import IleDelbeCore
import SwiftUI

/// Elapsed / duration with a seekable bar. Ticks (0.5 s) only while open and playing;
/// otherwise renders a static position computed once per render.
struct ScrubberView: View {
    var info: NowPlayingInfo
    var isOpen: Bool
    var onSeek: (TimeInterval) -> Void

    @State private var dragValue: Double?

    var body: some View {
        if isOpen && info.isPlaying {
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                content(now: context.date)
            }
        } else {
            content(now: .now)
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let elapsed = info.position(at: now) ?? 0
        if let duration = info.duration, info.canSeek {
            let shown = dragValue ?? min(elapsed, duration)
            HStack(spacing: 8) {
                timeLabel(shown)
                Slider(
                    value: Binding(get: { shown }, set: { dragValue = $0 }),
                    in: 0...duration,
                    onEditingChanged: { editing in
                        if !editing, let value = dragValue {
                            onSeek(value)
                            dragValue = nil
                        }
                    }
                )
                .controlSize(.mini)
                .tint(.white)
                timeLabel(duration)
            }
        } else {
            HStack {
                timeLabel(elapsed)
                Spacer(minLength: 0)
            }
        }
    }

    private func timeLabel(_ t: TimeInterval) -> some View {
        Text(TimeFormat.string(t))
            .font(.system(size: 10, weight: .medium).monospacedDigit())
            .foregroundStyle(.white.opacity(0.6))
            .frame(minWidth: 30)
    }
}
