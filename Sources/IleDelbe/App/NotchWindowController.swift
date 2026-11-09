import AppKit
import IleDelbeCore
import SwiftUI
import os

/// Owns the notch panel: placement on the notched screen, hover detection, open/close.
@MainActor
final class NotchWindowController {
    private let model: NotchViewModel
    private let panel: NotchPanel
    private let log = Logger(subsystem: "io.github.ileDelbe", category: "window")
    private var hover = HoverStateMachine()
    private var deadlineWork: DispatchWorkItem?
    private var monitors: [Any] = []
    private var screenObserver: NSObjectProtocol?

    init(model: NotchViewModel) {
        self.model = model
        panel = NotchPanel(contentRect: .zero)
        let hosting = NSHostingView(rootView: NotchRootView(model: model))
        hosting.sizingOptions = []  // the window frame is ours, never the content's
        panel.contentView = hosting
        panel.ignoresMouseEvents = true

        layout()

        let handler: (NSEvent) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.evaluateHover() }
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: handler) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved, handler: { event in
            handler(event)
            return event
        }) {
            monitors.append(local)
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.layout() }
        }
    }

    // MARK: Geometry

    private func layout() {
        guard let geometry = Self.notchGeometry() else {
            deadlineWork?.cancel()
            hover = HoverStateMachine()
            model.isOpen = false
            model.geometry = nil
            panel.ignoresMouseEvents = true
            panel.orderOut(nil)
            log.info("no notched screen; panel hidden")
            return
        }
        model.geometry = geometry
        // Windows snap to whole points; grow outward to integral bounds so the content
        // (centered by NotchRootView) stays centered on the notch, e.g. odd notch widths.
        panel.setFrame(NSIntegralRect(geometry.expanded), display: true)
        panel.orderFrontRegardless()
        log.info("panel frame \(NSStringFromRect(self.panel.frame), privacy: .public) notch \(NSStringFromRect(geometry.notch), privacy: .public)")
        evaluateHover()
    }

    /// Built-in display first, else any screen with a notch.
    private static func notchGeometry() -> NotchGeometry? {
        let screens = NSScreen.screens
        let ordered = screens.filter { $0.localizedName.contains("Built-in") }
            + screens.filter { !$0.localizedName.contains("Built-in") }
        for screen in ordered {
            if let g = NotchGeometry.make(screenFrame: screen.frame, safeAreaTop: screen.safeAreaInsets.top,
                                          auxiliaryTopLeft: screen.auxiliaryTopLeftArea,
                                          auxiliaryTopRight: screen.auxiliaryTopRightArea) {
                return g
            }
        }
        return nil
    }

    // MARK: Hover

    private func evaluateHover() {
        guard let geometry = model.geometry else { return }
        let trigger = hover.isOpen ? geometry.expanded : geometry.notch
        let now = ProcessInfo.processInfo.systemUptime
        hover.update(inTrigger: Self.contains(trigger, NSEvent.mouseLocation), now: now)
        apply()

        deadlineWork?.cancel()
        deadlineWork = nil
        if let deadline = hover.nextDeadline {
            let work = DispatchWorkItem { [weak self] in
                MainActor.assumeIsolated { self?.evaluateHover() }
            }
            deadlineWork = work
            // +0.01 s absorbs float rounding in the state machine (no zero-delay reschedule loop).
            DispatchQueue.main.asyncAfter(deadline: .now() + max(0, deadline + 0.01 - now), execute: work)
        }
    }

    private func apply() {
        guard model.isOpen != hover.isOpen else { return }
        model.isOpen = hover.isOpen
        // Closed: never intercept clicks (menu bar stays usable).
        panel.ignoresMouseEvents = !hover.isOpen
    }

    /// Inclusive of the max edges: the pointer pinned at the very top of the screen has y == maxY.
    private static func contains(_ rect: CGRect, _ p: CGPoint) -> Bool {
        p.x >= rect.minX && p.x <= rect.maxX && p.y >= rect.minY && p.y <= rect.maxY
    }
}
