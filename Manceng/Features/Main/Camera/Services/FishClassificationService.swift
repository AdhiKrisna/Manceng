//
//  FishClassificationService.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 19/06/26.
//

import CoreML
import UIKit

struct FishClassificationResult {
    let speciesName: String
    let confidence: Double
}

final class FishClassificationService: @unchecked Sendable {
    private static let minimumConfidence = 0.5
    private static let modelResourceName = "ClassificationModel-V2"
    private static let inputImageSize = 224
    private static let inputPixelFormat = kCVPixelFormatType_32ARGB
    private let model: MLModel?

    init(bundle: Bundle = .main) {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all

        if let compiledURL = bundle.url(forResource: Self.modelResourceName, withExtension: "mlmodelc"),
           let loaded = try? MLModel(contentsOf: compiledURL, configuration: configuration) {
            model = loaded
            return
        }

        if let modelURL = bundle.url(forResource: Self.modelResourceName, withExtension: "mlmodel"),
           let compiledURL = try? MLModel.compileModel(at: modelURL),
           let loaded = try? MLModel(contentsOf: compiledURL, configuration: configuration) {
            model = loaded
            return
        }

        model = nil
        print("[FishClassificationService] \(Self.modelResourceName) was not found in the app bundle")
    }

    func classify(image: UIImage, boundingBox: CGRect) -> FishClassificationResult? {
        guard let model,
              let croppedImage = crop(image: image, boundingBox: boundingBox),
              let cgImage = croppedImage.cgImage,
              let inputValue = try? MLFeatureValue(
                cgImage: cgImage,
                pixelsWide: Self.inputImageSize,
                pixelsHigh: Self.inputImageSize,
                pixelFormatType: Self.inputPixelFormat,
                options: nil
              ).imageBufferValue else {
            return nil
        }

        do {
            let provider = try MLDictionaryFeatureProvider(dictionary: [
                "image": MLFeatureValue(pixelBuffer: inputValue)
            ])
            let output = try model.prediction(from: provider)
            guard let label = output.featureValue(for: "classLabel")?.stringValue
                    ?? output.featureValue(for: "target")?.stringValue else {
                return nil
            }

            let probabilities = output.featureValue(for: "var_930")?.dictionaryValue
                ?? output.featureValue(for: "targetProbability")?.dictionaryValue
            let confidence = probabilities?[label]?.doubleValue ?? 0
            guard confidence >= Self.minimumConfidence else {
                return nil
            }

            return FishClassificationResult(
                speciesName: label,
                confidence: confidence
            )
        } catch {
            print("[FishClassificationService] Classification failed: \(error)")
            return nil
        }
    }

    private func crop(image: UIImage, boundingBox: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        guard imageWidth > 0, imageHeight > 0 else { return nil }

        let paddingRatio: CGFloat = 0.14
        let cropRect = CGRect(
            x: boundingBox.minX * imageWidth,
            y: (1 - boundingBox.maxY) * imageHeight,
            width: boundingBox.width * imageWidth,
            height: boundingBox.height * imageHeight
        )
        .insetBy(
            dx: -boundingBox.width * imageWidth * paddingRatio,
            dy: -boundingBox.height * imageHeight * paddingRatio
        )
        .intersection(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
        .integral

        guard cropRect.width > 1,
              cropRect.height > 1,
              let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return nil
        }

        return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
}
