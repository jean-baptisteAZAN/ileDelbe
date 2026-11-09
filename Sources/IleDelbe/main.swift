import AppKit

// Hidden mode for the README images; runs before NSApplication starts and never returns.
if let directory = ReadmeAssets.outputDirectory(in: CommandLine.arguments) {
    exit(MainActor.assumeIsolated { ReadmeAssets.render(to: directory) })
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
