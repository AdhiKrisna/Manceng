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
                        .offset(x: visualCenterOffsetX + tilt.parallaxX, y: tilt.parallaxY)
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
}
