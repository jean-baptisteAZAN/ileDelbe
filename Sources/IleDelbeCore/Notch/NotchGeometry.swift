import CoreGraphics

/// Width of the closed pill's wings on each side of the notch.
public struct ClosedWings: Equatable, Sendable {
    public var left: CGFloat
    public var right: CGFloat
    public init(left: CGFloat, right: CGFloat) { self.left = left; self.right = right }

    public static let none = ClosedWings(left: 0, right: 0)
    public static let standard = ClosedWings(left: 36, right: 36)
    public static let title = ClosedWings(left: 36, right: 120)
    public static let alert = ClosedWings(left: 110, right: 110)
}

/// Notch-related rects in AppKit screen coordinates (origin bottom-left, y up).
public struct NotchGeometry: Equatable, Sendable {
    public let notch: CGRect
    public let screenMaxY: CGFloat
    /// True for a screen without a hardware notch: the notch is drawn, not physical.
    public let isVirtual: Bool
    public static let bubbleWidth: CGFloat = 76
    public static let bubbleGap: CGFloat = 8
    public static let virtualNotchWidth: CGFloat = 180
    public static let idleBarSize = CGSize(width: 120, height: 4)
    public static let idleTolerance: CGFloat = 6

    public init(notch: CGRect, screenMaxY: CGFloat, isVirtual: Bool = false) {
        self.notch = notch
        self.screenMaxY = screenMaxY
        self.isVirtual = isVirtual
    }

    /// Notch drawn at the top center of a screen that has none.
    public static func virtual(screenFrame: CGRect, menuBarHeight: CGFloat) -> NotchGeometry {
        let notch = CGRect(x: screenFrame.midX - virtualNotchWidth / 2, y: screenFrame.maxY - menuBarHeight,
                           width: virtualNotchWidth, height: menuBarHeight)
        return NotchGeometry(notch: notch, screenMaxY: screenFrame.maxY, isVirtual: true)
    }

    public static func menuBarHeight(screenFrame: CGRect, visibleFrame: CGRect, fallback: CGFloat) -> CGFloat {
        let h = screenFrame.maxY - visibleFrame.maxY
        return h > 0 ? h : fallback
    }

    /// Thin bar shown at rest on a virtual notch.
    public var idleBarRect: CGRect {
        CGRect(x: notch.midX - Self.idleBarSize.width / 2, y: screenMaxY - Self.idleBarSize.height,
               width: Self.idleBarSize.width, height: Self.idleBarSize.height)
    }

    /// Virtual notch at rest (nothing in the wings): drawn as the thin idle bar.
    public func isIdleVirtual(_ wings: ClosedWings) -> Bool { isVirtual && wings == .none }

    /// What is drawn when closed.
    public func closedShapeRect(_ wings: ClosedWings) -> CGRect {
        isIdleVirtual(wings) ? idleBarRect : closedRect(wings)
    }

    /// What reacts to the pointer when closed: the idle bar gets a small tolerance below it.
    public func closedTriggerRect(_ wings: ClosedWings) -> CGRect {
        guard isIdleVirtual(wings) else { return closedRect(wings) }
        let bar = idleBarRect
        return CGRect(x: bar.minX, y: bar.minY - Self.idleTolerance,
                      width: bar.width, height: bar.height + Self.idleTolerance)
    }

    /// nil when screen has no notch (aux areas nil or safe top inset 0)
    public static func make(screenFrame: CGRect, safeAreaTop: CGFloat,
                            auxiliaryTopLeft: CGRect?, auxiliaryTopRight: CGRect?) -> NotchGeometry? {
        guard safeAreaTop > 0, let left = auxiliaryTopLeft, let right = auxiliaryTopRight else { return nil }
        let notch = CGRect(x: left.maxX, y: screenFrame.maxY - safeAreaTop,
                           width: right.minX - left.maxX, height: safeAreaTop)
        guard notch.width > 0 else { return nil }
        return NotchGeometry(notch: notch, screenMaxY: screenFrame.maxY, isVirtual: false)
    }

    public func closedRect(_ wings: ClosedWings) -> CGRect {
        CGRect(x: notch.minX - wings.left, y: notch.minY,
               width: notch.width + wings.left + wings.right, height: notch.height)
    }

    /// Horizontal shift of the closed pill's center from the notch center, for content that is
    /// laid out centered on the notch: drawn with it, the pill coincides with `closedRect(wings)`.
    public func closedOffsetX(_ wings: ClosedWings) -> CGFloat {
        closedRect(wings).midX - notch.midX
    }

    public func openRect(size: CGSize) -> CGRect {
        CGRect(x: notch.midX - size.width / 2, y: screenMaxY - size.height,
               width: size.width, height: size.height)
    }

    /// Panel window frame: the union of the open rect of `openSize` grown by the open halo
    /// margin, and every closed footprint that can appear (standard, title and alert wings, and
    /// the bubble after standard or title wings) grown by the closed halo margin. Symmetric around
    /// `notch.midX`, so content pinned top-center stays centered on the notch.
    public func windowFrame(openSize: CGSize, openMargin: (horizontal: CGFloat, bottom: CGFloat),
                            closedMargin: CGFloat) -> CGRect {
        let open = openRect(size: openSize)
        var half = open.width / 2 + openMargin.horizontal
        var minY = open.minY - openMargin.bottom
        var closed = [ClosedWings.standard, .title, .alert].map(closedRect)
        closed += [ClosedWings.standard, .title].map { bubbleRect(after: closedRect($0)) }
        for r in closed {
            half = max(half, notch.midX - r.minX + closedMargin, r.maxX - notch.midX + closedMargin)
            minY = min(minY, r.minY - closedMargin)
        }
        return CGRect(x: notch.midX - half, y: minY, width: 2 * half, height: screenMaxY - minY)
    }

    public func bubbleRect(after closed: CGRect) -> CGRect {
        CGRect(x: closed.maxX + Self.bubbleGap, y: notch.minY,
               width: Self.bubbleWidth, height: notch.height)
    }
}
