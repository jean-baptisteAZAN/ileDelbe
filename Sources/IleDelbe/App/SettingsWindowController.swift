import AppKit
import SwiftUI

/// The Réglages window: one reused window, resizable vertically only (its Form scrolls). The app stays an accessory app, so showing it
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
        // Record on every show, not only when hidden, so the remembered app is never stale.
        if let front = NSWorkspace.shared.frontmostApplication,
           front.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp = front
        }
        loginItem.refresh()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let host = NSHostingController(rootView: SettingsView(store: store, loginItem: loginItem))
        let window = SettingsWindow(contentViewController: host)
        window.title = "Réglages ileDelbe"
        window.styleMask = [.titled, .closable, .resizable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setContentSize(NSSize(width: 520, height: SettingsView.idealHeight))
        window.contentMinSize = NSSize(width: 520, height: SettingsView.minHeight)
        window.contentMaxSize = NSSize(width: 520, height: CGFloat.greatestFiniteMagnitude)
        // Never taller than the screen it opens on (e.g. a 1280×800 display with the Dock).
        if let visible = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame,
           window.frame.height > visible.height {
            let chrome = window.frame.height - window.contentLayoutRect.height
            window.setContentSize(NSSize(width: 520, height: max(SettingsView.minHeight, visible.height - chrome)))
        }
        window.center()
        return window
    }

    func windowWillClose(_ notification: Notification) {
        let app = previousApp
        previousApp = nil
        // Closed while the user already moved on to another app: leave focus alone.
        guard NSApp.isActive else { return }
        if let app, !app.isTerminated {
            app.activate()
        } else {
            NSApp.deactivate()
        }
    }
}

/// The app has no main menu (accessory app), so ⌘W and Esc are handled here. Both go through
/// `performClose`, so `windowWillClose` still hands focus back.
private final class SettingsWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           event.charactersIgnoringModifiers == "w" {
            performClose(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        performClose(nil)
    }
}
