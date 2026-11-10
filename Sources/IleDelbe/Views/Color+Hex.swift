import SwiftUI

extension Color {
    /// "#RRGGBB" (leading # optional); nil if malformed.
    init?(hex: String?) {
        guard let s = hex?.trimmingCharacters(in: CharacterSet(charactersIn: "#")), s.count == 6,
              let v = UInt32(s, radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }

    /// A halo opacity scaled by the « Intensité du halo » setting, clamped to 1.
    func haloOpacity(_ base: Double, scale: Double) -> Color {
        opacity(min(base * scale, 1))
    }
}
