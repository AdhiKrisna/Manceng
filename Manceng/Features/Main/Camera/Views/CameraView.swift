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
    /// Tampil otomatis saat masuk layar kamera (kamera sudah jalan di belakang),
    /// lalu bisa dibuka lagi lewat tombol info.
    @State private var showGuide = true

    /// Dipanggil saat user menekan Save di review — hasil tangkapan dikirim ke beranda.
    var onSave: (CatchModel) -> Void = { _ in }

    var body: some View {
        ZStack {
            if viewModel.cameraPermissionState.canUseCamera {
                ARCameraContainer(service: viewModel.arService)
                    .ignoresSafeArea()

                Color.black.opacity(0.18)
                    .ignoresSafeArea()

                GeometryReader { proxy in
                    if viewModel.arService.isARReady,
                       let scannedImage = viewModel.scannedImage,
                       !viewModel.segmentedFishes.isEmpty {
                        CameraSegmentationOverlay(
                            image: scannedImage,
                            fishes: viewModel.segmentedFishes,
                            displaySize: proxy.size
                        )
                    }
                }
                .ignoresSafeArea()
            } else {
                permissionBackground
            }

            VStack {
                topControls

                if viewModel.cameraPermissionState.canUseCamera {
                    checkingStatus
                    Spacer()
                    bottomControls
                } else {
                    Spacer()
                    permissionControls
                    Spacer()
                }
            }
            .padding(.horizontal, 20)

            if showGuide, viewModel.cameraPermissionState.canUseCamera {
                CameraGuideView(isPresented: $showGuide)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showGuide)
        .navigationBarBackButtonHidden()
        .fullScreenCover(isPresented: $viewModel.showReview) {
            CatchReviewView(
                image: viewModel.capturedImage,
                segmentedFishes: viewModel.segmentedFishes,
                onRetake: viewModel.retry,
                onSave: onSave
            )
        }
        .onDisappear {
            viewModel.stopScanning()
            viewModel.arService.stop()
        }
        .task {
            await viewModel.prepareCameraPermission()
            showGuide = viewModel.cameraPermissionState.canUseCamera
        }
        .task(id: viewModel.cameraPermissionState) {
            if viewModel.cameraPermissionState.canUseCamera {
                if !showGuide {
                    showGuide = true
                }
                await viewModel.startScanning()
            } else {
                viewModel.stopScanning()
                viewModel.arService.stop()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.refreshPermissionState()
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
                showGuide = true
            }
        }
    }

    private var checkingStatus: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                statusPill(
                    text: viewModel.permissionStatusText,
                    dotColor: viewModel.permissionStatusColor
                )

                statusPill(
                    text: viewModel.arService.isARReady ? "AR On" : "AR Off",
                    dotColor: viewModel.arService.isARReady ? .green : .red
                )

                if viewModel.arService.isARReady {
                    statusPill(
                        text: viewModel.fishStatusText,
                        dotColor: viewModel.segmentedFishes.count == 1 ? .green : .yellow
                    )
                }
            }

            Spacer()
        }
        .padding(.top, 84)
    }

    private func statusPill(text: String, dotColor: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)

            Text(text)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.black)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.white.opacity(0.72), in: Capsule())
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

            if !viewModel.arService.isARReady {
                Image(systemName: "iphone.gen3")
                    .font(.system(size: 42, weight: .regular))
                    .foregroundStyle(.white)
                    .shadow(radius: 3)
            }

            Text(viewModel.isProcessing ? "Processing fish" : viewModel.guidanceText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .shadow(radius: 2)

            Button {
                viewModel.capture()
            } label: {
                ZStack {
                    Circle()
                        .fill(viewModel.canCapture ? Color.black : Color.white.opacity(0.55))
                        .frame(width: 64, height: 64)

                    Circle()
                        .stroke(Color.white.opacity(0.82), lineWidth: 3)
                        .frame(width: 76, height: 76)

                    if viewModel.isProcessing {
                        ProgressView()
                            .tint(.black)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canCapture)
        }
    }
}

private struct CameraSegmentationOverlay: View {
    let image: UIImage
    let fishes: [SegmentedFish]
    let displaySize: CGSize

    var body: some View {
        let frame = imageFrame(imageSize: image.size, displaySize: displaySize)

        ZStack {
            ForEach(fishes) { fish in
                Image(uiImage: fish.maskImage)
                    .resizable()
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
                    .blendMode(.screen)
                    .opacity(0.78)

                let box = convertBoundingBox(
                    fish.fish.boundingBox,
                    imageSize: image.size,
                    imageFrame: frame
                )

                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: box.width, height: box.height)
                    .position(x: box.midX, y: box.midY)

                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.brandSky, lineWidth: 2)
                    .frame(width: box.width + 5, height: box.height + 5)
                    .position(x: box.midX, y: box.midY)

                if let length = fish.fish.estimatedLengthCm {
                    Text(String(format: "%.0f cm", length))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.82), in: Capsule())
                        .position(x: box.midX, y: max(box.minY - 14, 24))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func imageFrame(imageSize: CGSize, displaySize: CGSize) -> CGRect {
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

    private func convertBoundingBox(_ bbox: CGRect, imageSize: CGSize, imageFrame: CGRect) -> CGRect {
        CGRect(
            x: imageFrame.minX + bbox.minX * imageFrame.width,
            y: imageFrame.minY + (1 - bbox.maxY) * imageFrame.height,
            width: bbox.width * imageFrame.width,
            height: bbox.height * imageFrame.height
        )
    }
}

private struct ARCameraContainer: UIViewRepresentable {
    @ObservedObject var service: ARMeasurementService

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.backgroundColor = .black
        service.attach(sceneView: view)
        service.start()
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}

#Preview {
    CameraView()
}
