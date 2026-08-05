import Foundation

/// Pure, standalone, unit-testable core — the Swift analogue of v0's `src/places.ts`.
/// Imports only Foundation, so it links into the `DropinTests` logic-test bundle with
/// no AppKit/SwiftUI/MapKit dependency, exactly how places.test.ts runs under bare node.
enum LinkBuilder {
    /// 6-decimal coordinate string (~11 cm). Matches v0's coordString / toFixed(6).
    static func coordString(_ p: Place) -> String {
        String(format: "%.6f,%.6f", p.lat, p.lon)
    }

    static func mapsURL(_ p: Place, _ provider: MapProvider) -> String {
        let ll = coordString(p)
        switch provider {
        case .google:
            // `query` as coordinates pins the exact spot rather than re-searching the name.
            return "https://www.google.com/maps/search/?api=1&query=\(enc(ll))"
        case .osm:
            // v0 uses the raw doubles here (not the 6-dp string) — keep that asymmetry.
            return "https://www.openstreetmap.org/?mlat=\(p.lat)&mlon=\(p.lon)#map=17/\(p.lat)/\(p.lon)"
        case .geo:
            return "geo:\(ll)?q=\(enc("\(ll)(\(p.name))"))"
        case .apple:
            // Unified maps.apple.com/place form (macOS 15.4+). A place-id resolves to the canonical
            // POI card in iMessage's rich preview (a bare ll+q link renders a generic "Location"
            // pin); coordinate keeps the exact pin; name/address label it and are the fallback.
            var params = ["coordinate=\(ll)"]
            if let id = p.placeID, !id.isEmpty { params.insert("place-id=\(enc(id))", at: 0) }
            if !p.name.isEmpty { params.append("name=\(enc(p.name))") }
            if !p.address.isEmpty { params.append("address=\(enc(p.address))") }
            return "https://maps.apple.com/place?" + params.joined(separator: "&")
        }
    }

    /// The exact text that gets pasted or copied. Mirrors v0's buildPayload switch.
    static func payload(_ p: Place, _ s: PlaceSettings) -> String {
        let url = mapsURL(p, s.provider)
        switch s.outputFormat {
        case .nameLink: return "\(p.name)\n\(url)"
        case .nameInline: return "\(p.name) — \(url)"
        case .nameAddressLink: return [p.name, p.address, url].filter { !$0.isEmpty }.joined(separator: "\n")
        case .markdownLink: return "[\(p.name)](\(url))"
        case .address: return p.address.isEmpty ? p.name : p.address
        case .nameAddressInline:
            return "\([p.name, p.address].filter { !$0.isEmpty }.joined(separator: ", ")) — \(url)"
        case .link: return url
        }
    }

    /// Parses a "lat,lon" bias string; nil if unusable. Mirrors v0's parseBias range checks.
    static func parseBias(_ raw: String) -> (lat: Double, lon: Double)? {
        let parts = raw.trimmingCharacters(in: .whitespaces).split(separator: ",")
        guard parts.count == 2,
              let lat = Double(parts[0].trimmingCharacters(in: .whitespaces)),
              let lon = Double(parts[1].trimmingCharacters(in: .whitespaces)),
              lat.isFinite, lon.isFinite,
              (-90...90).contains(lat), (-180...180).contains(lon)
        else { return nil }
        return (lat, lon)
    }

    /// encodeURIComponent-equivalent. Plain `.urlQueryAllowed` leaves `& = ? # +` intact and
    /// WOULD corrupt a `q=` value like "Ben & Jerry's #1" (truncating at `#`).
    private static func enc(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? s
    }
}

extension CharacterSet {
    /// `.urlQueryAllowed` minus the sub-delimiters that break a query value.
    static let urlQueryValueAllowed: CharacterSet = {
        var cs = CharacterSet.urlQueryAllowed
        cs.remove(charactersIn: "&=?#+")
        return cs
    }()
}
