//
//  HistoryViewModel.swift
//  Manceng
//
//  Created by Codex on 19/06/26.
//

import Combine
import Foundation

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var selectedSort: SortOption = .latest

    func sortedCatches(_ catches: [CatchModel]) -> [CatchModel] {
        switch selectedSort {
        case .latest:
            return catches.sorted { $0.capturedAt > $1.capturedAt }
        case .weight:
            return catches.sorted { $0.weight > $1.weight }
        case .length:
            return catches.sorted { $0.length > $1.length }
        }
    }

    func bottomText(for item: CatchModel) -> String {
        switch selectedSort {
        case .latest:
            return item.capturedAt.formatted(date: .numeric, time: .omitted)
        case .weight:
            return formattedWeightWithUnit(item.weight)
        case .length:
            return String(format: "%.0f cm", item.length)
        }
    }

    private func formattedWeightWithUnit(_ weight: Double) -> String {
        let grams = weight * 1000
        if grams > 0, grams < 100 {
            return String(format: "%.0f grams", grams)
        }

        let value = weight < 1
            ? String(format: "%.2f", weight)
            : String(format: "%.1f", weight)
        return "\(value) kg"
    }
}
