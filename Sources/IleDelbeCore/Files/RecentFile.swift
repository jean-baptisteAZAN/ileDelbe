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
    public var parentName: String {
        let parent = url.deletingLastPathComponent()
        let grand = parent.deletingLastPathComponent().path
        let home = NSHomeDirectory()
        // Mapping applies only when the grandparent looks like a home directory (/Users/x or real home).
        let isHomeChild = grand == home || grand.split(separator: "/").count == 2 && grand.hasPrefix("/Users/")
        if isHomeChild {
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
        var seen = Set<URL>()
        let valid = candidates.filter { file in
            guard !file.isDirectory else { return false }
            let comps = file.url.standardizedFileURL.pathComponents
            if comps.contains(where: { $0.hasPrefix(".") && $0 != "." && $0 != ".." }) { return false }
            if comps.contains(where: { $0.lowercased().hasSuffix(".app") }) { return false }
            if comps.count >= library.count && Array(comps.prefix(library.count)) == library { return false }
            return seen.insert(file.url).inserted
        }
        return Array(valid.sorted { $0.lastUsed > $1.lastUsed }.prefix(limit))
    }
}
