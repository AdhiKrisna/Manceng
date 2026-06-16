//
//  ContentView.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 10/06/26.
//

import SwiftUI

//content utamanya disini aja
// checking swift data, ngecek onboarding, permission maybe, dsb
struct ContentView: View {
    @State private var hasCompletedOnboarding = false
    @State private var hasCompletedMainWalkthrough = false
    @State private var selectedMainTab: MainView.Tab = .home
    
    var body: some View {
        if hasCompletedOnboarding {
            MainView(
                selectedTab: $selectedMainTab,
                showWalkthrough: !hasCompletedMainWalkthrough,
                onWalkthroughComplete: {
                    hasCompletedMainWalkthrough = true
                }
            )
        } else {
            OnBoardingView {
                hasCompletedOnboarding = true
            }
        }
    }
}

#Preview {
    ContentView()
}
