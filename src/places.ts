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
export type OutputFormat = "link" | "nameLink" | "nameInline" | "nameAddressLink";

export interface Preferences {
  provider: MapProvider;
  outputFormat?: OutputFormat;
  bias?: string;
  geocoder?: string;
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
    case "link":
    default:
      return url;
  }
}
