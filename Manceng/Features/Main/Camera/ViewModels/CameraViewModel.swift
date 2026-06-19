//
//  ViewModel.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 15/06/26.
//

import Foundation
import Combine
import UIKit

@MainActor
final class CameraViewModel: ObservableObject {
    @Published var cameraPermissionState: CameraPermissionState = .notDetermined
    @Published var segmentedFishes: [SegmentedFish] = []
    @Published var scannedImage: UIImage?
    @Published var capturedImage: UIImage?
    @Published var capturedSegmentedFishes: [SegmentedFish] = []
    @Published var capturedLocation: CatchLocationMetadata?
    @Published var shouldPromptLocationSettingsInReview = false
    @Published var showReview = false
    @Published var isScanningFish = false
    @Published var isCapturing = false
    @Published var errorMessage: String?
    @Published var showPermissionAlert = false
    @Published var showUnknownSpeciesAlert = false
    private var isScanningPaused = false

    let arService = ARMeasurementService()
    private let cameraService = CameraService()
    private let permissionService = CameraPermissionService()
    private let catchLocationService = CatchLocationService()
    private let classificationService = FishClassificationService()
    private let weightEstimationService = FishWeightEstimationService()
    private let minimumClassificationConfidence = 0.80
    private let scanIntervalNanoseconds: UInt64 = 900_000_000
    private var scanningTask: Task<Void, Never>?

    var canCapture: Bool {
        cameraPermissionState.canUseCamera &&
        arService.isARReady &&
        !isScanningFish &&
        !isCapturing &&
        hasReliableFishMeasurement &&
        hasValidFishOrientation
    }

    var centerInstructionText: String {
        guard arService.isARReady else {
            return arService.measurementGuidance
        }

        if segmentedFishes.count > 1 {
            return "Only 1 fish can be scanned at a time"
        }

        guard hasReliableFishMeasurement else {
            return "Show 1 fish clearly in view"
        }

        return "Keep the fish head on the left and tail on the right"
    }

    var focusedFishBoundingBox: CGRect? {
        guard segmentedFishes.count == 1 else { return nil }
        return segmentedFishes.first?.fish.boundingBox
    }

    var shouldShowPermissionAlert: Bool {
        cameraPermissionState == .denied || cameraPermissionState == .restricted
    }

    private var hasValidFishOrientation: Bool {
        guard segmentedFishes.count == 1,
              let segmentedFish = segmentedFishes.first else {
            return false
        }

        return FishMaskOrientationAnalyzer.isHeadLeftTailRight(maskImage: segmentedFish.maskImage)
    }

    private var hasReliableFishMeasurement: Bool {
        guard segmentedFishes.count == 1,
              let length = segmentedFishes.first?.fish.estimatedLengthCm else {
            return false
        }

        return length.isFinite && length > 0
    }

    func prepareCameraPermission() async {
        cameraPermissionState = permissionService.currentState()

        if cameraPermissionState == .notDetermined {
            cameraPermissionState = await permissionService.requestAccess()
        }

        showPermissionAlert = shouldShowPermissionAlert
    }

    func requestCameraPermission() async {
        cameraPermissionState = await permissionService.requestAccess()
        showPermissionAlert = shouldShowPermissionAlert
    }

    func refreshPermissionState() {
        cameraPermissionState = permissionService.currentState()
        showPermissionAlert = shouldShowPermissionAlert
    }

    func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(settingsURL) else {
            return
        }

        UIApplication.shared.open(settingsURL)
    }

    func startScanning() async {
        guard cameraPermissionState.canUseCamera else { return }
        guard scanningTask == nil else { return }

        scanningTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                await self.scanCurrentFrame()
                try? await Task.sleep(nanoseconds: self.scanIntervalNanoseconds)
            }
        }

        await scanningTask?.value
        scanningTask = nil
    }

    func stopScanning() {
        scanningTask?.cancel()
        scanningTask = nil
        isScanningFish = false
    }

    func setScanningPaused(_ isPaused: Bool) {
        isScanningPaused = isPaused
        if isPaused {
            isScanningFish = false
        }
    }

    func capture() async {
        guard !isCapturing else { return }
        if let sessionError = arService.sessionErrorMessage {
            errorMessage = sessionError
            return
        }
        guard arService.isARReady else {
            errorMessage = "AR is not ready yet"
            return
        }
        let lockedFishes = segmentedFishes

        guard lockedFishes.count == 1 else {
            errorMessage = segmentedFishes.isEmpty ? "No fish detected yet" : "Make sure only 1 fish is visible"
            return
        }
        guard let lockedFish = lockedFishes.first,
              FishMaskOrientationAnalyzer.isHeadLeftTailRight(maskImage: lockedFish.maskImage) else {
            errorMessage = "Keep the fish head on the left"
            return
        }
        guard (lockedFish.fish.speciesConfidence ?? 0) >= minimumClassificationConfidence else {
            showUnknownSpeciesAlert = true
            return
        }
        guard let image = scannedImage else {
            errorMessage = "Camera is not ready yet"
            return
        }

        isCapturing = true
        isScanningPaused = true
        capturedImage = image
        capturedSegmentedFishes = lockedFishes
        capturedLocation = await catchLocationService.requestCurrentLocation()
        shouldPromptLocationSettingsInReview = catchLocationService.isAuthorizationDenied
        isCapturing = false
        errorMessage = nil
        showReview = true
    }

    func retry() {
        showReview = false
        capturedImage = nil
        capturedSegmentedFishes = []
        capturedLocation = nil
        shouldPromptLocationSettingsInReview = false
        isScanningPaused = false
        isCapturing = false
        errorMessage = nil
        showUnknownSpeciesAlert = false
    }

    private func scanCurrentFrame() async {
        guard cameraPermissionState.canUseCamera,
              arService.isARReady,
              !isScanningFish,
              !isScanningPaused else {
            if !arService.isARReady {
                segmentedFishes = []
                scannedImage = nil
            }
            return
        }

        guard let image = arService.captureImage() else { return }
        isScanningFish = true

        let fishes = await segment(image: image)
        var enriched = fishes
        for index in enriched.indices {
            let classification = await classify(
                image: image,
                boundingBox: enriched[index].fish.boundingBox
            )
            let speciesName = classification?.speciesName ?? "Fish class unavailable"
            let length = arService.estimateLengthCm(
                for: enriched[index].fish.boundingBox,
                imageSize: image.size
            )
            enriched[index].fish.estimatedLengthCm = length
            enriched[index].fish.species = speciesName
            enriched[index].fish.speciesConfidence = classification?.confidence

            if let length {
                enriched[index].fish.estimatedWeightKg =
                    weightEstimationService.estimateWeightKg(speciesName: speciesName, lengthCm: length)
                    ?? arService.estimateWeightKg(lengthCm: length)
            } else {
                enriched[index].fish.estimatedWeightKg = nil
            }
        }

        scannedImage = image
        segmentedFishes = enriched
        isScanningFish = false
    }

    private func segment(image: UIImage) async -> [SegmentedFish] {
        await withCheckedContinuation { continuation in
            cameraService.segment(image: image) { fishes in
                continuation.resume(returning: fishes)
            }
        }
    }

    private func classify(image: UIImage, boundingBox: CGRect) async -> FishClassificationResult? {
        let classificationService = classificationService

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = classificationService.classify(image: image, boundingBox: boundingBox)
                continuation.resume(returning: result)
            }
        }
    }
}
