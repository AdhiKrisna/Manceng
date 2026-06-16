//
//  ViewModel.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 15/06/26.
//

import Foundation
import Combine
import UIKit
import SwiftUI

@MainActor
final class CameraViewModel: ObservableObject {
    @Published var cameraPermissionState: CameraPermissionState = .notDetermined
    @Published var segmentedFishes: [SegmentedFish] = []
    @Published var scannedImage: UIImage?
    @Published var capturedImage: UIImage?
    @Published var showReview = false
    @Published var isProcessing = false
    @Published var isScanningFish = false
    @Published var errorMessage: String?
    @Published var showPermissionAlert = false

    let arService = ARMeasurementService()
    private let cameraService = CameraService()
    private let permissionService = CameraPermissionService()
    private let scanIntervalNanoseconds: UInt64 = 900_000_000
    private var scanningTask: Task<Void, Never>?

    var primaryFish: DetectedFish? {
        segmentedFishes.max { $0.fish.confidence < $1.fish.confidence }?.fish
    }

    var canCapture: Bool {
        cameraPermissionState.canUseCamera && arService.isARReady && segmentedFishes.count == 1 && !isProcessing
    }

    var guidanceText: String {
        if !cameraPermissionState.canUseCamera { return "Camera permission needed" }
        if !arService.isARReady { return "Move your phone" }
        if isScanningFish { return "Scanning fish" }
        if segmentedFishes.count == 1 { return "Capture only 1 fish" }
        if segmentedFishes.isEmpty { return "Find 1 fish" }
        return "Only 1 fish allowed"
    }

    var fishStatusText: String {
        if !arService.isARReady { return "" }
        if segmentedFishes.count == 1 { return "1 fish locked" }
        return "\(segmentedFishes.count) fish detected"
    }

    var permissionStatusText: String {
        switch cameraPermissionState {
        case .authorized:
            return "Camera Allowed"
        case .notDetermined:
            return "Camera Pending"
        case .denied, .restricted:
            return "Camera Blocked"
        }
    }

    var permissionStatusColor: Color {
        cameraPermissionState.canUseCamera ? .green : .red
    }

    var shouldShowPermissionAlert: Bool {
        cameraPermissionState == .denied || cameraPermissionState == .restricted
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

    func capture() {
        guard !isProcessing else { return }
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
        guard let image = arService.captureImage() else {
            errorMessage = "Camera belum siap"
            return
        }

        capturedImage = image
        isProcessing = true
        errorMessage = nil

        cameraService.segment(image: image) { [weak self] fishes in
            Task { @MainActor in
                guard let self else { return }

                var enriched = fishes
                for index in enriched.indices {
                    let length = self.arService.estimateLengthCm(
                        for: enriched[index].fish.boundingBox,
                        imageSize: image.size
                    )
                    enriched[index].fish.estimatedLengthCm = length
                    enriched[index].fish.estimatedWeightKg = 0.7
                    enriched[index].fish.species = "Catfish"
                }

                guard enriched.count == 1 else {
                    self.segmentedFishes = enriched
                    self.isProcessing = false
                    self.errorMessage = enriched.isEmpty ? "Ikan belum terdeteksi" : "Pastikan hanya ada 1 ikan"
                    return
                }

                self.segmentedFishes = enriched
                self.isProcessing = false
                self.showReview = true
            }
        }
    }

    func retry() {
        showReview = false
        capturedImage = nil
        errorMessage = nil
    }

    private func scanCurrentFrame() async {
        guard cameraPermissionState.canUseCamera, arService.isARReady, !isProcessing, !isScanningFish else {
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
