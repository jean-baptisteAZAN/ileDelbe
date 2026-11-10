import AppKit
import IleDelbeCore
import SwiftUI

struct FilesPaneView: View {
    var files: [RecentFile]
    var home: URL
    /// How many files to show (setting: 3 or 5). `files` may hold more.
    var count: Int = 3
    var icon: (RecentFile) -> NSImage
    var now: Date
    var onOpen: (RecentFile) -> Void
    var onDragStart: () -> Void

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ModuleLabel("Récents")
            if files.isEmpty {
                ModuleEmptyText("Aucun fichier récent")
            } else {
                // 3 flexible columns: 3 files fill one row, 5 wrap as 3 + 2 (cards ~50 pt, two rows fit).
                LazyVGrid(columns: Self.columns, alignment: .leading, spacing: 8) {
                    ForEach(files.prefix(count)) { file in
                        card(file)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func card(_ file: RecentFile) -> some View {
        HStack(spacing: 10) {
            RecentFileIcon(image: icon(file), size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                Text("\(file.parentName(home: home)) · \(RelativeTime.string(from: file.lastUsed, now: now))")
                    .font(.system(size: 10.5)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.06)))
        .recentFileInteractions(file, shape: RoundedRectangle(cornerRadius: 12, style: .continuous),
                                onOpen: onOpen, onDragStart: onDragStart)
    }
}

#if DEBUG
#Preview("Files 3") {
    FilesPaneView(files: PreviewSamples.files, home: PreviewSamples.home, icon: { PreviewSamples.icon($0) },
                  now: .now, onOpen: { _ in }, onDragStart: {})
        .previewPanel(width: 548, height: 130)
}

/// Onglets pane below the tab bar: 512 × ~146 pt, the 5 files wrap as 3 + 2.
#Preview("Files 5") {
    FilesPaneView(files: PreviewSamples.files, home: PreviewSamples.home, count: 5, icon: { PreviewSamples.icon($0) },
                  now: .now, onOpen: { _ in }, onDragStart: {})
        .previewPanel(width: 548, height: 182)
}

#Preview("Files 0") {
    FilesPaneView(files: [], home: PreviewSamples.home, icon: { _ in NSImage() }, now: .now, onOpen: { _ in },
                  onDragStart: {})
        .previewPanel(width: 548, height: 130)
}
#endif
