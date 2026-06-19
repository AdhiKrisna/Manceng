//
//  FishWeightEstimationService.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 19/06/26.
//

import Foundation

struct FishWeightEstimationService {
    private struct WeightAnnotation: Decodable {
        let id: String
        let nama: String
        let a: Double
        let b: Double
    }

    private let annotations: [WeightAnnotation]

    init(bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: "weight_anotation", withExtension: "txt"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([WeightAnnotation].self, from: data) else {
            annotations = []
            return
        }

        annotations = decoded
    }

    func estimateWeightKg(speciesName: String, lengthCm: Double) -> Double? {
        guard lengthCm.isFinite, lengthCm > 0,
              let annotation = annotation(for: speciesName) else {
            return nil
        }

        let grams = annotation.a * pow(lengthCm, annotation.b)
        guard grams.isFinite, grams > 0 else { return nil }
        return grams / 1000
    }

    private func annotation(for speciesName: String) -> WeightAnnotation? {
        let normalizedSpecies = normalize(speciesName)
        guard !normalizedSpecies.isEmpty else { return nil }

        if let exact = annotations.first(where: { entry in
            normalize(entry.nama) == normalizedSpecies || normalize(entry.id) == normalizedSpecies
        }) {
            return exact
        }

        return annotations.first { entry in
            let normalizedName = normalize(entry.nama)
            let normalizedID = normalize(entry.id)
            return normalizedName.contains(normalizedSpecies)
                || normalizedSpecies.contains(normalizedName)
                || normalizedID.contains(normalizedSpecies)
                || normalizedSpecies.contains(normalizedID)
        }
    }

    private func normalize(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .filter { $0.isLetter || $0.isNumber }
            .lowercased()
    }
}
