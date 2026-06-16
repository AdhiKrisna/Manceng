//
//  HomeView.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 15/06/26.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \CatchModel.capturedAt, order: .reverse) private var catches: [CatchModel]

    var body: some View {
        Group {
            if catches.isEmpty {
                Text("Belum ada catch tersimpan")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(catches) { item in
                            catchRow(item)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Home")
    }

    private func catchRow(_ item: CatchModel) -> some View {
        HStack(spacing: 14) {
            Image(uiImage: item.image)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .background(Color.BrandColorPrimaryYellow, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.species)
                    .font(.headline)
                Text(String(format: "%.1f kg | %.0f cm", item.weight, item.length))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let location = item.location {
                    Text(location)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    HomeView()
}
