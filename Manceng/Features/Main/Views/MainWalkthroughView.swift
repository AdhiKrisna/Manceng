
//
//  MainWalkthroughView.swift
//  Manceng
//
//  Created by Raihan Zhaky Al Hafizh on 16/06/26.
//

import SwiftUI

struct MainWalkthroughView: View {
    @Binding var selectedTab: MainView.Tab
    let onComplete: () -> Void
    @State private var currentStep = 0
    
    let steps: [WalkthroughStep] = [
        WalkthroughStep(text: "View your 5 latest, heaviest, or longest catches."),
        WalkthroughStep(text: "See all the locations where you caught your fish."),
        WalkthroughStep(text: "Browse every verified catch you've recorded."),
        WalkthroughStep(text: "Scan your catch to instantly get species, length, and weight.")
    ]
    
    var body: some View {
        ZStack {
            // Dark overlay (#000000 54%)
            Color.black.opacity(0.54)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                WalkthroughView(
                    steps: steps,
                    currentStep: $currentStep,
                    onNext: {
                        if currentStep < steps.count - 1 {
                            currentStep += 1
                            updateSelectedTab()
                        } else {
                            onComplete()
                        }
                    }
                )
            }
            .padding(.bottom, 24)
        }
        .onAppear {
            updateSelectedTab()
        }
    }
    
    private func updateSelectedTab() {
        switch currentStep {
        case 0: selectedTab = .home
        case 1: selectedTab = .map
        case 2: selectedTab = .history
        default: selectedTab = .home
        }
    }
}

#Preview {
    MainWalkthroughView(selectedTab: .constant(.home), onComplete: {})
}
