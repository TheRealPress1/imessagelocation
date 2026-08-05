import Foundation

/// Single source of truth for prefs, read by BOTH SwiftUI (@AppStorage) and the
/// non-SwiftUI paste path. @AppStorage defaults to UserDefaults.standard, so the
/// keys here must match the @AppStorage keys in the Settings views.
enum SettingsStore {
    private static let defaults = UserDefaults.standard

    enum Key {
        static let provider = "provider"
        static let format = "outputFormat"
        static let near = "searchNear"
        static let unit = "distanceUnit"
    }

    /// Snapshot for `LinkBuilder.payload` (used by the paste path, off SwiftUI).
    static var current: PlaceSettings {
        PlaceSettings(
            provider: defaults.string(forKey: Key.provider).flatMap(MapProvider.init(rawValue:)) ?? .apple,
            outputFormat: defaults.string(forKey: Key.format).flatMap(OutputFormat.init(rawValue:)) ?? .link,
            searchNear: defaults.string(forKey: Key.near) ?? "",
            distanceUnit: defaults.string(forKey: Key.unit).flatMap(DistanceUnit.init(rawValue:)) ?? .km
        )
    }
}
