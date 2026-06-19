
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
            if let firstCatch = mappedCatches.first, let lat = firstCatch.latitude, let lon = firstCatch.longitude {
                cameraPosition = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
            }
        }
    }
}

#Preview {
    MapView { _ in }
        .modelContainer(for: CatchModel.self, inMemory: true)
}
