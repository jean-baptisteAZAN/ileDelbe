import AppKit
import SwiftUI

/// The Réglages window: one reused, non-resizable window. The app stays an accessory app, so showing it
/// activates ileDelbe and closing it hands focus back to the app that was frontmost before.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let store: SettingsStore
    private let loginItem: LoginItemService
    private var window: NSWindow?
    private var previousApp: NSRunningApplication?

    init(store: SettingsStore, loginItem: LoginItemService) {
        self.store = store
        self.loginItem = loginItem
    }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        if !window.isVisible {
            let front = NSWorkspace.shared.frontmostApplication
            previousApp = front?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : front
        }
        loginItem.refresh()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let host = NSHostingController(rootView: SettingsView(store: store, loginItem: loginItem))
        let window = NSWindow(contentViewController: host)
        window.title = "Réglages ileDelbe"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }

    func windowWillClose(_ notification: Notification) {
        let app = previousApp
        previousApp = nil
        app?.activate()
    }
}
