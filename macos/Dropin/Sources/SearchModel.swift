import MapKit
import CoreLocation

/// A Sendable-safe snapshot of one completion. Keeps the non-Sendable
/// MKLocalSearchCompletion main-actor-only (the model is @MainActor).
struct Completion: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let raw: MKLocalSearchCompletion
}

/// Two-stage MapKit pipeline: MKLocalSearchCompleter for as-you-type completions,
/// MKLocalSearch to resolve a chosen completion into a full Place.
@MainActor
final class SearchModel: NSObject, ObservableObject {
    @Published var query: String = "" { didSet { scheduleSearch() } }
    @Published private(set) var completions: [Completion] = []

    private let completer = MKLocalSearchCompleter()
    private var debounceTask: Task<Void, Never>?

    override init() {
        super.init()
        completer.resultTypes = [.address, .pointOfInterest, .query]
        completer.delegate = self
    }

    /// Bias completions toward the user's "Search Near" area (a bias, not a hard filter).
    func setBias(_ coordinate: CLLocationCoordinate2D?) {
        guard let coordinate else { return }
        completer.region = MKCoordinateRegion(
            center: coordinate, latitudinalMeters: 50_000, longitudinalMeters: 50_000)
    }

    private func scheduleSearch() {
        debounceTask?.cancel()
        let text = query
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)   // ~200ms debounce
            guard !Task.isCancelled, let self else { return }
            if text.isEmpty {
                self.completer.cancel()
                self.completions = []
            } else {
                self.completer.queryFragment = text
            }
        }
    }

    /// Resolve a completion into a Place using the macOS 26 API (no deprecated .placemark).
    func resolve(_ completion: Completion) async -> Place? {
        let request = MKLocalSearch.Request(completion: completion.raw)
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first else { return nil }
            let coordinate = item.location.coordinate
            guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
            return Place(
                id: "\(coordinate.latitude),\(coordinate.longitude)",
                name: item.name ?? completion.title,
                address: item.address?.fullAddress ?? "",
                lat: coordinate.latitude,
                lon: coordinate.longitude
            )
        } catch {
            return nil
        }
    }
}

extension SearchModel: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // Delivered on the main thread; snapshot to value types, then hop onto the actor.
        let mapped = completer.results.map {
            Completion(title: $0.title, subtitle: $0.subtitle, raw: $0)
        }
        MainActor.assumeIsolated { self.completions = mapped }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        MainActor.assumeIsolated { self.completions = [] }
    }
}
