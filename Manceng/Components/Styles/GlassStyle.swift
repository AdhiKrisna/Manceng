//
//  GlassStyle.swift
//  Manceng
//
//  Created by Krisna on 15/06/26.
//

import SwiftUI

struct GlassPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension View {
    @ViewBuilder
    func glassStyle<S: InsettableShape>(_ shape: S, lineWidth: CGFloat = 1.2) -> some View {
        self
            .background {
                ZStack {
                    shape.fill(Color.white.opacity(0.18))
                    shape.fill(.ultraThinMaterial).opacity(0.35)
                }
            }
            .overlay {
                shape.strokeBorder(Color.white.opacity(0.36), lineWidth: lineWidth)
            }
            .clipShape(shape)
    }
}

struct GlassCircleIcon: View {
    let systemName: String
    var size: CGFloat = 52
    var iconSize: CGFloat = 20
    var iconColor: Color = .black

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(iconColor)
            .frame(width: size, height: size)
            .glassStyle(Circle())
    }
}

struct CircleIconButton: View {
    let systemName: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassCircleIcon(systemName: systemName)
        }
        .buttonStyle(GlassPressStyle())
    }
}

struct ButtonOnboard: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.ButtonFont)
                .foregroundStyle(Color.brandWhite)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(Color.NeutralColorPrimaryBrown1, in: RoundedRectangle(cornerRadius: Radius.borderRadius))
        }
        .buttonStyle(GlassPressStyle())
    }
}

#Preview {
    ButtonOnboard(
        title: "Save",
        action: {}
    )
}


#Preview("Glass Press Style") {
    Button("Tap Me") {
        // Action kosong
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 12)
    .glassStyle(Capsule())
    .buttonStyle(GlassPressStyle())
    .padding()
}

#Preview("Glass Style Modifier") {
    VStack(spacing: 20) {
        Text("Glass Card")
            .padding()
            .glassStyle(RoundedRectangle(cornerRadius: 20))

        Text("Glass Capsule")
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .glassStyle(Capsule())
    }
    .padding()
}

#Preview("Glass Circle Icon") {
    VStack(spacing: 20) {
        GlassCircleIcon(systemName: "heart.fill")

        GlassCircleIcon(
            systemName: "camera.fill",
            size: 64,
            iconSize: 24,
            iconColor: .blue
        )

        GlassCircleIcon(
            systemName: "bookmark.fill",
            size: 48,
            iconSize: 18,
            iconColor: .orange
        )
    }
    .padding()
}
