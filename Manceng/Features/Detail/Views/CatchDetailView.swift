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
    @StateObject private var motion = Model3DMotionManager()
    @State private var fishInteraction = FishInteractionState()
    
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
        self.speciesName = catchModel.species.uppercased()
        self.length = String(format: "%.0f cm", catchModel.length)
        self.weight = String(format: "%.1f Kg", catchModel.weight)
        self.location = catchModel.location ?? "-"
    }

    var body: some View {
        GeometryReader { proxy in
            let availableHeight = proxy.size.height
            let previewHeight = min(300, max(210, availableHeight * 0.34))
            let topPadding = max(24, proxy.safeAreaInsets.top + 12)

            ZStack {
                Color.BrandColorPrimaryYellow
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
        .fullScreenCover(isPresented: $showShareTemplate) {
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
        .onAppear { motion.start() }
        .onDisappear { motion.stop() }
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
                    CircleIconButton(systemName: "trash") {
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
                FishModelView(
                    motion: motion,
                    interaction: fishInteraction,
                    onSingleTap: {},
                    extraYawDegrees: 90,
                    fillSize: 0.45,
                    allowZoom: false
                )
                .frame(height: min(150, height * 0.55))
                .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 30)

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

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            field(label: "Fish Name", value: speciesName)

            HStack(alignment: .top) {
                let weightValue = catchModel?.weight ?? 0
                let lengthValue = catchModel?.length ?? 0
                field(label: "Weight", value: String(format: "%.1f", weightValue), unit: "kg", isSize: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                field(label: "Length", value: String(format: "%.0f", lengthValue), unit: "cm", isSize: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            field(label: "Location", value: location)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func field(label: String, value: String, unit: String? = nil, isSize: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.Caption1Bold)
                .foregroundStyle(.black)

            Text("\(Text(value).font(.Title1Bold)) \(Text(unit ?? "").font(.kgcmFont))")
                .foregroundStyle(.black)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .padding(.leading, isSize ? 30 : 0)
        }
    }
}

#Preview {
    CatchDetailView()
}
