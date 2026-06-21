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
    private var timeoutTask: Task<Void, Never>?
    private var cachedMetadata: CatchLocationMetadata?
    private var cachedMetadataDate: Date?
    private let cachedMetadataLifetime: TimeInterval = 300
    private let locationRequestTimeoutNanoseconds: UInt64 = 1_200_000_000

    var isAuthorizationDenied: Bool {
        manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func warmUpIfAuthorized() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
    }

    func requestCurrentLocation() async -> CatchLocationMetadata? {
        if let validCachedMetadata {
            return validCachedMetadata
        }

        guard continuation == nil else { return cachedMetadata }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            scheduleLocationTimeout()

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
                manager.startUpdatingLocation()
                manager.requestLocation()
            case .denied, .restricted:
                finish(with: validCachedMetadata)
            case .notDetermined:
                break
            @unknown default:
                finish(with: validCachedMetadata)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            Task { @MainActor in finish(with: validCachedMetadata) }
            return
        }

        Task { @MainActor in
            await handleLocationUpdate(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in finish(with: validCachedMetadata) }
    }

    private func handleLocationUpdate(_ location: CLLocation) async {
        guard continuation != nil || validCachedMetadata == nil else { return }

        let displayName = await reverseGeocode(location) ?? cachedMetadata?.displayName ?? "Unknown"
        let metadata = CatchLocationMetadata(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            displayName: displayName
        )
        cachedMetadata = metadata
        cachedMetadataDate = Date()

        guard continuation != nil else { return }
        finish(with: metadata)
    }

    private var validCachedMetadata: CatchLocationMetadata? {
        guard let cachedMetadata, let cachedMetadataDate else { return nil }
        guard Date().timeIntervalSince(cachedMetadataDate) <= cachedMetadataLifetime else {
            return nil
        }
        return cachedMetadata
    }

    private func scheduleLocationTimeout() {
        timeoutTask?.cancel()
        timeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: locationRequestTimeoutNanoseconds)
            guard !Task.isCancelled, continuation != nil else { return }
            finish(with: validCachedMetadata)
        }
    }

    private func finish(with metadata: CatchLocationMetadata?) {
        timeoutTask?.cancel()
        timeoutTask = nil
        continuation?.resume(returning: metadata)
        continuation = nil
    }

    private func reverseGeocode(_ location: CLLocation) async -> String? {
        if #unavailable(iOS 26.0) {
            return await reverseGeocodeWithCoreLocation(location)
        }

        return await reverseGeocodeWithMapKit(location)
    }

    @available(iOS 26.0, *)
    private func reverseGeocodeWithMapKit(_ location: CLLocation) async -> String? {
        let request = MKReverseGeocodingRequest(location: location)
        guard let mapItem = try? await request?.mapItems.first else {
            return nil
        }

        if let address = mapItem.addressRepresentations {
            let city = firstAddressComponent(address.cityWithContext(.automatic))
            let specificAddress = address.fullAddress(includingRegion: false, singleLine: true)
            if let specificAddress = cleanAddressComponent(specificAddress), !isCoordinateLikeAddress(specificAddress) {
                return condensedPlaceName(specificAddress, city: city)
            }

            if let city {
                return city
            }
        }

        return cleanAddressComponent(mapItem.name)
    }

    @available(iOS, deprecated: 26.0)
    private func reverseGeocodeWithCoreLocation(_ location: CLLocation) async -> String? {
        let geocoder = CLGeocoder()
        guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else {
            return nil
        }

        return displayName(for: placemark)
    }

    private func displayName(for placemark: CLPlacemark) -> String? {
        let primaryPlace = [
            placemark.areasOfInterest?.first,
            placemark.inlandWater,
            placemark.ocean,
            placemark.name,
            placemark.subLocality,
            placemark.thoroughfare
        ].compactMap { cleanAddressComponent($0) }
            .first { !isGenericAddressComponent($0, in: placemark) }

        let city = cleanAddressComponent(placemark.locality)
        if let primaryPlace {
            if let city, city != primaryPlace {
                return "\(primaryPlace), \(city)"
            }

            return primaryPlace
        }

        return city
    }

    private func cleanAddressComponent(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }

    private func isGenericAddressComponent(_ value: String, in placemark: CLPlacemark) -> Bool {
        let genericComponents = [
            placemark.locality,
            placemark.subAdministrativeArea,
            placemark.administrativeArea,
            placemark.country
        ].compactMap { cleanAddressComponent($0) }

        return genericComponents.contains(value)
    }

    private func isCoordinateLikeAddress(_ value: String) -> Bool {
        value.range(of: #"^-?\d+(\.\d+)?,\s*-?\d+(\.\d+)?$"#, options: .regularExpression) != nil
    }

    private func condensedPlaceName(_ value: String, city: String? = nil) -> String {
        let components = value
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let first = components.first, let city, first != city {
            return "\(first), \(city)"
        }

        guard components.count > 2 else {
            return value
        }

        return components.prefix(2).joined(separator: ", ")
    }

    private func firstAddressComponent(_ value: String?) -> String? {
        cleanAddressComponent(value)?
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}
