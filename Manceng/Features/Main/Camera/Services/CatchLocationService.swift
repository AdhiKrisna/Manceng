//
//  CatchLocationService.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 18/06/26.
//

import CoreLocation
import Foundation
import MapKit

@MainActor
final class CatchLocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CatchLocationMetadata?, Never>?

    var isAuthorizationDenied: Bool {
        manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func requestCurrentLocation() async -> CatchLocationMetadata? {
        guard continuation == nil else { return nil }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation

            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            case .denied, .restricted:
                finish(with: nil)
            @unknown default:
                finish(with: nil)
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            case .denied, .restricted:
                finish(with: nil)
            case .notDetermined:
                break
            @unknown default:
                finish(with: nil)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            Task { @MainActor in finish(with: nil) }
            return
        }

        Task { @MainActor in
            let displayName = await reverseGeocode(location) ?? coordinateText(for: location)
            finish(
                with: CatchLocationMetadata(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    displayName: displayName
                )
            )
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in finish(with: nil) }
    }

    private func reverseGeocode(_ location: CLLocation) async -> String? {
        let request = MKReverseGeocodingRequest(location: location)
        guard let mapItem = try? await request?.mapItems.first else {
            return nil
        }

        let address = mapItem.addressRepresentations
        let displayName = address?.cityWithContext(.automatic)
            ?? address?.fullAddress(includingRegion: false, singleLine: true)
            ?? mapItem.name

        guard let displayName, !displayName.isEmpty else {
            return nil
        }

        return displayName
    }

    private func coordinateText(for location: CLLocation) -> String {
        String(
            format: "%.5f, %.5f",
            location.coordinate.latitude,
            location.coordinate.longitude
        )
    }

    private func finish(with metadata: CatchLocationMetadata?) {
        continuation?.resume(returning: metadata)
        continuation = nil
    }
}
