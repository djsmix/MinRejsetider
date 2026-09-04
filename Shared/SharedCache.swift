import Foundation

/// Delt cache + settings i App Group, så app og widget deler data
/// og undgår dobbelt-kald.
enum SharedStore {
    static var defaults: UserDefaults {
        UserDefaults(suiteName: SharedConstants.appGroup) ?? .standard
    }

    // MARK: Settings
    static func loadSettings() -> AppSettings {
        guard let d = defaults.data(forKey: "settings"),
              let s = try? JSONDecoder().decode(AppSettings.self, from: d)
        else { return AppSettings() }
        return s
    }
    static func saveSettings(_ s: AppSettings) {
        if let d = try? JSONEncoder().encode(s) {
            defaults.set(d, forKey: "settings")
        }
    }

    // MARK: Departures cache (ét samlet cache for multi-kald)
    struct CacheEnvelope: Codable {
        var fetchedAt: Date
        var departures: [Departure]
    }

    static func loadCache() -> CacheEnvelope? {
        guard let d = defaults.data(forKey: "departureCache"),
              let c = try? JSONDecoder().decode(CacheEnvelope.self, from: d)
        else { return nil }
        return c
    }
    static func saveCache(_ deps: [Departure], at: Date = Date()) {
        let env = CacheEnvelope(fetchedAt: at, departures: deps)
        if let d = try? JSONEncoder().encode(env) {
            defaults.set(d, forKey: "departureCache")
        }
        defaults.set(at, forKey: "lastFetch")
    }
    static func lastFetch() -> Date? {
        defaults.object(forKey: "lastFetch") as? Date
    }
    static func cacheAge(now: Date = Date()) -> TimeInterval? {
        guard let l = lastFetch() else { return nil }
        return now.timeIntervalSince(l)
    }
}
