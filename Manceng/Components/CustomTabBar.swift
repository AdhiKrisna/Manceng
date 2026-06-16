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
        HStack(spacing: 4) {
            TabBarItem(icon: "house.fill", label: "Home", isSelected: selectedTab == .home) {
                selectedTab = .home
            }
            TabBarItem(icon: "map.fill", label: "Maps", isSelected: selectedTab == .map) {
                selectedTab = .map
            }
            TabBarItem(icon: "fish.fill", label: "History", isSelected: selectedTab == .history) {
                selectedTab = .history
            }
        }
        .padding(6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))

        Spacer()

        Button(action: onCamera) {
            Image(systemName: "camera.fill")
                .font(.title2)
                .frame(width: 56, height: 56)
                .background(.regularMaterial, in: Circle())
        }
        .foregroundStyle(.primary)
    }
}

struct TabBarItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                isSelected ? Color.primary.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 14)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

