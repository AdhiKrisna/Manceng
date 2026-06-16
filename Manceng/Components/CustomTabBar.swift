//
//  CustomTabBar.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 14/06/26.
//
import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: MainView.Tab
    let onCamera: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Pill: 3 tab items grouped in a capsule container
            HStack(spacing: 2) {
                tabItem(.home, label: "Home", tab: .home)
                tabItem(.map, label: "Maps", tab: .map)
                tabItem(.history, label: "History", tab: .history)
            }
            .padding(4)
            .background(Capsule().fill(.background.secondary))

            Spacer()

            // Camera: standalone circle at far right
            Button(action: onCamera) {
                Image(systemName: AppIcons.camera.systemName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(.background.secondary))
            }
            .buttonStyle(.plain)
        }
    }

    private func tabItem(_ icon: AppIcons, label: String, tab: MainView.Tab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon.systemName)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(selectedTab == tab ? .primary : .secondary)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background {
                if selectedTab == tab {
                    Capsule().fill(.background)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.BrandColorPrimaryYellow.ignoresSafeArea()
        VStack {
            Spacer()
            VStack(spacing: 0) {
                Divider()
                CustomTabBar(selectedTab: .constant(.home), onCamera: {})
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
            .background(.regularMaterial)
        }
    }
}
