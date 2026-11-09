import Foundation

public struct RecentFile: Equatable, Sendable, Identifiable {
    public var id: URL { url }
    public let url: URL
    public let lastUsed: Date
    public let isDirectory: Bool

    public init(url: URL, lastUsed: Date, isDirectory: Bool) {
        self.url = url; self.lastUsed = lastUsed; self.isDirectory = isDirectory
    }

    public var name: String { url.lastPathComponent }

    /// French label for home's Desktop/Documents/Downloads direct children; else the parent folder name.
    public func parentName(home: URL) -> String {
        let parent = url.deletingLastPathComponent()
        if parent.deletingLastPathComponent().standardizedFileURL.path == home.standardizedFileURL.path {
            switch parent.lastPathComponent {
            case "Desktop": return "Bureau"
            case "Downloads": return "Téléchargements"
            case "Documents": return "Documents"
            default: break
            }
        }
        return parent.lastPathComponent
    }
}

public enum RecentFiles {
    public static let limit = 3

    public static func select(_ candidates: [RecentFile], home: URL) -> [RecentFile] {
        let library = home.appendingPathComponent("Library").standardizedFileURL.pathComponents
        var newest: [URL: RecentFile] = [:]
        for file in candidates {
            guard !file.isDirectory else { continue }
            let comps = file.url.standardizedFileURL.pathComponents
            if comps.contains(where: { $0.hasPrefix(".") && $0 != "." && $0 != ".." }) { continue }
            if comps.contains(where: { $0.lowercased().hasSuffix(".app") }) { continue }
            if comps.count >= library.count && Array(comps.prefix(library.count)) == library { continue }
            let key = file.url.standardizedFileURL
            if let existing = newest[key], existing.lastUsed >= file.lastUsed { continue }
            newest[key] = file
        }
        let valid = Array(newest.values)
        return Array(valid.sorted { $0.lastUsed > $1.lastUsed }.prefix(limit))
    }
}
