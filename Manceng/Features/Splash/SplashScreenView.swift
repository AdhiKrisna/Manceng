//
//  SplashScreenView.swift
//  FiSharee
//
//  Created by Made Vidyatma Adhi Krisna on 23/06/26.
//

import SwiftUI

struct SplashScreenView: View {
    let onFinished: () -> Void

    @State private var logoOpacity = 0.0

    var body: some View {
        ZStack {
            Color.brandColorPrimaryYellow
                .ignoresSafeArea()

            Image("onboarding")
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 220)
                .opacity(logoOpacity)
        }
        .onAppear {
            runSplashAnimation()
        }
    }

    private func runSplashAnimation() {
        withAnimation(.easeIn(duration: 0.8)) {
            logoOpacity = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeOut(duration: 0.8)) {
                logoOpacity = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            onFinished()
        }
    }
}

#Preview {
    SplashScreenView {}
}
