import Foundation

/// Which map service shared links point to. Raw values are the persisted schema —
/// keep them frozen (they mirror v0's package.json dropdown values).
enum MapProvider: String, CaseIterable, Codable, Sendable, Identifiable {
    case apple, google, osm, geo
    var id: String { rawValue }
    var label: String {
        switch self {
        case .apple: return "Apple Maps (best preview in iMessage)"
        case .google: return "Google Maps (most universal)"
        case .osm: return "OpenStreetMap"
        case .geo: return "geo: URI (raw coordinates)"
        }
    }
}

/// What text gets pasted. Mirrors v0's `OutputFormat` union, including the
/// markdownLink / address / nameAddressInline additions shipped in v0.
enum OutputFormat: String, CaseIterable, Codable, Sendable, Identifiable {
    case link, nameLink, nameInline, nameAddressLink, markdownLink, address, nameAddressInline
    var id: String { rawValue }
    var title: String {
        switch self {
        case .link: return "Just the link (renders a map preview)"
        case .nameLink: return "Name, then link on a new line"
        case .nameInline: return "Name — link, on one line"
        case .nameAddressLink: return "Name, address, then link"
        case .markdownLink: return "Markdown link — [Name](url)"
        case .address: return "Address only (no link)"
        case .nameAddressInline: return "Name, address — link, on one line"
        }
    }
}

/// Plain value snapshot of the prefs the link builder needs. Keeps `LinkBuilder`
/// UI-free and injectable, so it stays unit-testable like v0's places.ts.
struct PlaceSettings: Equatable, Sendable {
    var provider: MapProvider = .apple
    var outputFormat: OutputFormat = .link
    /// Raw "lat,lon" bias string, validated by `LinkBuilder.parseBias`.
    var searchNear: String = ""
    var distanceUnit: DistanceUnit = .km
}

enum DistanceUnit: String, CaseIterable, Codable, Sendable, Identifiable {
    case km, mi
    var id: String { rawValue }
    var label: String { self == .km ? "Kilometres / metres" : "Miles / feet" }
}
