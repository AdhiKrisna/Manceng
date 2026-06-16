
//
//  HomeView.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 15/06/26.
//

import SwiftUI
import SwiftData
import RealityKit
import CoreMotion
import Combine

struct HomeView: View {
    @Query(sort: \CatchModel.capturedAt, order: .reverse) private var catches: [CatchModel]
    @State private var rotationAngle: Angle = .zero
    @StateObject private var motionManager = MotionManager()

    var body: some View {
        ZStack {
            Color.BrandColorPrimaryYellow
                .ignoresSafeArea()

            if let latestCatch = catches.first {
                // Show latest catch
                VStack(spacing: 24) {
                    Image(uiImage: latestCatch.image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .rotation3DEffect(
                            rotationAngle,
                            axis: (x: 0, y: 1, z: 0)
                        )
                        .onAppear {
                            motionManager.startGyroUpdates { yaw in
                                rotationAngle = .degrees(yaw * 180 / .pi)
                            }
                        }
                        .onDisappear {
                            motionManager.stopGyroUpdates()
                        }

                    VStack(spacing: 8) {
                        Text(latestCatch.species)
                            .font(.Title1Semibold)
                            .foregroundColor(.NeutralColorPrimaryBlack1)

                        HStack(spacing: 16) {
                            Text(String(format: "%.1f kg", latestCatch.weight))
                                .font(.Caption1Bold)
                                .foregroundColor(.NeutralColorPrimaryBlack1.opacity(0.7))

                            Text(String(format: "%.0f cm", latestCatch.length))
                                .font(.Caption1Bold)
                                .foregroundColor(.NeutralColorPrimaryBlack1.opacity(0.7))
                        }
                    }
                }
                .padding(24)
            } else {
                // Show empty state
                VStack(spacing: 24) {
                    // 3D Model tenggiri.usdc with gyro rotation
                    RealityView { content in
                        do {
                            let entity = try await Entity.load(named: "tenggiri.usdc")
                            content.add(entity)
                        } catch {
                            print("Failed to load 3D model: \(error)")
                        }
                    } placeholder: {
                        // Placeholder if model fails to load
                        ZStack {
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                                .cornerRadius(16)

                            Image(systemName: "fish.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .rotation3DEffect(
                        rotationAngle,
                        axis: (x: 0, y: 1, z: 0)
                    )
                    .onAppear {
                        motionManager.startGyroUpdates { yaw in
                            rotationAngle = .degrees(yaw * 180 / .pi)
                        }
                    }
                    .onDisappear {
                        motionManager.stopGyroUpdates()
                    }
                    .frame(width: 200, height: 200)

                    VStack(spacing: 8) {
                        Text("No catches recorded yet!")
                            .font(.Title1Semibold)
                            .foregroundColor(.NeutralColorPrimaryBlack1)

                        Text("Tap camera button below to get started!")
                            .font(.Caption1Bold)
                            .foregroundColor(.NeutralColorPrimaryBlack1.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(24)
            }
        }
    }
}

class MotionManager: ObservableObject {
    let objectWillChange: ObservableObjectPublisher = ObservableObjectPublisher()

    private let cmManager = CMMotionManager()
    private let operationQueue = OperationQueue()

    func startGyroUpdates(_ update: @escaping (Double) -> Void) {
        guard cmManager.isGyroAvailable else { return }
        cmManager.gyroUpdateInterval = 0.05
        cmManager.startGyroUpdates(to: operationQueue) { data, error in
            guard let data = data else { return }
            DispatchQueue.main.async {
                update(data.rotationRate.z)
            }
        }
    }

    func stopGyroUpdates() {
        cmManager.stopGyroUpdates()
    }

    deinit {
        cmManager.stopGyroUpdates()
    }
}

#Preview {
    HomeView()
}
