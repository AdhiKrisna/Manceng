
//
//  MainWalkthroughView.swift
//  Manceng
//
//  Created by Raihan Zhaky Al Hafizh on 16/06/26.
//

import SwiftUI

/// Dimming + bottom-left tutorial card layer. The tab bar (with its spotlight)
/// is rendered separately by `MainView` on top of this, so this view only owns
/// the dark overlay and the step card.
struct MainWalkthroughView: View {
    let steps: [WalkthroughStep]
    @Binding var currentStep: Int
    let onNext: () -> Void

    /// Vertical space kept clear at the bottom for the floating tab bar.
    private let tabBarReservedHeight: CGFloat = 104

    var body: some View {
        ZStack {
            // Dark overlay (#000000 54%) across the whole screen.
            Color.black.opacity(0.54)
                .ignoresSafeArea()

            VStack {
                Spacer()

                HStack {
                    WalkthroughView(
                        steps: steps,
                        currentStep: $currentStep,
                        onNext: onNext
                    )
                    .frame(maxWidth: 240)

                    Spacer(minLength: 0)
                }
                .padding(.leading, 20)
            }
            .padding(.bottom, tabBarReservedHeight + 12)
        }
    }
}

#Preview {
    ZStack {
        Color.BrandColorPrimaryYellow.ignoresSafeArea()
        MainWalkthroughView(
            steps: [WalkthroughStep(text: "View your 5 latest, heaviest, or longest catches.")],
            currentStep: .constant(0),
            onNext: {}
        )
    }
}
