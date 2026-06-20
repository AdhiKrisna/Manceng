//
//  FishMaskOrientationAnalyzer.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 18/06/26.
//

import UIKit
import CoreGraphics

enum FishMaskOrientationAnalyzer {
    struct Analysis {
        let headClockPosition: Int
        let rotationToHeadLeftRadians: CGFloat

        var isHeadAllowedForCapture: Bool {
            headClockPosition == 12 || (6...11).contains(headClockPosition)
        }
    }

    static func isHeadLeftTailRight(maskImage: UIImage) -> Bool {
        analyze(maskImage: maskImage)?.headClockPosition == 9
    }

    static func analyze(maskImage: UIImage) -> Analysis? {
        guard let mask = maskData(from: maskImage),
              let bounds = alphaBounds(in: mask.pixels, width: mask.width, height: mask.height) else {
            return nil
        }

        return analyze(mask: mask, bounds: bounds)
    }

    private static func analyze(mask: MaskData, bounds: CGRect) -> Analysis? {
        if let edgeAnalysis = edgeAlignedAnalysis(mask: mask, bounds: bounds) {
            return edgeAnalysis
        }

        var points: [CGPoint] = []
        points.reserveCapacity(Int(bounds.width * bounds.height))

        for y in Int(bounds.minY)..<Int(bounds.maxY) {
            for x in Int(bounds.minX)..<Int(bounds.maxX) {
                let alpha = mask.pixels[(y * mask.width + x) * 4 + 3]
                guard alpha > 127 else { continue }
                points.append(CGPoint(x: x, y: y))
            }
        }

        guard points.count > 12 else { return nil }

        let count = CGFloat(points.count)
        let center = points.reduce(CGPoint.zero) { partial, point in
            CGPoint(x: partial.x + point.x, y: partial.y + point.y)
        }
        .applying(CGAffineTransform(scaleX: 1 / count, y: 1 / count))

        var covarianceXX: CGFloat = 0
        var covarianceXY: CGFloat = 0
        var covarianceYY: CGFloat = 0

        for point in points {
            let dx = point.x - center.x
            let dy = point.y - center.y
            covarianceXX += dx * dx
            covarianceXY += dx * dy
            covarianceYY += dy * dy
        }

        let axisAngle = 0.5 * atan2(2 * covarianceXY, covarianceXX - covarianceYY)
        let axis = CGVector(dx: cos(axisAngle), dy: sin(axisAngle))
        let perpendicular = CGVector(dx: -axis.dy, dy: axis.dx)

        let projections = points.map { point in
            ((point.x - center.x) * axis.dx) + ((point.y - center.y) * axis.dy)
        }

        guard let minProjection = projections.min(),
              let maxProjection = projections.max(),
              maxProjection - minProjection > 8 else {
            return nil
        }

        let minTailScore = tailForkScore(
            points: points,
            center: center,
            axis: axis,
            perpendicular: perpendicular,
            projectionRange: minProjection...(minProjection + (maxProjection - minProjection) * 0.28)
        )
        let maxTailScore = tailForkScore(
            points: points,
            center: center,
            axis: axis,
            perpendicular: perpendicular,
            projectionRange: (maxProjection - (maxProjection - minProjection) * 0.28)...maxProjection
        )

        let headProjection = maxTailScore > minTailScore ? minProjection : maxProjection
        let headPoint = CGPoint(
            x: center.x + axis.dx * headProjection,
            y: center.y + axis.dy * headProjection
        )
        let headVector = CGVector(dx: headPoint.x - center.x, dy: headPoint.y - center.y)
        let headClockPosition = clockPosition(for: headVector)
        let headAngle = atan2(headVector.dy, headVector.dx)
        let rotationToLeft = normalizedSignedRadians(CGFloat.pi - headAngle)

        return Analysis(
            headClockPosition: headClockPosition,
            rotationToHeadLeftRadians: rotationToLeft
        )
    }

    private static func edgeAlignedAnalysis(mask: MaskData, bounds: CGRect) -> Analysis? {
        let aspectRatio = bounds.width / max(bounds.height, 1)
        if aspectRatio >= 1.15 {
            let sampleWidth = max(1, Int(bounds.width / 3))
            let leftRange = Int(bounds.minX)..<min(Int(bounds.minX) + sampleWidth, mask.width)
            let rightRange = max(Int(bounds.maxX) - sampleWidth, 0)..<Int(bounds.maxX)
            let yRange = Int(bounds.minY)..<Int(bounds.maxY)
            let leftScore = tailForkScore(in: mask, xRange: leftRange, yRange: yRange)
            let rightScore = tailForkScore(in: mask, xRange: rightRange, yRange: yRange)

            guard max(leftScore, rightScore) > 0 else { return nil }
            return analysis(headVector: rightScore >= leftScore
                ? CGVector(dx: -1, dy: 0)
                : CGVector(dx: 1, dy: 0)
            )
        }

        if aspectRatio <= 0.87 {
            let sampleHeight = max(1, Int(bounds.height / 3))
            let topRange = Int(bounds.minY)..<min(Int(bounds.minY) + sampleHeight, mask.height)
            let bottomRange = max(Int(bounds.maxY) - sampleHeight, 0)..<Int(bounds.maxY)
            let xRange = Int(bounds.minX)..<Int(bounds.maxX)
            let topScore = tailForkScore(in: mask, yRange: topRange, xRange: xRange)
            let bottomScore = tailForkScore(in: mask, yRange: bottomRange, xRange: xRange)

            guard max(topScore, bottomScore) > 0 else { return nil }
            return analysis(headVector: bottomScore >= topScore
                ? CGVector(dx: 0, dy: -1)
                : CGVector(dx: 0, dy: 1)
            )
        }

        return nil
    }

    private static func analysis(headVector: CGVector) -> Analysis {
        let headClockPosition = clockPosition(for: headVector)
        let headAngle = atan2(headVector.dy, headVector.dx)
        let rotationToLeft = normalizedSignedRadians(CGFloat.pi - headAngle)

        return Analysis(
            headClockPosition: headClockPosition,
            rotationToHeadLeftRadians: rotationToLeft
        )
    }

    private static func clockPosition(for vector: CGVector) -> Int {
        let angle = atan2(vector.dx, -vector.dy)
        let normalizedAngle = angle < 0 ? angle + 2 * CGFloat.pi : angle
        let hour = Int((normalizedAngle / (CGFloat.pi / 6)).rounded()) % 12
        return hour == 0 ? 12 : hour
    }

    private static func normalizedSignedRadians(_ radians: CGFloat) -> CGFloat {
        var normalized = radians
        while normalized > CGFloat.pi {
            normalized -= 2 * CGFloat.pi
        }
        while normalized < -CGFloat.pi {
            normalized += 2 * CGFloat.pi
        }
        return normalized
    }

    private static func tailForkScore(
        points: [CGPoint],
        center: CGPoint,
        axis: CGVector,
        perpendicular: CGVector,
        projectionRange: ClosedRange<CGFloat>
    ) -> Double {
        let slicePerpendiculars = points.compactMap { point -> CGFloat? in
            let dx = point.x - center.x
            let dy = point.y - center.y
            let projection = dx * axis.dx + dy * axis.dy
            guard projectionRange.contains(projection) else { return nil }
            return dx * perpendicular.dx + dy * perpendicular.dy
        }

        guard let minPerpendicular = slicePerpendiculars.min(),
              let maxPerpendicular = slicePerpendiculars.max(),
              maxPerpendicular > minPerpendicular else {
            return 0
        }

        let binCount = 18
        var bins = [Int](repeating: 0, count: binCount)
        for value in slicePerpendiculars {
            let normalized = (value - minPerpendicular) / (maxPerpendicular - minPerpendicular)
            let index = min(binCount - 1, max(0, Int((normalized * CGFloat(binCount - 1)).rounded())))
            bins[index] += 1
        }

        let threshold = max(2, (bins.max() ?? 0) / 5)
        var clusters = 0
        var isInsideCluster = false
        for bin in bins {
            if bin >= threshold, !isInsideCluster {
                clusters += 1
                isInsideCluster = true
            } else if bin < threshold {
                isInsideCluster = false
            }
        }

        let spread = Double(maxPerpendicular - minPerpendicular)
        return spread + Double(clusters) * 18 + Double(slicePerpendiculars.count) * 0.015
    }

    private static func legacyIsHeadLeftTailRight(maskImage: UIImage) -> Bool {
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

    private static func tailForkScore(in mask: MaskData, yRange: Range<Int>, xRange: Range<Int>) -> Double {
        var score: Double = 0

        for y in yRange {
            var segments = 0
            var currentSegmentWidth = 0
            var minX = mask.width
            var maxX = -1

            for x in xRange {
                let alpha = mask.pixels[(y * mask.width + x) * 4 + 3]
                if alpha > 127 {
                    currentSegmentWidth += 1
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                } else if currentSegmentWidth > 0 {
                    if currentSegmentWidth >= 2 {
                        segments += 1
                    }
                    currentSegmentWidth = 0
                }
            }

            if currentSegmentWidth >= 2 {
                segments += 1
            }

            guard maxX >= minX else { continue }

            score += Double(maxX - minX + 1) / Double(max(1, xRange.count))
            if segments >= 2 {
                score += Double(segments) * 4
            }
        }

        return score
    }
}
