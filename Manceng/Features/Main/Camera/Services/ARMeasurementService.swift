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

    func attach(sceneView: ARSCNView) {
        self.sceneView = sceneView
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.scene = SCNScene()
    }

    func start() {
        guard let sceneView else {
            trackingStateText = "Camera view not ready"
            isARReady = false
            return
        }

        guard !isSessionRunning else { return }
        guard ARWorldTrackingConfiguration.isSupported else {
            trackingStateText = "AR not supported"
            isARReady = false
            sessionErrorMessage = "This device does not support ARKit world tracking."
            return
        }

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        sessionErrorMessage = nil
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isSessionRunning = true
    }

    func stop() {
        sceneView?.session.pause()
        isSessionRunning = false
        isARReady = false
        hasDetectedPlane = false
    }

    func captureImage() -> UIImage? {
        sceneView?.snapshot()
    }

    // MARK: - Measurement

    func estimateLengthCm(for boundingBox: CGRect, imageSize: CGSize) -> Double? {
        if let arLength = raycastLengthCm(for: boundingBox, imageSize: imageSize) {
            isUsingFallbackMeasurement = false
            return arLength
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

        if boundingBox.width >= boundingBox.height {
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
              let first = worldPosition(from: firstPoint, in: sceneView),
              let second = worldPosition(from: secondPoint, in: sceneView) else {
            return nil
        }

        let lengthMeters = simd_distance(first, second)
        guard lengthMeters.isFinite, lengthMeters > 0.01, lengthMeters < 2.5 else { return nil }
        return Double(lengthMeters) * 100
    }

    private func worldPosition(from point: CGPoint, in sceneView: ARSCNView) -> SIMD3<Float>? {
        if let query = sceneView.raycastQuery(from: point, allowing: .existingPlaneInfinite, alignment: .any),
           let result = sceneView.session.raycast(query).first {
            let t = result.worldTransform
            return SIMD3<Float>(t.columns.3.x, t.columns.3.y, t.columns.3.z)
        }

        if let query = sceneView.raycastQuery(from: point, allowing: .existingPlaneGeometry, alignment: .any),
           let result = sceneView.session.raycast(query).first {
            let t = result.worldTransform
            return SIMD3<Float>(t.columns.3.x, t.columns.3.y, t.columns.3.z)
        }

        return nil
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

    private func planeDetectionState(from frame: ARFrame) -> (hasPlane: Bool, distance: Double?) {
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

    private func guidance(for trackingState: ARCamera.TrackingState, hasPlane: Bool, distance: Double?) -> String {
        switch trackingState {
        case .notAvailable:
            return "Move iPhone to start"
        case .limited(let reason):
            switch reason {
            case .excessiveMotion:
                return "Move iPhone more slowly"
            case .insufficientFeatures:
                return "Find a nearby surface to measure"
            case .initializing:
                return "Move iPhone to start"
            case .relocalizing:
                return "Keep moving iPhone"
            @unknown default:
                return "Move iPhone to improve tracking"
            }
        case .normal:
            guard hasPlane else {
                return "Find a nearby surface to measure"
            }

            if let distance {
                if distance < 0.18 {
                    return "Move further away"
                }
                if distance > 1.4 {
                    return "Move closer"
                }
            }

            return "1 fish only\nHead must face left"
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

        Task { @MainActor in
            let planeState = self.planeDetectionState(from: frame)
            self.hasDetectedPlane = planeState.hasPlane
            self.distanceMeters = planeState.distance
            self.measurementGuidance = self.guidance(
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

            let distanceIsUsable = planeState.distance.map { distance in
                distance >= 0.18 && distance <= 1.4
            } ?? true

            self.isARReady = trackingIsNormal && planeState.hasPlane && distanceIsUsable
            self.trackingStateText = self.isARReady ? "AR On" : "AR Off"
            if self.isARReady {
                self.sessionErrorMessage = nil
            }
            self.focalLengthPixels = fx
            self.focalLengthYPixels = fy
            self.cameraImageResolution = imageRes
        }
    }
}
