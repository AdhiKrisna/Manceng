//
//  CatchReviewView.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 15/06/26.
//

import SwiftUI

struct CatchReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CatchReviewViewModel

    let onRetake: () -> Void
    let onSave: (CatchModel) -> Void

    init(
        image: UIImage?,
        segmentedFishes: [SegmentedFish],
        onRetake: @escaping () -> Void,
        onSave: @escaping (CatchModel) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: CatchReviewViewModel(
            image: image,
            segmentedFishes: segmentedFishes
        ))
        self.onRetake = onRetake
        self.onSave = onSave
    }

    var body: some View {
        GeometryReader { proxy in
            let availableHeight = proxy.size.height
            let previewHeight = min(300, max(210, availableHeight * 0.34))
            let topPadding = max(48, proxy.safeAreaInsets.top + 36)

            ZStack {
                Color.BrandColorPrimaryYellow
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 18) {
                    fishPreview(height: previewHeight)
                        .frame(maxWidth: .infinity)
                        .frame(height: previewHeight)

                    infoCard

                    Spacer(minLength: 8)

                    saveButton
                }
                .padding(.horizontal, 20)
                .padding(.top, topPadding)
                .padding(.bottom, max(18, proxy.safeAreaInsets.bottom + 10))
            }
            .overlay(alignment: .top) { topBar }
        }
    }

    private var topBar: some View {
        HStack {
            CircleIconButton(systemName: "chevron.left") { onRetake() }

            Spacer()

            ShareLink(item: shareText) {
                GlassCircleIcon(systemName: "square.and.arrow.up")
                    .foregroundStyle(.black)
            }
            .buttonStyle(GlassPressStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var shareText: String {
        "\(viewModel.fishName) \(viewModel.weightText), \(viewModel.lengthText)"
    }

    private func fishPreview(height: CGFloat) -> some View {
        ZStack {
            if let maskedImage = viewModel.maskedFishImage {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    Image(uiImage: maskedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
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
            } else if let image = viewModel.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 20)
            } else {
                Image(systemName: "fish.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.black.opacity(0.75))
                    .padding(54)
            }
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            field(label: "Fish Name", value: viewModel.fishName)

            HStack(alignment: .top, spacing: 0) {
                field(label: "Weight", value: viewModel.weightText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                field(label: "Length", value: viewModel.lengthText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            field(label: "Location", value: "South China Sea")
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func field(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.captionFont)
                .foregroundStyle(.black)
            Text(value)
                .font(.title1Bold)
                .foregroundStyle(.black)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
    }

    private var saveButton: some View {
        ButtonOnboard(title: "Save") {
            onSave(savedCatch)
            dismiss()
        }
    }

    /// Bangun model `Catch` dari hasil review untuk ditampilkan sebagai card di beranda.
    private var savedCatch: CatchModel {
        CatchModel(
            image: viewModel.maskedFishImage ?? viewModel.image ?? UIImage(),
            species: viewModel.fishName,
            weight: viewModel.weightValue,
            length: viewModel.lengthValue,
            location: "South China Sea"
        )
    }
}

#Preview {
    CatchReviewView(image: nil, segmentedFishes: [], onRetake: {}, onSave: { _ in })
}
