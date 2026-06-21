
import MapKit
import SwiftData
import SwiftUI

struct MapView: View {
    @Query(sort: \CatchModel.capturedAt, order: .reverse) private var catches: [CatchModel]
    @State private var cameraPosition: MapCameraPosition = .automatic
    let onSelectCatch: (CatchModel) -> Void
    
    init(onSelectCatch: @escaping (CatchModel) -> Void) {
        self.onSelectCatch = onSelectCatch
    }

    private var mappedCatches: [CatchModel] {
        catches.filter { item in
            item.latitude != nil && item.longitude != nil
        }
    }

    var body: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()

            ForEach(mappedCatches) { item in
                if let latitude = item.latitude,
                   let longitude = item.longitude {
                    Annotation(
                        item.species,
                        coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    ) {
                        PinMap(catchModel: item)
                            .onTapGesture {
                                onSelectCatch(item)
                            }
                    }
                }
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .onAppear {
            if let overviewRegion = catchOverviewRegion {
                cameraPosition = .region(overviewRegion)
            }
        }
    }

    private var catchOverviewRegion: MKCoordinateRegion? {
        let coordinates = mappedCatches.compactMap { item -> CLLocationCoordinate2D? in
            guard let latitude = item.latitude,
                  let longitude = item.longitude else {
                return nil
            }

            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }

        guard let firstCoordinate = coordinates.first else { return nil }

        let minLatitude = coordinates.map(\.latitude).min() ?? firstCoordinate.latitude
        let maxLatitude = coordinates.map(\.latitude).max() ?? firstCoordinate.latitude
        let minLongitude = coordinates.map(\.longitude).min() ?? firstCoordinate.longitude
        let maxLongitude = coordinates.map(\.longitude).max() ?? firstCoordinate.longitude

        let center = CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )

        let latitudeDelta = max((maxLatitude - minLatitude) * 1.4, 0.05)
        let longitudeDelta = max((maxLongitude - minLongitude) * 1.4, 0.05)

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }
}

#Preview {
    MapView { _ in }
        .modelContainer(for: CatchModel.self, inMemory: true)
}
