
//
//  MainView.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 10/06/26.
//

import Foundation
import SwiftUI
import SwiftData
import MapKit

struct MapView: View {
    @Query(sort: \CatchModel.capturedAt, order: .reverse) private var catches: [CatchModel]

    var body: some View {
        ZStack {
            if let firstCatch = catches.first, let lat = firstCatch.latitude, let lon = firstCatch.longitude {
                Map(position: .constant(.region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )))) {
                    ForEach(catches.filter { $0.latitude != nil && $0.longitude != nil }) { catchItem in
                        Marker(
                            catchItem.species,
                            coordinate: CLLocationCoordinate2D(
                                latitude: catchItem.latitude!,
                                longitude: catchItem.longitude!
                            )
                        )
                    }
                }
            } else {
                Map(position: .constant(.region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456),
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                ))))
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    MapView()
        .modelContainer(for: CatchModel.self, inMemory: true)
}
