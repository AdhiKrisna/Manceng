
//
//  ShareTemplatesView.swift
//  Manceng
//
//  Created by Trae on 16/06/26.
//

import SwiftUI
import UIKit
import MessageUI

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
                        .padding(.top, max(0, proxy.safeAreaInsets.top - 8))

                   
                    templateCarousel(height: proxy.size.height * 0.62, screenWidth: proxy.size.width)
                        .padding(.top, 4)

                    Spacer(minLength: 8)

                    shareSection
                        .padding(.horizontal, 8)
                        .padding(.bottom, 0)
                }
                .ignoresSafeArea(.container, edges: .bottom)
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
        let cardSpacing: CGFloat = 14
        let cardWidth = min(screenWidth - 56, height * ShareTemplateCard.aspectRatio)
        let sideInset = max(20, (screenWidth - cardWidth) / 2)

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: cardSpacing) {
                ForEach(Array(ShareTemplate.all.enumerated()), id: \.offset) { index, template in
                    ShareTemplateCard(
                        template: template,
                        fishImage: viewModel.fishImage,
                        content: viewModel.displayContent(for: template)
                    )
                    .frame(width: cardWidth, height: height)
                    .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, sideInset, for: .scrollContent)
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
    }

    private var shareSection: some View {
        VStack(spacing: 18) {
            Text("Share section")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)

            HStack(spacing: 28) {
                ForEach(ShareChannel.allCases) { channel in
                    ShareButton(
                        assetName: channel.assetName,
                        systemImage: channel.systemImage,
                        label: channel.label,
                        iconScale: channel.iconScale
                    ) {
                        share(to: channel)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 26)
        .padding(.bottom, 34)
        .background(Color.neutralColorPrimaryBlack50)
        .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
    }

    private func share(to channel: ShareChannel) {
        viewModel.shareTemplateAsImage { image in
            guard let image else { return }
            switch channel {
            case .instagram:
                presentInstagram(image: image)
            case .whatsApp:
                presentWhatsApp(image: image)
            case .iMessage:
                presentMessageComposer(image: image)
            case .more:
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

    private func presentInstagram(image: UIImage) {
        guard let root = rootViewController() else {
            presentSystemShareSheet(image: image)
            return
        }

        ShareDocumentPresenter.shared.present(
            image: image,
            fileName: "fishare-catch.igo",
            uti: "com.instagram.exclusivegram",
            from: root
        ) {
            presentSystemShareSheet(image: image)
        }
    }

    private func presentWhatsApp(image: UIImage) {
        guard let root = rootViewController() else {
            presentSystemShareSheet(image: image)
            return
        }

        ShareDocumentPresenter.shared.present(
            image: image,
            fileName: "fishare-catch.png",
            uti: "net.whatsapp.image",
            from: root
        ) {
            presentSystemShareSheet(image: image)
        }
    }

    private func presentMessageComposer(image: UIImage) {
        guard
            MFMessageComposeViewController.canSendText(),
            MFMessageComposeViewController.canSendAttachments(),
            let pngData = image.pngData()
        else {
            presentSystemShareSheet(image: image)
            return
        }

        let messageVC = MFMessageComposeViewController()
        messageVC.messageComposeDelegate = ShareMessageComposeDelegate.shared
        messageVC.body = "Check out my catch from FiShare"
        messageVC.addAttachmentData(pngData, typeIdentifier: "public.png", filename: "fishare-catch.png")
        rootViewController()?.present(messageVC, animated: true)
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

    var assetName: String? {
        switch self {
        case .instagram: return "ig"
        case .whatsApp: return "wa"
        case .iMessage: return "imes"
        case .more: return nil
        }
    }

    var systemImage: String? {
        switch self {
        case .instagram, .whatsApp, .iMessage: return nil
        case .more: return "ellipsis"
        }
    }

    var iconScale: CGFloat {
        switch self {
        case .whatsApp: return 1.28
        case .instagram, .iMessage, .more: return 1
        }
    }
}

private final class ShareMessageComposeDelegate: NSObject, MFMessageComposeViewControllerDelegate {
    static let shared = ShareMessageComposeDelegate()

    func messageComposeViewController(
        _ controller: MFMessageComposeViewController,
        didFinishWith result: MessageComposeResult
    ) {
        controller.dismiss(animated: true)
    }
}

private final class ShareDocumentPresenter: NSObject, UIDocumentInteractionControllerDelegate {
    static let shared = ShareDocumentPresenter()

    private var controller: UIDocumentInteractionController?

    func present(
        image: UIImage,
        fileName: String,
        uti: String,
        from rootViewController: UIViewController,
        fallback: () -> Void
    ) {
        guard let fileURL = writeImage(image, fileName: fileName) else {
            fallback()
            return
        }

        let controller = UIDocumentInteractionController(url: fileURL)
        controller.uti = uti
        controller.delegate = self
        self.controller = controller

        let sourceRect = CGRect(
            x: rootViewController.view.bounds.midX,
            y: rootViewController.view.bounds.maxY - 96,
            width: 1,
            height: 1
        )

        let didPresent = controller.presentOpenInMenu(
            from: sourceRect,
            in: rootViewController.view,
            animated: true
        )

        if !didPresent {
            fallback()
            self.controller = nil
        }
    }

    private func writeImage(_ image: UIImage, fileName: String) -> URL? {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let data: Data?

        if fileName.lowercased().hasSuffix(".png") {
            data = image.pngData()
        } else {
            data = image.jpegData(compressionQuality: 0.96)
        }

        guard let data else { return nil }

        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }
}

/// Size-agnostic share card. Used for the in-app carousel and,
/// wrapped in a fixed frame, for `ImageRenderer` output.
struct ShareTemplateCard: View {
    static let aspectRatio: CGFloat = 2544 / 4796

    let template: ShareTemplate
    let fishImage: UIImage
    let content: ShareTemplateDisplayContent

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                Image(template.assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()

                switch template.kind {
                case .template1:
                    templateOne(size)
                case .template2:
                    templateTwo(size)
                case .template3:
                    templateThree(size)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .aspectRatio(Self.aspectRatio, contentMode: .fit)
        .background(template.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func templateOne(_ size: CGSize) -> some View {
        let locationLength = CGFloat(content.locationText?.count ?? 0)
        let locationXShift = min(size.width * 0.055, max(0, locationLength - 16) * size.width * 0.002)
        let locationYShift = min(size.height * 0.055, max(0, locationLength - 20) * size.height * 0.0012)

        return ZStack {
            fishView()
                .scaleEffect(x: -1, y: -1)
                .frame(width: size.width * 0.76, height: size.height * 0.78)
                .position(x: size.width * 0.54, y: size.height * 0.555)

            rotatedSingleLine(
                content.speciesText,
                size: size.width * 0.184,
                color: template.textColor,
                width: size.height * 0.43,
                minScale: 0.2,
                tracking: 0
            )
            .position(x: size.width * 0.135, y: size.height * 0.235)

            if let locationText = content.locationText {
                rotatedSingleLine(
                    locationText,
                    size: size.width * 0.041,
                    color: template.textColor.opacity(0.66),
                    width: size.height * 0.32,
                    minScale: 0.24,
                    tracking: size.width * 0.004
                )
                .position(
                    x: size.width * 0.225 - locationXShift,
                    y: size.height * 0.235 + locationYShift
                )
            }

            VStack(alignment: .trailing, spacing: size.height * 0.012) {
                Text(content.templateOneWeight)
                Text(content.templateOneLength)
                Text(content.year)
            }
            .font(.impactRegular(size: size.width * 0.048))
            .foregroundStyle(Color.neutralColorPrimaryBlack50)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .frame(width: size.width * 0.3, alignment: .trailing)
            .position(x: size.width * 0.82, y: size.height * 0.105)
        }
    }

    private func templateTwo(_ size: CGSize) -> some View {
        ZStack {
            verticalText(content.speciesVerticalGlyphs, size: size.width * 0.092, color: template.textColor, spacing: -4)
                .position(x: size.width * 0.92, y: size.height * 0.48)

            fishView()
                .rotationEffect(.degrees(90))
                .frame(width: size.width * 0.75, height: size.height * 0.47)
                .position(x: size.width * 0.48, y: size.height * 0.44)

            if let locationText = content.locationText {
                HStack(spacing: size.width * 0.018) {
                    Circle()
                        .fill(Color.brandColorPrimaryYellow)
                        .frame(width: size.width * 0.026, height: size.width * 0.026)

                    Text(locationText)
                        .font(.impactRegular(size: size.width * 0.037))
                        .tracking(size.width * 0.006)
                        .foregroundStyle(Color.neutralColorPrimaryBlack1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
                    .frame(width: size.height * 0.24, alignment: .leading)
                    .rotationEffect(.degrees(-90))
                    .position(x: size.width * 0.11, y: size.height * 0.112)
            }

            Text(content.templateTwoWeight)
                .font(.impactRegular(size: size.width * 0.058))
                .tracking(size.width * 0.008)
                .foregroundStyle(Color.neutralColorPrimaryBlack50)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: size.width * 0.64, alignment: .center)
                .position(x: size.width * 0.5, y: size.height * 0.165)

            Text(content.templateTwoLength)
                .font(.impactRegular(size: size.width * 0.058))
                .tracking(size.width * 0.008)
                .foregroundStyle(Color.neutralColorPrimaryBlack50)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: size.width * 0.64, alignment: .center)
                .position(x: size.width * 0.5, y: size.height * 0.755)
        }
    }

    private func templateThree(_ size: CGSize) -> some View {
        ZStack {
            fishView()
                .scaleEffect(x: -1, y: -1)
                .frame(width: size.width * 0.82, height: size.height * 0.72)
                .position(x: size.width * 0.52, y: size.height * 0.58)

            Text(content.templateThreeSpecies)
                .font(.impactRegular(size: size.width * 0.22))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .shadow(color: .black.opacity(0.28), radius: 4, x: 0, y: 2)
                .frame(width: size.width * 0.94)
                .position(x: size.width * 0.5, y: size.height * 0.515)

            Text(content.templateThreeWeight)
                .templateThreeMetric(size: size.width * 0.04)
                .frame(width: size.width * 0.36, alignment: .leading)
                .position(x: size.width * 0.28, y: size.height * 0.043)

            Text(content.templateThreeLength)
                .templateThreeMetric(size: size.width * 0.04)
                .frame(width: size.width * 0.36, alignment: .trailing)
                .position(x: size.width * 0.72, y: size.height * 0.043)

            if let locationText = content.locationText {
                Text(locationText)
                    .font(.impactRegular(size: size.width * 0.032))
                    .tracking(size.width * 0.006)
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: size.width * 0.78)
                    .position(x: size.width * 0.5, y: size.height * 0.925)
            }
        }
    }

    private func fishView() -> some View {
        Image(uiImage: fishImage)
            .resizable()
            .scaledToFit()
    }

    private func verticalText(
        _ glyphs: [String],
        size: CGFloat,
        color: Color,
        spacing: CGFloat = -3
    ) -> some View {
        VStack(spacing: spacing) {
            ForEach(Array(glyphs.enumerated()), id: \.offset) { _, glyph in
                if glyph == " " {
                    Color.clear
                        .frame(width: size, height: size * 0.72)
                } else {
                    Text(glyph)
                        .font(.impactRegular(size: size))
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
        }
    }

    private func rotatedLabelStack(
        primary: String,
        secondary: String?,
        primarySize: CGFloat,
        secondarySize: CGFloat,
        color: Color,
        secondaryColor: Color,
        spacing: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            Text(primary)
                .font(.impactRegular(size: primarySize))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            if let secondary {
                Text(secondary)
                    .font(.impactRegular(size: secondarySize))
                    .tracking(secondarySize * 0.08)
                    .foregroundStyle(secondaryColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
            }
        }
    }

    private func rotatedSingleLine(
        _ text: String,
        size: CGFloat,
        color: Color,
        width: CGFloat,
        minScale: CGFloat,
        tracking: CGFloat
    ) -> some View {
        Text(text)
            .font(.impactRegular(size: size))
            .tracking(tracking)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(minScale)
            .frame(width: width, alignment: .leading)
            .rotationEffect(.degrees(-90))
    }
}

private extension Text {
    func templateThreeMetric(size: CGFloat) -> some View {
        self
            .font(.impactRegular(size: size))
            .foregroundStyle(Color.white.opacity(0.78))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

/// Fixed-size wrapper used exclusively by `ImageRenderer` so the produced
/// UIImage matches the source template asset ratio.
struct ShareTemplateRenderCard: View {
    let template: ShareTemplate
    let fishImage: UIImage
    let content: ShareTemplateDisplayContent

    var body: some View {
        ShareTemplateCard(
            template: template,
            fishImage: fishImage,
            content: content
        )
        .frame(width: 1080, height: 2036)
    }
}

struct ShareButton: View {
    let assetName: String?
    let systemImage: String?
    let label: String
    let iconScale: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                icon
                    .frame(width: 57, height: 57)

                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(GlassPressStyle())
    }

    @ViewBuilder
    private var icon: some View {
        if let assetName {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .scaleEffect(iconScale)
        } else if let systemImage {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 57, height: 57)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.88))
                )
        }
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
