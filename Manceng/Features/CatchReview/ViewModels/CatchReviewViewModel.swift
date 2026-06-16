//
//  CatchReviewViewModel.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 15/06/26.
//

import Foundation
import Combine
import UIKit

@MainActor
final class CatchReviewViewModel: ObservableObject {
    let image: UIImage?
    let segmentedFishes: [SegmentedFish]

    var fishName: String {
        "Catfish"
    }

    var weightText: String {
        String(format: "%.1f kg", weightValue)
    }

    var lengthText: String {
        String(format: "%.0f cm", lengthValue)
    }

    var primaryFish: DetectedFish? {
        primarySegmentedFish?.fish
    }

    var primarySegmentedFish: SegmentedFish? {
        segmentedFishes.max { $0.fish.confidence < $1.fish.confidence }
    }

    var lengthValue: Double {
        primaryFish?.estimatedLengthCm ?? 0
    }

    var weightValue: Double {
        primaryFish?.estimatedWeightKg ?? 0.7
    }

    var maskedFishImage: UIImage? {
        guard let image,
              let segmentedFish = primarySegmentedFish else {
            return nil
        }

        return Self.makeMaskedFishImage(
            image: image,
            maskImage: segmentedFish.maskImage
        )
    }

    init(image: UIImage?, segmentedFishes: [SegmentedFish]) {
        self.image = image
        self.segmentedFishes = segmentedFishes
    }

    private static func makeMaskedFishImage(
        image: UIImage,
        maskImage: UIImage
    ) -> UIImage? {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return nil }
        let canvasWidth = max(1, Int(imageSize.width.rounded()))
        let canvasHeight = max(1, Int(imageSize.height.rounded()))

        guard let imagePixels = rgbaPixels(from: image, width: canvasWidth, height: canvasHeight),
              let maskPixels = rgbaPixels(from: maskImage, width: canvasWidth, height: canvasHeight),
              let maskBounds = alphaBounds(in: maskPixels, width: canvasWidth, height: canvasHeight) else {
            return nil
        }

        let paddingX = max(maskBounds.width * 0.08, 6)
        let paddingY = max(maskBounds.height * 0.08, 6)
        let cropRect = maskBounds
            .insetBy(dx: -paddingX, dy: -paddingY)
            .intersection(CGRect(origin: .zero, size: imageSize))
            .integral

        guard cropRect.width > 1, cropRect.height > 1 else { return nil }

        return cutoutImage(
            imagePixels: imagePixels,
            maskPixels: maskPixels,
            sourceWidth: canvasWidth,
            cropRect: cropRect
        )
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

    private static func cutoutImage(
        imagePixels: [UInt8],
        maskPixels: [UInt8],
        sourceWidth: Int,
        cropRect: CGRect
    ) -> UIImage? {
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

        let orientedOutput = portraitOrientedPixels(
            outputPixels,
            width: cropWidth,
            height: cropHeight
        )
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let data = Data(orientedOutput.pixels)
        guard let provider = CGDataProvider(data: data as CFData),
              let cgImage = CGImage(
                width: orientedOutput.width,
                height: orientedOutput.height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: orientedOutput.width * 4,
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

    private static func portraitOrientedPixels(
        _ pixels: [UInt8],
        width: Int,
        height: Int
    ) -> (pixels: [UInt8], width: Int, height: Int) {
        guard width > height else {
            return (pixels, width, height)
        }

        let rotatedWidth = height
        let rotatedHeight = width
        var rotatedPixels = [UInt8](repeating: 0, count: pixels.count)

        for y in 0..<height {
            for x in 0..<width {
                let sourceOffset = (y * width + x) * 4
                let destinationX = height - 1 - y
                let destinationY = x
                let destinationOffset = (destinationY * rotatedWidth + destinationX) * 4

                rotatedPixels[destinationOffset] = pixels[sourceOffset]
                rotatedPixels[destinationOffset + 1] = pixels[sourceOffset + 1]
                rotatedPixels[destinationOffset + 2] = pixels[sourceOffset + 2]
                rotatedPixels[destinationOffset + 3] = pixels[sourceOffset + 3]
            }
        }

        return (rotatedPixels, rotatedWidth, rotatedHeight)
    }
}
