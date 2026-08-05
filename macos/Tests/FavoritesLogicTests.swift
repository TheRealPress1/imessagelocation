import XCTest

final class FavoritesLogicTests: XCTestCase {
    private let switchyards = Place(
        id: "N1", name: "Switchyards",
        address: "151 Ted Turner Dr NW, Atlanta",
        lat: 33.7489954, lon: -84.3879824, placeID: "IABC123")

    private let bareDrop = Place(
        id: "b", name: "33.749, -84.388", address: "",
        lat: 33.7489954, lon: -84.3879824, placeID: nil)

    func testAddIsIdempotentByPlaceID() {
        let list = FavoritesLogic.addFavorite([], Favorite(label: "Work", place: switchyards))
        // Same placeID, different label → not added twice.
        let again = FavoritesLogic.addFavorite(list, Favorite(label: "Office", place: switchyards))
        XCTAssertEqual(again.count, 1)
    }

    func testDedupFallsBackToCoordAndNameWhenNoPlaceID() {
        let a = FavoritesLogic.addFavorite([], Favorite(place: bareDrop))
        let b = FavoritesLogic.addFavorite(a, Favorite(place: bareDrop))
        XCTAssertEqual(b.count, 1, "same coord + name dedups")
        var renamed = bareDrop; renamed.name = "Somewhere else"
        let c = FavoritesLogic.addFavorite(a, Favorite(place: renamed))
        XCTAssertEqual(c.count, 2, "different name at same coord is distinct")
    }

    func testContainsPlaceMatchesByPlaceIDIgnoringLabel() {
        let list = [Favorite(label: "Home", place: switchyards)]
        XCTAssertTrue(FavoritesLogic.containsPlace(list, switchyards))
        XCTAssertFalse(FavoritesLogic.containsPlace(list, bareDrop.with(placeID: "OTHER")))
    }

    func testRemoveById() {
        let f = Favorite(place: switchyards)
        XCTAssertTrue(FavoritesLogic.removeFavorite([f], id: f.id).isEmpty)
        XCTAssertEqual(FavoritesLogic.removeFavorite([f], id: UUID()).count, 1, "absent id is a no-op")
    }

    func testRenameChangesLabelNotIdentity() {
        let f = Favorite(label: "", place: switchyards)
        let out = FavoritesLogic.renameFavorite([f], id: f.id, label: "Home")
        XCTAssertEqual(out.first?.label, "Home")
        XCTAssertEqual(out.first?.id, f.id, "rename keeps identity stable")
    }

    func testMoveReordersByOffsets() {
        let a = Favorite(label: "A", place: switchyards)
        let b = Favorite(label: "B", place: bareDrop)
        let out = FavoritesLogic.moveFavorite([a, b], from: IndexSet(integer: 1), to: 0)
        XCTAssertEqual(out.map(\.label), ["B", "A"])
    }

    func testDisplayNameFallsBackToPlaceName() {
        XCTAssertEqual(Favorite(label: "  ", place: switchyards).displayName, "Switchyards")
        XCTAssertEqual(Favorite(label: "Home", place: switchyards).displayName, "Home")
    }

    /// The load-bearing invariant: the SENT payload uses the real place, never the label.
    func testSentPayloadUsesRealPlaceNotLabel() {
        let fav = Favorite(label: "Home", place: switchyards)
        let payload = LinkBuilder.payload(fav.place, PlaceSettings(provider: .apple, outputFormat: .nameLink))
        XCTAssertTrue(payload.hasPrefix("Switchyards\n"), payload)
        XCTAssertFalse(payload.contains("Home"))
    }

    func testCodableRoundTrip() throws {
        let list = [Favorite(label: "Home", place: switchyards), Favorite(place: bareDrop)]
        let data = try JSONEncoder().encode(list)
        XCTAssertEqual(try JSONDecoder().decode([Favorite].self, from: data), list)
    }
}

private extension Place {
    func with(placeID: String?) -> Place {
        var copy = self; copy.placeID = placeID; return copy
    }
}
