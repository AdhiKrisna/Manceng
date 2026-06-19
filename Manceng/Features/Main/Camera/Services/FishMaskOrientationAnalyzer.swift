//
//  FishMaskOrientationAnalyzer.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 18/06/26.
//

import UIKit
import CoreGraphics

enum FishMaskOrientationAnalyzer {
    static func isHeadLeftTailRight(maskImage: UIImage) -> Bool {
        guard let mask = maskData(from: maskImage),
              let bounds = alphaBounds(in: mask.pixels, width: mask.width, height: mask.height) else {
            return false
        }

        guard bounds.width > bounds.height else {
            return false
        }

        let sampleWidth = max(1, Int(bounds.width / 3))
        let leftRange = Int(bounds.minX)..<min(Int(bounds.minX) + sampleWidth, mask.width)
        let rightRange = max(Int(bounds.maxX) - sampleWidth, 0)..<Int(bounds.maxX)
        let leftScore = tailForkScore(in: mask, xRange: leftRange, yRange: Int(bounds.minY)..<Int(bounds.maxY))
        let rightScore = tailForkScore(in: mask, xRange: rightRange, yRange: Int(bounds.minY)..<Int(bounds.maxY))

        return rightScore > leftScore
    }

    private struct MaskData {
        let pixels: [UInt8]
        let width: Int
        let height: Int
    }

    private static func maskData(from image: UIImage) -> MaskData? {
        let width = max(1, Int(image.size.width.rounded()))
        let height = max(1, Int(image.size.height.rounded()))
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

        return MaskData(pixels: pixels, width: width, height: height)
    }

    private static func alphaBounds(in pixels: [UInt8], width: Int, height: Int) -> CGRect? {
        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            for x in 0..<width {
                let alpha = pixels[(y * width + x) * 4 + 3]
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

    private static func tailForkScore(in mask: MaskData, xRange: Range<Int>, yRange: Range<Int>) -> Double {
        var score: Double = 0

        for x in xRange {
            var segments = 0
            var currentSegmentHeight = 0
            var minY = mask.height
            var maxY = -1

            for y in yRange {
                let alpha = mask.pixels[(y * mask.width + x) * 4 + 3]
                if alpha > 127 {
                    currentSegmentHeight += 1
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                } else if currentSegmentHeight > 0 {
                    if currentSegmentHeight >= 2 {
                        segments += 1
                    }
                    currentSegmentHeight = 0
                }
            }

            if currentSegmentHeight >= 2 {
                segments += 1
            }

            guard maxY >= minY else { continue }

            score += Double(maxY - minY + 1) / Double(max(1, yRange.count))
            if segments >= 2 {
                score += Double(segments) * 4
            }
        }

        return score
    }
}
