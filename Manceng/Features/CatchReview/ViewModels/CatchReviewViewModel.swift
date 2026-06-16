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
            maskImage: segmentedFish.maskImage,
            boundingBox: segmentedFish.fish.boundingBox
        )
    }

    init(image: UIImage?, segmentedFishes: [SegmentedFish]) {
        self.image = image
        self.segmentedFishes = segmentedFishes
    }

    private static func makeMaskedFishImage(
        image: UIImage,
        maskImage: UIImage,
        boundingBox: CGRect
    ) -> UIImage? {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return nil }

        let fishRect = CGRect(
            x: boundingBox.minX * imageSize.width,
            y: (1 - boundingBox.maxY) * imageSize.height,
            width: boundingBox.width * imageSize.width,
            height: boundingBox.height * imageSize.height
        )

        let paddingX = fishRect.width * 0.22
        let paddingY = fishRect.height * 0.22
        let cropRect = CGRect(
            x: max(0, fishRect.minX - paddingX),
            y: max(0, fishRect.minY - paddingY),
            width: min(imageSize.width, fishRect.maxX + paddingX) - max(0, fishRect.minX - paddingX),
            height: min(imageSize.height, fishRect.maxY + paddingY) - max(0, fishRect.minY - paddingY)
        ).integral

        guard cropRect.width > 1, cropRect.height > 1 else { return nil }

        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = image.scale
        rendererFormat.opaque = false

        return UIGraphicsImageRenderer(size: cropRect.size, format: rendererFormat).image { context in
            let fullImageRect = CGRect(
                x: -cropRect.minX,
                y: -cropRect.minY,
                width: imageSize.width,
                height: imageSize.height
            )

            image.draw(in: fullImageRect)
            context.cgContext.setBlendMode(.destinationIn)
            maskImage.draw(in: fullImageRect)
        }
    }
}
