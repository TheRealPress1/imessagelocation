/**
 * Pure data layer: geocoding, parsing, and link construction.
 *
 * Deliberately imports nothing from @raycast/api so it can be exercised by
 * plain `node` in CI without the Raycast runtime present. Anything that needs
 * to become a UI concern (icons) is resolved in icons.ts instead.
 */

/** ------------------------------------------------------------------
 * Preferences, mirrored from the `preferences` block in package.json.
 * ------------------------------------------------------------------ */

export type MapProvider = "apple" | "google" | "osm" | "geo";
export type OutputFormat =
  "link" | "nameLink" | "nameInline" | "nameAddressLink" | "markdownLink" | "address" | "nameAddressInline";
export type DistanceUnit = "km" | "mi";

export interface Preferences {
  provider: MapProvider;
  outputFormat?: OutputFormat;
  bias?: string;
  geocoder?: string;
  /** Units for the distance-from-bias shown on results. Defaults to "km". */
  distanceUnit?: DistanceUnit;
  /** Whether the detail pane starts open. Also toggled at runtime with ⌘D. */
  showDetail?: boolean;
}

export const DEFAULT_GEOCODER = "https://photon.komoot.io/api";

/** ------------------------------------------------------------------
 * Photon GeoJSON response shape.
 * Photon returns a FeatureCollection; every field in `properties` is
 * optional, because what OSM knows about a pub differs from what it
 * knows about a country.
 * ------------------------------------------------------------------ */

export interface PhotonProperties {
  name?: string;
  housenumber?: string;
  street?: string;
  postcode?: string;
  city?: string;
  district?: string;
  locality?: string;
  county?: string;
  state?: string;
  country?: string;
  countrycode?: string;
  osm_key?: string;
  osm_value?: string;
  osm_id?: number;
  osm_type?: string;
  type?: string;
}

export interface PhotonFeature {
  type?: string;
  /** Photon always returns Point geometry as [longitude, latitude]. */
  geometry?: { type?: string; coordinates?: [number, number] };
  properties?: PhotonProperties;
}

export interface PhotonResponse {
  features?: PhotonFeature[];
}

/** A normalised place, independent of whichever geocoder produced it. */
export interface Place {
  id: string;
  name: string;
  /** Human-readable address line; may be empty for wide areas like countries. */
  address: string;
  lat: number;
  lon: number;
  /** Raw OSM taxonomy, kept so the UI layer can pick an icon. */
  osmKey?: string;
  osmValue?: string;
  /** e.g. "Cafe", "Restaurant" — shown as an accessory in the list. */
  category?: string;
}

/** ------------------------------------------------------------------
 * Search URL construction
 * ------------------------------------------------------------------ */

/** Parses a "lat,lon" preference string. Returns null if it isn't usable. */
export function parseBias(raw?: string): { lat: number; lon: number } | null {
  if (!raw) return null;
  const match = raw.trim().match(/^(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)$/);
  if (!match) return null;
  const lat = Number(match[1]);
  const lon = Number(match[2]);
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) return null;
  if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
  return { lat, lon };
}

export function buildSearchUrl(query: string, prefs: Preferences, limit = 12): string {
  const endpoint = (prefs.geocoder?.trim() || DEFAULT_GEOCODER).replace(/\/+$/, "");
  const params = new URLSearchParams({ q: query.trim(), limit: String(limit) });

  const bias = parseBias(prefs.bias);
  if (bias) {
    params.set("lat", String(bias.lat));
    params.set("lon", String(bias.lon));
    // Lean harder on proximity than Photon's default of 0.4. When someone
    // types a venue name into a chat, they almost always mean the nearby one.
    params.set("location_bias_scale", "0.6");
  }

  return `${endpoint}?${params.toString()}`;
}

/** ------------------------------------------------------------------
 * Parsing
 * ------------------------------------------------------------------ */

/** Builds "123 Main St, Atlanta, Georgia, United States" from OSM's scattered fields. */
export function formatAddress(p: PhotonProperties): string {
  const street = [p.housenumber, p.street].filter(Boolean).join(" ");
  const locality = p.city || p.locality || p.district || p.county;
  const parts = [street, locality, p.state, p.country].filter(
    (part): part is string => typeof part === "string" && part.length > 0,
  );
  // A city's own name is often duplicated across fields; don't say "Berlin, Berlin".
  return parts.filter((part, i) => parts.indexOf(part) === i).join(", ");
}

/** Turns OSM's key/value taxonomy into a readable category label. */
export function formatCategory(p: PhotonProperties): string | undefined {
  const value = p.osm_value;
  if (!value || value === "yes") return undefined;
  return value.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

/**
 * Normalises a Photon response into Places, dropping anything without
 * coordinates or a usable label.
 */
export function parsePlaces(response: PhotonResponse | undefined): Place[] {
  const features = response?.features ?? [];
  const seen = new Set<string>();
  const places: Place[] = [];

  for (const feature of features) {
    const coords = feature.geometry?.coordinates;
    if (!coords || coords.length < 2) continue;

    const [lon, lat] = coords;
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) continue;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) continue;

    const p = feature.properties ?? {};
    const address = formatAddress(p);
    // Unnamed results (a bare address, a road segment) still deserve a label.
    const name = p.name || [p.housenumber, p.street].filter(Boolean).join(" ") || address;
    if (!name) continue;

    // Photon can return the same venue as both a node and a way.
    const key = `${name}|${lat.toFixed(4)}|${lon.toFixed(4)}`;
    if (seen.has(key)) continue;
    seen.add(key);

    places.push({
      id: `${p.osm_type ?? "x"}${p.osm_id ?? key}`,
      name,
      address,
      lat,
      lon,
      osmKey: p.osm_key,
      osmValue: p.osm_value,
      category: formatCategory(p),
    });
  }

  return places;
}

/** ------------------------------------------------------------------
 * Output construction
 * ------------------------------------------------------------------ */

export function coordString(place: Place): string {
  return `${place.lat.toFixed(6)},${place.lon.toFixed(6)}`;
}

export function mapsUrl(place: Place, provider: MapProvider): string {
  const ll = coordString(place);

  switch (provider) {
    case "google":
      // `query` as coordinates pins the exact spot rather than re-searching
      // the name, which can drift to a different branch of the same chain.
      return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(ll)}`;
    case "osm":
      return `https://www.openstreetmap.org/?mlat=${place.lat}&mlon=${place.lon}#map=17/${place.lat}/${place.lon}`;
    case "geo":
      return `geo:${ll}?q=${encodeURIComponent(`${ll}(${place.name})`)}`;
    case "apple":
    default:
      // When `ll` is present Apple treats `q` as the pin's label, so the
      // recipient sees the venue name rather than raw coordinates.
      return `https://maps.apple.com/?ll=${ll}&q=${encodeURIComponent(place.name)}`;
  }
}

/** The exact text that gets pasted or copied. */
export function buildPayload(place: Place, prefs: Preferences): string {
  const url = mapsUrl(place, prefs.provider);

  switch (prefs.outputFormat) {
    case "nameLink":
      return `${place.name}\n${url}`;
    case "nameInline":
      return `${place.name} — ${url}`;
    case "nameAddressLink":
      return [place.name, place.address, url].filter(Boolean).join("\n");
    case "markdownLink":
      // Markdown link text is literal; the URL is already query-encoded by mapsUrl.
      return `[${place.name}](${url})`;
    case "address":
      // A bare address, with a fall back to the name so we never emit nothing.
      return place.address || place.name;
    case "nameAddressInline":
      return `${[place.name, place.address].filter(Boolean).join(", ")} — ${url}`;
    case "link":
    default:
      return url;
  }
}

/** ------------------------------------------------------------------
 * Recents & favorites — pure list reducers.
 *
 * Kept here rather than in the UI layer so their dedup/cap/ordering
 * semantics are exercised by the Node test suite. The UI only persists the
 * arrays these return (via LocalStorage) and re-renders off the new reference.
 * ------------------------------------------------------------------ */

/** How many recently sent places to remember. Favorites are uncapped. */
export const RECENTS_CAP = 12;

/** True if any entry in `list` shares this id. */
export function containsId(list: Place[], id: string): boolean {
  return list.some((p) => p.id === id);
}

/**
 * Prepend `place`, drop any prior entry with the same id, then cap the length.
 * Re-sending a place moves it to the front instead of duplicating it.
 * Returns a new array; never mutates `list`.
 */
export function addToRecents(list: Place[], place: Place, cap: number = RECENTS_CAP): Place[] {
  return [place, ...list.filter((p) => p.id !== place.id)].slice(0, Math.max(0, cap));
}

/** Return a new array with the entry whose id === `id` removed. */
export function removeById(list: Place[], id: string): Place[] {
  return list.filter((p) => p.id !== id);
}

/** Toggle `place` in a favorites list: remove if already present, else prepend. New array. */
export function toggleFavorite(list: Place[], place: Place): Place[] {
  return containsId(list, place.id) ? removeById(list, place.id) : [place, ...list];
}

/**
 * The two sections shown when the search bar is idle. A place that is both
 * pinned and recent appears only under Favorites, never twice.
 */
export function idleSections(favorites: Place[], recents: Place[]): { favorites: Place[]; recents: Place[] } {
  return { favorites, recents: recents.filter((r) => !containsId(favorites, r.id)) };
}

/** ------------------------------------------------------------------
 * Distance — pure geo helpers for the "Search Near" bias.
 * ------------------------------------------------------------------ */

/** Great-circle distance in kilometres between two lat/lon points. */
export function haversineKm(aLat: number, aLon: number, bLat: number, bLon: number): number {
  const R = 6371; // mean Earth radius, km
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(bLat - aLat);
  const dLon = toRad(bLon - aLon);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(aLat)) * Math.cos(toRad(bLat)) * Math.sin(dLon / 2) ** 2;
  // Math.min guards floating-point overshoot at antipodal points.
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(h)));
}

/**
 * Human-friendly distance. Sub-kilometre distances read as metres (km) or
 * feet (mi) so a venue down the street shows "300 m", not "0.3 km".
 * Returns "" for a nonsensical input so callers can skip rendering it.
 */
export function formatDistance(km: number, unit: DistanceUnit = "km"): string {
  if (!Number.isFinite(km) || km < 0) return "";
  if (unit === "mi") {
    const miles = km * 0.621371;
    if (miles < 0.1) return `${Math.round(miles * 5280)} ft`;
    return `${miles < 10 ? miles.toFixed(1) : Math.round(miles)} mi`;
  }
  if (km < 1) return `${Math.round(km * 1000)} m`;
  return `${km < 10 ? km.toFixed(1) : Math.round(km)} km`;
}

/**
 * Distance from the user's "Search Near" bias to a place, formatted.
 * Returns null when no usable bias is set, so the UI can omit the accessory.
 */
export function distanceLabel(place: Place, prefs: Preferences): string | null {
  const bias = parseBias(prefs.bias);
  if (!bias) return null;
  return formatDistance(haversineKm(bias.lat, bias.lon, place.lat, place.lon), prefs.distanceUnit ?? "km");
}

/** ------------------------------------------------------------------
 * Detail pane — pure builders for List.Item.Detail content.
 * ------------------------------------------------------------------ */

/** Every provider's link for a place, in a stable order. */
export function allProviderLinks(place: Place): { provider: MapProvider; label: string; url: string }[] {
  const labels: Record<MapProvider, string> = {
    apple: "Apple Maps",
    google: "Google Maps",
    osm: "OpenStreetMap",
    geo: "geo: URI",
  };
  const order: MapProvider[] = ["apple", "google", "osm", "geo"];
  return order.map((provider) => ({ provider, label: labels[provider], url: mapsUrl(place, provider) }));
}

/** CommonMark body for the detail pane: heading, address, distance, and every provider link. */
export function detailMarkdown(place: Place, prefs: Preferences): string {
  const lines = [`## ${place.name}`];
  if (place.address) lines.push(place.address);
  const distance = distanceLabel(place, prefs);
  if (distance) lines.push(`_${distance} from your search area_`);
  lines.push("", "**Open in:**");
  for (const { label, url } of allProviderLinks(place)) {
    // geo: URIs aren't clickable in a Markdown renderer; render them as code.
    lines.push(url.startsWith("geo:") ? `- ${label}: \`${url}\`` : `- [${label}](${url})`);
  }
  return lines.join("\n");
}
