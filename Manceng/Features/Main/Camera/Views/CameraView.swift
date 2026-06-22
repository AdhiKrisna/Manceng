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
    
    /// Dipanggil saat user menekan Save di review — hasil tangkapan dikirim ke beranda.
    var onSave: (CatchModel) -> Void = { _ in }

    var body: some View {
        ZStack {
            if viewModel.cameraPermissionState.canUseCamera {
                ARCameraContainer(
                    service: viewModel.arService,
                    isCoachingVisible: viewModel.isARCoachingVisible
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
               !viewModel.shouldShowARCoaching,
               !viewModel.showCameraGuide,
               !viewModel.isCapturing,
               !viewModel.canCapture {
                centerInstruction
            }

            if viewModel.cameraPermissionState.canUseCamera,
               viewModel.isCapturing {
                captureScanningMessage
            }

            if viewModel.cameraPermissionState.canUseCamera,
               !viewModel.shouldShowARCoaching,
               !viewModel.showCameraGuide,
               let imageSize = viewModel.scannedImage?.size,
               let boundingBox = viewModel.focusedFishBoundingBox {
                FishScanCornerGuide(
                    boundingBox: boundingBox,
                    imageSize: imageSize
                )
                .allowsHitTesting(false)
            }

            if viewModel.showCameraGuide, viewModel.cameraPermissionState.canUseCamera {
                CameraGuideView(isPresented: Binding(
                    get: { viewModel.showCameraGuide },
                    set: { viewModel.setCameraGuidePresented($0) }
                ))
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.showCameraGuide)
        .navigationBarBackButtonHidden()
        .fullScreenCover(isPresented: $viewModel.showReview) {
            CatchReviewView(
                image: viewModel.capturedImage,
                segmentedFishes: viewModel.capturedSegmentedFishes,
                locationMetadata: viewModel.capturedLocation,
                shouldPromptLocationSettings: viewModel.shouldPromptLocationSettingsInReview,
                onRetake: viewModel.retry,
                onSave: onSave
            )
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .task {
            await viewModel.prepareCameraPermission()
        }
        .task(id: viewModel.cameraPermissionState) {
            if viewModel.cameraPermissionState.canUseCamera {
                viewModel.presentCameraGuideIfNeeded()
                if !viewModel.showCameraGuide {
                    viewModel.startARCoachingGate()
                }
                await viewModel.startScanning()
            } else {
                viewModel.stopARCoachingGate()
                viewModel.stopScanning()
                viewModel.arService.stop()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.handleSceneBecameActive()
            }
        }
        .alert("Camera access needed", isPresented: $viewModel.showPermissionAlert) {
            Button("Settings") {
                viewModel.openSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow Camera access in Settings to use capture and fish segmentation.")
        }
        .alert("Spesies ikan tidak diketahui", isPresented: $viewModel.showUnknownSpeciesAlert) {
            Button("Oke", role: .cancel) {}
        }
    }

    private var topControls: some View {
        HStack {
            CircleIconButton(systemName: "chevron.left") { dismiss() }

            Spacer()

            CircleIconButton(systemName: "info") {
                viewModel.presentCameraGuide()
            }
        }
        .padding(.top, 8)
    }

    private var centerInstruction: some View {
        VStack(spacing: 6) {
            Text(viewModel.centerInstructionText)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            if let statusText = viewModel.centerInstructionStatusText {
                Text(statusText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(radius: 4)
    }

    private var captureScanningMessage: some View {
        CaptureScanningMessage()
    }

    private var permissionBackground: some View {
        Color.neutralColorPrimaryBlack1
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

//            Button {
//                Task {
//                    if viewModel.cameraPermissionState == .notDetermined {
//                        await viewModel.requestCameraPermission()
//                    } else {
//                        viewModel.openSettings()
//                    }
//                }
//            } label: {
//                Text(viewModel.cameraPermissionState == .notDetermined ? "Allow Camera" : "Open Settings")
//                    .font(.system(size: 15, weight: .bold))
//                    .foregroundStyle(.black)
//                    .frame(maxWidth: .infinity)
//                    .frame(height: 52)
//                    .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
//            }
//            .buttonStyle(.plain)
//            .padding(.horizontal, 24)
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
                        .fill(captureButtonFill)
                        .frame(width: 64, height: 64)

                    Circle()
                        .stroke(Color.white.opacity(0.82), lineWidth: 3)
                        .frame(width: 76, height: 76)
                }
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canCapture || viewModel.isCapturing)
        }
    }

    private var captureButtonFill: Color {
        if viewModel.isCapturing {
            return Color.white.opacity(0.55)
        }

        return viewModel.canCapture ? Color.brandColorPrimaryYellow : Color.white.opacity(0.55)
    }
}

private struct CaptureScanningMessage: View {
    @State private var showSlowNotice = false

    var body: some View {
        VStack(spacing: 14) {
            CaptureScanningIndicator()

            Text("Scanning your fish...")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            if showSlowNotice {
                Text("Scanning mungkin butuh waktu agak lama untuk pertama kali")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(radius: 4)
        .task {
            showSlowNotice = false
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.2)) {
                showSlowNotice = true
            }
        }
    }
}

private struct CaptureScanningIndicator: View {
    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1.0 / 30.0)) { context in
            let seconds = context.date.timeIntervalSinceReferenceDate
            let phoneOffset = CGFloat(sin(seconds * .pi / 0.8) * 18)
            let scanPulse = (sin(seconds * 2 * .pi / 0.9) + 1) / 2
            let scanOpacity = 0.26 + (scanPulse * 0.56)
            let scanScale = CGFloat(0.88 + (scanPulse * 0.20))

            ZStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.white.opacity(scanOpacity))
                        .frame(width: 58, height: 3)
                        .scaleEffect(x: scanScale, anchor: .center)

                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.92), lineWidth: 2)
                        .frame(width: 28, height: 46)
                        .overlay(alignment: .top) {
                            Capsule()
                                .fill(Color.white.opacity(0.75))
                                .frame(width: 10, height: 2)
                                .padding(.top, 5)
                        }
                        .offset(x: phoneOffset)
                }
                .frame(width: 88, height: 54)
            }
            .frame(width: 104, height: 66)
            .background(.black.opacity(0.34), in: Capsule())
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
        view.debugOptions = []
        service.attach(sceneView: view)

        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.tag = Self.coachingOverlayTag
        coachingOverlay.session = view.session
        coachingOverlay.goal = .anyPlane
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

private struct FishScanCornerGuide: View {
    let boundingBox: CGRect
    let imageSize: CGSize
    @State private var pulse = false

    var body: some View {
        GeometryReader { proxy in
            let rect = displayRect(in: proxy.size)

            Path { path in
                addCornerLines(to: &path, rect: rect)
            }
            .trim(from: 0, to: pulse ? 1 : 0.82)
            .stroke(
                Color.white.opacity(0.9),
                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
            )
            .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 2)
            .scaleEffect(pulse ? 1.02 : 0.98, anchor: .center)
            .animation(.easeInOut(duration: 0.72).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
        }
    }

    private func displayRect(in displaySize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }

        let scale = max(displaySize.width / imageSize.width, displaySize.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        let imageFrame = CGRect(
            x: (displaySize.width - width) / 2,
            y: (displaySize.height - height) / 2,
            width: width,
            height: height
        )

        let minX = imageFrame.minX + boundingBox.minX * imageFrame.width
        let maxX = imageFrame.minX + boundingBox.maxX * imageFrame.width
        let minY = imageFrame.minY + (1 - boundingBox.maxY) * imageFrame.height
        let maxY = imageFrame.minY + (1 - boundingBox.minY) * imageFrame.height

        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        ).insetBy(dx: -10, dy: -10)
    }

    private func addCornerLines(to path: inout Path, rect: CGRect) {
        let cornerLength = min(max(min(rect.width, rect.height) * 0.18, 18), 42)

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerLength))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + cornerLength, y: rect.minY))

        path.move(to: CGPoint(x: rect.maxX - cornerLength, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cornerLength))

        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerLength))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - cornerLength, y: rect.maxY))

        path.move(to: CGPoint(x: rect.minX + cornerLength, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cornerLength))
    }
}

#Preview {
    CameraView()
}
