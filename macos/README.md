# Dropin for macOS (v1)

The standalone menu-bar version of Dropin. Same idea as the [Raycast extension](../README.md),
but with no Raycast dependency and **a real map you can pan and click** — so you can share a spot
that has no name, not just a searchable venue.

Summon a Spotlight-style panel with a global hotkey, search a place (or click the map to drop a
pin), press `↵`, and the map link is pasted straight into whatever app you were typing in.

## Status

Scaffolded and **compiling against the macOS 26 SDK**; the pure link/payload core is unit-tested
(10/10, ported from v0's `places.test.ts`). The interactive behaviour — hotkey summon, panel focus,
map click-to-drop, and auto-paste — is wired per Apple's current docs but **needs on-device
verification** (a GUI + a real chat window; it can't be exercised headlessly). See _Verify_ below.

## Requirements

- macOS 26+, Xcode 26.5
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Build & run

```bash
cd macos
xcodegen generate        # regenerates Dropin.xcodeproj from project.yml
open Dropin.xcodeproj
```

In Xcode: pick the **Dropin** scheme and press ⌘R.

> **First run — sign in once.** Automatic signing needs your Apple ID in Xcode → Settings →
> Accounts so it can provision a macOS development profile for team `8HN6V7WUTB`. This matters:
> a proper Apple signature is what makes **MapKit tiles render** (ad-hoc/unsigned builds get blank
> tiles) and what makes the **Accessibility grant persist** across rebuilds.

Headless compile-check / tests (ad-hoc signing — tiles won't authenticate, fine for CI):

```bash
xcodebuild -scheme Dropin -configuration Debug build \
  CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=""
xcodebuild -scheme Dropin test \
  CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=""
```

## First-run setup

1. Launch → a **map-pin icon** appears in the menu bar (no Dock icon — it's an `LSUIElement` agent).
2. **Grant Accessibility.** The first paste opens System Settings → Privacy & Security →
   Accessibility; enable **Dropin**. This lets it synthesize ⌘V into the app you were typing in.
   (The link is always copied to the clipboard too, so you can paste manually if you skip this.)
3. **Set your hotkey:** menu-bar icon → _Preferences → Hotkey_ (default ⌘⇧Space). Include ⌘ or ⌃ —
   macOS blocks ⌥/⇧-only global hotkeys.
4. Pick your **map provider / output format / Search Near** in _Preferences → Maps / Search_.

## Use

Focus a chat → press the hotkey → search a place **or** click the map to drop a pin → `↵` (or
**Send**). The link lands in the chat.

## Architecture

| Area | Files | Notes |
| --- | --- | --- |
| **Pure core** (unit-tested) | `Dropin/Sources/Core/` | `LinkBuilder`, `Place`, `MapProvider`/`OutputFormat` — a Foundation-only port of v0's `places.ts`. Compiled into both the app and the test bundle. |
| App shell | `DropinApp`, `AppDelegate`, `PanelController` | `MenuBarExtra` + an AppKit-owned floating panel & prefs window. |
| Floating panel | `SpotlightPanel` | Non-activating `NSPanel`, `canBecomeKey = true` — becomes key without stealing focus, so the paste target stays frontmost. |
| Global hotkey | `HotkeyName` + [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) 3.0.1+ | Carbon under the hood; no Accessibility needed just to be summoned. |
| Search | `SearchModel` | `MKLocalSearchCompleter` (debounced) → `MKLocalSearch` → `Place`; Swift-6-safe delegate bridge. |
| Interactive map | `Views/DropMapView` | SwiftUI `Map` + `MapReader.convert`; a **named** coordinate space avoids the macOS tap-offset bug. Reverse geocode via `MKReverseGeocodingRequest` (macOS 26; `CLGeocoder` is deprecated). |
| Auto-paste | `AutoPaste` | Pasteboard → cooperative activation (`yieldActivation`/`activate`) → `CGEvent` ⌘V, gated on `CGPreflightPostEventAccess`. |
| Preferences | `Views/SettingsRootView` | `@AppStorage` (same `UserDefaults` keys the paste path reads). |

## Signing & distribution

- **Dev:** Automatic signing, _Apple Development_, team `8HN6V7WUTB`. App Sandbox **off** (CGEvent +
  Accessibility require it), Hardened Runtime **on**.
- **Release (later):** switch to a _Developer ID Application_ cert → notarize with `notarytool` →
  `create-dmg` → Homebrew cask. **No Maps entitlement** — it's for directions extensions only and
  would make Gatekeeper refuse to launch; tiles work purely from a valid Developer-ID signature.

## Verify (on device)

- The hotkey summons the panel **centered over your current app**, which keeps focus.
- You can **type** in the search field immediately (panel is key but the app didn't activate).
- **Clicking the map** drops a pin and names it (reverse geocode).
- Selecting a result / pressing **Send** pastes the link into the **previously-focused** app.
- **Esc** or clicking away dismisses the panel.
