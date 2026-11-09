import AppKit
import IleDelbeCore
import Observation
import os

/// Most recently used files, pushed by Spotlight (`NSMetadataQuery`) — no polling.
@MainActor @Observable
final class RecentFilesService {
    private(set) var files: [RecentFile] = []

    @ObservationIgnored private let home: URL
    @ObservationIgnored private let query = NSMetadataQuery()
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var icons: [String: NSImage] = [:]
    @ObservationIgnored private let log = Logger(subsystem: "io.github.ileDelbe", category: "files")

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home
        let since = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date(timeIntervalSinceNow: -30 * 86_400)
        query.predicate = NSPredicate(format: "%K >= %@", NSMetadataItemLastUsedDateKey, since as NSDate)
        query.searchScopes = [NSMetadataQueryUserHomeScope]
        query.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemLastUsedDateKey, ascending: false)]
        let hop: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        for name in [Notification.Name.NSMetadataQueryDidFinishGathering, .NSMetadataQueryDidUpdate] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: query, queue: .main, using: hop))
        }
        // The service is main-actor isolated, so the query starts (and notifies) on the main thread.
        if !query.start() { log.error("recent files query failed to start") }
    }

    func open(_ file: RecentFile) { NSWorkspace.shared.open(file.url) }

    func icon(for file: RecentFile) -> NSImage {
        let path = file.url.path
        if let cached = icons[path] { return cached }
        let image = NSWorkspace.shared.icon(forFile: path)
        icons[path] = image
        return image
    }

    private func refresh() {
        query.disableUpdates()
        defer { query.enableUpdates() }
        var candidates: [RecentFile] = []
        for index in 0..<min(query.resultCount, 40) {
            guard let item = query.result(at: index) as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  let date = item.value(forAttribute: NSMetadataItemLastUsedDateKey) as? Date
            else { continue }
            let tree = item.value(forAttribute: NSMetadataItemContentTypeTreeKey) as? [String] ?? []
            candidates.append(RecentFile(url: URL(fileURLWithPath: path), lastUsed: date,
                                         isDirectory: tree.contains("public.folder")))
        }
        let selected = RecentFiles.select(candidates, home: home)
        log.debug("recent files: \(candidates.count) candidates, \(selected.map(\.name).joined(separator: ", "), privacy: .public)")
        if selected != files { files = selected }
    }
}
