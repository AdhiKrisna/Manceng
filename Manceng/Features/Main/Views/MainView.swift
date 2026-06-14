//
//  HomeView.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 10/06/26.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Text("Welcome to Manceng")
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.BrandColorPrimaryYellow)
            .ignoresSafeArea()
            .overlay(alignment: .bottom) {
                CustomTabBar()
                    .padding(.horizontal, 24)
            }
        }
    }
}

#Preview {
    HomeView()
}
