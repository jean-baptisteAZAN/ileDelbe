import Foundation
import Testing
@testable import IleDelbeCore

@Suite struct RecentFilesTests {
    let home = URL(fileURLWithPath: "/Users/test")
    func f(_ path: String, _ t: TimeInterval, dir: Bool = false) -> RecentFile {
        RecentFile(url: URL(fileURLWithPath: path), lastUsed: Date(timeIntervalSince1970: t), isDirectory: dir)
    }

    @Test func keepsThreeNewest() {
        let c = (1...5).map { f("/Users/test/Documents/f\($0).txt", Double($0)) }
        #expect(RecentFiles.select(c, home: home).map(\.name) == ["f5.txt", "f4.txt", "f3.txt"])
    }

    @Test func excludes() {
        let c = [
            f("/Users/test/.config/x.json", 1), f("/Users/test/Library/Caches/y.db", 2),
            f("/Applications/Foo.app", 3), f("/Users/test/Foo.app/Contents/Info.plist", 4),
            f("/Users/test/Dir", 5, dir: true),
        ]
        #expect(RecentFiles.select(c, home: home).isEmpty)
    }

    @Test func oneAndNone() {
        let a = f("/Users/test/a.txt", 1)
        #expect(RecentFiles.select([a], home: home) == [a])
        #expect(RecentFiles.select([], home: home) == [])
    }

    @Test func dedupes() {
        let a = f("/Users/test/a.txt", 1)
        #expect(RecentFiles.select([a, a], home: home).count == 1)
    }

    @Test func parentName() {
        #expect(f("/Users/test/Downloads/a.pdf", 0).parentName == "Téléchargements")
        #expect(f("/Users/test/Desktop/b.png", 0).parentName == "Bureau")
        #expect(f("/Users/test/Documents/d.png", 0).parentName == "Documents")
        #expect(f("/Users/test/Projets/c.txt", 0).parentName == "Projets")
    }
}
