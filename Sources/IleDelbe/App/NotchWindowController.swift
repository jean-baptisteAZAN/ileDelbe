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
    /// Whether the pointer was last seen inside the bubble rect while closed (open → Minuteur tab).
    private var pointerInBubble = false

    /// The window extends past `expanded` (sides and bottom) only so the open halo is not cut by
    /// the window edge. Hover/click rects stay geometry-based; the margin is transparent and the
    /// panel ignores mouse events while closed.
    static let glowMargin = (horizontal: CGFloat(30), bottom: CGFloat(44))

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
        let e = geometry.expanded
        let m = Self.glowMargin
        let frame = CGRect(x: e.minX - m.horizontal, y: e.minY - m.bottom,
                           width: e.width + 2 * m.horizontal, height: e.height + m.bottom)
        panel.setFrame(NSIntegralRect(frame), display: true)
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

    /// Re-arms itself on every change, so the trigger rect follows the bubble / alert width.
    private func observeClosedLayout() {
        _ = withObservationTracking {
            model.closedLayout
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
        let nowPlaying = model.nowPlaying
        let mouse = NSEvent.mouseLocation
        // Safety net: a drag session can swallow the mouse-up; a move with the button up ends it.
        if model.isDraggingFile, NSEvent.pressedMouseButtons & 1 == 0 { model.isDraggingFile = false }
        var inTrigger: Bool
        if hover.isOpen {
            inTrigger = Self.contains(geometry.expanded, mouse)
        } else {
            let layout = model.closedLayout
            let main: CGRect = switch layout {
            case .plain: geometry.notch
            case .media, .mediaAndBubble, .timer: geometry.closedActive  // the visible pill
            case .alert: geometry.closedAlert
            }
            let inBubble = layout == .mediaAndBubble && Self.contains(geometry.bubble, mouse)
            inTrigger = Self.contains(main, mouse) || inBubble
            if inTrigger { pointerInBubble = inBubble }
        }
        if model.isDraggingFile { inTrigger = true }  // keep the panel open while dragging a file out
        if case .unavailable = nowPlaying.status { inTrigger = false }  // adapter down: show nothing
        let now = ProcessInfo.processInfo.systemUptime
        hover.update(inTrigger: inTrigger, now: now)
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
        if hover.isOpen { model.panelWillOpen(fromBubble: pointerInBubble) }
        model.isOpen = hover.isOpen
        if !hover.isOpen { model.panelDidClose() }
        // Closed: never intercept clicks (menu bar stays usable), bubble included.
        panel.ignoresMouseEvents = !hover.isOpen
    }

    /// Inclusive of the max edges: the pointer pinned at the very top of the screen has y == maxY.
    private static func contains(_ rect: CGRect, _ p: CGPoint) -> Bool {
        p.x >= rect.minX && p.x <= rect.maxX && p.y >= rect.minY && p.y <= rect.maxY
    }
}
