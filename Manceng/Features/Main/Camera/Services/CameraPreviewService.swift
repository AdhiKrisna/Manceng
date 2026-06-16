//
//  CameraPreviewService.swift
//  Manceng
//
//  Created by Codex on 16/06/26.
//

import AVFoundation
import Combine
import CoreImage
import UIKit

final class CameraPreviewService: NSObject, ObservableObject {
    @Published var isCameraReady = false
    @Published var errorMessage: String?

    let session = AVCaptureSession()

    private let videoQueue = DispatchQueue(label: "manceng.camera.video")
    nonisolated(unsafe) private let context = CIContext()
    private let videoOutput = AVCaptureVideoDataOutput()
    nonisolated(unsafe) private let imageLock = NSLock()
    private var isConfigured = false
    nonisolated(unsafe) private var latestImage: UIImage?

    func start() {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            setState(isReady: false, error: "Camera permission needed")
            return
        }

        if !isConfigured {
            configureSession()
        }

        guard isConfigured else { return }

        if !session.isRunning {
            session.startRunning()
        }

        setState(isReady: true, error: nil)
    }

    func stop() {
        if session.isRunning {
            session.stopRunning()
        }

        setState(isReady: false, error: nil)
    }

    func captureImage() -> UIImage? {
        imageLock.lock()
        defer { imageLock.unlock() }
        return latestImage
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        defer {
            session.commitConfiguration()
        }

        do {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(for: .video) else {
                setState(isReady: false, error: "Camera device tidak tersedia")
                return
            }

            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                setState(isReady: false, error: "Camera input tidak bisa dipakai")
                return
            }
            session.addInput(input)

            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            videoOutput.setSampleBufferDelegate(self, queue: videoQueue)

            guard session.canAddOutput(videoOutput) else {
                setState(isReady: false, error: "Camera output tidak bisa dipakai")
                return
            }
            session.addOutput(videoOutput)

            isConfigured = true
        } catch {
            setState(isReady: false, error: error.localizedDescription)
        }
    }

    private func setState(isReady: Bool, error: String?) {
        isCameraReady = isReady
        errorMessage = error
    }
}

extension CameraPreviewService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let image = UIImage(cgImage: cgImage, scale: 1, orientation: .right)

        imageLock.lock()
        latestImage = image
        imageLock.unlock()
    }
}
