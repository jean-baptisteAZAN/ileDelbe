import Foundation
import IleDelbeCore
import Observation

/// The user's settings, persisted under `AppSettings.storageKey`. Every write is normalized
/// (bounds, module list repair, forced module reset) before it is stored, observed and saved.
@MainActor @Observable
final class SettingsStore {
    /// Observed backing value; always normalized.
    private var stored: AppSettings

    var settings: AppSettings {
        get { stored }
        set {
            // A computed front instead of `didSet`: re-assigning a normalized value from inside
            // `didSet` is fragile under the @Observable macro's accessor rewriting.
            let normalized = newValue.normalized()
            guard normalized != stored else { return }  // no spurious observation or write
            stored = normalized
            defaults.set(normalized.encoded(), forKey: AppSettings.storageKey)
        }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        stored = AppSettings.load(defaults.data(forKey: AppSettings.storageKey))
    }
}
