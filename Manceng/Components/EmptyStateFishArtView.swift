//
//  EmptyStateFishArtView.swift
//  Manceng
//
//  Created by Codex on 21/06/26.
//

import SwiftUI

final class EmptyStateFishTiltSmoother {
    var rotX: Double = 0
    var rotY: Double = 0
}

struct EmptyStateFishArtView: View {
    @ObservedObject var motion: Model3DMotionManager
    var fishHeight: CGFloat = 260
    var baseRotation: Angle = .degrees(-90)
    var visualCenterOffsetX: CGFloat = -14

    private let maxTilt: Double = 14
    private let gyroGain: Double = 1.6
    private let gyroEasing: Double = 0.6
    private let maxParallax: Double = 7

    @State private var tiltSmoother = EmptyStateFishTiltSmoother()
    @State private var entranceReveal: CGFloat = 0.001
    @State private var entranceXOffset: CGFloat = 0
    @State private var entranceYOffset: CGFloat = -1600
    @State private var entranceRotation: Double = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 60.0)) { _ in
            let tilt = currentTilt()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                ZStack(alignment: .bottom) {
                    contactShadow(tilt: tilt)

                    Image("asset_ikan")
                        .resizable()
                        .scaledToFit()
                        .frame(height: fishHeight)
                        .rotationEffect(baseRotation)
                        .rotationEffect(.degrees(entranceRotation), anchor: .top)
                        .offset(x: visualCenterOffsetX + tilt.parallaxX, y: tilt.parallaxY)
                        .offset(x: entranceXOffset, y: entranceYOffset)
                        .mask(alignment: .top) {
                            Rectangle()
                                .scaleEffect(y: entranceReveal, anchor: .top)
                        }
                        .rotation3DEffect(.degrees(tilt.rotX), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
                        .rotation3DEffect(.degrees(tilt.rotY), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                        .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 30)
                }

                Ellipse()
                    .fill(.black.opacity(0.22))
                    .blur(radius: 16)
                    .frame(width: 210, height: 34)
                    .padding(.top, 18)

                Spacer(minLength: 0)
            }
        }
        .onAppear {
            playEntranceAnimation()
        }
    }

    private func currentTilt() -> (rotX: Double, rotY: Double, parallaxX: Double, parallaxY: Double) {
        let radToDeg = 180.0 / .pi
        let targetX = clampTilt(motion.pitch * radToDeg * gyroGain)
        let targetY = clampTilt(motion.roll * radToDeg * gyroGain)
        tiltSmoother.rotX += (targetX - tiltSmoother.rotX) * gyroEasing
        tiltSmoother.rotY += (targetY - tiltSmoother.rotY) * gyroEasing

        return (
            tiltSmoother.rotX,
            tiltSmoother.rotY,
            tiltSmoother.rotY / maxTilt * maxParallax,
            -tiltSmoother.rotX / maxTilt * maxParallax
        )
    }

    private func clampTilt(_ value: Double) -> Double {
        min(max(value, -maxTilt), maxTilt)
    }

    private func contactShadow(tilt: (rotX: Double, rotY: Double, parallaxX: Double, parallaxY: Double)) -> some View {
        Ellipse()
            .fill(.black.opacity(0.25))
            .frame(width: 110, height: 22)
            .scaleEffect(x: 1 + abs(tilt.rotY) / maxTilt * 0.12,
                         y: 1 - abs(tilt.rotX) / maxTilt * 0.2)
            .offset(x: visualCenterOffsetX + tilt.parallaxX, y: 52)
            .blur(radius: 12)
            .allowsHitTesting(false)
    }

    private func playEntranceAnimation() {
        entranceReveal = 0.001
        entranceXOffset = 0
        entranceYOffset = -1600
        entranceRotation = 0

        Task { @MainActor in
            withAnimation(.easeOut(duration: 0.58)) {
                entranceReveal = 1
                entranceYOffset = 0
            }

            try? await Task.sleep(nanoseconds: 580_000_000)

            withAnimation(.spring(response: 0.22, dampingFraction: 0.58)) {
                entranceYOffset = -18
            }

            try? await Task.sleep(nanoseconds: 170_000_000)

            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                entranceYOffset = 0
            }

            try? await Task.sleep(nanoseconds: 180_000_000)

            withAnimation(.easeInOut(duration: 0.18)) {
                entranceXOffset = 10
                entranceRotation = 5
            }

            try? await Task.sleep(nanoseconds: 180_000_000)

            withAnimation(.easeInOut(duration: 0.2)) {
                entranceXOffset = -8
                entranceRotation = -4
            }

            try? await Task.sleep(nanoseconds: 200_000_000)

            withAnimation(.easeInOut(duration: 0.22)) {
                entranceXOffset = 5
                entranceRotation = 2.4
            }

            try? await Task.sleep(nanoseconds: 220_000_000)

            withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                entranceXOffset = 0
                entranceRotation = 0
            }
        }
    }
}
