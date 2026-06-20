
//
//  ShareTemplatesViewModel.swift
//  Manceng
//
//  Created by Trae on 16/06/26.
//

import Foundation
import SwiftUI
import Combine

struct ShareTemplateDisplayContent {
    let speciesText: String
    let locationText: String?
    let speciesVerticalGlyphs: [String]
    let templateOneWeight: String
    let templateOneLength: String
    let templateTwoWeight: String
    let templateTwoLength: String
    let templateThreeWeight: String
    let templateThreeLength: String
    let templateThreeSpecies: String
    let year: String
    let showsLocation: Bool
}

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
            content: displayContent(for: selectedTemplate)
        )
    }

    func shareTemplateAsImage(completion: @escaping (UIImage?) -> Void) {
        let renderer = ImageRenderer(content: renderTemplate())
        renderer.scale = 2
        completion(renderer.uiImage)
    }

    func displayContent(for _: ShareTemplate) -> ShareTemplateDisplayContent {
        let cleanLocation = cleanedLocation
        return ShareTemplateDisplayContent(
            speciesText: displaySpeciesText,
            locationText: cleanLocation?.uppercased(),
            speciesVerticalGlyphs: verticalGlyphs(from: displaySpeciesText),
            templateOneWeight: formattedWeight,
            templateOneLength: formattedLength,
            templateTwoWeight: "WEIGHT : \(formattedWeight)",
            templateTwoLength: "HEIGHT : \(formattedLength)",
            templateThreeWeight: "Weight . \(formattedWeight)",
            templateThreeLength: "Length . \(formattedLength)",
            templateThreeSpecies: templateThreeSpeciesText,
            year: currentYear,
            showsLocation: cleanLocation != nil
        )
    }

    private var formattedWeight: String {
        let grams = weight * 1000
        if grams < 100 {
            return "\(Int(round(grams))) Grams"
        }
        if weight < 1 {
            return String(format: "%.2f Kg", weight)
        }
        if weight.rounded() == weight {
            return String(format: "%.0f Kg", weight)
        }
        return String(format: "%.1f Kg", weight)
    }

    private var formattedLength: String {
        "\(Int(round(length))) Cm"
    }

    private var currentYear: String {
        "\(Calendar.current.component(.year, from: Date()))"
    }

    private var cleanedLocation: String? {
        guard let location else { return nil }
        let value = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.lowercased() != "unknown" else { return nil }
        return value
    }

    private var displaySpeciesText: String {
        let normalized = species
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        let spaced = normalized.reduce(into: "") { partial, character in
            if let previous = partial.last,
               previous.isLowercase,
               character.isUppercase {
                partial.append(" ")
            }
            partial.append(character)
        }

        return spaced
            .split(separator: " ")
            .map(String.init)
            .joined(separator: " ")
            .uppercased()
    }

    private var templateThreeSpeciesText: String {
        let words = displaySpeciesText
            .split(separator: " ")
            .map(String.init)

        guard words.count == 1, let word = words.first else {
            return words.joined(separator: " ")
        }

        let midpoint = max(1, word.count / 2)
        let splitIndex = word.index(word.startIndex, offsetBy: midpoint)
        return "\(word[..<splitIndex]) \(word[splitIndex...])"
    }

    private func verticalGlyphs(from text: String) -> [String] {
        let words = text
            .uppercased()
            .split(separator: " ")
            .map(String.init)

        return words.enumerated().flatMap { index, word in
            let letters = word.map(String.init)
            return index == 0 ? letters : [" "] + letters
        }
    }
}
