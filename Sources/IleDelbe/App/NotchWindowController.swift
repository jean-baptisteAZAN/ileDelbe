import AppKit
import IleDelbeCore
import SwiftUI
import os

/// Owns the notch panel of one screen: placement, hover detection, open/close. One per selected
/// screen (`ScreenCoordinator`); the model is shared and at most one panel is open at a time.
@MainActor
final class NotchWindowController {
    let id: String
    private(set) var geometry: NotchGeometry
    private let model: NotchViewModel
    private let panel: NotchPanel
    private let hosting: NSHostingView<NotchRootView>
    private let log = Logger(subsystem: "io.github.ileDelbe", category: "window")
    private var hover: HoverStateMachine
    private var deadlineWork: DispatchWorkItem?
    /// A window shrink deferred while open (`applyFrame(deferShrink:)`), applied after closing.
    private var hasPendingShrink = false
    private var settleWork: DispatchWorkItem?
    private var monitors: [Any] = []
    private var isTornDown = false
    /// Identifies the live `observeWindowSize` observation.
    private var windowSizeToken = UUID()
    /// Whether the pointer was last seen inside the bubble rect while closed (open → Minuteur tab).
    private var pointerInBubble = false
    /// Two-finger horizontal swipe → one Île page per gesture.
    private var swipe = PageSwipe()

    init(model: NotchViewModel, screenID: String, geometry: NotchGeometry) {
        self.model = model
        id = screenID
        self.geometry = geometry
        hover = HoverStateMachine(openDelay: model.settings.settings.openDelay)
        panel = NotchPanel(contentRect: .zero)
        hosting = NSHostingView(rootView: NotchRootView(model: model, screenID: screenID, geometry: geometry))
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
        // Île page swipe. Local only: scroll events reach the panel only while it takes clicks,
        // i.e. open and under the pointer. Never a global scroll monitor.
        if let local = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handleScroll(event) }
            return event
        }) {
            monitors.append(local)
        }
        observeSharedState()
        observeWindowSize()
        observeOpenDelay()
    }

    // MARK: Geometry

    /// The screen moved, resized or changed its menu bar: re-frame the window on `geometry`.
    /// `fromScreenChange`: called for `didChangeScreenParametersNotification` (wake, KVM, same-frame
    /// reconnect): re-apply the frame, order the panel front (no focus) and re-check hover even
    /// when the geometry is unchanged, as the window server may have dropped or moved the panel.
    func update(geometry: NotchGeometry, fromScreenChange: Bool) {
        guard !isTornDown else { return }
        let changed = geometry != self.geometry
        if changed {
            self.geometry = geometry
            hosting.rootView = NotchRootView(model: model, screenID: id, geometry: geometry)
        }
        if changed || fromScreenChange { layout() }
        // The open size depends on the notch height: track the new geometry.
        if changed { observeWindowSize() }
    }

    /// The screen is gone or no longer selected: close, stop listening, hide the window.
    func tearDown() {
        guard !isTornDown else { return }
        closeNow()
        isTornDown = true
        deadlineWork?.cancel()
        deadlineWork = nil
        settleWork?.cancel()
        settleWork = nil
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        panel.ignoresMouseEvents = true
        panel.orderOut(nil)
    }

    private func layout() {
        applyFrame()
        panel.orderFrontRegardless()
        let g = geometry
        log.info("notch \(NSStringFromRect(g.notch), privacy: .public) virtual=\(g.isVirtual, privacy: .public)")
        evaluateHover()
    }

    /// Frames the window on the largest open size of the current style, density and modules,
    /// widened to cover every closed pill and bubble (`NotchGeometry.windowFrame`).
    /// Only `setFrame`: never reorders the panel or takes focus, so it is safe while open.
    /// `deferShrink`: while open the shape springs down to a smaller size (~0.35 s), so shrinking
    /// the window at once would clip it. The window grows now and shrinks once the panel has
    /// closed (`settleFrameAfterClose`). Hover and pass-through use `panelSize`, not this frame.
    private func applyFrame(deferShrink: Bool = false) {
        // Windows snap to whole points; grow outward to integral bounds so the content
        // (centered by NotchRootView) stays centered on the notch, e.g. odd notch widths.
        // The window extends past the open panel so the open halo is not cut by the window edge,
        // and covers every closed pill + bubble (title mode or the alert can be wider than a
        // small open panel). That extra area never takes clicks: see `updateMousePassThrough`.
        let m = HaloStyle.windowMargin
        var frame = NSIntegralRect(geometry.windowFrame(openSize: model.maxPanelSize(for: geometry),
                                                        openMargin: (horizontal: m.horizontal, bottom: m.bottom),
                                                        closedMargin: HaloStyle.closed.radius))
        if deferShrink && model.isOpen(on: id) {
            let covering = frame.union(panel.frame)
            hasPendingShrink = covering != frame
            frame = covering
        } else {
            hasPendingShrink = false
            settleWork?.cancel()
            settleWork = nil
        }
        guard frame != panel.frame else { return }
        panel.setFrame(frame, display: true)
        log.info("panel frame \(NSStringFromRect(self.panel.frame), privacy: .public)")
    }

    /// Re-arms itself: style, density or module changes re-frame the window, even while open.
    private func observeWindowSize() {
        guard !isTornDown else { return }
        let token = UUID()
        windowSizeToken = token
        _ = withObservationTracking {
            model.maxPanelSize(for: geometry)
        } onChange: { [weak self] in
            Task { @MainActor in
                // A newer observation (re-armed by `update(geometry:)`) supersedes this one.
                guard let self, !self.isTornDown, self.windowSizeToken == token else { return }
                self.observeWindowSize()
                self.applyFrame(deferShrink: true)
                self.evaluateHover()
            }
        }
    }

    /// Re-arms itself: the hover open delay follows the setting.
    private func observeOpenDelay() {
        guard !isTornDown else { return }
        hover.openDelay = withObservationTracking {
            model.settings.settings.openDelay
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeOpenDelay() }
        }
    }

    // MARK: Hover

    /// Re-arms itself on every change, so the trigger rect follows the bubble / wings width, a
    /// notch blocked by another screen's open panel re-checks once it has closed, and the end of
    /// a file drag (seen by whichever screen's monitor runs first) reaches the open panel.
    private func observeSharedState() {
        guard !isTornDown else { return }
        _ = withObservationTracking {
            (model.closedLayout, model.closedWings, model.openScreenID, model.isDraggingFile)
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, !self.isTornDown else { return }
                self.observeSharedState()
                self.evaluateHover()
            }
        }
    }

    private func endFileDrag() {
        guard model.isDraggingFile else { return }
        model.isDraggingFile = false
        evaluateHover()
    }

    private func evaluateHover() {
        guard !isTornDown else { return }
        let mouse = NSEvent.mouseLocation
        // Safety net: a drag session can swallow the mouse-up; a move with the button up ends it.
        if model.isDraggingFile, NSEvent.pressedMouseButtons & 1 == 0 { model.isDraggingFile = false }
        // Always derived from the current state, so it follows the shape actually drawn.
        let openRect = geometry.openRect(size: model.panelSize(for: geometry))
        var inTrigger: Bool
        if hover.isOpen {
            // Keep the panel open while dragging a file out of it.
            inTrigger = Self.contains(openRect, mouse) || model.isDraggingFile
        } else if let other = model.openScreenID, other != id {
            inTrigger = false  // another screen's panel is open: wait until it has closed
        } else {
            let wings = model.closedWings
            // The visible pill (bare notch when plain); on an idle virtual notch, the thin bar
            // and its small tolerance below.
            let main = geometry.closedTriggerRect(wings)
            let inBubble = model.closedLayout == .mediaAndBubble
                && Self.contains(geometry.bubbleRect(after: geometry.closedRect(wings)), mouse)
            inTrigger = Self.contains(main, mouse) || inBubble
            if inTrigger { pointerInBubble = inBubble }
        }
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

    /// Feeds `PageSwipe` while the open Île shows its pages; a step moves one page.
    private func handleScroll(_ event: NSEvent) {
        guard hover.isOpen, model.isOpen(on: id), model.settings.settings.style == .island, !model.showsAll,
              event.window === panel else { return }
        let phase: PageSwipe.Phase
        if event.phase.contains(.began) {
            phase = .began
        } else if event.phase.contains(.changed) {
            phase = .changed
        } else if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            phase = .ended
        } else if event.phase.isEmpty {
            phase = .none  // mouse wheel, or momentum (filtered by `isMomentum`)
        } else {
            return  // .mayBegin, .stationary: no movement
        }
        if let step = swipe.feed(deltaX: event.scrollingDeltaX, deltaY: event.scrollingDeltaY, phase: phase,
                                 isMomentum: !event.momentumPhase.isEmpty) {
            model.step(step)
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
        guard model.isOpen(on: id) != hover.isOpen else { return }
        if hover.isOpen, let other = model.openScreenID, other != id {
            // Safety net (evaluateHover already blocks it): never open over another screen's panel.
            hover.forceClose()
            return
        }
        if hover.isOpen {
            model.panelWillOpen(on: id, fromBubble: pointerInBubble)
        } else {
            model.panelDidClose(on: id)
            settleFrameAfterClose()
        }
    }

    /// Applies a shrink deferred while open, once the closing spring has run (the shape may
    /// still be shrinking from a size larger than the new window). Skipped if it reopens.
    private func settleFrameAfterClose() {
        guard hasPendingShrink else { return }
        settleWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.isTornDown, !self.model.isOpen(on: self.id) else { return }
                self.applyFrame()
            }
        }
        settleWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    /// Clicks reach the panel only while it is open and the pointer is over the panel itself
    /// (or a file drag is in progress). Closed (bubble included), and in the transparent glow
    /// margin around the open panel, clicks pass through to the menu bar and apps below.
    /// Updated on every mouse move.
    private func updateMousePassThrough(inOpenPanel: Bool) {
        // A file drag only starts in the open panel: closed notches on other screens stay click-through.
        let ignores = !(hover.isOpen && (inOpenPanel || model.isDraggingFile))
        guard panel.ignoresMouseEvents != ignores else { return }
        panel.ignoresMouseEvents = ignores
        log.info("ignoresMouseEvents=\(ignores, privacy: .public)")
    }

    /// Inclusive of the max edges: the pointer pinned at the very top of the screen has y == maxY.
    private static func contains(_ rect: CGRect, _ p: CGPoint) -> Bool {
        p.x >= rect.minX && p.x <= rect.maxX && p.y >= rect.minY && p.y <= rect.maxY
    }
}
