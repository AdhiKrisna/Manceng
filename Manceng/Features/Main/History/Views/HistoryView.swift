//
//  HistoryView.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 14/06/26.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    enum SortOption: String, CaseIterable, Identifiable {
        case latest = "Latest"
        case weight = "Weight"
        case length = "Length"
        
        var id: String { self.rawValue }
    }

    @State private var selectedSort: SortOption = .latest
    @Query private var allCatches: [CatchModel]

    var sortedCatches: [CatchModel] {
        switch selectedSort {
        case .latest:
            return allCatches.sorted(by: { $0.capturedAt > $1.capturedAt })
        case .weight:
            return allCatches.sorted(by: { $0.weight > $1.weight })
        case .length:
            return allCatches.sorted(by: { $0.length > $1.length })
        }
    }

    let columns = [
        GridItem(.flexible(), spacing: 18),
        GridItem(.flexible(), spacing: 18),
        GridItem(.flexible(), spacing: 18)
    ]

    var body: some View {
        ZStack {
            Color.BrandColorPrimaryYellow
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 18)

                if sortedCatches.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(sortedCatches) { item in
                                historyItem(item)
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.bottom, 118)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
    }

    private var header: some View {
        ZStack {
            Text("History")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)

            HStack {
                Spacer()
                sortMenu
            }
        }
        .frame(height: 44)
    }

    private var sortMenu: some View {
        Menu {
            ForEach(SortOption.allCases) { option in
                Button {
                    selectedSort = option
                } label: {
                    HStack {
                        Text(option.rawValue)
                        if selectedSort == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Circle()
                .fill(Color.white.opacity(0.5))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)
                }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "fish.fill")
                .font(.system(size: 44))
            Text("History masih kosong")
                .font(.system(size: 16, weight: .semibold))
        }
        .foregroundStyle(.black.opacity(0.62))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 90)
    }

    private func historyItem(_ item: CatchModel) -> some View {
        VStack(spacing: 4) {
            Image(uiImage: item.image)
                .resizable()
                .scaledToFit()
                .frame(height: 100)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 10)

            Text(item.species.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.top, 8)

            Text(bottomText(for: item))
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.black.opacity(0.58))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }

    private func bottomText(for item: CatchModel) -> String {
        switch selectedSort {
        case .latest:
            return item.capturedAt.formatted(date: .numeric, time: .omitted)
        case .weight:
            return String(format: "%.0f Kg", item.weight)
        case .length:
            return String(format: "%.0f cm", item.length)
        }
    }
}

#Preview {
    HistoryView()
}
