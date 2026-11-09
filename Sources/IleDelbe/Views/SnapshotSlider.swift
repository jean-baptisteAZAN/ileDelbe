import SwiftUI

extension EnvironmentValues {
    /// True while rendering offscreen with `ImageRenderer` (README images). AppKit-backed controls
    /// such as `Slider` do not render there, so views swap them for a drawn look-alike.
    @Entry var isStaticSnapshot = false
}

/// Drawn stand-in for a mini `Slider` (track, fill, knob). Only used for static snapshots.
struct SnapshotSlider: View {
    var fraction: Double
    var tint: Color

    var body: some View {
        GeometryReader { proxy in
            let f = max(0, min(1, fraction))
            let knob: CGFloat = 10
            let x = (proxy.size.width - knob) * f
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.2)).frame(height: 3)
                Capsule().fill(tint).frame(width: x + knob / 2, height: 3)
                Circle().fill(Color.white)
                    .frame(width: knob, height: knob)
                    .shadow(color: .black.opacity(0.3), radius: 1)
                    .offset(x: x)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 14)
    }
}
