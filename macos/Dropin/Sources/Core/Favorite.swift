import Foundation

/// A saved recurring place. `label` is display-only (e.g. "Home"); the shared *link*
/// always uses `place` (name + placeID), so the recipient sees the real place, not the label.
struct Favorite: Equatable, Codable, Sendable, Identifiable {
    var id: UUID = UUID()
    /// Custom display label. Empty ⇒ show `place.name`.
    var label: String = ""
    var place: Place

    /// What a row shows: the trimmed label, or the place name when no label is set.
    var displayName: String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? place.name : trimmed
    }
}
