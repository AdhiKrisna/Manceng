//
//  CameraPermissionService.swift
//  Manceng
//
//  Created by Codex on 15/06/26.
//

import AVFoundation

enum CameraPermissionState: Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted

    var canUseCamera: Bool {
        self == .authorized
    }
}

final class CameraPermissionService {
    func currentState() -> CameraPermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }

    func requestAccess() async -> CameraPermissionState {
        let isGranted = await AVCaptureDevice.requestAccess(for: .video)
        return isGranted ? .authorized : currentState()
    }
}
