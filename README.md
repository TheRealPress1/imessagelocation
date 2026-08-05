<div align="center">

<img src="assets/extension-icon.png" width="104" alt="Dropin">

# Dropin

**Search for any place. Drop its map link straight into whatever you're typing in.**

No tab-switching to Maps, no copy-pasting an address you had to go find first.

</div>

<!--
  TODO: record the demo GIF and drop it here. This is the single highest-leverage
  thing in the whole repo — for a tool like this the GIF *is* the pitch.

  Six seconds, no cursor jitter, no wasted frames:
    1. A real iMessage conversation, cursor blinking in the message box
    2. ⌥Space → "switchyards"
    3. ↵
    4. The link lands in the message box
    5. ↵ — sent, map bubble renders

  Record with `⌘⇧5` at 1280x800, convert with:
    ffmpeg -i demo.mov -vf "fps=20,scale=760:-1:flags=lanczos" -loop 0 assets/demo.gif
-->

<div align="center">
  <img src="assets/demo.gif" width="760" alt="Dropin demo">
</div>

---

## The problem

You're mid-conversation. "Want to meet at Switchyards Monday?" You know the venue.
You don't know the address, and you're not going to memorise it.

So you leave the conversation, open Maps, search, hit share, pick the app, pick the
thread — and by the time you're back you've forgotten what else you were going to say.

Messages can share _your_ location. It cannot share _a_ location. Dropin fills that gap
without ever taking focus away from the thing you were typing in.

## How it works

Hit your Raycast hotkey, type a venue name, press `↵`. Raycast pastes the map link
back into whatever app had focus — Messages, Slack, WhatsApp Web, Discord, Notes, an
email draft. Dropin doesn't know or care which; that's the point.

```
⌥Space → "switchyards" → ↵
```

```
https://maps.apple.com/?ll=33.748995,-84.387982&q=Switchyards
```

In iMessage that renders as a tappable map bubble. Everywhere else it's a link that
opens the right pin.

## Install

Not on the Raycast store yet. To run it locally:

```bash
git clone https://github.com/TheRealPress1/imessagelocation.git
cd imessagelocation
npm install
npm run dev
```

`npm run dev` registers the command with your local Raycast and hot-reloads on save.
It stays installed as long as the dev process runs; `npm run build` makes it permanent.

Then bind it to something you can hit without thinking. `⌥Space` then a few letters is
fine, but a dedicated hotkey (Raycast → Extensions → Dropin → Record Hotkey) is the
difference between using this and forgetting it exists.

## Settings

On first run Dropin asks which map service your links should point to. There is no
right answer, so it doesn't pick one for you:

| Setting               | What it does                                                 |
| --------------------- | ------------------------------------------------------------ |
| **Map Links**         | Apple Maps, Google Maps, OpenStreetMap, or a raw `geo:` URI. |
| **What to Send**      | Just the link, or the place name alongside it.               |
| **Search Near**       | Optional `lat,lon` to bias results toward your area.         |
| **Geocoder Endpoint** | Optional. Point at your own Photon server.                   |

Two things worth knowing:

**Apple Maps links render a map preview in iMessage. Google Maps links are more
portable.** Apple Maps links open natively on any Apple device and produce the big
tappable bubble; on Android they fall back to a web page, which works but looks
ordinary. Pick based on who you actually text.

**iMessage only draws the map preview when the message contains nothing but the
link.** Add the place name and it collapses to a plain blue link. That's why
_Just the link_ is the default — if you want to say something about the place, send it
as a second message.

**Set "Search Near" if you search venue names.** Without it, `switchyards` ranks
globally and the one down the street may not be first. Grab a `lat,lon` pair from any
map URL and paste it in once.

## Actions

| Shortcut | Action                                                  |
| -------- | ------------------------------------------------------- |
| `↵`      | Paste the location into the app you were just typing in |
| `⌘↵`     | Copy the location link                                  |
| `⌘⇧A`    | Copy the street address as plain text                   |
| `⌘⇧C`    | Copy raw coordinates                                    |
| `⌘O`     | Open the place in your browser                          |

## Privacy

Dropin never phones home. There is no account, no analytics, no telemetry, no server
of ours anywhere in the path.

The one network call it makes is your search text going to the geocoder — by default
the public [Photon](https://github.com/komoot/photon) instance, which is
OpenStreetMap-backed and needs no API key. If you'd rather not send search terms to a
third party, run your own Photon instance and point **Geocoder Endpoint** at it.

Dropin never reads your location. "Search Near" is a coordinate you type in yourself.

> If you're going to search heavily, please self-host. The public Photon instance is a
> volunteer-run courtesy, not an entitlement.

## Development

```bash
npm run dev        # hot-reloading dev build in Raycast
npm test           # unit tests (hermetic, no network)
npm run typecheck  # tsc --noEmit
npm run lint       # ray lint
```

The code splits so the interesting parts are testable without a Raycast runtime:

- **`src/places.ts`** — geocoding, parsing, and link construction. Imports nothing from
  `@raycast/api`, so plain `node` can exercise it. All the logic worth testing is here.
- **`src/icons.ts`** — maps OpenStreetMap's `key`/`value` taxonomy onto Raycast icons.
- **`src/send-place.tsx`** — the list UI and actions. Thin on purpose.

To verify the live geocoder still returns the shape we parse:

```bash
DROPIN_LIVE=1 npm test
```

That test is skipped by default so CI stays hermetic and we stay polite to Photon.

## Roadmap

**v0 — Raycast extension.** ← you are here. Ships the core idea to Mac power users
without any of the signing, notarisation, or App Store friction.

**v1 — standalone menu-bar app.** A real map you can pan and click, for picking a spot
that has no name. `LSUIElement` app, global hotkey via
[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts), Spotlight-style
floating panel, `MKLocalSearchCompleter` for search, `CLGeocoder` for reverse-geocoding
arbitrary clicks. Distributed as a notarised DMG plus a Homebrew cask.

> Spike this first: `MKMapView` and `MKLocalSearch` outside the App Store can need the
> Maps entitlement and a real signing identity. If contributors cloning the repo get
> blank tiles, the fallback is MapLibre GL + OSM tiles in a `WKWebView` — no Apple
> entitlement, fully open.

**v2 — iOS iMessage extension.** The literal in-Messages version:
`MSMessagesAppViewController`, MapKit inside, an `MSMessageTemplateLayout` whose image
is an `MKMapSnapshotter` render. Deliberately last — it needs a paid developer account
and App Store review, and it won't run on a Mac.

Non-goals: accounts, sync, a backend, a subscription, "AI".

## Contributing

Issues and PRs welcome. Two asks: keep `src/places.ts` free of `@raycast/api` imports
so it stays testable, and add a test for any parsing change — OSM data is messy enough
that regressions are easy and silent.

## Credits

Geocoding by [Photon](https://github.com/komoot/photon), data by
[OpenStreetMap](https://www.openstreetmap.org/copyright) contributors (ODbL).

## License

MIT — see [LICENSE](LICENSE).
