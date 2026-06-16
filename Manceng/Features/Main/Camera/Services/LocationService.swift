
//
//  LocationService.swift
//  Manceng
//
//  Created by Trae on 16/06/26.
//

import CoreLocation
import Foundation
import MapKit
import Combine

@MainActor
class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var locationString: String?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation() {
        manager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location.coordinate

        Task { @MainActor in
            do {
                let request = MKLocalSearch.Request()
                request.region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
                let result = try await MKLocalSearch(request: request).start()
                if let mapItem = result.mapItems.first {
                    let address = [
                        mapItem.placemark.locality,
                        mapItem.placemark.administrativeArea,
                        mapItem.placemark.country
                    ].compactMap { $0 }.joined(separator: ", ")
                    self.locationString = address
                }
            } catch {
                print("Failed to reverse geocode: \(error)")
            }
        }
    }
}
