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
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedMainTab: MainView.Tab = .home
    @State private var isShowingSplash = true
    
    var body: some View {
        if isShowingSplash {
            SplashScreenView {
                isShowingSplash = false
            }
        } else {
            if hasCompletedOnboarding {
                MainView(
                    selectedTab: $selectedMainTab,
                    showWalkthrough: false
                )
            } else {
                OnBoardingView {
                    hasCompletedOnboarding = true
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
