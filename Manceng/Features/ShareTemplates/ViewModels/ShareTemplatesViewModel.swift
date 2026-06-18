
//
//  ShareTemplatesViewModel.swift
//  Manceng
//
//  Created by Trae on 16/06/26.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class ShareTemplatesViewModel: ObservableObject {
    @Published var selectedTemplate: ShareTemplate = .all[0]
    @Published var fishImage: UIImage
    @Published var species: String
    @Published var weight: Double
    @Published var length: Double
    @Published var location: String?
    @Published var currentPageIndex: Int = 0
    @Published var scrollPositionID: Int? = 0

    init(
        fishImage: UIImage,
        species: String,
        weight: Double,
        length: Double,
        location: String?
    ) {
        self.fishImage = fishImage
        self.species = species
        self.weight = weight
        self.length = length
        self.location = location
    }

    func renderTemplate() -> some View {
        ShareTemplateRenderCard(
            template: selectedTemplate,
            fishImage: fishImage,
            species: species,
            weight: weight,
            length: length,
            location: location
        )
    }

    func shareTemplateAsImage(completion: @escaping (UIImage?) -> Void) {
        let renderer = ImageRenderer(content: renderTemplate())
        renderer.scale = 1
        completion(renderer.uiImage)
    }
}
