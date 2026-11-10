import AppKit
import IleDelbeCore
import SwiftUI

/// Grille card: the `count` most recent files as icons with their names, in a row.
/// Clickable and draggable like the pane.
struct FilesCardView: View {
    var files: [RecentFile]
    /// How many files the setting asks for (3 or 5).
    var count: Int = 3
    var icon: (RecentFile) -> NSImage
    var onOpen: (RecentFile) -> Void
    var onDragStart: () -> Void

    var body: some View {
        ModuleCard("Fichiers récents") {
            if files.isEmpty {
                ModuleEmptyText("Aucun fichier récent", size: 12.5)
            } else {
                // Items shrink below 44 pt in a narrow card (two-column Grille with five files).
                HStack(alignment: .top, spacing: 4) {
                    ForEach(files.prefix(count)) { item($0) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func item(_ file: RecentFile) -> some View {
        VStack(spacing: 3) {
            RecentFileIcon(image: icon(file), size: 24)
            Text(file.name)
                .font(.system(size: 9.5))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: 44)
        .recentFileInteractions(file, onOpen: onOpen, onDragStart: onDragStart)
    }
}

#if DEBUG
#Preview("Files card, 5") {
    FilesCardView(files: PreviewSamples.files, count: 5, icon: { PreviewSamples.icon($0) }, onOpen: { _ in },
                  onDragStart: {})
        .previewCard(width: 260, height: 72)
}

#Preview("Files card, 3") {
    FilesCardView(files: PreviewSamples.files, icon: { PreviewSamples.icon($0) }, onOpen: { _ in }, onDragStart: {})
        .previewCard(width: 260, height: 72)
}

#Preview("Files card, empty") {
    FilesCardView(files: [], icon: { _ in NSImage() }, onOpen: { _ in }, onDragStart: {})
        .previewCard(width: 260, height: 72)
}
#endif
