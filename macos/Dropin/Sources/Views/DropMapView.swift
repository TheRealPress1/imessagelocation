import SwiftUI
import MapKit
import CoreLocation

/// A pannable map. Clicking an empty spot drops a pin and reverse-geocodes it —
/// the whole point of v1: sharing a place that has no name.
struct DropMapView: View {
    let initialCenter: CLLocationCoordinate2D
    var onDrop: (Place) -> Void

    @State private var position: MapCameraPosition
    @State private var dropped: CLLocationCoordinate2D?
    @State private var droppedName: String = ""

    // An explicit named space, NOT .local, dodges the macOS vertical-offset bug
    // (FB13135770) that bites when the map sits below other UI (the search field).
    private let space = NamedCoordinateSpace.named("dropinMap")

    init(initialCenter: CLLocationCoordinate2D, onDrop: @escaping (Place) -> Void) {
        self.initialCenter = initialCenter
        self.onDrop = onDrop
        _position = State(initialValue: .region(MKCoordinateRegion(
            center: initialCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08))))
    }

    var body: some View {
        MapReader { proxy in
            Map(position: $position, interactionModes: .all) {
                if let dropped {
                    Marker(droppedName.isEmpty ? "Dropped pin" : droppedName, coordinate: dropped)
                }
            }
            .coordinateSpace(space)
            .onTapGesture(coordinateSpace: space) { point in
                guard let coordinate = proxy.convert(point, from: space) else { return }
                dropped = coordinate
                droppedName = ""
                Task { await reverseGeocode(coordinate) }
            }
        }
    }

    // macOS 26: CLGeocoder.reverseGeocodeLocation is deprecated → MKReverseGeocodingRequest.
    @MainActor
    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var name = String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
        var address = ""
        var placeID: String? = nil

        if let request = MKReverseGeocodingRequest(location: location),
           let items = try? await request.mapItems,
           let item = items.first {
            name = item.name ?? item.address?.fullAddress ?? name
            address = item.address?.fullAddress ?? ""
            placeID = item.identifier?.rawValue
        }

        droppedName = name
        onDrop(Place(
            id: "\(coordinate.latitude),\(coordinate.longitude)",
            name: name, address: address,
            lat: coordinate.latitude, lon: coordinate.longitude,
            placeID: placeID))
    }
}
