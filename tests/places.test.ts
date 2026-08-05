import test from "node:test";
import assert from "node:assert/strict";

import {
  DEFAULT_GEOCODER,
  RECENTS_CAP,
  addToRecents,
  allProviderLinks,
  buildPayload,
  buildSearchUrl,
  containsId,
  coordString,
  detailMarkdown,
  distanceLabel,
  formatAddress,
  formatCategory,
  formatDistance,
  haversineKm,
  idleSections,
  mapsUrl,
  parseBias,
  parsePlaces,
  removeById,
  toggleFavorite,
} from "../src/places";
import type { PhotonResponse, Place, Preferences } from "../src/places";

const APPLE: Preferences = { provider: "apple", outputFormat: "link" };

/**
 * Fixture matching Photon's documented GeoJSON shape
 * (https://github.com/komoot/photon/blob/master/docs/api-v1.md).
 * Note the coordinate order: Photon emits [longitude, latitude].
 */
const FIXTURE: PhotonResponse = {
  features: [
    {
      type: "Feature",
      geometry: { type: "Point", coordinates: [-84.3879824, 33.7489954] },
      properties: {
        name: "Switchyards",
        housenumber: "151",
        street: "Ted Turner Drive Northwest",
        postcode: "30303",
        city: "Atlanta",
        state: "Georgia",
        country: "United States",
        countrycode: "US",
        osm_key: "amenity",
        osm_value: "coworking_space",
        osm_type: "N",
        osm_id: 1234567890,
      },
    },
    {
      type: "Feature",
      geometry: { type: "Point", coordinates: [13.3888599, 52.5170365] },
      properties: {
        name: "Berlin",
        city: "Berlin",
        state: "Berlin",
        country: "Germany",
        countrycode: "DE",
        osm_key: "place",
        osm_value: "city",
        osm_type: "N",
        osm_id: 240109189,
      },
    },
    // No name, only an address — should still be usable.
    {
      type: "Feature",
      geometry: { type: "Point", coordinates: [-73.9857, 40.7484] },
      properties: {
        housenumber: "20",
        street: "West 34th Street",
        city: "New York",
        state: "New York",
        country: "United States",
        osm_key: "building",
        osm_value: "yes",
      },
    },
    // Junk that must be dropped rather than crash the list.
    { type: "Feature", geometry: { type: "Point", coordinates: undefined }, properties: { name: "No coords" } },
    { type: "Feature", properties: { name: "No geometry at all" } },
    {
      type: "Feature",
      geometry: { type: "Point", coordinates: [999, 999] },
      properties: { name: "Off the planet" },
    },
  ],
};

test("parsePlaces keeps valid features and drops broken ones", () => {
  const places = parsePlaces(FIXTURE);
  assert.equal(places.length, 3, "3 of the 6 fixture features are usable");
  assert.deepEqual(
    places.map((p) => p.name),
    ["Switchyards", "Berlin", "20 West 34th Street"],
  );
});

test("parsePlaces reads coordinates in Photon's lon,lat order", () => {
  const [switchyards] = parsePlaces(FIXTURE);
  // Atlanta is ~33.7 N, ~84.4 W. Swapping these is the classic geo bug.
  assert.ok(switchyards.lat > 33 && switchyards.lat < 34, `lat was ${switchyards.lat}`);
  assert.ok(switchyards.lon > -85 && switchyards.lon < -84, `lon was ${switchyards.lon}`);
});

test("parsePlaces deduplicates the same venue returned twice", () => {
  const doubled: PhotonResponse = {
    features: [FIXTURE.features![0], { ...FIXTURE.features![0], properties: { ...FIXTURE.features![0].properties } }],
  };
  assert.equal(parsePlaces(doubled).length, 1);
});

test("parsePlaces survives empty and undefined responses", () => {
  assert.deepEqual(parsePlaces(undefined), []);
  assert.deepEqual(parsePlaces({}), []);
  assert.deepEqual(parsePlaces({ features: [] }), []);
});

test("formatAddress assembles OSM's scattered fields", () => {
  assert.equal(
    formatAddress(FIXTURE.features![0].properties!),
    "151 Ted Turner Drive Northwest, Atlanta, Georgia, United States",
  );
});

test("formatAddress does not repeat a city that is also its own state", () => {
  // Berlin is both city and state; "Berlin, Berlin, Germany" reads badly.
  assert.equal(formatAddress(FIXTURE.features![1].properties!), "Berlin, Germany");
});

test("formatCategory humanises OSM values and ignores 'yes'", () => {
  assert.equal(formatCategory({ osm_value: "coworking_space" }), "Coworking Space");
  assert.equal(formatCategory({ osm_value: "cafe" }), "Cafe");
  assert.equal(formatCategory({ osm_value: "yes" }), undefined);
  assert.equal(formatCategory({}), undefined);
});

test("parseBias accepts good coordinates and rejects bad ones", () => {
  assert.deepEqual(parseBias("33.749,-84.388"), { lat: 33.749, lon: -84.388 });
  assert.deepEqual(parseBias("  33.749 , -84.388  "), { lat: 33.749, lon: -84.388 });
  assert.deepEqual(parseBias("40,-74"), { lat: 40, lon: -74 });
  assert.equal(parseBias(undefined), null);
  assert.equal(parseBias(""), null);
  assert.equal(parseBias("Atlanta"), null);
  assert.equal(parseBias("91,0"), null, "latitude out of range");
  assert.equal(parseBias("0,181"), null, "longitude out of range");
  assert.equal(parseBias("33.749"), null, "needs both values");
});

test("buildSearchUrl targets the public Photon instance by default", () => {
  const url = new URL(buildSearchUrl("switchyards atlanta", APPLE));
  assert.equal(`${url.origin}${url.pathname}`, DEFAULT_GEOCODER);
  assert.equal(url.searchParams.get("q"), "switchyards atlanta");
  assert.equal(url.searchParams.get("limit"), "12");
  assert.equal(url.searchParams.get("lat"), null, "no bias params when unset");
});

test("buildSearchUrl adds bias params only when the preference parses", () => {
  const biased = new URL(buildSearchUrl("switchyards", { ...APPLE, bias: "33.749,-84.388" }));
  assert.equal(biased.searchParams.get("lat"), "33.749");
  assert.equal(biased.searchParams.get("lon"), "-84.388");
  assert.equal(biased.searchParams.get("location_bias_scale"), "0.6");

  const garbage = new URL(buildSearchUrl("switchyards", { ...APPLE, bias: "somewhere nice" }));
  assert.equal(garbage.searchParams.get("lat"), null);
});

test("buildSearchUrl honours a custom endpoint and strips trailing slashes", () => {
  const url = buildSearchUrl("x", { ...APPLE, geocoder: "https://photon.example.com/api///" });
  assert.ok(url.startsWith("https://photon.example.com/api?"), url);
});

const SWITCHYARDS: Place = parsePlaces(FIXTURE)[0];

test("apple links carry the name as the pin label", () => {
  const url = new URL(mapsUrl(SWITCHYARDS, "apple"));
  assert.equal(url.host, "maps.apple.com");
  assert.equal(url.searchParams.get("ll"), "33.748995,-84.387982");
  assert.equal(url.searchParams.get("q"), "Switchyards");
});

test("google links pin exact coordinates rather than re-searching the name", () => {
  const url = new URL(mapsUrl(SWITCHYARDS, "google"));
  assert.equal(url.host, "www.google.com");
  assert.equal(url.searchParams.get("api"), "1");
  assert.equal(url.searchParams.get("query"), "33.748995,-84.387982");
});

test("osm links include both a marker and a zoomed hash", () => {
  const url = mapsUrl(SWITCHYARDS, "osm");
  assert.ok(url.includes("mlat=33.7489954"), url);
  assert.ok(url.includes("#map=17/"), url);
});

test("geo URIs are well formed and encode the label", () => {
  const url = mapsUrl(SWITCHYARDS, "geo");
  assert.ok(url.startsWith("geo:33.748995,-84.387982?q="), url);
  assert.ok(decodeURIComponent(url).includes("(Switchyards)"), url);
});

test("names with spaces and ampersands survive URL encoding", () => {
  const tricky: Place = { ...SWITCHYARDS, name: "Ben & Jerry's #1" };
  const url = new URL(mapsUrl(tricky, "apple"));
  assert.equal(url.searchParams.get("q"), "Ben & Jerry's #1", "round-trips through encode/decode");
});

test("coordString fixes precision at 6 decimals (~11cm)", () => {
  assert.equal(coordString(SWITCHYARDS), "33.748995,-84.387982");
});

test("the default payload is the bare link, so iMessage renders a map preview", () => {
  const payload = buildPayload(SWITCHYARDS, { provider: "apple", outputFormat: "link" });
  assert.ok(payload.startsWith("https://maps.apple.com/"));
  assert.ok(!payload.includes("\n"), "extra text would suppress the rich preview");
});

test("payload formats compose name, address, and link as configured", () => {
  const nameLink = buildPayload(SWITCHYARDS, { provider: "apple", outputFormat: "nameLink" });
  assert.equal(nameLink.split("\n").length, 2);
  assert.ok(nameLink.startsWith("Switchyards\nhttps://"));

  const inline = buildPayload(SWITCHYARDS, { provider: "apple", outputFormat: "nameInline" });
  assert.ok(!inline.includes("\n"));
  assert.ok(inline.startsWith("Switchyards — https://"));

  const full = buildPayload(SWITCHYARDS, { provider: "apple", outputFormat: "nameAddressLink" });
  assert.equal(full.split("\n").length, 3);
  assert.ok(full.includes("151 Ted Turner Drive Northwest"));
});

test("payload falls back to the bare link when no format is configured", () => {
  const payload = buildPayload(SWITCHYARDS, { provider: "apple" });
  assert.equal(payload, mapsUrl(SWITCHYARDS, "apple"));
});

test("a place with no address omits the empty line instead of leaving a gap", () => {
  const berlin = parsePlaces(FIXTURE)[1];
  const bare: Place = { ...berlin, address: "" };
  const full = buildPayload(bare, { provider: "apple", outputFormat: "nameAddressLink" });
  assert.equal(full.split("\n").length, 2);
});

/** ------------------------------------------------------------------
 * Recents & favorites reducers (pure)
 * ------------------------------------------------------------------ */

/** Terse Place factory for list tests — only `id` matters to these reducers. */
const P = (id: string, over: Partial<Place> = {}): Place => ({
  id,
  name: id,
  address: "",
  lat: 0,
  lon: 0,
  ...over,
});

test("addToRecents prepends the newest place, keeping most-recent-first", () => {
  const list = addToRecents(addToRecents([], P("a")), P("b"));
  assert.deepEqual(
    list.map((p) => p.id),
    ["b", "a"],
  );
});

test("addToRecents dedups by id and moves the re-sent place to the front", () => {
  const list = addToRecents([P("a"), P("b"), P("c")], P("c"));
  assert.deepEqual(
    list.map((p) => p.id),
    ["c", "a", "b"],
  );
  assert.equal(list.length, 3, "no duplicate entry");
});

test("addToRecents dedups by id even when other fields changed", () => {
  const list = addToRecents([P("a", { name: "Old" })], P("a", { name: "New" }));
  assert.equal(list.length, 1);
  assert.equal(list[0].name, "New");
});

test("addToRecents caps the list, dropping the oldest", () => {
  const list = addToRecents(addToRecents(addToRecents([], P("a"), 2), P("b"), 2), P("c"), 2);
  assert.deepEqual(
    list.map((p) => p.id),
    ["c", "b"],
  );
});

test("addToRecents never mutates its input", () => {
  const input = [P("a")];
  const out = addToRecents(input, P("b"));
  assert.notEqual(out, input);
  assert.deepEqual(
    input.map((p) => p.id),
    ["a"],
    "input untouched",
  );
});

test("RECENTS_CAP is the default cap for addToRecents", () => {
  const many = Array.from({ length: RECENTS_CAP + 5 }, (_, i) => P(`p${i}`));
  const list = many.reduce<Place[]>((acc, p) => addToRecents(acc, p), []);
  assert.equal(list.length, RECENTS_CAP);
});

test("removeById drops only the matching id and preserves order", () => {
  assert.deepEqual(
    removeById([P("a"), P("b"), P("c")], "b").map((p) => p.id),
    ["a", "c"],
  );
});

test("removeById is a no-op for an absent id", () => {
  assert.deepEqual(
    removeById([P("a")], "z").map((p) => p.id),
    ["a"],
  );
});

test("containsId reports membership by id", () => {
  assert.equal(containsId([P("a"), P("b")], "b"), true);
  assert.equal(containsId([P("a")], "z"), false);
});

test("toggleFavorite adds when absent and removes when present", () => {
  const added = toggleFavorite([P("a")], P("b"));
  assert.deepEqual(
    added.map((p) => p.id),
    ["b", "a"],
    "prepended",
  );
  const removed = toggleFavorite(added, P("b"));
  assert.deepEqual(
    removed.map((p) => p.id),
    ["a"],
  );
});

test("toggleFavorite matches by id regardless of other fields", () => {
  const removed = toggleFavorite([P("a", { name: "Home" })], P("a", { name: "Work" }));
  assert.deepEqual(removed, []);
});

test("idleSections filters favorites out of the recents section", () => {
  const sections = idleSections([P("a")], [P("a"), P("b")]);
  assert.deepEqual(
    sections.favorites.map((p) => p.id),
    ["a"],
  );
  assert.deepEqual(
    sections.recents.map((p) => p.id),
    ["b"],
    "the pinned place isn't shown twice",
  );
});

test("idleSections preserves order and handles empty inputs", () => {
  assert.deepEqual(idleSections([], []), { favorites: [], recents: [] });
  const sections = idleSections([], [P("a"), P("b")]);
  assert.deepEqual(
    sections.recents.map((p) => p.id),
    ["a", "b"],
  );
});

/** ------------------------------------------------------------------
 * Distance helpers (pure)
 * ------------------------------------------------------------------ */

test("haversineKm is ~0 for identical points and is symmetric", () => {
  assert.ok(haversineKm(33.749, -84.388, 33.749, -84.388) < 1e-9);
  const a = haversineKm(33.749, -84.388, 40.7484, -73.9857);
  const b = haversineKm(40.7484, -73.9857, 33.749, -84.388);
  assert.ok(Math.abs(a - b) < 1e-9, "distance is symmetric");
});

test("haversineKm matches a known city-pair distance (Atlanta→NYC ≈ 1200 km)", () => {
  const km = haversineKm(33.749, -84.388, 40.7484, -73.9857);
  assert.ok(km > 1150 && km < 1250, `got ${km}`);
});

test("formatDistance switches to metres / feet under a threshold", () => {
  assert.equal(formatDistance(0.3, "km"), "300 m");
  assert.equal(formatDistance(1.2, "km"), "1.2 km");
  assert.equal(formatDistance(12.6, "km"), "13 km");
  assert.equal(formatDistance(1.2, "mi"), "0.7 mi");
  assert.equal(formatDistance(0.05, "mi"), `${Math.round(0.05 * 0.621371 * 5280)} ft`);
  assert.equal(formatDistance(5), "5.0 km", "defaults to km");
  assert.equal(formatDistance(NaN, "km"), "");
  assert.equal(formatDistance(-1, "km"), "");
});

test("distanceLabel is null without a bias and a unit-suffixed string with one", () => {
  assert.equal(distanceLabel(SWITCHYARDS, { provider: "apple" }), null);
  const km = distanceLabel(SWITCHYARDS, { provider: "apple", bias: "33.749,-84.388" });
  assert.ok(km !== null && km.endsWith("m"), km ?? "null");
  const mi = distanceLabel(SWITCHYARDS, { provider: "apple", bias: "40.7484,-73.9857", distanceUnit: "mi" });
  assert.ok(mi !== null && mi.endsWith("mi"), mi ?? "null");
});

/** ------------------------------------------------------------------
 * New output formats
 * ------------------------------------------------------------------ */

test("markdownLink wraps the name and link in Markdown syntax", () => {
  const md = buildPayload(SWITCHYARDS, { provider: "apple", outputFormat: "markdownLink" });
  assert.ok(md.startsWith("[Switchyards](https://maps.apple.com/"), md);
  assert.ok(md.endsWith(")"), md);
});

test("address format emits the plain address, falling back to the name", () => {
  assert.equal(buildPayload(SWITCHYARDS, { provider: "apple", outputFormat: "address" }), SWITCHYARDS.address);
  const bare: Place = { ...SWITCHYARDS, address: "" };
  assert.equal(buildPayload(bare, { provider: "apple", outputFormat: "address" }), bare.name, "never empty");
});

test("nameAddressInline stays on one line with a name, address, and link", () => {
  const inline = buildPayload(SWITCHYARDS, { provider: "apple", outputFormat: "nameAddressInline" });
  assert.ok(!inline.includes("\n"));
  assert.ok(inline.startsWith("Switchyards, 151 Ted Turner Drive Northwest"), inline);
  assert.ok(inline.includes(" — https://"), inline);
});

/** ------------------------------------------------------------------
 * Detail pane builders (pure)
 * ------------------------------------------------------------------ */

test("allProviderLinks returns every provider with a url matching mapsUrl", () => {
  const links = allProviderLinks(SWITCHYARDS);
  assert.deepEqual(
    links.map((l) => l.provider),
    ["apple", "google", "osm", "geo"],
  );
  for (const l of links) assert.equal(l.url, mapsUrl(SWITCHYARDS, l.provider));
});

test("detailMarkdown lists provider links and only shows distance with a bias", () => {
  const plain = detailMarkdown(SWITCHYARDS, { provider: "apple" });
  assert.ok(plain.includes("## Switchyards"), plain);
  assert.ok(plain.includes("[Apple Maps]("), plain);
  assert.ok(plain.includes("`geo:"), "geo shown as code, not a broken link");
  assert.ok(!plain.includes("from your search area"));

  const biased = detailMarkdown(SWITCHYARDS, { provider: "apple", bias: "40.7484,-73.9857" });
  assert.ok(biased.includes("from your search area"), biased);
});

/**
 * Live check against the real geocoder. Skipped by default so CI stays
 * hermetic and we stay polite to the public Photon instance.
 *
 *   DROPIN_LIVE=1 npm test
 */
test("live: the real geocoder still returns the shape we parse", { skip: !process.env.DROPIN_LIVE }, async () => {
  const url = buildSearchUrl("eiffel tower", APPLE, 3);
  const response = await fetch(url, { headers: { Accept: "application/json" } });
  assert.equal(response.status, 200);

  const places = parsePlaces((await response.json()) as PhotonResponse);
  assert.ok(places.length > 0, "expected at least one result");

  const tower = places[0];
  assert.ok(tower.name.length > 0);
  // Paris is ~48.86 N, ~2.29 E. Catches a silent lat/lon flip upstream.
  assert.ok(Math.abs(tower.lat - 48.858) < 0.5, `lat was ${tower.lat}`);
  assert.ok(Math.abs(tower.lon - 2.294) < 0.5, `lon was ${tower.lon}`);
});
