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
        ZStack {
            if isShowingSplash {
                SplashScreenView {
                    isShowingSplash = false
                }
                .transition(.opacity)
            } else if hasCompletedOnboarding {
                MainView(
                    selectedTab: $selectedMainTab,
                    showWalkthrough: false
                )
                .transition(.opacity)
            } else {
                OnBoardingView {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        hasCompletedOnboarding = true
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: isShowingSplash)
        .animation(.easeInOut(duration: 0.35), value: hasCompletedOnboarding)
    }
}

#Preview {
    ContentView()
}
