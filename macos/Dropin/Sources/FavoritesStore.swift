import Foundation
import Observation

/// Shared source of truth for favorites, observed by both the panel and Preferences.
/// @Observable + @MainActor singleton (macOS 26 idiom). Backed by one JSON blob in
/// UserDefaults.standard (same store as SettingsStore); @AppStorage can't hold arrays.
/// Views read `FavoritesStore.shared` directly — an @Observable read in `body` is tracked
/// by SwiftUI, so no environment injection is needed.
@MainActor
@Observable
final class FavoritesStore {
    static let shared = FavoritesStore()

    private static let key = "favorites"
    private let defaults = UserDefaults.standard

    private(set) var favorites: [Favorite]

    init() {
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([Favorite].self, from: data) {
            favorites = decoded
        } else {
            favorites = []
        }
    }

    func isFavorite(_ place: Place) -> Bool { FavoritesLogic.containsPlace(favorites, place) }

    func add(_ place: Place, label: String = "") {
        favorites = FavoritesLogic.addFavorite(favorites, Favorite(label: label, place: place))
        save()
    }

    func remove(id: Favorite.ID) {
        favorites = FavoritesLogic.removeFavorite(favorites, id: id)
        save()
    }

    func rename(id: Favorite.ID, label: String) {
        favorites = FavoritesLogic.renameFavorite(favorites, id: id, label: label)
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        favorites = FavoritesLogic.moveFavorite(favorites, from: source, to: destination)
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(favorites) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
