import AppKit
import IleDelbeCore
import SwiftUI

extension View {
    /// Click opens the file, drag carries it out (the panel stays open while dragging:
    /// `onDragStart`). Shared by every Fichiers view.
    func recentFileInteractions(_ file: RecentFile, shape: some Shape = Rectangle(),
                                onOpen: @escaping (RecentFile) -> Void,
                                onDragStart: @escaping () -> Void) -> some View {
        contentShape(shape)
            .onTapGesture { onOpen(file) }
            .onDrag {
                onDragStart()
                return NSItemProvider(contentsOf: file.url) ?? NSItemProvider()
            }
    }
}

/// A file's icon at a square size.
struct RecentFileIcon: View {
    var image: NSImage
    var size: CGFloat

    var body: some View {
        Image(nsImage: image)
            .resizable().aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}
