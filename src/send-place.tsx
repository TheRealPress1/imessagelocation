import { useState } from "react";
import { Action, ActionPanel, Icon, List, Toast, getPreferenceValues, showToast, Keyboard } from "@raycast/api";
import { useFetch, useLocalStorage } from "@raycast/utils";
import { iconFor } from "./icons";
import {
  addToRecents,
  buildPayload,
  buildSearchUrl,
  containsId,
  coordString,
  detailMarkdown,
  distanceLabel,
  idleSections,
  mapsUrl,
  parsePlaces,
  removeById,
  toggleFavorite,
  type PhotonResponse,
  type Place,
  type Preferences,
} from "./places";

const MIN_QUERY_LENGTH = 2;

type ItemContext = "search" | "recent" | "favorite";

/** The persisted recents/favorites lists plus the mutators the UI needs. */
interface PlaceLists {
  recents: Place[];
  favorites: Place[];
  isLoading: boolean;
  /** Record a place as just-sent (paste or copy). */
  commit: (place: Place) => void;
  removeRecent: (id: string) => void;
  clearRecents: () => void;
  toggleFav: (place: Place) => void;
}

/**
 * Marshals two LocalStorage-backed arrays through the pure reducers in
 * places.ts. All list logic lives there; this hook only persists the result.
 */
function usePlaceLists(): PlaceLists {
  const recents = useLocalStorage<Place[]>("dropin.recents", []);
  const favorites = useLocalStorage<Place[]>("dropin.favorites", []);
  const recentList = recents.value ?? [];
  const favoriteList = favorites.value ?? [];

  return {
    recents: recentList,
    favorites: favoriteList,
    isLoading: recents.isLoading || favorites.isLoading,
    commit: (place) => void recents.setValue(addToRecents(recentList, place)),
    removeRecent: (id) => void recents.setValue(removeById(recentList, id)),
    clearRecents: () => void recents.removeValue(),
    toggleFav: (place) => void favorites.setValue(toggleFavorite(favoriteList, place)),
  };
}

export default function SendPlace() {
  const prefs = getPreferenceValues<Preferences>();
  const [searchText, setSearchText] = useState("");
  const [showDetail, setShowDetail] = useState<boolean>(prefs.showDetail ?? false);
  const toggleDetail = () => setShowDetail((v) => !v);

  const query = searchText.trim();
  const shouldSearch = query.length >= MIN_QUERY_LENGTH;

  const lists = usePlaceLists();

  const { isLoading: isFetching, data } = useFetch<PhotonResponse>(
    // useFetch needs a syntactically valid URL even when it isn't going to
    // run, so fall back to the un-executed query's own URL shape.
    buildSearchUrl(shouldSearch ? query : "_", prefs),
    {
      execute: shouldSearch,
      // Keeps the previous results on screen while the next keystroke's
      // request is in flight, so the list doesn't flicker empty.
      keepPreviousData: true,
      headers: {
        "User-Agent": "Dropin-Raycast (+https://github.com/TheRealPress1/imessagelocation)",
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

  const results = shouldSearch ? parsePlaces(data) : [];
  const idle = idleSections(lists.favorites, lists.recents);
  const hasIdleContent = idle.favorites.length > 0 || idle.recents.length > 0;

  const itemProps = { prefs, lists, showDetail, onToggleDetail: toggleDetail };

  return (
    <List
      isLoading={isFetching || lists.isLoading}
      isShowingDetail={showDetail}
      onSearchTextChange={setSearchText}
      searchBarPlaceholder="Search for a place — a venue name works, no address needed"
      throttle
      filtering={false}
    >
      {shouldSearch ? (
        results.length === 0 ? (
          <List.EmptyView
            icon={!isFetching ? Icon.MagnifyingGlass : Icon.Geopin}
            title={isFetching ? "Searching…" : `Nothing found for "${query}"`}
            description={
              isFetching
                ? undefined
                : "Try a broader search, or set “Search Near” in this extension's preferences to bias results toward your area."
            }
          />
        ) : (
          results.map((place) => <PlaceItem key={place.id} place={place} context="search" {...itemProps} />)
        )
      ) : hasIdleContent ? (
        <>
          {idle.favorites.length > 0 ? (
            <List.Section title="Favorites">
              {idle.favorites.map((place) => (
                <PlaceItem key={place.id} place={place} context="favorite" {...itemProps} />
              ))}
            </List.Section>
          ) : null}
          {idle.recents.length > 0 ? (
            <List.Section title="Recent">
              {idle.recents.map((place) => (
                <PlaceItem key={place.id} place={place} context="recent" {...itemProps} />
              ))}
            </List.Section>
          ) : null}
        </>
      ) : lists.isLoading ? null : (
        // Only shown once storage has hydrated, so it never flashes before
        // saved favorites/recents appear.
        <List.EmptyView
          icon={Icon.Geopin}
          title="Where to?"
          description="Type a venue, landmark, or address. Press ↵ to paste its map link straight back into whatever you were typing in."
        />
      )}
    </List>
  );
}

function PlaceItem({
  place,
  prefs,
  lists,
  showDetail,
  onToggleDetail,
  context,
}: {
  place: Place;
  prefs: Preferences;
  lists: PlaceLists;
  showDetail: boolean;
  onToggleDetail: () => void;
  context: ItemContext;
}) {
  const payload = buildPayload(place, prefs);
  const url = mapsUrl(place, prefs.provider);
  // A geo: URI isn't something a browser can open.
  const canOpenInBrowser = prefs.provider !== "geo";
  const isFavorite = containsId(lists.favorites, place.id);
  const distance = distanceLabel(place, prefs);

  // Raycast recommends dropping accessories while the detail pane is open,
  // since the same information lives in the detail metadata.
  const accessories: List.Item.Accessory[] | undefined = showDetail
    ? undefined
    : [
        ...(distance ? [{ text: distance, icon: Icon.Ruler, tooltip: "Distance from your search area" }] : []),
        ...(place.category ? [{ tag: place.category }] : []),
      ];

  return (
    <List.Item
      icon={iconFor(place)}
      title={place.name}
      subtitle={showDetail ? undefined : place.address}
      accessories={accessories && accessories.length > 0 ? accessories : undefined}
      detail={
        <List.Item.Detail
          markdown={detailMarkdown(place, prefs)}
          metadata={
            <List.Item.Detail.Metadata>
              {place.address ? (
                <List.Item.Detail.Metadata.Label title="Address" text={place.address} icon={Icon.House} />
              ) : null}
              {place.category ? <List.Item.Detail.Metadata.Label title="Category" text={place.category} /> : null}
              <List.Item.Detail.Metadata.Label title="Coordinates" text={coordString(place)} icon={Icon.Pin} />
              {distance ? <List.Item.Detail.Metadata.Label title="Distance" text={distance} icon={Icon.Ruler} /> : null}
            </List.Item.Detail.Metadata>
          }
        />
      }
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
              onPaste={() => {
                lists.commit(place);
                void showToast({ style: Toast.Style.Success, title: "Pasted", message: place.name });
              }}
            />
            {/* As the second action, Raycast auto-binds this to ⌘↵ — no explicit shortcut needed. */}
            <Action.CopyToClipboard
              title="Copy Location Link"
              icon={Icon.Link}
              content={payload}
              onCopy={() => lists.commit(place)}
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
              shortcut={Keyboard.Shortcut.Common.Copy}
            />
            <Action.CopyToClipboard
              title="Copy as Markdown Link"
              icon={Icon.Link}
              content={buildPayload(place, { ...prefs, outputFormat: "markdownLink" })}
              shortcut={{ modifiers: ["cmd", "shift"], key: "m" }}
            />
            {canOpenInBrowser ? (
              <Action.OpenInBrowser
                title="Open in Maps"
                icon={Icon.Map}
                url={url}
                shortcut={Keyboard.Shortcut.Common.Open}
              />
            ) : null}
          </ActionPanel.Section>

          <ActionPanel.Section>
            <Action
              title={showDetail ? "Hide Details" : "Show Details"}
              icon={showDetail ? Icon.EyeDisabled : Icon.Eye}
              onAction={onToggleDetail}
              shortcut={{ modifiers: ["cmd"], key: "d" }}
            />
            <Action
              title={isFavorite ? "Remove Favorite" : "Pin to Favorites"}
              icon={isFavorite ? Icon.StarDisabled : Icon.Star}
              onAction={() => lists.toggleFav(place)}
              shortcut={{ modifiers: ["cmd", "shift"], key: "f" }}
            />
            {context === "recent" ? (
              <Action
                title="Remove from Recent"
                icon={Icon.XMarkCircle}
                onAction={() => lists.removeRecent(place.id)}
                shortcut={{ modifiers: ["ctrl"], key: "x" }}
              />
            ) : null}
            {lists.recents.length > 0 ? (
              <Action
                title="Clear Recents"
                icon={Icon.Trash}
                style={Action.Style.Destructive}
                onAction={() => lists.clearRecents()}
                shortcut={{ modifiers: ["cmd", "shift"], key: "backspace" }}
              />
            ) : null}
          </ActionPanel.Section>
        </ActionPanel>
      }
    />
  );
}
