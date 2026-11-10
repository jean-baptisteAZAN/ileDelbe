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
    public static let bubbleWidth: CGFloat = 76
    public static let bubbleGap: CGFloat = 8

    /// nil when screen has no notch (aux areas nil or safe top inset 0)
    public static func make(screenFrame: CGRect, safeAreaTop: CGFloat,
                            auxiliaryTopLeft: CGRect?, auxiliaryTopRight: CGRect?) -> NotchGeometry? {
        guard safeAreaTop > 0, let left = auxiliaryTopLeft, let right = auxiliaryTopRight else { return nil }
        let notch = CGRect(x: left.maxX, y: screenFrame.maxY - safeAreaTop,
                           width: right.minX - left.maxX, height: safeAreaTop)
        guard notch.width > 0 else { return nil }
        return NotchGeometry(notch: notch, screenMaxY: screenFrame.maxY)
    }

    public func closedRect(_ wings: ClosedWings) -> CGRect {
        CGRect(x: notch.minX - wings.left, y: notch.minY,
               width: notch.width + wings.left + wings.right, height: notch.height)
    }

    public func openRect(size: CGSize) -> CGRect {
        CGRect(x: notch.midX - size.width / 2, y: screenMaxY - size.height,
               width: size.width, height: size.height)
    }

    public func bubbleRect(after closed: CGRect) -> CGRect {
        CGRect(x: closed.maxX + Self.bubbleGap, y: notch.minY,
               width: Self.bubbleWidth, height: notch.height)
    }
}
