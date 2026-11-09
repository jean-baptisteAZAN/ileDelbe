import Foundation

public enum RelativeTime {
    public static func string(from date: Date, now: Date) -> String {
        let delta = max(0, now.timeIntervalSince(date))
        if delta < 60 { return "à l'instant" }
        if delta < 3_600 { return "il y a \(Int(delta / 60)) min" }
        if delta < 86_400 { return "il y a \(Int(delta / 3_600)) h" }
        if delta < 172_800 { return "hier" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "d MMM"
        return "le " + f.string(from: date)
    }
}
