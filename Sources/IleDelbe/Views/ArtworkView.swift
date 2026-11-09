import AppKit
import SwiftUI

/// Album art, or a gray rounded placeholder with a note symbol.
struct ArtworkView: View {
    var data: Data?
    var size: CGFloat
    var cornerRadius: CGFloat

    var body: some View {
        Group {
            if let data, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.gray.opacity(0.35)
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.45, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
