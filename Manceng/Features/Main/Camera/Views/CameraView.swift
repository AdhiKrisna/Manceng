//
//  CameraView.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 10/06/26.
//

import SwiftUI
import ARKit

struct CameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = CameraViewModel()
    @AppStorage("hasSeenCameraGuide") private var hasSeenCameraGuide = false
    @State private var showCameraGuide = false
    @State private var shouldShowARCoaching = true
    @State private var arCoachingTask: Task<Void, Never>?

    /// Dipanggil saat user menekan Save di review — hasil tangkapan dikirim ke beranda.
    var onSave: (CatchModel) -> Void = { _ in }

    var body: some View {
        ZStack {
            if viewModel.cameraPermissionState.canUseCamera {
                ARCameraContainer(
                    service: viewModel.arService,
                    isCoachingVisible: shouldShowARCoaching && !showCameraGuide
                )
                    .ignoresSafeArea()

                Color.black.opacity(0.18)
                    .ignoresSafeArea()

            } else {
                permissionBackground
            }

            VStack {
                topControls

                if viewModel.cameraPermissionState.canUseCamera {
                    Spacer()
                    bottomControls
                } else {
                    Spacer()
                    permissionControls
                    Spacer()
                }
            }
            .padding(.horizontal, 20)

            if viewModel.cameraPermissionState.canUseCamera,
               viewModel.arService.isARReady,
               !shouldShowARCoaching,
               !showCameraGuide {
                centerInstruction
            }

            if showCameraGuide, viewModel.cameraPermissionState.canUseCamera {
                CameraGuideView(isPresented: $showCameraGuide)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showCameraGuide)
        .navigationBarBackButtonHidden()
        .fullScreenCover(isPresented: $viewModel.showReview) {
            CatchReviewView(
                image: viewModel.capturedImage,
                segmentedFishes: viewModel.segmentedFishes,
                locationMetadata: viewModel.capturedLocation,
                onRetake: viewModel.retry,
                onSave: onSave
            )
        }
        .onDisappear {
            arCoachingTask?.cancel()
            viewModel.stopScanning()
            viewModel.arService.stop()
        }
        .task {
            await viewModel.prepareCameraPermission()
        }
        .task(id: viewModel.cameraPermissionState) {
            if viewModel.cameraPermissionState.canUseCamera {
                presentCameraGuideIfNeeded()
                if !showCameraGuide {
                    startARCoachingGate()
                }
                await viewModel.startScanning()
            } else {
                arCoachingTask?.cancel()
                shouldShowARCoaching = true
                viewModel.stopScanning()
                viewModel.arService.stop()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.refreshPermissionState()
                if viewModel.cameraPermissionState.canUseCamera, !viewModel.arService.isARReady {
                    startARCoachingGate()
                }
            }
        }
        .onChange(of: showCameraGuide) { _, isPresented in
            viewModel.setScanningPaused(isPresented)
            if !isPresented, viewModel.cameraPermissionState.canUseCamera {
                startARCoachingGate()
            }
        }
        .alert("Permission kamera belum ada", isPresented: $viewModel.showPermissionAlert) {
            Button("Settings") {
                viewModel.openSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Aktifkan akses Camera di Settings supaya fitur capture dan segmentation bisa dipakai.")
        }
    }

    private var topControls: some View {
        HStack {
            CircleIconButton(systemName: "chevron.left") { dismiss() }

            Spacer()

            CircleIconButton(systemName: "info") {
                viewModel.setScanningPaused(true)
                showCameraGuide = true
            }
        }
    }

    private func presentCameraGuideIfNeeded() {
        guard !hasSeenCameraGuide else { return }
        hasSeenCameraGuide = true
        viewModel.setScanningPaused(true)
        showCameraGuide = true
    }

    private func startARCoachingGate() {
        arCoachingTask?.cancel()
        shouldShowARCoaching = true

        arCoachingTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)

            while !viewModel.arService.isARReady, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 120_000_000)
            }

            guard !Task.isCancelled else { return }
            shouldShowARCoaching = false
        }
    }

    private var centerInstruction: some View {
        Text(viewModel.centerInstructionText)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(radius: 4)
    }

    private var permissionBackground: some View {
        LinearGradient(
            colors: [Color.black, Color.brandBlue.opacity(0.92)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var permissionControls: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.white)

            Text("Camera access needed")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Text("Allow camera access to open AR measurement and fish detection.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.82))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Button {
                Task {
                    if viewModel.cameraPermissionState == .notDetermined {
                        await viewModel.requestCameraPermission()
                    } else {
                        viewModel.openSettings()
                    }
                }
            } label: {
                Text(viewModel.cameraPermissionState == .notDetermined ? "Allow Camera" : "Open Settings")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 16) {
            if let errorMessage = viewModel.errorMessage ?? viewModel.arService.sessionErrorMessage {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.red.opacity(0.7), in: Capsule())
            }

            Button {
                Task {
                    await viewModel.capture()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(viewModel.canCapture && !viewModel.isCapturing ? Color.black : Color.white.opacity(0.55))
                        .frame(width: 64, height: 64)

                    Circle()
                        .stroke(Color.white.opacity(0.82), lineWidth: 3)
                        .frame(width: 76, height: 76)

                    if viewModel.isCapturing {
                        ProgressView()
                            .tint(.black)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canCapture || viewModel.isCapturing)
        }
    }
}

private struct ARCameraContainer: UIViewRepresentable {
    @ObservedObject var service: ARMeasurementService
    let isCoachingVisible: Bool
    private static let coachingOverlayTag = 618

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.backgroundColor = .black
        service.attach(sceneView: view)

        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.tag = Self.coachingOverlayTag
        coachingOverlay.session = view.session
        coachingOverlay.goal = .tracking
        coachingOverlay.activatesAutomatically = false
        coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(coachingOverlay)
        NSLayoutConstraint.activate([
            coachingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            coachingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            coachingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            coachingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        coachingOverlay.isHidden = !isCoachingVisible
        coachingOverlay.setActive(isCoachingVisible, animated: false)

        service.start()
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        guard let coachingOverlay = uiView.viewWithTag(Self.coachingOverlayTag) as? ARCoachingOverlayView else {
            return
        }

        coachingOverlay.isHidden = !isCoachingVisible
        coachingOverlay.setActive(isCoachingVisible, animated: true)
    }
}

#Preview {
    CameraView()
}
