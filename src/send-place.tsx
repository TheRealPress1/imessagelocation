import { useState } from "react";
import { Action, ActionPanel, Icon, List, Toast, getPreferenceValues, showToast } from "@raycast/api";
import { useFetch } from "@raycast/utils";
import { iconFor } from "./icons";
import {
  buildPayload,
  buildSearchUrl,
  coordString,
  mapsUrl,
  parsePlaces,
  type PhotonResponse,
  type Place,
  type Preferences,
} from "./places";

const MIN_QUERY_LENGTH = 2;

export default function SendPlace() {
  const prefs = getPreferenceValues<Preferences>();
  const [searchText, setSearchText] = useState("");

  const query = searchText.trim();
  const shouldSearch = query.length >= MIN_QUERY_LENGTH;

  const { isLoading, data } = useFetch<PhotonResponse>(
    // useFetch needs a syntactically valid URL even when it isn't going to
    // run, so fall back to the un-executed query's own URL shape.
    buildSearchUrl(shouldSearch ? query : "_", prefs),
    {
      execute: shouldSearch,
      // Keeps the previous results on screen while the next keystroke's
      // request is in flight, so the list doesn't flicker empty.
      keepPreviousData: true,
      headers: {
        "User-Agent": "Dropin-Raycast (+https://github.com/gmoney/dropin)",
        Accept: "application/json",
      },
      onError: async (error) => {
        await showToast({
          style: Toast.Style.Failure,
          title: "Couldn't reach the geocoder",
          message: error.message,
        });
      },
    },
  );

  const places = shouldSearch ? parsePlaces(data) : [];

  return (
    <List
      isLoading={isLoading}
      onSearchTextChange={setSearchText}
      searchBarPlaceholder="Search for a place — a venue name works, no address needed"
      throttle
      filtering={false}
    >
      {places.length === 0 ? (
        <List.EmptyView
          icon={shouldSearch && !isLoading ? Icon.MagnifyingGlass : Icon.Geopin}
          title={!shouldSearch ? "Where to?" : isLoading ? "Searching…" : `Nothing found for "${query}"`}
          description={
            !shouldSearch
              ? "Type a venue, landmark, or address. Press ↵ to paste its map link straight back into whatever you were typing in."
              : isLoading
                ? undefined
                : "Try a broader search, or set “Search Near” in this extension's preferences to bias results toward your area."
          }
        />
      ) : (
        places.map((place) => <PlaceItem key={place.id} place={place} prefs={prefs} />)
      )}
    </List>
  );
}

function PlaceItem({ place, prefs }: { place: Place; prefs: Preferences }) {
  const payload = buildPayload(place, prefs);
  const url = mapsUrl(place, prefs.provider);
  // A geo: URI isn't something a browser can open.
  const canOpenInBrowser = prefs.provider !== "geo";

  return (
    <List.Item
      icon={iconFor(place)}
      title={place.name}
      subtitle={place.address}
      accessories={place.category ? [{ text: place.category }] : undefined}
      actions={
        <ActionPanel>
          <ActionPanel.Section>
            {/* The whole point of the extension: Raycast pastes into whatever
                app had focus before the launcher opened, so you land back in
                your conversation with the link already in the message box. */}
            <Action.Paste
              title="Paste Location"
              icon={Icon.Geopin}
              content={payload}
              onPaste={() => showToast({ style: Toast.Style.Success, title: "Pasted", message: place.name })}
            />
            <Action.CopyToClipboard
              title="Copy Location Link"
              icon={Icon.Link}
              content={payload}
              shortcut={{ modifiers: ["cmd"], key: "enter" }}
            />
          </ActionPanel.Section>

          <ActionPanel.Section>
            {place.address ? (
              <Action.CopyToClipboard
                title="Copy Address"
                icon={Icon.Text}
                content={place.address}
                shortcut={{ modifiers: ["cmd", "shift"], key: "a" }}
              />
            ) : null}
            <Action.CopyToClipboard
              title="Copy Coordinates"
              icon={Icon.Pin}
              content={coordString(place)}
              shortcut={{ modifiers: ["cmd", "shift"], key: "c" }}
            />
            {canOpenInBrowser ? (
              <Action.OpenInBrowser
                title="Open in Maps"
                icon={Icon.Map}
                url={url}
                shortcut={{ modifiers: ["cmd"], key: "o" }}
              />
            ) : null}
          </ActionPanel.Section>
        </ActionPanel>
      }
    />
  );
}
