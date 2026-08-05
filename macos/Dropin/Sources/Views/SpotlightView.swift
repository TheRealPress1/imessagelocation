import SwiftUI
import CoreLocation
import UniformTypeIdentifiers

extension UTType {
    /// Private drag type for intra-app favorite reordering.
    static let dropinPlace = UTType(exportedAs: "com.dropin.place")
}

/// A draggable favorite payload with two representations: the map link (plain text — what an external
/// text field / Messages receives) and the favorite id (a private type — used only for in-bar reorder).
/// The custom type is listed FIRST so our own drop target reads the id; external apps fall back to text.
struct DraggedFavorite: Codable, Transferable {
    let id: UUID
    let link: String
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .dropinPlace)
        ProxyRepresentation(exporting: \.link)
    }
}

/// The panel's content: a search field over the as-you-type results (when typing), or — when the
/// field is empty — the full click-to-drop map with your Favorites as a draggable bar along the bottom.
struct SpotlightView: View {
    let initialBias: (lat: Double, lon: Double)?
    var onCommit: (Place) -> Void
    var onCancel: () -> Void

    @StateObject private var model = SearchModel()
    private let store = FavoritesStore.shared
    @State private var mapSelection: Place?
    @State private var dropTargetID: Favorite.ID?
    @State private var savedCompletionIDs: Set<Completion.ID> = []
    @FocusState private var searchFocused: Bool

    private var center: CLLocationCoordinate2D {
        if let initialBias {
            return CLLocationCoordinate2D(latitude: initialBias.lat, longitude: initialBias.lon)
        }
        return CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194) // fallback: SF
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search a place — or click the map to drop a pin", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20))
                    .focused($searchFocused)
                    .onSubmit(submit)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()
            content
        }
        .frame(width: 720, height: 520)
        .background(.regularMaterial)
        .background(quickSendShortcuts)   // hidden ⌘1–9 speed-dial (fire even while typing)
        .onAppear {
            model.setBias(initialBias.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) })
            // One runloop turn after the panel is key, else focus no-ops.
            DispatchQueue.main.async { searchFocused = true }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !model.query.isEmpty && !model.completions.isEmpty {
            VStack(spacing: 0) {
                searchResults
                if !store.favorites.isEmpty {
                    Divider()
                    favoritesBar          // visible while searching, so a saved place drops into it
                }
            }
        } else {
            mapArea   // full map; favorites live in a bar along the bottom
        }
    }

    // MARK: - Search results (primary tap = send; ☆ = save)

    private var searchResults: some View {
        List {
            ForEach(model.completions) { completion in
                HStack {
                    Button { commit(completion) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(completion.title)
                            if !completion.subtitle.isEmpty {
                                Text(completion.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    saveStar(completion)
                }
            }
        }
        .listStyle(.plain)
    }

    /// The trailing ☆ on a search row: fills + bounces the instant it's tapped, then resolves & saves.
    private func saveStar(_ completion: Completion) -> some View {
        let isSaved = savedCompletionIDs.contains(completion.id)
        return Button {
            guard !savedCompletionIDs.contains(completion.id) else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                _ = savedCompletionIDs.insert(completion.id)   // instant feedback, before the async resolve
            }
            Task {
                if let place = await model.resolve(completion) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { store.add(place) }
                } else {
                    savedCompletionIDs.remove(completion.id)
                }
            }
        } label: {
            Image(systemName: isSaved ? "star.fill" : "star")
                .foregroundStyle(isSaved ? Color.yellow : Color.secondary)
                .contentTransition(.symbolEffect(.replace))   // morph star → star.fill
                .symbolEffect(.bounce, value: isSaved)        // one-shot pop when it fills
        }
        .buttonStyle(.plain)
        .help("Save to favorites")
    }

    // MARK: - Full map, with favorites / selection / hint pinned along the bottom

    private var mapArea: some View {
        ZStack(alignment: .bottom) {
            DropMapView(initialCenter: center) { mapSelection = $0 }
            if let selection = mapSelection {
                selectionBar(selection)          // dropped-pin Send/Save takes over the bottom
            } else if !store.favorites.isEmpty {
                favoritesBar
            } else {
                emptyHint
            }
        }
    }

    private var emptyHint: some View {
        Text("Search a place, click the map to drop a pin, or ☆ places to save them here.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.thinMaterial, in: Capsule())
            .padding(.bottom, 12)
    }

    // MARK: - Favorites bar (one-click send; drag to reorder)

    private var favoritesBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(store.favorites.enumerated()), id: \.element.id) { index, fav in
                    favoriteChip(fav, index: index)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.5).combined(with: .opacity),
                            removal: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.thinMaterial)
    }

    private func favoriteChip(_ fav: Favorite, index: Int) -> some View {
        Button { onCommit(fav.place) } label: {          // one-click send — ALWAYS fav.place
            HStack(spacing: 6) {
                Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption2)
                Text(fav.displayName).fontWeight(.medium).lineLimit(1)
                if index < 9 {
                    Text("⌘\(index + 1)").font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(.regularMaterial, in: Capsule())
            .overlay(
                Capsule().strokeBorder(dropTargetID == fav.id ? Color.accentColor : .clear, lineWidth: 2)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .draggable(DraggedFavorite(id: fav.id, link: LinkBuilder.payload(fav.place, SettingsStore.current))) {
            HStack(spacing: 6) {
                Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption2)
                Text(fav.displayName).fontWeight(.medium)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(.regularMaterial, in: Capsule())
        }
        .dropDestination(for: DraggedFavorite.self) { items, _ in
            reorder(draggedID: items.first?.id, before: fav.id)
        } isTargeted: { targeted in
            dropTargetID = targeted ? fav.id : (dropTargetID == fav.id ? nil : dropTargetID)
        }
    }

    // MARK: - Map drop selection

    private func selectionBar(_ selection: Place) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(selection.name).fontWeight(.medium)
                if !selection.address.isEmpty {
                    Text(selection.address).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { store.add(selection) }
            } label: {
                Image(systemName: store.isFavorite(selection) ? "star.fill" : "star")
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: store.isFavorite(selection))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("d", modifiers: .command)
            .help("Save to favorites (⌘D)")

            Button("Send") { onCommit(selection) }
                .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .background(.thinMaterial)
    }

    // Hidden buttons that give ⌘1…⌘9 to the first nine favorites.
    private var quickSendShortcuts: some View {
        ZStack {
            ForEach(Array(store.favorites.prefix(9).enumerated()), id: \.element.id) { index, fav in
                Button("") { onCommit(fav.place) }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                    .opacity(0)
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: - Actions

    /// Move the dragged favorite to the position of `targetID` (drop-before semantics),
    /// persisting via the shared store / pure `FavoritesLogic.moveFavorite`.
    private func reorder(draggedID: UUID?, before targetID: Favorite.ID) -> Bool {
        dropTargetID = nil
        guard let draggedID, draggedID != targetID,
              let from = store.favorites.firstIndex(where: { $0.id == draggedID }),
              let to = store.favorites.firstIndex(where: { $0.id == targetID })
        else { return false }
        store.move(from: IndexSet(integer: from), to: to)
        return true
    }

    private func submit() {
        if let first = model.completions.first {
            commit(first)
        } else if let selection = mapSelection {
            onCommit(selection)
        }
    }

    private func commit(_ completion: Completion) {
        Task {
            if let place = await model.resolve(completion) {
                onCommit(place)
            }
        }
    }
}
