import CoreGraphics

/// Notch-related rects in AppKit screen coordinates (origin bottom-left, y up).
public struct NotchGeometry: Equatable, Sendable {
    public let notch: CGRect
    public let closedActive: CGRect
    public let expanded: CGRect
    public static let closedActiveWing: CGFloat = 36
    public static let expandedSize = CGSize(width: 440, height: 170)

    /// nil when screen has no notch (aux areas nil or safe top inset 0)
    public static func make(screenFrame: CGRect, safeAreaTop: CGFloat,
                            auxiliaryTopLeft: CGRect?, auxiliaryTopRight: CGRect?) -> NotchGeometry? {
        guard safeAreaTop > 0, let left = auxiliaryTopLeft, let right = auxiliaryTopRight else { return nil }
        let notch = CGRect(x: left.maxX, y: screenFrame.maxY - safeAreaTop,
                           width: right.minX - left.maxX, height: safeAreaTop)
        guard notch.width > 0 else { return nil }
        let wing = closedActiveWing
        let closedActive = CGRect(x: notch.minX - wing, y: notch.minY,
                                  width: notch.width + 2 * wing, height: notch.height)
        let size = expandedSize
        let expanded = CGRect(x: notch.midX - size.width / 2, y: screenFrame.maxY - size.height,
                              width: size.width, height: size.height)
        return NotchGeometry(notch: notch, closedActive: closedActive, expanded: expanded)
    }
}
