import Foundation

public struct RGBColor: Equatable, Sendable {
    public var r, g, b: Double
    public init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }
}

public enum HaloColor {
    public static let minSaturation = 0.15, minBrightness = 0.12
    public static let boostedSaturation = 0.55, boostedBrightness = 0.75

    /// nil when the average is too grey (S < minSaturation) or too dark (B < minBrightness);
    /// otherwise same hue with S = max(S, boostedSaturation), B = max(B, boostedBrightness).
    public static func glow(fromAverage c: RGBColor) -> RGBColor? {
        let mx = max(c.r, c.g, c.b), mn = min(c.r, c.g, c.b)
        guard mx > 0 else { return nil }
        let s = (mx - mn) / mx
        guard s >= minSaturation, mx >= minBrightness else { return nil }
        let d = mx - mn
        var h: Double
        if mx == c.r { h = ((c.g - c.b) / d).truncatingRemainder(dividingBy: 6) }
        else if mx == c.g { h = (c.b - c.r) / d + 2 }
        else { h = (c.r - c.g) / d + 4 }
        if h < 0 { h += 6 }
        return fromHSB(h: h, s: max(s, boostedSaturation), v: max(mx, boostedBrightness))
    }

    /// h in 0..<6 (sextants).
    private static func fromHSB(h: Double, s: Double, v: Double) -> RGBColor {
        let c = v * s
        let x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1))
        let m = v - c
        let (r, g, b): (Double, Double, Double)
        switch Int(h) {
        case 0: (r, g, b) = (c, x, 0)
        case 1: (r, g, b) = (x, c, 0)
        case 2: (r, g, b) = (0, c, x)
        case 3: (r, g, b) = (0, x, c)
        case 4: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        return RGBColor(r: r + m, g: g + m, b: b + m)
    }
}
