
//
//  ShareTemplatesView.swift
//  Manceng
//
//  Created by Trae on 16/06/26.
//

import SwiftUI
import UIKit

struct ShareTemplatesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ShareTemplatesViewModel

    init(
        fishImage: UIImage,
        species: String,
        weight: Double,
        length: Double,
        location: String?
    ) {
        _viewModel = StateObject(wrappedValue: ShareTemplatesViewModel(
            fishImage: fishImage,
            species: species,
            weight: weight,
            length: length,
            location: location
        ))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                viewModel.selectedTemplate.backgroundColor
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.25), value: viewModel.currentPageIndex)

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, max(48, proxy.safeAreaInsets.top + 20))

                   
                    templateCarousel(height: proxy.size.height * 0.55, screenWidth: proxy.size.width)
                        .padding(.top, 24)

                    Spacer(minLength: 16)

                    shareSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, max(24, proxy.safeAreaInsets.bottom + 10))
                }
            }
        }
    }

    private var header: some View {
        HStack {
            CircleIconButton(systemName: "chevron.left") {
                dismiss()
            }

            Spacer()
        }
    }
    private func templateCarousel(height: CGFloat, screenWidth: CGFloat) -> some View {
        let cardSpacing: CGFloat = 0
        let firstLeading: CGFloat = 8
        let middleHorizontal: CGFloat = 12
        let lastTrailing: CGFloat = 8
        let outerPeek: CGFloat = 44

        let cardWidth: CGFloat = screenWidth - 20 - outerPeek

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: cardSpacing) {
                ForEach(Array(ShareTemplate.all.enumerated()), id: \.offset) { index, template in
                    ShareTemplateCard(
                        template: template,
                        fishImage: viewModel.fishImage,
                        species: viewModel.species,
                        weight: viewModel.weight,
                        length: viewModel.length,
                        location: viewModel.location
                    )
                    .frame(width: cardWidth)
                    .padding(.leading, leadingPadding(for: index))
                    .padding(.trailing, trailingPadding(for: index))
                    .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.leading, 20, for: .scrollContent)
        .contentMargins(.trailing, 0, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $viewModel.scrollPositionID)
        .frame(height: height)
        .onChange(of: viewModel.scrollPositionID) { _, newValue in
            guard let newValue else { return }
            viewModel.currentPageIndex = newValue
            withAnimation(.easeInOut(duration: 0.25)) {
                viewModel.selectedTemplate = ShareTemplate.all[newValue]
            }
        }

         func leadingPadding(for index: Int) -> CGFloat {
            if index == 0 {
                return 4      // sebelumnya 8, bikin peek kanan lebih kelihatan
            } else if index == ShareTemplate.all.count - 1 {
                return 6      // sebelumnya 12, biar card terakhir tidak terlalu geser ke kanan
            } else {
                return 8      // sebelumnya 12, biar peek kiri-kanan item tengah lebih kelihatan
            }
        }

         func trailingPadding(for index: Int) -> CGFloat {
            if index == ShareTemplate.all.count - 1 {
                return 4      // kecil supaya ujung kanan tetap rapih
            } else if index == 0 {
                return 8      // cukup buat sneak peek card kedua
            } else {
                return 8      // item tengah, jangan terlalu besar
            }
        }
    }

    private var shareSection: some View {
        VStack(spacing: 20) {
            Text("Share to...")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(viewModel.selectedTemplate.textColor)

            HStack(spacing: 24) {
                ForEach(ShareChannel.allCases) { channel in
                    ShareButton(
                        systemImage: channel.systemImage,
                        label: channel.label
                    ) {
                        share(to: channel)
                    }
                }
            }
        }
        .padding(.vertical, 30)
        .padding(.horizontal, 24)
        .background(viewModel.selectedTemplate.textColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    private func share(to channel: ShareChannel) {
        viewModel.shareTemplateAsImage { image in
            guard let image else { return }
            switch channel {
            case .instagram:
                presentInstagramStories(image: image)
            case .whatsApp, .iMessage, .more:
                presentSystemShareSheet(image: image)
            }
        }
    }

    private func presentSystemShareSheet(image: UIImage) {
        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        rootViewController()?.present(activityVC, animated: true)
    }

    private func presentInstagramStories(image: UIImage) {
        guard
            let storiesURL = URL(string: "instagram-stories://share?source_application=manceng"),
            UIApplication.shared.canOpenURL(storiesURL),
            let pngData = image.pngData()
        else {
            presentSystemShareSheet(image: image)
            return
        }

        let items: [[String: Any]] = [[
            "com.instagram.sharedSticker.stickerImage": pngData,
            "com.instagram.sharedSticker.backgroundTopColor":
                viewModel.selectedTemplate.backgroundColorHex,
            "com.instagram.sharedSticker.backgroundBottomColor":
                viewModel.selectedTemplate.backgroundColorHex
        ]]
        let options: [UIPasteboard.OptionsKey: Any] = [
            .expirationDate: Date().addingTimeInterval(60 * 5)
        ]
        UIPasteboard.general.setItems(items, options: options)
        UIApplication.shared.open(storiesURL)
    }

    private func rootViewController() -> UIViewController? {
        guard
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let root = windowScene.windows.first(where: \.isKeyWindow)?.rootViewController
        else { return nil }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}

enum ShareChannel: String, CaseIterable, Identifiable {
    case instagram, whatsApp, iMessage, more

    var id: String { rawValue }

    var label: String {
        switch self {
        case .instagram: return "Instagram"
        case .whatsApp: return "WhatsApp"
        case .iMessage: return "iMessage"
        case .more: return "More"
        }
    }

    var systemImage: String {
        switch self {
        case .instagram: return "camera.fill"
        case .whatsApp: return "message.fill"
        case .iMessage: return "bubble.left.fill"
        case .more: return "ellipsis"
        }
    }
}

/// Size-agnostic share card. Used for the in-app carousel and,
/// wrapped in a fixed frame, for `ImageRenderer` output.
struct ShareTemplateCard: View {
    let template: ShareTemplate
    let fishImage: UIImage
    let species: String
    let weight: Double
    let length: Double
    let location: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(uiImage: fishImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 12)

            VStack(alignment: .leading, spacing: 14) {
                cardField(label: "Fish Name", value: species)
                cardField(label: "Weight", value: String(format: "%.1f kg", weight))
                cardField(label: "Length", value: String(format: "%.0f cm", length))
                if let location {
                    cardField(label: "Location", value: location)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(template.cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func cardField(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(template.textColor.opacity(0.6))
            Text(value)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(template.textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

/// Fixed-size wrapper used exclusively by `ImageRenderer` so the produced
/// UIImage has consistent, share-friendly dimensions (1080x1350, 4:5).
struct ShareTemplateRenderCard: View {
    let template: ShareTemplate
    let fishImage: UIImage
    let species: String
    let weight: Double
    let length: Double
    let location: String?

    var body: some View {
        ShareTemplateCard(
            template: template,
            fishImage: fishImage,
            species: species,
            weight: weight,
            length: length,
            location: location
        )
        .frame(width: 1080, height: 1350)
    }
}

struct ShareButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 36))
                    .foregroundStyle(.black)
                    .frame(width: 72, height: 72)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    )

                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(GlassPressStyle())
    }
}

#Preview {
    ShareTemplatesView(
        fishImage: UIImage(systemName: "fish.fill") ?? UIImage(),
        species: "Catfish",
        weight: 0.7,
        length: 50,
        location: "Jakarta, Indonesia"
    )
}
