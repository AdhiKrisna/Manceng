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
    @Published var capturedLocation: CatchLocationMetadata?
    @Published var showReview = false
    @Published var isScanningFish = false
    @Published var isCapturing = false
    @Published var errorMessage: String?
    @Published var showPermissionAlert = false
    private var isScanningPaused = false

    let arService = ARMeasurementService()
    let locationService = LocationService()
    private let cameraService = CameraService()
    private let permissionService = CameraPermissionService()
    private let catchLocationService = CatchLocationService()
    private let scanIntervalNanoseconds: UInt64 = 900_000_000
    private var scanningTask: Task<Void, Never>?

    var canCapture: Bool {
        cameraPermissionState.canUseCamera && arService.isARReady && hasValidFishOrientation
    }

    var centerInstructionText: String {
        "1 fish only\nHead must face left"
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
            errorMessage = "AR belum On"
            return
        }
        guard segmentedFishes.count == 1 else {
            errorMessage = segmentedFishes.isEmpty ? "Ikan belum terdeteksi" : "Pastikan hanya ada 1 ikan"
            return
        }
        guard hasValidFishOrientation else {
            errorMessage = "Arahkan kepala ikan ke kiri"
            return
        }
        guard let image = scannedImage else {
            errorMessage = "Camera belum siap"
            return
        }

        isCapturing = true
        capturedImage = image
        capturedLocation = await catchLocationService.requestCurrentLocation()
        isCapturing = false
        errorMessage = nil
        showReview = true
    }

    func retry() {
        showReview = false
        capturedImage = nil
        capturedLocation = nil
        isCapturing = false
        errorMessage = nil
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
        scannedImage = image
        isScanningFish = true

        let fishes = await segment(image: image)
        var enriched = fishes
        for index in enriched.indices {
            let length = arService.estimateLengthCm(
                for: enriched[index].fish.boundingBox,
                imageSize: image.size
            )
            enriched[index].fish.estimatedLengthCm = length
            enriched[index].fish.estimatedWeightKg = 0.7
            enriched[index].fish.species = "Catfish"
        }

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
}
