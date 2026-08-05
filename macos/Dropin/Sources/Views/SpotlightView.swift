import SwiftUI
import CoreLocation

/// The panel's content: a search field over the as-you-type results (when typing), or — when the
/// field is empty — your saved Favorites (one-click / ⌘-number send) above the click-to-drop map.
struct SpotlightView: View {
    let initialBias: (lat: Double, lon: Double)?
    var onCommit: (Place) -> Void
    var onCancel: () -> Void

    @StateObject private var model = SearchModel()
    private let store = FavoritesStore.shared
    @State private var mapSelection: Place?
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
            searchResults
        } else {
            VStack(spacing: 0) {
                if !store.favorites.isEmpty {
                    favoritesList
                    Divider()
                }
                mapArea
            }
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

                    Button {
                        Task { if let place = await model.resolve(completion) { store.add(place) } }
                    } label: {
                        Image(systemName: "star")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Save to favorites")
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Favorites (one-click send; ⌘N hint)

    private var favoritesList: some View {
        List {
            ForEach(Array(store.favorites.enumerated()), id: \.element.id) { index, fav in
                Button { onCommit(fav.place) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fav.displayName).fontWeight(.medium)
                            if fav.displayName != fav.place.name {
                                Text(fav.place.name).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if index < 9 {
                            Text("⌘\(index + 1)").font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
        .frame(maxHeight: 240)
    }

    // MARK: - Map + drop selection

    private var mapArea: some View {
        ZStack(alignment: .bottom) {
            DropMapView(initialCenter: center) { mapSelection = $0 }
            if let selection = mapSelection {
                selectionBar(selection)
            } else if store.favorites.isEmpty {
                Text("Search a place, click the map to drop a pin, or ☆ places to save them here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 12)
            }
        }
    }

    private func selectionBar(_ selection: Place) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(selection.name).fontWeight(.medium)
                if !selection.address.isEmpty {
                    Text(selection.address).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button { store.add(selection) } label: {
                Image(systemName: store.isFavorite(selection) ? "star.fill" : "star")
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
