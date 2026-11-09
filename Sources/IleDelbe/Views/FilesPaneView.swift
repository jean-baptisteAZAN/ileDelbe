import AppKit
import IleDelbeCore
import SwiftUI
import UniformTypeIdentifiers

struct FilesPaneView: View {
    var files: [RecentFile]
    var home: URL
    var icon: (RecentFile) -> NSImage
    var now: Date
    var onOpen: (RecentFile) -> Void
    var onDragStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Récents")
                .font(.system(size: 10.5, weight: .semibold))
                .textCase(.uppercase).tracking(0.8)
                .foregroundStyle(.secondary)
            if files.isEmpty {
                Text("Aucun fichier récent")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 8) {
                    ForEach(files.prefix(3)) { file in
                        card(file)
                    }
                    if files.count < 3 { Spacer(minLength: 0) }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func card(_ file: RecentFile) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: icon(file))
                .resizable().aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
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
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture { onOpen(file) }
        .onDrag {
            onDragStart()
            return NSItemProvider(contentsOf: file.url) ?? NSItemProvider()
        }
    }
}

#if DEBUG
private let previewHome = URL(fileURLWithPath: "/Users/demo")
private let previewFiles = [
    RecentFile(url: previewHome.appendingPathComponent("Desktop/Capture.png"), lastUsed: .now.addingTimeInterval(-300), isDirectory: false),
    RecentFile(url: previewHome.appendingPathComponent("Documents/Devis client 2026.pdf"), lastUsed: .now.addingTimeInterval(-7200), isDirectory: false),
    RecentFile(url: previewHome.appendingPathComponent("Downloads/notes.txt"), lastUsed: .now.addingTimeInterval(-90000), isDirectory: false),
]

#Preview("Files 3") {
    FilesPaneView(files: previewFiles, home: previewHome, icon: { NSWorkspace.shared.icon(for: UTType(filenameExtension: $0.url.pathExtension) ?? .data) },
                  now: .now, onOpen: { _ in }, onDragStart: {})
        .padding(18).frame(width: 548, height: 130).background(Color.black)
}

#Preview("Files 0") {
    FilesPaneView(files: [], home: previewHome, icon: { _ in NSImage() }, now: .now, onOpen: { _ in }, onDragStart: {})
        .padding(18).frame(width: 548, height: 130).background(Color.black)
}
#endif
