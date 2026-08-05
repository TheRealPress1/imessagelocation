import Foundation

/// A normalised place, independent of whichever provider produced it.
/// Mirrors v0's `Place` in `src/places.ts`.
struct Place: Equatable, Codable, Sendable, Identifiable {
    var id: String
    var name: String
    /// Human-readable address line; may be empty for wide areas or bare map drops.
    var address: String
    var lat: Double
    var lon: Double
    /// Apple Maps place identifier (MKMapItem.identifier.rawValue), when the place came from
    /// search. Lets the Apple link resolve to the canonical named card in iMessage.
    var placeID: String? = nil
}
