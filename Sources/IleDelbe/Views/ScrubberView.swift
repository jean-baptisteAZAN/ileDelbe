import IleDelbeCore
import SwiftUI

/// Elapsed / duration with a seekable bar. Ticks (0.5 s) only while open and playing;
/// otherwise renders a static position computed once per render.
struct ScrubberView: View {
    var info: NowPlayingInfo
    var isOpen: Bool
    var fill: Color = .white
    var onSeek: (TimeInterval) -> Void

    @State private var dragValue: Double?
    /// Value released by the last drag, shown until the adapter reports a new state (or 1 s passes)
    /// so the thumb does not snap back to the stale position.
    @State private var heldValue: Double?
    @State private var holdToken = 0

    var body: some View {
        Group {
            if isOpen && info.isPlaying {
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    content(now: context.date)
                }
            } else {
                content(now: .now)
            }
        }
        .onChange(of: info) { heldValue = nil }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let elapsed = info.position(at: now) ?? 0
        if let duration = info.duration, info.canSeek {
            let shown = dragValue ?? heldValue ?? min(elapsed, duration)
            HStack(spacing: 8) {
                timeLabel(shown)
                Slider(
                    value: Binding(get: { shown }, set: { dragValue = $0 }),
                    in: 0...duration,
                    onEditingChanged: { editing in
                        if !editing, let value = dragValue {
                            onSeek(value)
                            hold(value)
                            dragValue = nil
                        }
                    }
                )
                .controlSize(.mini)
                .tint(fill)
                timeLabel(duration)
            }
        } else {
            HStack {
                timeLabel(elapsed)
                Spacer(minLength: 0)
            }
        }
    }

    private func hold(_ value: Double) {
        heldValue = value
        holdToken += 1
        let token = holdToken
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            if holdToken == token { heldValue = nil }
        }
    }

    private func timeLabel(_ t: TimeInterval) -> some View {
        Text(TimeFormat.string(t))
            .font(.system(size: 10, weight: .medium).monospacedDigit())
            .foregroundStyle(.white.opacity(0.6))
            .frame(minWidth: 30)
    }
}
