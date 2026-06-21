//
//  CatchDetailView.swift
//  Manceng
//
//  Halaman detail tangkapan: mirip dengan CatchReviewView tapi tanpa save,
//  dengan 3D model preview dan button back, share, hapus.
//

import SwiftUI
import SwiftData
import UIKit

struct CatchDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // CatchModel untuk data tangkapan asli (atau backward compatible parameters)
    let catchModel: CatchModel?
    let speciesName: String
    let length: String
    let weight: String
    let location: String
    
    @State private var showShareTemplate = false
    @State private var showDeleteAlert = false
    @State private var imageRotationX: Double = 0
    @State private var imageRotationY: Double = 0
    
    // Backward compatible initializer
    init(
        speciesName: String = "BARRAMUNDI FISH",
        length: String = "50 cm",
        weight: String = "7.2 Kg",
        location: String = "Batam"
    ) {
        self.catchModel = nil
        self.speciesName = speciesName
        self.length = length
        self.weight = weight
        self.location = location
    }
    
    // Initializer with CatchModel
    init(catchModel: CatchModel) {
        self.catchModel = catchModel
        self.speciesName = catchModel.species.capitalized
        self.length = String(format: "%.0f cm", catchModel.length)
        self.weight = String(format: "%.1f Kg", catchModel.weight)
        self.location = catchModel.location ?? "-"
    }

    var body: some View {
        GeometryReader { proxy in
            let availableHeight = proxy.size.height
            let previewHeight = min(430, max(300, availableHeight * 0.44))
            let topPadding = max(24, proxy.safeAreaInsets.top + 12)

            ZStack {
                Color.brandColorPrimaryYellow
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 18) {
                    fishPreview(height: previewHeight)
                        .frame(maxWidth: .infinity)
                        .frame(height: previewHeight)

                    infoCard

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, topPadding)
                .padding(.bottom, max(18, proxy.safeAreaInsets.bottom + 10))
            }
            .overlay(alignment: .top) { topBar }
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $showShareTemplate) {
            if let catchModel = catchModel {
                ShareTemplatesView(
                    fishImage: catchModel.image,
                    species: catchModel.species,
                    weight: catchModel.weight,
                    length: catchModel.length,
                    location: catchModel.location ?? "Unknown"
                )
            }
        }
        .alert("Delete Catch?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let catchModel = catchModel {
                    modelContext.delete(catchModel)
                    do {
                        try modelContext.save()
                    } catch {
                        print("Failed to delete catch: \(error.localizedDescription)")
                    }
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this catch? This action cannot be undone.")
        }
    }

    private var topBar: some View {
        HStack {
            CircleIconButton(systemName: "chevron.left") { dismiss() }

            Spacer()

            HStack(spacing: 6) {
                CircleIconButton(systemName: "square.and.arrow.up") {
                    showShareTemplate = true
                }
                if catchModel != nil {
                    CircleIconButton(systemName: "trash", iconColor: .red) {
                        showDeleteAlert = true
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func fishPreview(height: CGFloat) -> some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                detailFishImage
                    .frame(height: min(340, height * 0.84))
                    .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 30)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                imageRotationY = Double(value.translation.width) * 0.35
                                imageRotationX = -Double(value.translation.height) * 0.35
                            }
                            .onEnded { _ in
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                                    imageRotationX = 0
                                    imageRotationY = 0
                                }
                            }
                    )

                Ellipse()
                    .fill(.black.opacity(0.22))
                    .blur(radius: 16)
                    .frame(width: 210, height: 34)
                    .padding(.top, 18)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
        }
    }

    private var detailFishImage: some View {
        Group {
            if let image = catchModel?.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "fish.fill")
                    .resizable()
                    .scaledToFit()
            }
        }
        .rotationEffect(.degrees(90))
        .rotation3DEffect(.degrees(imageRotationY), axis: (x: 0, y: 1, z: 0), perspective: 0.65)
        .rotation3DEffect(.degrees(imageRotationX), axis: (x: 1, y: 0, z: 0), perspective: 0.65)
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            field(label: "Fish Name", value: speciesName)

            HStack(alignment: .top) {
                let lengthValue = catchModel?.length ?? 0
                let weightDisplay = detailWeightDisplay
                field(label: "Weight", value: weightDisplay.value, unit: weightDisplay.unit, isSize: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                field(label: "Length", value: String(format: "%.0f", lengthValue), unit: "cm", isSize: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            field(label: "Location", value: location, lineLimit: 2)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var detailWeightDisplay: (value: String, unit: String) {
        guard let weightValue = catchModel?.weight else {
            let parts = weight.split(separator: " ", maxSplits: 1).map(String.init)
            guard let value = parts.first else { return (weight, "") }
            return (value, parts.dropFirst().first ?? "")
        }

        let grams = weightValue * 1000
        if grams < 100 {
            return (String(format: "%.0f", grams), "grams")
        }

        let value = weightValue < 1
            ? String(format: "%.2f", weightValue)
            : String(format: "%.1f", weightValue)
        return (value, "kg")
    }

    private func field(label: String, value: String, unit: String? = nil, isSize: Bool = false, lineLimit: Int = 2) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.captionRegular)
                .foregroundStyle(.black)

            Text("\(Text(value).font(.title1Bold)) \(Text(unit ?? "").font(.kgCmFont))")
                .foregroundStyle(.black)
                .lineLimit(lineLimit)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, isSize ? 30 : 0)
        }
    }
}

#Preview {
    CatchDetailView()
}
