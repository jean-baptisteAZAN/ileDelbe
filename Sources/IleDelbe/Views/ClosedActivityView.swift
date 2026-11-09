import IleDelbeCore
import SwiftUI

/// Content of the closed-but-playing pill: artwork on the left wing, equalizer on the right wing.
/// The middle (hardware notch) is left empty.
struct ClosedActivityView: View {
    var artworkData: Data?
    var isPlaying: Bool

    var body: some View {
        HStack(spacing: 0) {
            ArtworkView(data: artworkData, size: 20, cornerRadius: 4)
                .frame(width: NotchGeometry.closedActiveWing)
            Spacer(minLength: 0)
            EqualizerView(isPlaying: isPlaying)
                .frame(width: NotchGeometry.closedActiveWing)
        }
    }
}
