import AppKit
import CoreGraphics
import IleDelbeCore

/// Reads the connected screens: identity, kind and notch geometry.
@MainActor
enum ScreenProvider {
    /// Every connected screen, in `NSScreen.screens` order (the first one is the main screen).
    /// Ids are unique: identical monitors can share a display UUID, so a repeat gets a
    /// `#<CGDirectDisplayID>` suffix (the first one keeps the bare UUID).
    static func current() -> [(info: ScreenInfo, screen: NSScreen)] {
        let screens = NSScreen.screens
        var used = Set<String>()
        return screens.enumerated().map { index, screen in
            let displayID = displayID(of: screen)
            let base = identifier(of: screen, displayID: displayID)
            var id = base
            if used.contains(id) { id = "\(base)#\(displayID.map(String.init) ?? String(index))" }
            var n = 2
            while used.contains(id) {
                id = "\(base)#\(index)-\(n)"
                n += 1
            }
            used.insert(id)
            let info = ScreenInfo(id: id,
                                  name: screen.localizedName,
                                  isBuiltIn: displayID.map { CGDisplayIsBuiltin($0) != 0 } ?? false,
                                  isMain: index == 0,
                                  hasNotch: hardwareNotch(screen) != nil)
            return (info, screen)
        }
    }

    /// The hardware notch when the screen has one, else a virtual notch at its top center,
    /// as tall as its menu bar. A screen that reports none (menu bar hidden, not yet laid out)
    /// borrows the main screen's menu bar height, then the system status bar thickness.
    static func geometry(for screen: NSScreen) -> NotchGeometry {
        if let g = hardwareNotch(screen) { return g }
        let height = NotchGeometry.menuBarHeight(screenFrame: screen.frame, visibleFrame: screen.visibleFrame,
                                                 fallback: fallbackMenuBarHeight())
        return .virtual(screenFrame: screen.frame, menuBarHeight: height)
    }

    private static func hardwareNotch(_ screen: NSScreen) -> NotchGeometry? {
        NotchGeometry.make(screenFrame: screen.frame, safeAreaTop: screen.safeAreaInsets.top,
                           auxiliaryTopLeft: screen.auxiliaryTopLeftArea,
                           auxiliaryTopRight: screen.auxiliaryTopRightArea)
    }

    /// The primary screen's own menu bar height when it reports one, else the status bar thickness.
    private static func fallbackMenuBarHeight() -> CGFloat {
        if let primary = NSScreen.screens.first {
            let h = primary.frame.maxY - primary.visibleFrame.maxY
            if h > 0 { return h }
        }
        return NSStatusBar.system.thickness
    }

    private static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    /// The display UUID string: stable across reconnects, unlike the display number.
    private static func identifier(of screen: NSScreen, displayID: CGDirectDisplayID?) -> String {
        guard let displayID else { return "screen-\(screen.localizedName)" }
        if let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue(),
           let string = CFUUIDCreateString(nil, uuid) as String? {
            return string
        }
        return "display-\(displayID)"
    }
}
