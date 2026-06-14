//
//  CustomTabBar.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 14/06/26.
//
import SwiftUI

struct CustomTabBar: View {
    let gold = Color(
        red: 191 / 255,
        green: 142 / 255,
        blue: 0 / 255
    )
    var body: some View {
        ZStack(alignment: .top) {
            // Background capsule only
            Capsule()
                .frame(width: 289, height: 88)
                .foregroundStyle(.brown)
                .shadow(
                    color: .black.opacity(0.15),
                    radius: 10,
                    y: 4
                )

            // Icons
            HStack {
                Spacer()
                NavigationLink {
                    MapView()
                } label: {
                    tabButton(icon: .map, size: 30)
                }

                Spacer()

                // Camera button dengan circle sendiri
                NavigationLink {
                    CameraView()
                } label: {
                    ZStack {
                        Circle()
                            .frame(width: 120, height: 120)
                            .foregroundStyle(.brown)
                        
                        tabButton(icon: .camera, size: 44)
                    }
                    .offset(y: -16)
                }

                Spacer()

                NavigationLink {
                    HistoryView()
                } label: {
                    tabButton(icon: .history, size: 30)
                }
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 58)
            .frame(height: 88)
        }
        .frame(height: 120)
    }

    @ViewBuilder
    private func tabButton(icon: AppIcons, size: CGFloat) -> some View {
        Image(systemName: icon.systemName)
            .font(.system(size: size))
    }
}
