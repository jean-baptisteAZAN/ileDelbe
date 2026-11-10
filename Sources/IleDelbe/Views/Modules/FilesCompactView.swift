import AppKit
import IleDelbeCore
import SwiftUI

/// Île page: at most 3 tiles (icon, name, relative time), clickable and draggable like the
/// pane, and « +N » for the rest when the setting asks for 5.
struct FilesCompactView: View {
    static let maxTiles = 3

    var files: [RecentFile]
    /// How many files the setting asks for (3 or 5).
    var count: Int = 3
    var icon: (RecentFile) -> NSImage
    var now: Date
    var onOpen: (RecentFile) -> Void
    var onDragStart: () -> Void

    var body: some View {
        if files.isEmpty {
            ModuleEmptyText("Aucun fichier récent")
        } else {
            let shown = files.prefix(min(count, Self.maxTiles))
            let more = min(count, files.count) - shown.count
            HStack(spacing: 10) {
                ForEach(shown) { tile($0) }
                if shown.count < Self.maxTiles { Spacer(minLength: 0) }
                if more > 0 {
                    Text("+\(more)")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func tile(_ file: RecentFile) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return HStack(spacing: 8) {
            RecentFileIcon(image: icon(file), size: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(file.name)
                    .font(.system(size: 11.5, weight: .medium)).foregroundStyle(.white)
                Text(RelativeTime.string(from: file.lastUsed, now: now))
                    .font(.system(size: 10.5)).foregroundStyle(.secondary)
            }
            .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(shape.fill(Color.cardFill))
        .recentFileInteractions(file, shape: shape, onOpen: onOpen, onDragStart: onDragStart)
    }
}

#if DEBUG
#Preview("Files compact, 5") {
    FilesCompactView(files: PreviewSamples.files, count: 5, icon: { PreviewSamples.icon($0) }, now: .now,
                     onOpen: { _ in }, onDragStart: {})
        .previewCompactRow()
}

#Preview("Files compact, 3") {
    FilesCompactView(files: PreviewSamples.files, icon: { PreviewSamples.icon($0) }, now: .now,
                     onOpen: { _ in }, onDragStart: {})
        .previewCompactRow()
}

#Preview("Files compact, empty") {
    FilesCompactView(files: [], icon: { _ in NSImage() }, now: .now, onOpen: { _ in }, onDragStart: {})
        .previewCompactRow()
}
#endif
