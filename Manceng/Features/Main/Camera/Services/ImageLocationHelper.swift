
//
//  ImageLocationHelper.swift
//  Manceng
//
//  Created by Trae on 16/06/26.
//

import Foundation
import ImageIO
import CoreLocation

struct ImageLocationHelper {
    static func extractLocation(from imageData: Data) -> CLLocationCoordinate2D? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return nil
        }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return nil
        }
        guard let gpsDictionary = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] else {
            return nil
        }
        guard let latitude = gpsDictionary[kCGImagePropertyGPSLatitude as String] as? Double,
              let longitude = gpsDictionary[kCGImagePropertyGPSLongitude as String] as? Double else {
            return nil
        }
        var coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        if let latitudeRef = gpsDictionary[kCGImagePropertyGPSLatitudeRef as String] as? String, latitudeRef == "S" {
            coordinate.latitude = -coordinate.latitude
        }
        if let longitudeRef = gpsDictionary[kCGImagePropertyGPSLongitudeRef as String] as? String, longitudeRef == "W" {
            coordinate.longitude = -coordinate.longitude
        }
        return coordinate
    }
}
