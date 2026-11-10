import AppKit
import CoreGraphics
import IleDelbeCore

/// Reads the connected screens: identity, kind and notch geometry.
@MainActor
enum ScreenProvider {
    /// Every connected screen, in `NSScreen.screens` order (the first one is the main screen).
    static func current() -> [(info: ScreenInfo, screen: NSScreen)] {
        let screens = NSScreen.screens
        return screens.enumerated().map { index, screen in
            let displayID = displayID(of: screen)
            let info = ScreenInfo(id: identifier(of: screen, displayID: displayID),
                                  name: screen.localizedName,
                                  isBuiltIn: displayID.map { CGDisplayIsBuiltin($0) != 0 } ?? false,
                                  isMain: index == 0,
                                  hasNotch: hasNotch(screen))
            return (info, screen)
        }
    }

    /// The hardware notch when the screen has one, else a virtual notch at its top center,
    /// as tall as its menu bar (the system menu bar height when it reports none).
    static func geometry(for screen: NSScreen) -> NotchGeometry {
        if let g = NotchGeometry.make(screenFrame: screen.frame, safeAreaTop: screen.safeAreaInsets.top,
                                      auxiliaryTopLeft: screen.auxiliaryTopLeftArea,
                                      auxiliaryTopRight: screen.auxiliaryTopRightArea) {
            return g
        }
        let height = NotchGeometry.menuBarHeight(screenFrame: screen.frame, visibleFrame: screen.visibleFrame,
                                                 fallback: NSStatusBar.system.thickness)
        return .virtual(screenFrame: screen.frame, menuBarHeight: height)
    }

    private static func hasNotch(_ screen: NSScreen) -> Bool {
        screen.safeAreaInsets.top > 0 && screen.auxiliaryTopLeftArea != nil && screen.auxiliaryTopRightArea != nil
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
