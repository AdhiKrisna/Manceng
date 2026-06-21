
//
//  ShareTemplatesView.swift
//  Manceng
//
//  Created by Trae on 16/06/26.
//

import SwiftUI
import UIKit
import MessageUI
import LinkPresentation

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
                Color.brandColorPrimaryYellow
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    templateCarousel(height: proxy.size.height * 0.66, screenWidth: proxy.size.width)

                    pageDots
                        .padding(.top, 24)

                    Spacer()
                }
            }
            .overlay(alignment: .top) { header }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // Placement mirrors CatchDetailView.topBar.
    private var header: some View {
        HStack {
            CircleIconButton(systemName: "chevron.left") {
                dismiss()
            }

            Spacer()

            shareButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var shareButton: some View {
        Button {
            shareSelected()
        } label: {
            Text("Share")
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundStyle(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 15)
                .glassStyle(Capsule())
        }
        .buttonStyle(GlassPressStyle())
    }

    private var pageDots: some View {
        let dotColor = Color.neutralColorPrimaryBlack1
        return HStack(spacing: 8) {
            ForEach(ShareTemplate.all.indices, id: \.self) { index in
                Capsule()
                    .fill(index == viewModel.currentPageIndex ? dotColor : dotColor.opacity(0.3))
                    .frame(width: index == viewModel.currentPageIndex ? 22 : 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.currentPageIndex)
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
                    // Center card stays full size; side cards shrink + dim.
                    .scrollTransition(.interactive) { content, phase in
                        content
                            .scaleEffect(phase.isIdentity ? 1 : 0.8)
                            .opacity(phase.isIdentity ? 1 : 0.55)
                    }
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

    private func shareSelected() {
        viewModel.shareTemplateAsImage { image in
            guard let image else { return }
            presentSystemShareSheet(image: image)
        }
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
        // ShareImageItemSource supplies LPLinkMetadata so the sheet shows a
        // preview card of the selected template (not just a bare thumbnail).
        let item = ShareImageItemSource(image: image, title: viewModel.species)
        let activityVC = UIActivityViewController(
            activityItems: [item],
            applicationActivities: nil
        )
        rootViewController()?.present(activityVC, animated: true)
    }

    /// Instagram Stories via pasteboard, per Meta's documented flow
    /// (https://developers.facebook.com/docs/instagram-platform/sharing-to-stories).
    private func presentInstagram(image: UIImage) {
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        guard
            let storiesURL = URL(string: "instagram-stories://share?source_application=\(bundleID)"),
            UIApplication.shared.canOpenURL(storiesURL)
        else {
            presentAppNotInstalledAlert(name: "Instagram", appStoreURL: Self.instagramAppStoreURL)
            return
        }

        guard let pngData = image.pngData() else {
            presentSystemShareSheet(image: image)
            return
        }

        // Full-bleed template image → use it as the Stories background.
        // ponytail: backgroundTopColor/bottomColor only matter for a transparent
        // sticker over a solid backdrop; our image already fills the frame, so skip.
        // ponytail: contentURL attribution omitted — no per-template URL yet
        // (see ShareTemplate; add the link here once one exists).
        let items: [String: Any] = [
            "com.instagram.sharedSticker.backgroundImage": pngData
        ]
        UIPasteboard.general.setItems(
            [items],
            options: [.expirationDate: Date().addingTimeInterval(60)] // privacy: clear after 1 min
        )

        UIApplication.shared.open(storiesURL)
    }

    private func presentWhatsApp(image: UIImage) {
        // WhatsApp can't attach an image via a URL scheme; the documented path is
        // UIDocumentInteractionController with UTI "net.whatsapp.image". The user
        // then picks the contact inside WhatsApp.
        // ponytail: image-only — WhatsApp's "Open in" flow doesn't carry a caption
        // alongside the image; text would need the separate whatsapp://send?text= scheme.
        guard
            let waURL = URL(string: "whatsapp://"),
            UIApplication.shared.canOpenURL(waURL)
        else {
            presentAppNotInstalledAlert(name: "WhatsApp", appStoreURL: Self.whatsAppAppStoreURL)
            return
        }

        guard let root = rootViewController() else {
            presentSystemShareSheet(image: image)
            return
        }

        // .wai (WhatsApp Image) + JPEG is WhatsApp's documented format — only WhatsApp
        // declares this UTI, so the "Open in" sheet filters down to a single WhatsApp
        // entry (effectively one tap) instead of a generic app list.
        ShareDocumentPresenter.shared.present(
            image: image,
            fileName: "fishare-catch.wai",
            uti: "net.whatsapp.image",
            from: root
        ) {
            presentSystemShareSheet(image: image)
        }
    }

    private static let instagramAppStoreURL = URL(string: "https://apps.apple.com/app/instagram/id389801252")
    private static let whatsAppAppStoreURL = URL(string: "https://apps.apple.com/app/whatsapp-messenger/id310633997")

    private func presentAppNotInstalledAlert(name: String, appStoreURL: URL?) {
        let alert = UIAlertController(
            title: "\(name) tidak ditemukan",
            message: "Aplikasi \(name) belum terpasang di perangkat ini.",
            preferredStyle: .alert
        )
        if let appStoreURL {
            alert.addAction(UIAlertAction(title: "Buka App Store", style: .default) { _ in
                UIApplication.shared.open(appStoreURL)
            })
        }
        alert.addAction(UIAlertAction(title: "Tutup", style: .cancel))
        rootViewController()?.present(alert, animated: true)
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

/// Feeds the share sheet a rich preview (image + title) via LinkPresentation,
/// while the actual shared item stays the template UIImage.
private final class ShareImageItemSource: NSObject, UIActivityItemSource {
    private let image: UIImage
    private let title: String

    init(image: UIImage, title: String) {
        self.image = image
        self.title = title
    }

    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any {
        image
    }

    func activityViewController(
        _ controller: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        image
    }

    func activityViewControllerLinkMetadata(_ controller: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        let provider = NSItemProvider(object: image)
        metadata.imageProvider = provider
        metadata.iconProvider = provider
        return metadata
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
    private var fileURL: URL?

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
        self.fileURL = fileURL

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
            cleanup()
        }
    }

    // Release the controller and delete the temp file once the menu/app handoff ends.
    func documentInteractionControllerDidDismissOpenInMenu(_ controller: UIDocumentInteractionController) {
        cleanup()
    }

    func documentInteractionController(
        _ controller: UIDocumentInteractionController,
        didEndSendingToApplication application: String?
    ) {
        cleanup()
    }

    private func cleanup() {
        if let fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        fileURL = nil
        controller = nil
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
        return ZStack {
            fishView()
                .scaleEffect(x: -1, y: -1)
                .frame(width: size.width * 0.76, height: size.height * 0.78)
                .position(x: size.width * 0.54, y: size.height * 0.555)

            rotatedTemplateOneLabel(size)
                .position(x: size.width * 0.16, y: size.height * 0.235)

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
                    .position(x: size.width * 0.5, y: size.height * 0.965)
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

    private func rotatedTemplateOneLabel(_ size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: size.height * 0.002) {
            Text(content.speciesText)
                .font(.impactRegular(size: size.width * 0.184))
                .foregroundStyle(template.textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.2)
                .frame(width: size.height * 0.43, alignment: .leading)

            if let locationText = content.locationText {
                Text(locationText)
                    .font(.impactRegular(size: size.width * 0.041))
                    .tracking(size.width * 0.004)
                    .foregroundStyle(template.textColor.opacity(0.66))
                    .lineLimit(1)
                    .minimumScaleFactor(0.24)
                    .frame(width: size.height * 0.38, alignment: .leading)
            }
        }
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
