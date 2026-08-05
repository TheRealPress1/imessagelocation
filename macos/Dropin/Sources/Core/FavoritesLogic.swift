import Foundation

/// Pure, standalone, unit-testable list reducers for favorites — the analogue of `LinkBuilder`.
/// No persistence, no UI: every function takes a list and returns a new list (or a Bool), so it
/// runs in the Foundation-only `DropinTests` bundle.
enum FavoritesLogic {

    /// Identity key for dedup: prefer the canonical Apple place-id; otherwise 6-dp-rounded
    /// coordinates + case-insensitive name. Never the custom label (that's user metadata).
    static func placeKey(_ p: Place) -> String {
        if let id = p.placeID, !id.isEmpty { return "id:\(id)" }
        let lat = (p.lat * 1_000_000).rounded() / 1_000_000
        let lon = (p.lon * 1_000_000).rounded() / 1_000_000
        return "ll:\(lat),\(lon)|\(p.name.lowercased())"
    }

    static func containsPlace(_ list: [Favorite], _ place: Place) -> Bool {
        let key = placeKey(place)
        return list.contains { placeKey($0.place) == key }
    }

    /// Append if the place isn't already saved; otherwise return the list unchanged
    /// (idempotent — pressing Save twice does nothing).
    static func addFavorite(_ list: [Favorite], _ favorite: Favorite) -> [Favorite] {
        guard !containsPlace(list, favorite.place) else { return list }
        return list + [favorite]
    }

    static func removeFavorite(_ list: [Favorite], id: Favorite.ID) -> [Favorite] {
        list.filter { $0.id != id }
    }

    /// Reorder with the same IndexSet/offset semantics as SwiftUI's `.onMove`, but implemented
    /// in pure Foundation (SwiftUI's `move(fromOffsets:toOffset:)` can't link in the test bundle).
    static func moveFavorite(_ list: [Favorite], from source: IndexSet, to destination: Int) -> [Favorite] {
        var copy = list
        let moving = source.map { copy[$0] }                 // IndexSet iterates ascending
        for index in source.sorted(by: >) { copy.remove(at: index) }
        let insertAt = destination - source.filter { $0 < destination }.count
        copy.insert(contentsOf: moving, at: insertAt)
        return copy
    }

    static func renameFavorite(_ list: [Favorite], id: Favorite.ID, label: String) -> [Favorite] {
        list.map { fav in
            guard fav.id == id else { return fav }
            var out = fav
            out.label = label
            return out
        }
    }
}
