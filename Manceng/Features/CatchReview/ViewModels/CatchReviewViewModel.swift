//
//  CatchReviewViewModel.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 15/06/26.
//

import Combine
import UIKit

@MainActor
final class CatchReviewViewModel: ObservableObject {
    let image: UIImage?
    let reviewFishImage: UIImage?
    let savedFishImage: UIImage?
    private let primaryFish: DetectedFish?

    var fishName: String {
        primaryFish?.species ?? "Unfortunately, we couldn't identify this fish"
    }

    var weightText: String {
        weightValue < 1
            ? String(format: "%.2f", weightValue)
            : String(format: "%.1f", weightValue)
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

    init(image: UIImage?, segmentedFishes: [SegmentedFish]) {
        self.image = image
        let primarySegmentedFish = segmentedFishes.max { $0.fish.confidence < $1.fish.confidence }
        self.primaryFish = primarySegmentedFish?.fish

        if let image, let maskImage = primarySegmentedFish?.maskImage {
            let maskedImages = Self.makeMaskedFishImages(image: image, maskImage: maskImage)
            self.reviewFishImage = maskedImages.review
            self.savedFishImage = maskedImages.saved
        } else {
            self.reviewFishImage = nil
            self.savedFishImage = nil
        }
    }

    private struct PixelImage {
        let pixels: [UInt8]
        let width: Int
        let height: Int
    }

    private static func makeMaskedFishImages(
        image: UIImage,
        maskImage: UIImage
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

        guard let cutout = cutoutPixels(
            imagePixels: imagePixels,
            maskPixels: maskPixels,
            sourceWidth: canvasWidth,
            cropRect: cropRect
        ) else {
            return (nil, nil)
        }

        let reviewPixels = displayCorrectedPixels(from: cutout)
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
                let maskAlpha = maskPixels[sourceOffset + 3]

                guard maskAlpha > 127 else { continue }

                outputPixels[destinationOffset] = UInt8((UInt16(imagePixels[sourceOffset]) * UInt16(maskAlpha)) / 255)
                outputPixels[destinationOffset + 1] = UInt8((UInt16(imagePixels[sourceOffset + 1]) * UInt16(maskAlpha)) / 255)
                outputPixels[destinationOffset + 2] = UInt8((UInt16(imagePixels[sourceOffset + 2]) * UInt16(maskAlpha)) / 255)
                outputPixels[destinationOffset + 3] = maskAlpha
            }
        }

        return PixelImage(pixels: outputPixels, width: cropWidth, height: cropHeight)
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
}
