import XCTest

/// Ports v0's tests/places.test.ts assertions to the pure Swift core, so the
/// link/payload logic stays verified independent of any UI.
final class LinkBuilderTests: XCTestCase {
    private let switchyards = Place(
        id: "N1", name: "Switchyards",
        address: "151 Ted Turner Drive Northwest, Atlanta, Georgia, United States",
        lat: 33.7489954, lon: -84.3879824)

    func testCoordStringFixesSixDecimals() {
        XCTAssertEqual(LinkBuilder.coordString(switchyards), "33.748995,-84.387982")
    }

    func testAppleLinkCarriesNameAsPinLabel() throws {
        let url = try XCTUnwrap(URLComponents(string: LinkBuilder.mapsURL(switchyards, .apple)))
        XCTAssertEqual(url.host, "maps.apple.com")
        let q = url.queryItems ?? []
        XCTAssertEqual(q.first(where: { $0.name == "ll" })?.value, "33.748995,-84.387982")
        XCTAssertEqual(q.first(where: { $0.name == "q" })?.value, "Switchyards")
    }

    func testGoogleLinkPinsExactCoordinates() throws {
        let url = try XCTUnwrap(URLComponents(string: LinkBuilder.mapsURL(switchyards, .google)))
        XCTAssertEqual(url.host, "www.google.com")
        let q = url.queryItems ?? []
        XCTAssertEqual(q.first(where: { $0.name == "api" })?.value, "1")
        XCTAssertEqual(q.first(where: { $0.name == "query" })?.value, "33.748995,-84.387982")
    }

    func testOsmLinkHasMarkerAndZoomHash() {
        let url = LinkBuilder.mapsURL(switchyards, .osm)
        XCTAssertTrue(url.contains("mlat=33.7489954"), url)
        XCTAssertTrue(url.contains("#map=17/"), url)
    }

    func testGeoURIIsWellFormed() {
        let url = LinkBuilder.mapsURL(switchyards, .geo)
        XCTAssertTrue(url.hasPrefix("geo:33.748995,-84.387982?q="), url)
        XCTAssertTrue(url.contains("(Switchyards)"), url)
    }

    func testNamesWithSpecialCharactersSurviveEncoding() throws {
        let tricky = Place(id: "x", name: "Ben & Jerry's #1", address: "", lat: 33.7489954, lon: -84.3879824)
        let url = try XCTUnwrap(URLComponents(string: LinkBuilder.mapsURL(tricky, .apple)))
        // Round-trips through encode/decode without the & or # corrupting the query.
        XCTAssertEqual(url.queryItems?.first(where: { $0.name == "q" })?.value, "Ben & Jerry's #1")
    }

    func testDefaultPayloadIsBareLink() {
        let payload = LinkBuilder.payload(switchyards, PlaceSettings(provider: .apple, outputFormat: .link))
        XCTAssertTrue(payload.hasPrefix("https://maps.apple.com/"))
        XCTAssertFalse(payload.contains("\n"), "extra text would suppress iMessage's rich preview")
    }

    func testPayloadFormatsComposeNameAddressLink() {
        let nameLink = LinkBuilder.payload(switchyards, PlaceSettings(provider: .apple, outputFormat: .nameLink))
        XCTAssertEqual(nameLink.split(separator: "\n").count, 2)
        XCTAssertTrue(nameLink.hasPrefix("Switchyards\nhttps://"))

        let inline = LinkBuilder.payload(switchyards, PlaceSettings(provider: .apple, outputFormat: .nameInline))
        XCTAssertFalse(inline.contains("\n"))
        XCTAssertTrue(inline.hasPrefix("Switchyards — https://"))

        let full = LinkBuilder.payload(switchyards, PlaceSettings(provider: .apple, outputFormat: .nameAddressLink))
        XCTAssertEqual(full.split(separator: "\n").count, 3)
        XCTAssertTrue(full.contains("151 Ted Turner Drive Northwest"))
    }

    func testMarkdownAddressAndInlineFormats() {
        let md = LinkBuilder.payload(switchyards, PlaceSettings(provider: .apple, outputFormat: .markdownLink))
        XCTAssertTrue(md.hasPrefix("[Switchyards](https://maps.apple.com/"), md)
        XCTAssertTrue(md.hasSuffix(")"))

        let addr = LinkBuilder.payload(switchyards, PlaceSettings(provider: .apple, outputFormat: .address))
        XCTAssertEqual(addr, switchyards.address)

        let bare = Place(id: "b", name: "Switchyards", address: "", lat: 33.7, lon: -84.3)
        XCTAssertEqual(LinkBuilder.payload(bare, PlaceSettings(provider: .apple, outputFormat: .address)),
                       bare.name, "address falls back to name when empty")

        let inline = LinkBuilder.payload(switchyards, PlaceSettings(provider: .apple, outputFormat: .nameAddressInline))
        XCTAssertFalse(inline.contains("\n"))
        XCTAssertTrue(inline.hasPrefix("Switchyards, 151 Ted Turner Drive Northwest"))
        XCTAssertTrue(inline.contains(" — https://"))
    }

    func testParseBiasAcceptsGoodAndRejectsBad() {
        XCTAssertNotNil(LinkBuilder.parseBias("33.749,-84.388"))
        XCTAssertNotNil(LinkBuilder.parseBias("  33.749 , -84.388 "))
        XCTAssertNotNil(LinkBuilder.parseBias("40,-74"))
        XCTAssertNil(LinkBuilder.parseBias(""))
        XCTAssertNil(LinkBuilder.parseBias("Atlanta"))
        XCTAssertNil(LinkBuilder.parseBias("91,0"), "latitude out of range")
        XCTAssertNil(LinkBuilder.parseBias("0,181"), "longitude out of range")
        XCTAssertNil(LinkBuilder.parseBias("33.749"), "needs both values")
    }
}
