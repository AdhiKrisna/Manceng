//
//  ARMeasurementService.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 10/06/26.
//


import Foundation
import ARKit
import Combine
import UIKit

final class ARMeasurementService: NSObject, ObservableObject {
    @Published var trackingStateText = "Move your phone"
    @Published var isARReady = false
    @Published var sessionErrorMessage: String?
    @Published var measurementGuidance = "Move iPhone to find a surface"
    @Published var distanceMeters: Double?
    @Published var isUsingFallbackMeasurement = true

    private weak var sceneView: ARSCNView?
    private var isSessionRunning = false
    /// Focal length in pixels from camera intrinsics — updated every frame
    private var focalLengthPixels: Float?
    private var focalLengthYPixels: Float?
    /// Image resolution reported by the AR camera
    private var cameraImageResolution: CGSize?
    private var hasDetectedPlane = false
    private var shouldSkipProjectedMeasurement = false
    private let minimumMeasurementDistanceMeters: Float = 0.08
    private let maximumMeasurementDistanceMeters: Float = 1.2
    private let framePublishInterval: TimeInterval = 0.2
    private var lastFramePublishTimestamp: TimeInterval = 0
    private var isFramePublishingEnabled = true

    private struct SurfaceHit {
        let position: SIMD3<Float>
        let normal: SIMD3<Float>
        let distanceFromCamera: Float
    }

    private struct WorldRay {
        let origin: SIMD3<Float>
        let direction: SIMD3<Float>
    }

    func attach(sceneView: ARSCNView) {
        self.sceneView = sceneView
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.scene = SCNScene()
    }

    func start() {
        guard let sceneView else {
            publishState { service in
                service.trackingStateText = "Camera view not ready"
                service.isARReady = false
            }
            return
        }

        guard !isSessionRunning else { return }
        guard ARWorldTrackingConfiguration.isSupported else {
            publishState { service in
                service.trackingStateText = "AR not supported"
                service.isARReady = false
                service.sessionErrorMessage = "This device does not support ARKit world tracking."
            }
            return
        }

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        publishState { service in
            service.sessionErrorMessage = nil
        }
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isSessionRunning = true
    }

    func stop() {
        sceneView?.session.pause()
        isSessionRunning = false
        hasDetectedPlane = false
        publishState { service in
            service.isARReady = false
        }
    }

    func setFramePublishingEnabled(_ isEnabled: Bool) {
        isFramePublishingEnabled = isEnabled
    }

    func captureImage() -> UIImage? {
        sceneView?.snapshot()
    }

    // MARK: - Measurement

    func estimateLengthCm(for boundingBox: CGRect, imageSize: CGSize) -> Double? {
        shouldSkipProjectedMeasurement = false

        if let arLength = raycastLengthCm(for: boundingBox, imageSize: imageSize) {
            isUsingFallbackMeasurement = false
            return arLength
        }

        if !shouldSkipProjectedMeasurement,
           let projectedLength = projectedLengthCm(for: boundingBox, imageSize: imageSize) {
            isUsingFallbackMeasurement = false
            return projectedLength
        }

        measurementGuidance = "Find a nearby surface to measure"
        isUsingFallbackMeasurement = true
        return nil
    }

    func estimateWeightKg(lengthCm: Double) -> Double {
        let grams = 0.0200 * pow(lengthCm, 3.0)
        return grams / 1000
    }

    // MARK: - Raycast-based measurement

    private func raycastLengthCm(for boundingBox: CGRect, imageSize: CGSize) -> Double? {
        guard let sceneView else { return nil }

        let displaySize = sceneView.bounds.size
        guard displaySize.width > 0, displaySize.height > 0 else { return nil }

        let imageFrame = aspectFillFrame(imageSize: imageSize, displaySize: displaySize)

        let firstPoint: CGPoint
        let secondPoint: CGPoint
        let centerPoint = CGPoint(
            x: imageFrame.minX + boundingBox.midX * imageFrame.width,
            y: imageFrame.minY + (1 - boundingBox.midY) * imageFrame.height
        )

        let widthPixels = boundingBox.width * imageSize.width
        let heightPixels = boundingBox.height * imageSize.height

        if widthPixels >= heightPixels {
            let minX = imageFrame.minX + boundingBox.minX * imageFrame.width
            let maxX = imageFrame.minX + boundingBox.maxX * imageFrame.width
            let midY = imageFrame.minY + (1 - boundingBox.midY) * imageFrame.height

            firstPoint = CGPoint(x: minX, y: midY)
            secondPoint = CGPoint(x: maxX, y: midY)
        } else {
            let midX = imageFrame.minX + boundingBox.midX * imageFrame.width
            let topY = imageFrame.minY + (1 - boundingBox.maxY) * imageFrame.height
            let bottomY = imageFrame.minY + (1 - boundingBox.minY) * imageFrame.height

            firstPoint = CGPoint(x: midX, y: topY)
            secondPoint = CGPoint(x: midX, y: bottomY)
        }

        guard hasDetectedPlane,
              let surface = surfaceHit(from: centerPoint, in: sceneView),
              let cameraPosition = currentCameraPosition(in: sceneView),
              let firstRay = worldRay(from: firstPoint, in: sceneView),
              let secondRay = worldRay(from: secondPoint, in: sceneView) else {
            return nil
        }

        guard surface.distanceFromCamera >= minimumMeasurementDistanceMeters,
              surface.distanceFromCamera <= maximumMeasurementDistanceMeters else {
            measurementGuidance = surface.distanceFromCamera < minimumMeasurementDistanceMeters
                ? "Move slightly farther from the fish"
                : "Move closer to the fish"
            return nil
        }

        if let firstSurface = surfaceHit(from: firstPoint, in: sceneView),
           let secondSurface = surfaceHit(from: secondPoint, in: sceneView),
           surfaceHitsAreConsistent(center: surface, first: firstSurface, second: secondSurface) {
            let lengthMeters = simd_distance(firstSurface.position, secondSurface.position)
            guard lengthMeters.isFinite, lengthMeters > 0.01, lengthMeters < 1.5 else { return nil }
            return Double(lengthMeters) * 100
        }

        guard let first = intersection(of: firstRay, withPlaneAt: surface.position, normal: surface.normal),
              let second = intersection(of: secondRay, withPlaneAt: surface.position, normal: surface.normal) else {
            return nil
        }

        let endpointDistanceTolerance = max(0.06, surface.distanceFromCamera * 0.16)
        let firstDistanceDelta = abs(simd_distance(cameraPosition, first) - surface.distanceFromCamera)
        let secondDistanceDelta = abs(simd_distance(cameraPosition, second) - surface.distanceFromCamera)
        guard firstDistanceDelta <= endpointDistanceTolerance,
              secondDistanceDelta <= endpointDistanceTolerance else {
            measurementGuidance = "Align the fish on one clear surface"
            return nil
        }

        let lengthMeters = simd_distance(first, second)
        guard lengthMeters.isFinite, lengthMeters > 0.01, lengthMeters < 1.5 else { return nil }
        return Double(lengthMeters) * 100
    }

    private func projectedLengthCm(for boundingBox: CGRect, imageSize: CGSize) -> Double? {
        guard let sceneView,
              let focalLengthPixels,
              let focalLengthYPixels,
              let cameraImageResolution,
              imageSize.width > 0,
              imageSize.height > 0,
              cameraImageResolution.width > 0,
              cameraImageResolution.height > 0 else {
            return nil
        }

        let displaySize = sceneView.bounds.size
        guard displaySize.width > 0, displaySize.height > 0 else { return nil }

        let imageFrame = aspectFillFrame(imageSize: imageSize, displaySize: displaySize)
        let centerPoint = CGPoint(
            x: imageFrame.minX + boundingBox.midX * imageFrame.width,
            y: imageFrame.minY + (1 - boundingBox.midY) * imageFrame.height
        )

        guard hasDetectedPlane,
              let surface = surfaceHit(from: centerPoint, in: sceneView) else {
            return nil
        }

        let distanceMeters = surface.distanceFromCamera
        guard distanceMeters.isFinite,
              distanceMeters >= minimumMeasurementDistanceMeters,
              distanceMeters <= maximumMeasurementDistanceMeters else {
            measurementGuidance = distanceMeters < minimumMeasurementDistanceMeters
                ? "Move slightly farther from the fish"
                : "Move closer to the fish"
            return nil
        }

        let scaledFocalX = Double(focalLengthPixels) * Double(imageSize.width / cameraImageResolution.width)
        let scaledFocalY = Double(focalLengthYPixels) * Double(imageSize.height / cameraImageResolution.height)
        let widthPixels = Double(boundingBox.width * imageSize.width)
        let heightPixels = Double(boundingBox.height * imageSize.height)

        let lengthMeters: Double
        if widthPixels >= heightPixels {
            guard scaledFocalX > 0 else { return nil }
            lengthMeters = widthPixels * Double(distanceMeters) / scaledFocalX
        } else {
            guard scaledFocalY > 0 else { return nil }
            lengthMeters = heightPixels * Double(distanceMeters) / scaledFocalY
        }

        guard lengthMeters.isFinite, lengthMeters > 0.01, lengthMeters < 1.5 else {
            return nil
        }

        return lengthMeters * 100
    }

    private func surfaceHitsAreConsistent(center: SurfaceHit, first: SurfaceHit, second: SurfaceHit) -> Bool {
        let distanceTolerance = max(0.06, center.distanceFromCamera * 0.16)
        let firstDistanceDelta = abs(first.distanceFromCamera - center.distanceFromCamera)
        let secondDistanceDelta = abs(second.distanceFromCamera - center.distanceFromCamera)
        let normalSimilarity = min(
            simd_dot(center.normal, first.normal),
            simd_dot(center.normal, second.normal)
        )

        guard firstDistanceDelta <= distanceTolerance,
              secondDistanceDelta <= distanceTolerance,
              normalSimilarity >= 0.86 else {
            measurementGuidance = "Align the fish on one clear surface"
            shouldSkipProjectedMeasurement = true
            return false
        }

        return true
    }

    private func surfaceHit(from point: CGPoint, in sceneView: ARSCNView) -> SurfaceHit? {
        if let query = sceneView.raycastQuery(from: point, allowing: .existingPlaneGeometry, alignment: .any),
           let result = sceneView.session.raycast(query).first {
            return surfaceHit(from: result, in: sceneView)
        }

        if let query = sceneView.raycastQuery(from: point, allowing: .estimatedPlane, alignment: .any),
           let result = sceneView.session.raycast(query).first {
            return surfaceHit(from: result, in: sceneView)
        }

        return nil
    }

    private func surfaceHit(from result: ARRaycastResult, in sceneView: ARSCNView) -> SurfaceHit? {
        guard let cameraPosition = currentCameraPosition(in: sceneView) else { return nil }

        let transform = result.worldTransform
        let position = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        var normal = SIMD3<Float>(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z)
        let normalLength = simd_length(normal)
        guard normalLength > 0 else { return nil }
        normal /= normalLength

        let distance = simd_distance(cameraPosition, position)
        guard distance.isFinite else { return nil }

        return SurfaceHit(position: position, normal: normal, distanceFromCamera: distance)
    }

    private func currentCameraPosition(in sceneView: ARSCNView) -> SIMD3<Float>? {
        guard let frame = sceneView.session.currentFrame else { return nil }
        let cameraTransform = frame.camera.transform
        return SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
    }

    private func worldRay(from point: CGPoint, in sceneView: ARSCNView) -> WorldRay? {
        let nearPoint = sceneView.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 0))
        let farPoint = sceneView.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 1))
        let origin = SIMD3<Float>(nearPoint.x, nearPoint.y, nearPoint.z)
        let far = SIMD3<Float>(farPoint.x, farPoint.y, farPoint.z)
        var direction = far - origin
        let directionLength = simd_length(direction)
        guard directionLength > 0 else { return nil }
        direction /= directionLength

        return WorldRay(origin: origin, direction: direction)
    }

    private func intersection(
        of ray: WorldRay,
        withPlaneAt planePoint: SIMD3<Float>,
        normal: SIMD3<Float>
    ) -> SIMD3<Float>? {
        let denominator = simd_dot(ray.direction, normal)
        guard abs(denominator) > 0.0001 else { return nil }

        let distance = simd_dot(planePoint - ray.origin, normal) / denominator
        guard distance.isFinite, distance > 0 else { return nil }

        return ray.origin + ray.direction * distance
    }

    // MARK: - Distance estimation

    /// Estimates the distance from camera to the nearest detected surface
    private func updateDistanceFromFrame(_ frame: ARFrame) {
        let camera = frame.camera
        let cameraTransform = camera.transform
        let cameraPosition = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )

        // Find distance to nearest anchor plane
        var minDist: Float = .greatestFiniteMagnitude
        for anchor in frame.anchors {
            guard let plane = anchor as? ARPlaneAnchor else { continue }
            let planePos = SIMD3<Float>(
                plane.transform.columns.3.x,
                plane.transform.columns.3.y,
                plane.transform.columns.3.z
            )
            let dist = simd_distance(cameraPosition, planePos)
            if dist < minDist {
                minDist = dist
            }
        }

        if minDist < .greatestFiniteMagnitude, minDist > 0.05, minDist < 5.0 {
            distanceMeters = Double(minDist)
        }
    }

    nonisolated private func planeDetectionState(from frame: ARFrame) -> (hasPlane: Bool, distance: Double?) {
        let cameraTransform = frame.camera.transform
        let cameraPosition = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )

        var nearestDistance: Float = .greatestFiniteMagnitude
        var hasPlane = false

        for anchor in frame.anchors {
            guard let plane = anchor as? ARPlaneAnchor else { continue }
            hasPlane = true
            let planePosition = SIMD3<Float>(
                plane.transform.columns.3.x,
                plane.transform.columns.3.y,
                plane.transform.columns.3.z
            )
            nearestDistance = min(nearestDistance, simd_distance(cameraPosition, planePosition))
        }

        let distance = nearestDistance < .greatestFiniteMagnitude ? Double(nearestDistance) : nil
        return (hasPlane, distance)
    }

    nonisolated private func guidance(for trackingState: ARCamera.TrackingState, hasPlane: Bool, distance: Double?) -> String {
        switch trackingState {
        case .notAvailable:
            return "Move your phone to start"
        case .limited(let reason):
            switch reason {
            case .excessiveMotion:
                return "Move your phone more slowly"
            case .insufficientFeatures:
                return "Find a nearby surface to measure"
            case .initializing:
                return "Move your phone slowly to start scanning the surface"
            case .relocalizing:
                return "Keep moving your phone to scan the surface"
            @unknown default:
                return "Move your phone to improve tracking"
            }
        case .normal:
            guard hasPlane else {
                return "Place the fish on a flat surface"
            }
            
            return "Keep the fish steady on a clear surface"
        }
    }

    // MARK: - Helpers

    private func aspectFillFrame(imageSize: CGSize, displaySize: CGSize) -> CGRect {
        let scale = max(displaySize.width / imageSize.width, displaySize.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale

        return CGRect(
            x: (displaySize.width - width) / 2,
            y: (displaySize.height - height) / 2,
            width: width,
            height: height
        )
    }

    private func publishState(_ updates: @escaping (ARMeasurementService) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            updates(self)
        }
    }
}

// MARK: - ARSessionDelegate
extension ARMeasurementService: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor in
            self.isSessionRunning = false
            self.isARReady = false
            self.trackingStateText = "AR failed"
            self.sessionErrorMessage = error.localizedDescription
        }
    }

    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor in
            self.isARReady = false
            self.trackingStateText = "AR interrupted"
            self.sessionErrorMessage = "The camera session was interrupted. Please reopen the camera."
        }
    }

    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor in
            self.isSessionRunning = false
            self.sessionErrorMessage = nil
            self.start()
        }
    }

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let intrinsics = frame.camera.intrinsics
        let fx = intrinsics[0][0]
        let fy = intrinsics[1][1]
        let imageRes = frame.camera.imageResolution
        let planeState = planeDetectionState(from: frame)
        let guidanceText = guidance(
            for: frame.camera.trackingState,
            hasPlane: planeState.hasPlane,
            distance: planeState.distance
        )
        let trackingIsNormal: Bool
        if case .normal = frame.camera.trackingState {
            trackingIsNormal = true
        } else {
            trackingIsNormal = false
        }
        let isReady = trackingIsNormal && planeState.hasPlane

        Task { @MainActor in
            self.focalLengthPixels = fx
            self.focalLengthYPixels = fy
            self.cameraImageResolution = imageRes

            guard self.isFramePublishingEnabled else { return }

            let shouldPublish = frame.timestamp - self.lastFramePublishTimestamp >= self.framePublishInterval
                || self.isARReady != isReady
                || self.measurementGuidance != guidanceText
                || self.distanceMeters != planeState.distance
            guard shouldPublish else { return }

            self.lastFramePublishTimestamp = frame.timestamp
            self.hasDetectedPlane = planeState.hasPlane
            self.distanceMeters = planeState.distance
            self.measurementGuidance = guidanceText
            self.isARReady = isReady
            self.trackingStateText = self.isARReady ? "AR On" : "AR Off"
            if self.isARReady {
                self.sessionErrorMessage = nil
            }
        }
    }
}
