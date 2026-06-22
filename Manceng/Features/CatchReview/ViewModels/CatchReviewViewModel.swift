//
//  CatchReviewViewModel.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 15/06/26.
//

import Combine
import SwiftData
import UIKit
import Vision

@MainActor
final class CatchReviewViewModel: ObservableObject {
    let image: UIImage?
    let reviewFishImage: UIImage?
    let savedFishImage: UIImage?
    @Published var showLocationSettingsAlert: Bool
    @Published var showShareTemplate = false
    private let locationMetadata: CatchLocationMetadata?
    private let primaryFish: DetectedFish?
    private var savedCatchModel: CatchModel?

    var fishName: String {
        primaryFish?.species ?? "Unfortunately, we couldn't identify this fish"
    }

    var weightText: String {
        if shouldDisplayWeightInGrams {
            return String(format: "%.0f", weightValue * 1000)
        }

        return weightValue < 1
            ? String(format: "%.2f", weightValue)
            : String(format: "%.1f", weightValue)
    }

    var weightUnitText: String {
        shouldDisplayWeightInGrams ? "grams" : "kg"
    }

    var lengthText: String {
        String(format: "%.0f", lengthValue)
    }

    var lengthValue: Double {
        primaryFish?.estimatedLengthCm ?? 0
    }

    var weightValue: Double {
        primaryFish?.estimatedWeightKg ?? 0
    }

    private var shouldDisplayWeightInGrams: Bool {
        let grams = weightValue * 1000
        return grams > 0 && grams < 100
    }

    var locationDisplayText: String {
        locationMetadata?.displayName ?? "Unknown"
    }

    var capturedAt: Date {
        savedCatchModel?.capturedAt ?? Date()
    }

    init(
        image: UIImage?,
        segmentedFishes: [SegmentedFish],
        locationMetadata: CatchLocationMetadata?,
        shouldPromptLocationSettings: Bool
    ) {
        self.image = image
        self.locationMetadata = locationMetadata
        self.showLocationSettingsAlert = shouldPromptLocationSettings
        let primarySegmentedFish = segmentedFishes.max { $0.fish.confidence < $1.fish.confidence }
        self.primaryFish = primarySegmentedFish?.fish

        if let image, let primarySegmentedFish {
            let maskedImages = Self.makeMaskedFishImages(
                image: image,
                maskImage: primarySegmentedFish.maskImage,
                boundingBox: primarySegmentedFish.fish.boundingBox
            )
            self.reviewFishImage = maskedImages.review
            self.savedFishImage = maskedImages.saved
        } else {
            self.reviewFishImage = nil
            self.savedFishImage = nil
        }
    }

    func persistCatchIfNeeded(modelContext: ModelContext) -> CatchModel? {
        if let savedCatchModel {
            return savedCatchModel
        }

        let catchModel = makeCatchModel()
        modelContext.insert(catchModel)

        do {
            try modelContext.save()
            savedCatchModel = catchModel
            return catchModel
        } catch {
            print("Failed to save catch: \(error.localizedDescription)")
            return nil
        }
    }

    func shareCatch(modelContext: ModelContext) {
        guard persistCatchIfNeeded(modelContext: modelContext) != nil else { return }
        showShareTemplate = true
    }

    func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(settingsURL) else {
            return
        }

        UIApplication.shared.open(settingsURL)
    }

    private func makeCatchModel() -> CatchModel {
        CatchModel(
            image: savedFishImage ?? image ?? UIImage(),
            species: fishName,
            weight: weightValue,
            length: lengthValue,
            location: locationDisplayText,
            latitude: locationMetadata?.latitude,
            longitude: locationMetadata?.longitude
        )
    }

    private struct PixelImage {
        let pixels: [UInt8]
        let width: Int
        let height: Int
    }

    private static func makeMaskedFishImages(
        image: UIImage,
        maskImage: UIImage,
        boundingBox: CGRect
    ) -> (review: UIImage?, saved: UIImage?) {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return (nil, nil) }
        let canvasWidth = max(1, Int(imageSize.width.rounded()))
        let canvasHeight = max(1, Int(imageSize.height.rounded()))

        guard let imagePixels = rgbaPixels(from: image, width: canvasWidth, height: canvasHeight),
              let maskPixels = rgbaPixels(from: maskImage, width: canvasWidth, height: canvasHeight),
              let maskBounds = alphaBounds(in: maskPixels, width: canvasWidth, height: canvasHeight) else {
            return (nil, nil)
        }

        let paddingX = max(maskBounds.width * 0.08, 6)
        let paddingY = max(maskBounds.height * 0.08, 6)
        let cropRect = maskBounds
            .insetBy(dx: -paddingX, dy: -paddingY)
            .intersection(CGRect(origin: .zero, size: imageSize))
            .integral

        guard cropRect.width > 1, cropRect.height > 1 else { return (nil, nil) }

        guard let fallbackCutout = cutoutPixels(
            imagePixels: imagePixels,
            maskPixels: maskPixels,
            sourceWidth: canvasWidth,
            cropRect: cropRect
        ),
        let maskCutout = cutoutPixels(
            imagePixels: maskPixels,
            maskPixels: maskPixels,
            sourceWidth: canvasWidth,
            cropRect: cropRect
        ) else {
            return (nil, nil)
        }

        let correctedMaskPixels = displayCorrectedPixels(from: maskCutout)
        let cutout = visionForegroundCutout(from: image, boundingBox: boundingBox)
            ?? fallbackCutout
        let correctedPixels = displayCorrectedPixels(from: cutout)
        let reviewPixels = rotateHeadToLeft(
            imagePixels: correctedPixels,
            maskPixels: correctedMaskPixels
        )
        let savedPixels = rotateCounterClockwise(reviewPixels)
        return (makeImage(from: reviewPixels), makeImage(from: savedPixels))
    }

    private static func rgbaPixels(from image: UIImage, width: Int, height: Int) -> [UInt8]? {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        UIGraphicsPushContext(context)
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()

        return pixels
    }

    private static func visionForegroundCutout(
        from image: UIImage,
        boundingBox: CGRect
    ) -> PixelImage? {
        guard #available(iOS 17.0, *),
              let croppedImage = cropImage(image, normalizedBoundingBox: boundingBox),
              let cgImage = croppedImage.cgImage else {
            return nil
        }

        do {
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: cgImagePropertyOrientation(from: croppedImage.imageOrientation),
                options: [:]
            )
            try handler.perform([request])

            guard let observation = request.results?.first else { return nil }
            let outputBuffer = try observation.generateMaskedImage(
                ofInstances: observation.allInstances,
                from: handler,
                croppedToInstancesExtent: true
            )

            return pixelImage(from: outputBuffer)
        } catch {
            return nil
        }
    }

    private static func cgImagePropertyOrientation(
        from imageOrientation: UIImage.Orientation
    ) -> CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: return .up
        case .upMirrored: return .upMirrored
        case .down: return .down
        case .downMirrored: return .downMirrored
        case .left: return .left
        case .leftMirrored: return .leftMirrored
        case .right: return .right
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    private static func cropImage(
        _ image: UIImage,
        normalizedBoundingBox: CGRect
    ) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        let padding: CGFloat = 0.12
        let rawRect = CGRect(
            x: normalizedBoundingBox.minX * imageWidth,
            y: (1 - normalizedBoundingBox.maxY) * imageHeight,
            width: normalizedBoundingBox.width * imageWidth,
            height: normalizedBoundingBox.height * imageHeight
        )
        let paddedRect = rawRect
            .insetBy(dx: -rawRect.width * padding, dy: -rawRect.height * padding)
            .intersection(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
            .integral

        guard paddedRect.width > 1,
              paddedRect.height > 1,
              let croppedCGImage = cgImage.cropping(to: paddedRect) else {
            return nil
        }

        return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private static func pixelImage(from pixelBuffer: CVPixelBuffer) -> PixelImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        let image = UIImage(cgImage: cgImage, scale: 1, orientation: .up)
        let width = max(1, cgImage.width)
        let height = max(1, cgImage.height)
        guard let pixels = rgbaPixels(from: image, width: width, height: height) else {
            return nil
        }

        return PixelImage(pixels: pixels, width: width, height: height)
    }

    private static func alphaBounds(in maskPixels: [UInt8], width: Int, height: Int) -> CGRect? {
        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            for x in 0..<width {
                let alpha = maskPixels[(y * width + x) * 4 + 3]
                guard alpha > 127 else { continue }

                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }

        return CGRect(
            x: CGFloat(minX),
            y: CGFloat(minY),
            width: CGFloat(maxX - minX + 1),
            height: CGFloat(maxY - minY + 1)
        )
    }

    private static func cutoutPixels(
        imagePixels: [UInt8],
        maskPixels: [UInt8],
        sourceWidth: Int,
        cropRect: CGRect
    ) -> PixelImage? {
        let sourceHeight = max(1, imagePixels.count / max(1, sourceWidth * 4))
        let cropX = max(0, Int(cropRect.minX))
        let cropY = max(0, Int(cropRect.minY))
        let cropWidth = max(1, min(Int(cropRect.width), sourceWidth - cropX))
        let cropHeight = max(1, min(Int(cropRect.height), sourceHeight - cropY))
        var outputPixels = [UInt8](repeating: 0, count: cropWidth * cropHeight * 4)

        for y in 0..<cropHeight {
            for x in 0..<cropWidth {
                let sourceOffset = ((cropY + y) * sourceWidth + cropX + x) * 4
                let destinationOffset = (y * cropWidth + x) * 4
                let maskAlpha = refinedMaskAlpha(
                    in: maskPixels,
                    sourceWidth: sourceWidth,
                    sourceHeight: sourceHeight,
                    x: cropX + x,
                    y: cropY + y
                )

                guard maskAlpha > 8 else { continue }

                outputPixels[destinationOffset] = UInt8((UInt16(imagePixels[sourceOffset]) * UInt16(maskAlpha)) / 255)
                outputPixels[destinationOffset + 1] = UInt8((UInt16(imagePixels[sourceOffset + 1]) * UInt16(maskAlpha)) / 255)
                outputPixels[destinationOffset + 2] = UInt8((UInt16(imagePixels[sourceOffset + 2]) * UInt16(maskAlpha)) / 255)
                outputPixels[destinationOffset + 3] = maskAlpha
            }
        }

        return PixelImage(pixels: outputPixels, width: cropWidth, height: cropHeight)
    }

    private static func refinedMaskAlpha(
        in maskPixels: [UInt8],
        sourceWidth: Int,
        sourceHeight: Int,
        x: Int,
        y: Int
    ) -> UInt8 {
        let centerOffset = (y * sourceWidth + x) * 4
        guard maskPixels.indices.contains(centerOffset + 3),
              maskPixels[centerOffset + 3] > 127 else {
            return 0
        }

        var coveredSamples = 0
        var alphaTotal = 0
        let radius = 2
        let totalSamples = (radius * 2 + 1) * (radius * 2 + 1)

        for sampleY in max(0, y - radius)...min(sourceHeight - 1, y + radius) {
            for sampleX in max(0, x - radius)...min(sourceWidth - 1, x + radius) {
                let sampleOffset = (sampleY * sourceWidth + sampleX) * 4 + 3
                let alpha = maskPixels[sampleOffset]
                guard alpha > 127 else { continue }

                coveredSamples += 1
                alphaTotal += Int(alpha)
            }
        }

        guard coveredSamples >= 13 else { return 0 }
        guard coveredSamples < totalSamples else { return maskPixels[centerOffset + 3] }

        let averageAlpha = Double(alphaTotal) / Double(coveredSamples)
        let coverage = Double(coveredSamples) / Double(totalSamples)
        let featheredAlpha = averageAlpha * pow(coverage, 1.35)
        return UInt8(max(0, min(255, Int(featheredAlpha.rounded()))))
    }

    private static func makeImage(from pixelImage: PixelImage) -> UIImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let data = Data(pixelImage.pixels)
        guard let provider = CGDataProvider(data: data as CFData),
              let cgImage = CGImage(
                width: pixelImage.width,
                height: pixelImage.height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: pixelImage.width * 4,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    private static func displayCorrectedPixels(from pixelImage: PixelImage) -> PixelImage {
        flipVertically(reviewDisplayPixels(from: pixelImage))
    }

    private static func rotateHeadToLeft(imagePixels: PixelImage, maskPixels: PixelImage) -> PixelImage {
        guard let maskImage = makeImage(from: maskPixels),
              let analysis = FishMaskOrientationAnalyzer.analyze(maskImage: maskImage) else {
            return imagePixels
        }

        return rotate(imagePixels, radians: analysis.rotationToHeadLeftRadians)
    }

    private static func reviewDisplayPixels(from pixelImage: PixelImage) -> PixelImage {
        guard pixelImage.height > pixelImage.width else { return pixelImage }
        return rotateClockwise(pixelImage)
    }

    private static func flipVertically(_ pixelImage: PixelImage) -> PixelImage {
        var flippedPixels = [UInt8](repeating: 0, count: pixelImage.pixels.count)

        for y in 0..<pixelImage.height {
            let sourceRowStart = y * pixelImage.width * 4
            let destinationRowStart = (pixelImage.height - 1 - y) * pixelImage.width * 4
            let rowLength = pixelImage.width * 4

            flippedPixels.replaceSubrange(
                destinationRowStart..<(destinationRowStart + rowLength),
                with: pixelImage.pixels[sourceRowStart..<(sourceRowStart + rowLength)]
            )
        }

        return PixelImage(pixels: flippedPixels, width: pixelImage.width, height: pixelImage.height)
    }

    private static func rotateClockwise(_ pixelImage: PixelImage) -> PixelImage {
        let rotatedWidth = pixelImage.height
        let rotatedHeight = pixelImage.width
        var rotatedPixels = [UInt8](repeating: 0, count: pixelImage.pixels.count)

        for y in 0..<pixelImage.height {
            for x in 0..<pixelImage.width {
                let sourceOffset = (y * pixelImage.width + x) * 4
                let destinationX = pixelImage.height - 1 - y
                let destinationY = x
                let destinationOffset = (destinationY * rotatedWidth + destinationX) * 4

                rotatedPixels[destinationOffset] = pixelImage.pixels[sourceOffset]
                rotatedPixels[destinationOffset + 1] = pixelImage.pixels[sourceOffset + 1]
                rotatedPixels[destinationOffset + 2] = pixelImage.pixels[sourceOffset + 2]
                rotatedPixels[destinationOffset + 3] = pixelImage.pixels[sourceOffset + 3]
            }
        }

        return PixelImage(pixels: rotatedPixels, width: rotatedWidth, height: rotatedHeight)
    }

    private static func rotateCounterClockwise(_ pixelImage: PixelImage) -> PixelImage {
        let rotatedWidth = pixelImage.height
        let rotatedHeight = pixelImage.width
        var rotatedPixels = [UInt8](repeating: 0, count: pixelImage.pixels.count)

        for y in 0..<pixelImage.height {
            for x in 0..<pixelImage.width {
                let sourceOffset = (y * pixelImage.width + x) * 4
                let destinationX = y
                let destinationY = pixelImage.width - 1 - x
                let destinationOffset = (destinationY * rotatedWidth + destinationX) * 4

                rotatedPixels[destinationOffset] = pixelImage.pixels[sourceOffset]
                rotatedPixels[destinationOffset + 1] = pixelImage.pixels[sourceOffset + 1]
                rotatedPixels[destinationOffset + 2] = pixelImage.pixels[sourceOffset + 2]
                rotatedPixels[destinationOffset + 3] = pixelImage.pixels[sourceOffset + 3]
            }
        }

        return PixelImage(pixels: rotatedPixels, width: rotatedWidth, height: rotatedHeight)
    }

    private static func rotate(_ pixelImage: PixelImage, radians: CGFloat) -> PixelImage {
        guard abs(radians) > 0.01 else { return pixelImage }

        let cosValue = cos(radians)
        let sinValue = sin(radians)
        let sourceCenter = CGPoint(
            x: CGFloat(pixelImage.width - 1) / 2,
            y: CGFloat(pixelImage.height - 1) / 2
        )
        let corners = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: CGFloat(pixelImage.width - 1), y: 0),
            CGPoint(x: 0, y: CGFloat(pixelImage.height - 1)),
            CGPoint(x: CGFloat(pixelImage.width - 1), y: CGFloat(pixelImage.height - 1))
        ].map { point in
            rotatePoint(
                CGPoint(x: point.x - sourceCenter.x, y: point.y - sourceCenter.y),
                cosValue: cosValue,
                sinValue: sinValue
            )
        }

        guard let minX = corners.map(\.x).min(),
              let maxX = corners.map(\.x).max(),
              let minY = corners.map(\.y).min(),
              let maxY = corners.map(\.y).max() else {
            return pixelImage
        }

        let rotatedWidth = max(1, Int(ceil(maxX - minX)) + 1)
        let rotatedHeight = max(1, Int(ceil(maxY - minY)) + 1)
        var rotatedPixels = [UInt8](repeating: 0, count: rotatedWidth * rotatedHeight * 4)

        for destinationY in 0..<rotatedHeight {
            for destinationX in 0..<rotatedWidth {
                let rotatedPoint = CGPoint(
                    x: CGFloat(destinationX) + minX,
                    y: CGFloat(destinationY) + minY
                )
                let sourceRelativePoint = rotatePoint(
                    rotatedPoint,
                    cosValue: cosValue,
                    sinValue: -sinValue
                )
                let sourceX = Int(round(sourceRelativePoint.x + sourceCenter.x))
                let sourceY = Int(round(sourceRelativePoint.y + sourceCenter.y))

                guard sourceX >= 0,
                      sourceX < pixelImage.width,
                      sourceY >= 0,
                      sourceY < pixelImage.height else {
                    continue
                }

                let sourceOffset = (sourceY * pixelImage.width + sourceX) * 4
                let destinationOffset = (destinationY * rotatedWidth + destinationX) * 4
                rotatedPixels[destinationOffset] = pixelImage.pixels[sourceOffset]
                rotatedPixels[destinationOffset + 1] = pixelImage.pixels[sourceOffset + 1]
                rotatedPixels[destinationOffset + 2] = pixelImage.pixels[sourceOffset + 2]
                rotatedPixels[destinationOffset + 3] = pixelImage.pixels[sourceOffset + 3]
            }
        }

        return PixelImage(pixels: rotatedPixels, width: rotatedWidth, height: rotatedHeight)
    }

    private static func rotatePoint(_ point: CGPoint, cosValue: CGFloat, sinValue: CGFloat) -> CGPoint {
        CGPoint(
            x: cosValue * point.x - sinValue * point.y,
            y: sinValue * point.x + cosValue * point.y
        )
    }
}
