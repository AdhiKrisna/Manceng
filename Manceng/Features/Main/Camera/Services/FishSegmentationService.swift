//
//  SegmentationService.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 10/06/26.
//

import Foundation
import CoreML
import UIKit

final class FishSegmentationService {
    private let modelSize = 640
    private let maskSize = 160
    private let maskChannels = 32
    private let confidenceThreshold: Float = 0.5
    private let maskThreshold: Float = 0.5

    private let colX1 = 0
    private let colY1 = 1
    private let colX2 = 2
    private let colY2 = 3
    private let colConfidence = 4
    private let colCoeffStart = 6

    private var model: MLModel?
    private let ciContext = CIContext()

    init() {
        setupModel()
    }

    func segment(image: UIImage, completion: @escaping ([SegmentedFish]) -> Void) {
        guard let model else {
            print("[FishSegmentationService] best.mlpackage belum ter-load")
            completion([])
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            guard let input = self.makeModelInput(from: image) else {
                completion([])
                return
            }

            do {
                let provider = try MLDictionaryFeatureProvider(dictionary: [
                    "image": MLFeatureValue(pixelBuffer: input.pixelBuffer)
                ])
                let output = try model.prediction(from: provider)

                var detectionKey: String?
                var prototypeKey: String?

                for name in output.featureNames {
                    guard let array = output.featureValue(for: name)?.multiArrayValue else { continue }

                    if array.shape.count == 3 {
                        detectionKey = name
                    } else if array.shape.count == 4 {
                        prototypeKey = name
                    }
                }

                guard let detectionKey,
                      let prototypeKey,
                      let detections = output.featureValue(for: detectionKey)?.multiArrayValue,
                      let prototypes = output.featureValue(for: prototypeKey)?.multiArrayValue else {
                    print("[FishSegmentationService] Output model bukan format YOLO segmentation")
                    completion([])
                    return
                }

                completion(self.decode(detections: detections, prototypes: prototypes, input: input))
            } catch {
                print("[FishSegmentationService] Segmentasi gagal: \(error)")
                completion([])
            }
        }
    }

    private func setupModel() {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all

        if let compiledURL = Bundle.main.url(forResource: "best", withExtension: "mlmodelc"),
           let loaded = try? MLModel(contentsOf: compiledURL, configuration: configuration) {
            model = loaded
            return
        }

        if let packageURL = Bundle.main.url(forResource: "best", withExtension: "mlpackage"),
           let loaded = try? MLModel(contentsOf: packageURL, configuration: configuration) {
            model = loaded
            return
        }

        print("[FishSegmentationService] best.mlpackage/best.mlmodelc tidak ditemukan di bundle")
    }

    private struct ModelInput {
        let pixelBuffer: CVPixelBuffer
        let originalSize: CGSize
        let scale: CGFloat
        let paddingX: CGFloat
        let paddingY: CGFloat
        let scaledSize: CGSize
    }

    private func makeModelInput(from image: UIImage) -> ModelInput? {
        let originalSize = image.size
        guard originalSize.width > 0, originalSize.height > 0 else { return nil }

        let canvasSize = CGSize(width: modelSize, height: modelSize)
        let scale = min(canvasSize.width / originalSize.width, canvasSize.height / originalSize.height)
        let scaledSize = CGSize(width: originalSize.width * scale, height: originalSize.height * scale)
        let paddingX = (canvasSize.width - scaledSize.width) / 2
        let paddingY = (canvasSize.height - scaledSize.height) / 2
        let drawRect = CGRect(origin: CGPoint(x: paddingX, y: paddingY), size: scaledSize)

        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = 1
        rendererFormat.opaque = true

        let renderedImage = UIGraphicsImageRenderer(size: canvasSize, format: rendererFormat).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: canvasSize))
            image.draw(in: drawRect)
        }

        guard let cgImage = renderedImage.cgImage else { return nil }

        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            modelSize,
            modelSize,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let pixelBuffer else { return nil }
        ciContext.render(CIImage(cgImage: cgImage), to: pixelBuffer)

        return ModelInput(
            pixelBuffer: pixelBuffer,
            originalSize: originalSize,
            scale: scale,
            paddingX: paddingX,
            paddingY: paddingY,
            scaledSize: scaledSize
        )
    }

    private func decode(detections: MLMultiArray, prototypes: MLMultiArray, input: ModelInput) -> [SegmentedFish] {
        let maxDetections = detections.shape[1].intValue
        let detWidth = detections.shape[2].intValue
        guard detWidth >= colCoeffStart + maskChannels else { return [] }

        let detPtr = detections.dataPointer.bindMemory(to: Float32.self, capacity: detections.count)
        let protoPtr = prototypes.dataPointer.bindMemory(to: Float32.self, capacity: prototypes.count)
        let detStrides = detections.strides.map(\.intValue)
        let protoStrides = prototypes.strides.map(\.intValue)

        func det(_ row: Int, _ col: Int) -> Float {
            detPtr[row * detStrides[1] + col * detStrides[2]]
        }

        func proto(_ channel: Int, _ y: Int, _ x: Int) -> Float {
            protoPtr[channel * protoStrides[1] + y * protoStrides[2] + x * protoStrides[3]]
        }

        var results: [SegmentedFish] = []

        for row in 0..<maxDetections {
            let confidence = det(row, colConfidence)
            guard confidence >= confidenceThreshold else { continue }

            var x1 = CGFloat(det(row, colX1))
            var y1 = CGFloat(det(row, colY1))
            var x2 = CGFloat(det(row, colX2))
            var y2 = CGFloat(det(row, colY2))

            if max(x1, y1, x2, y2) <= 1.5 {
                x1 *= CGFloat(modelSize)
                y1 *= CGFloat(modelSize)
                x2 *= CGFloat(modelSize)
                y2 *= CGFloat(modelSize)
            }

            let modelRect = CGRect(
                x: min(x1, x2),
                y: min(y1, y2),
                width: abs(x2 - x1),
                height: abs(y2 - y1)
            )

            let clampedRect = CGRect(
                x: max(0, modelRect.minX),
                y: max(0, modelRect.minY),
                width: min(CGFloat(modelSize), modelRect.maxX) - max(0, modelRect.minX),
                height: min(CGFloat(modelSize), modelRect.maxY) - max(0, modelRect.minY)
            )
            guard clampedRect.width > 2, clampedRect.height > 2 else { continue }

            let originalRect = modelRectToOriginalRect(clampedRect, input: input)
            guard originalRect.width > 2, originalRect.height > 2 else { continue }

            let coefficients = (0..<maskChannels).map { det(row, colCoeffStart + $0) }
            guard let maskImage = makeMaskImage(
                coefficients: coefficients,
                bboxInModelSpace: clampedRect,
                prototypes: proto,
                input: input
            ) else { continue }

            let normalizedRect = CGRect(
                x: originalRect.minX / input.originalSize.width,
                y: 1 - (originalRect.maxY / input.originalSize.height),
                width: originalRect.width / input.originalSize.width,
                height: originalRect.height / input.originalSize.height
            )

            let fish = DetectedFish(
                boundingBox: normalizedRect,
                confidence: confidence,
                estimatedLengthCm: nil,
                estimatedWeightKg: nil,
                species: "Catfish"
            )
            results.append(SegmentedFish(fish: fish, maskImage: maskImage))
        }

        return results
    }

    private func modelRectToOriginalRect(_ rect: CGRect, input: ModelInput) -> CGRect {
        let minX = clamp((rect.minX - input.paddingX) / input.scale, min: 0, max: input.originalSize.width)
        let minY = clamp((rect.minY - input.paddingY) / input.scale, min: 0, max: input.originalSize.height)
        let maxX = clamp((rect.maxX - input.paddingX) / input.scale, min: 0, max: input.originalSize.width)
        let maxY = clamp((rect.maxY - input.paddingY) / input.scale, min: 0, max: input.originalSize.height)

        return CGRect(x: minX, y: minY, width: max(0, maxX - minX), height: max(0, maxY - minY))
    }

    private func makeMaskImage(
        coefficients: [Float],
        bboxInModelSpace: CGRect,
        prototypes: (_ channel: Int, _ y: Int, _ x: Int) -> Float,
        input: ModelInput
    ) -> UIImage? {
        var pixels = [UInt8](repeating: 0, count: maskSize * maskSize * 4)

        let minX = max(0, Int(floor(bboxInModelSpace.minX / 4)))
        let minY = max(0, Int(floor(bboxInModelSpace.minY / 4)))
        let maxX = min(maskSize - 1, Int(ceil(bboxInModelSpace.maxX / 4)))
        let maxY = min(maskSize - 1, Int(ceil(bboxInModelSpace.maxY / 4)))

        for y in minY...maxY {
            for x in minX...maxX {
                var logit: Float = 0
                for channel in 0..<maskChannels {
                    logit += coefficients[channel] * prototypes(channel, y, x)
                }

                let probability = 1 / (1 + exp(-logit))
                guard probability >= maskThreshold else { continue }

                let offset = (y * maskSize + x) * 4
                pixels[offset] = 78
                pixels[offset + 1] = 190
                pixels[offset + 2] = 255
                // Make the mask solid (alpha 255) where the fish is detected
                pixels[offset + 3] = 255
            }
        }

        guard let maskCGImage = makeCGImage(fromRGBA: pixels, width: maskSize, height: maskSize) else {
            return nil
        }

        let contentRect = CGRect(
            x: input.paddingX / 4,
            y: input.paddingY / 4,
            width: input.scaledSize.width / 4,
            height: input.scaledSize.height / 4
        ).integral

        guard let croppedMask = maskCGImage.cropping(to: contentRect) else { return nil }

        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = 1
        rendererFormat.opaque = false
        return UIGraphicsImageRenderer(size: input.originalSize, format: rendererFormat).image { _ in
            UIImage(cgImage: croppedMask).draw(in: CGRect(origin: .zero, size: input.originalSize))
        }
    }

    private func makeCGImage(fromRGBA pixels: [UInt8], width: Int, height: Int) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let data = Data(pixels)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    private func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minValue), maxValue)
    }
}
