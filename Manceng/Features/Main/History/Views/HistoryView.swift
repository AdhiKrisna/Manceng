//
//  HistoryView.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 14/06/26.
//

import SwiftData
import SwiftUI

struct HistoryView: View {
    @State private var selectedSort: SortOption = .latest
    @StateObject private var model3DMotion = Model3DMotionManager()
    @State private var interaction = FishInteractionState()
    @Query private var allCatches: [CatchModel]

    private var sortedCatches: [CatchModel] {
        switch selectedSort {
        case .latest:
            return allCatches.sorted { $0.capturedAt > $1.capturedAt }
        case .weight:
            return allCatches.sorted { $0.weight > $1.weight }
        case .length:
            return allCatches.sorted { $0.length > $1.length }
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 18),
        GridItem(.flexible(), spacing: 18),
        GridItem(.flexible(), spacing: 18),
    ]

    var body: some View {
        let catches = sortedCatches
        VStack {
            header
                .padding(.horizontal, 20)
            Spacer()
            if catches.isEmpty {
                VStack {
                    emptyState.padding(.bottom, 118)

                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(catches) { item in
                            historyItem(item)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 118)
                }
                .scrollIndicators(.hidden)
            }
            Spacer()

        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.BrandColorPrimaryYellow)
    }

    private var header: some View {
        ZStack {
            Text("History")
                .font(.title1Semibold)
                .foregroundStyle(Color.NeutralColorPrimaryBlack1)

            HStack {
                Spacer()

                SortButton(selectedSort: $selectedSort)
            }
        }
        .frame(height: 40)
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            FishModelView(
                motion: model3DMotion,
                interaction: interaction,
                extraYawDegrees: 90,
                fillSize: 0.45,
                allowZoom: false
            )
            .frame(height: 320)
            .onAppear { model3DMotion.start() }
            .onDisappear { model3DMotion.stop() }

            VStack(spacing: 8) {
                Text("No catches recorded yet!")
                    .font(.title1Semibold)
                    .foregroundColor(.NeutralColorPrimaryBlack1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("Tap camera button below to get started!")
                    .font(.caption1Bold)
                    .foregroundColor(.NeutralColorPrimaryBlack1.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 340)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    private func historyItem(_ item: CatchModel) -> some View {
        VStack(spacing: 4) {
            Image(uiImage: item.image)
                .resizable()
                .scaledToFit()
                .frame(height: 100)
                .shadow(
                    color: .black.opacity(0.15),
                    radius: 8,
                    x: 0,
                    y: 10
                )

            Text(item.species.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.top, 8)

            Text(bottomText(for: item))
                .font(.system(size: 10))
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
            return "\(formattedWeight(item.weight)) kg"
        case .length:
            return String(format: "%.0f cm", item.length)
        }
    }

    private func formattedWeight(_ weight: Double) -> String {
        weight < 1
            ? String(format: "%.2f", weight)
            : String(format: "%.1f", weight)
    }
}

#Preview {
    HistoryView()
}
