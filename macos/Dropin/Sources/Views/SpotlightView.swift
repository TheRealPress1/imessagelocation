import SwiftUI
import CoreLocation

/// The panel's content: a search field over either the as-you-type results list
/// (when typing) or the click-to-drop map (when the field is empty).
struct SpotlightView: View {
    let initialBias: (lat: Double, lon: Double)?
    var onCommit: (Place) -> Void
    var onCancel: () -> Void

    @StateObject private var model = SearchModel()
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
        .onAppear {
            model.setBias(initialBias.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) })
            // One runloop turn after the panel is key, else focus no-ops.
            DispatchQueue.main.async { searchFocused = true }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !model.query.isEmpty && !model.completions.isEmpty {
            List {
                ForEach(model.completions) { completion in
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
                }
            }
            .listStyle(.plain)
        } else {
            ZStack(alignment: .bottom) {
                DropMapView(initialCenter: center) { mapSelection = $0 }
                if let selection = mapSelection {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selection.name).fontWeight(.medium)
                            if !selection.address.isEmpty {
                                Text(selection.address).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button("Send") { onCommit(selection) }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(12)
                    .background(.thinMaterial)
                }
            }
        }
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
