//
//  CatchModel.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 10/06/26.
//

import SwiftUI
import SwiftData

@Model
final class CatchModel: Identifiable {
    @Attribute(.unique) var id: UUID
    @Attribute(.externalStorage) var imageData: Data?
    var species: String
    var weight: Double
    var length: Double
    var location: String?
    var capturedAt: Date

    @Transient var image: UIImage {
        if let imageData, let uiImage = UIImage(data: imageData) {
            return uiImage
        }
        return UIImage()
    }

    init(
        id: UUID = UUID(),
        image: UIImage,
        imageData: Data? = nil,
        species: String,
        weight: Double,
        length: Double,
        location: String?,
        capturedAt: Date = Date()
    ) {
        self.id = id
        self.imageData = imageData ?? image.pngData()
        self.species = species
        self.weight = weight
        self.length = length
        self.location = location
        self.capturedAt = capturedAt
    }
}
