import MapKit
import SwiftData
import SwiftUI

struct MapView: View {
    @Query(sort: \CatchModel.capturedAt, order: .reverse) private var catches: [CatchModel]
    @State private var cameraPosition: MapCameraPosition = .automatic

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
                        VStack(spacing: 4) {
                            Image(systemName: "fish.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.brandBlue, in: Circle())

                            Text(item.species)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.white.opacity(0.85), in: Capsule())
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
        .overlay {
            if mappedCatches.isEmpty {
                ContentUnavailableView(
                    "No catch locations yet",
                    systemImage: "map",
                    description: Text("Saved catches with location access will appear here.")
                )
            }
        }
    }
}

#Preview {
    MapView()
}
