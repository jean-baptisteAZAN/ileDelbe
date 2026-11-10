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
    private var hover: HoverStateMachine
    private var deadlineWork: DispatchWorkItem?
    private var monitors: [Any] = []
    private var screenObserver: NSObjectProtocol?
    /// Whether the pointer was last seen inside the bubble rect while closed (open → Minuteur tab).
    private var pointerInBubble = false

    init(model: NotchViewModel) {
        self.model = model
        hover = HoverStateMachine(openDelay: model.settings.settings.openDelay)
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
        // End of a file drag out of the panel: drop the "keep open" override.
        let mouseUp: (NSEvent) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.endFileDrag() }
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp, handler: mouseUp) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp, handler: { event in
            mouseUp(event)
            return event
        }) {
            monitors.append(local)
        }
        observeClosedLayout()
        observeWindowSize()
        observeOpenDelay()
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
            hover = HoverStateMachine(openDelay: model.settings.settings.openDelay)
            model.isOpen = false
            model.geometry = nil
            panel.ignoresMouseEvents = true
            panel.orderOut(nil)
            log.info("no notched screen; panel hidden")
            return
        }
        model.geometry = geometry
        applyFrame()
        panel.orderFrontRegardless()
        log.info("notch \(NSStringFromRect(geometry.notch), privacy: .public)")
        evaluateHover()
    }

    /// Frames the window on the largest open size of the current style, density and modules.
    /// Only `setFrame`: never reorders the panel or takes focus, so it is safe while open.
    private func applyFrame() {
        guard let geometry = model.geometry else { return }
        // Windows snap to whole points; grow outward to integral bounds so the content
        // (centered by NotchRootView) stays centered on the notch, e.g. odd notch widths.
        let e = geometry.openRect(size: model.maxPanelSize)
        // The window extends past the open panel only so the open halo is not cut by the window
        // edge. That margin never takes clicks: see `updateMousePassThrough`.
        let m = HaloStyle.windowMargin
        let frame = NSIntegralRect(CGRect(x: e.minX - m.horizontal, y: e.minY - m.bottom,
                                          width: e.width + 2 * m.horizontal, height: e.height + m.bottom))
        guard frame != panel.frame else { return }
        panel.setFrame(frame, display: true)
        log.info("panel frame \(NSStringFromRect(self.panel.frame), privacy: .public)")
    }

    /// Re-arms itself: style, density or module changes re-frame the window, even while open.
    private func observeWindowSize() {
        _ = withObservationTracking {
            model.maxPanelSize
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.observeWindowSize()
                self?.applyFrame()
                self?.evaluateHover()
            }
        }
    }

    /// Re-arms itself: the hover open delay follows the setting.
    private func observeOpenDelay() {
        hover.openDelay = withObservationTracking {
            model.settings.settings.openDelay
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeOpenDelay() }
        }
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

    /// Re-arms itself on every change, so the trigger rect follows the bubble / wings width.
    private func observeClosedLayout() {
        _ = withObservationTracking {
            (model.closedLayout, model.closedWings)
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.observeClosedLayout()
                self?.evaluateHover()
            }
        }
    }

    private func endFileDrag() {
        guard model.isDraggingFile else { return }
        model.isDraggingFile = false
        evaluateHover()
    }

    private func evaluateHover() {
        guard let geometry = model.geometry else { return }
        let mouse = NSEvent.mouseLocation
        // Safety net: a drag session can swallow the mouse-up; a move with the button up ends it.
        if model.isDraggingFile, NSEvent.pressedMouseButtons & 1 == 0 { model.isDraggingFile = false }
        // Always derived from the current state, so it follows the shape actually drawn.
        let openRect = geometry.openRect(size: model.panelSize)
        var inTrigger: Bool
        if hover.isOpen {
            inTrigger = Self.contains(openRect, mouse)
        } else {
            let main = geometry.closedRect(model.closedWings)  // the visible pill (bare notch when plain)
            let inBubble = model.closedLayout == .mediaAndBubble
                && Self.contains(geometry.bubbleRect(after: main), mouse)
            inTrigger = Self.contains(main, mouse) || inBubble
            if inTrigger { pointerInBubble = inBubble }
        }
        if model.isDraggingFile { inTrigger = true }  // keep the panel open while dragging a file out
        let now = ProcessInfo.processInfo.systemUptime
        hover.update(inTrigger: inTrigger, now: now)
        apply()
        updateMousePassThrough(inOpenPanel: Self.contains(openRect, mouse))

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

    /// Closes the panel now (e.g. the gear was clicked). It reopens only after the pointer has
    /// left the trigger and come back.
    func closeNow() {
        deadlineWork?.cancel()
        deadlineWork = nil
        hover.forceClose()
        apply()
        updateMousePassThrough(inOpenPanel: false)
    }

    private func apply() {
        guard model.isOpen != hover.isOpen else { return }
        if hover.isOpen { model.panelWillOpen(fromBubble: pointerInBubble) }
        model.isOpen = hover.isOpen
        if !hover.isOpen { model.panelDidClose() }
    }

    /// Clicks reach the panel only while it is open and the pointer is over the panel itself
    /// (or a file drag is in progress). Closed (bubble included), and in the transparent glow
    /// margin around the open panel, clicks pass through to the menu bar and apps below.
    /// Updated on every mouse move.
    private func updateMousePassThrough(inOpenPanel: Bool) {
        let ignores = !((hover.isOpen && inOpenPanel) || model.isDraggingFile)
        guard panel.ignoresMouseEvents != ignores else { return }
        panel.ignoresMouseEvents = ignores
        log.info("ignoresMouseEvents=\(ignores, privacy: .public)")
    }

    /// Inclusive of the max edges: the pointer pinned at the very top of the screen has y == maxY.
    private static func contains(_ rect: CGRect, _ p: CGPoint) -> Bool {
        p.x >= rect.minX && p.x <= rect.maxX && p.y >= rect.minY && p.y <= rect.maxY
    }
}
