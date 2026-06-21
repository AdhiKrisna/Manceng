//
//  CameraGuideView.swift
//  Manceng
//
//  Guideline kamera (paged) yang muncul saat tombol info ditekan.


import SwiftUI

struct CameraGuideView: View {
    @Binding var isPresented: Bool
    /// Bila diisi, tampilkan tombol lanjut (mis. "Mulai") yang membuka kamera
    /// setelah panduan ditutup. `nil` → panduan hanya informatif (tombol X saja).
    var onContinue: (() -> Void)? = nil

    @State private var page = 0
    @State private var appeared = false
    @State private var fishBob: CGFloat = 0
    @State private var phoneNudge: CGFloat = 0

    private struct GuidePage: Identifiable {
        let id = UUID()
        let title: String
        let showsPhone: Bool
    }

    private let pages: [GuidePage] = [
        GuidePage(title: "You have to capture only one fish", showsPhone: false),
        GuidePage(title: "Place your catch on a flat, even surface", showsPhone: true)
    ]

    var body: some View {
        ZStack {
            Color.neutralColorPrimaryBlack50
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            card
                .padding(.horizontal, 24)
                .scaleEffect(appeared ? 1 : 0.9)
                .opacity(appeared ? 1 : 0)
        }
        .onAppear { startAnimations() }
    }

    // MARK: - Card

    private var card: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, item in
                    pageView(item).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            dots
                .padding(.bottom, onContinue == nil ? 22 : 16)

            if let onContinue {
                continueButton(onContinue)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
        .frame(height: onContinue == nil ? 440 : 500)
        .background(
            Color.white.opacity(0.6)
                .background(.ultraThinMaterial.opacity(0.35))
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.6), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            CircleIconButton(systemName: "xmark") { dismiss() }
                .padding(10)
        }
        .shadow(color: Color.neutralColorPrimaryWhite.opacity(0.4), radius: 28, y: 12)
    }

    private func pageView(_ item: GuidePage) -> some View {
        VStack(spacing: 28) {
            Text(item.title)
                .font(.title2.bold())
                .foregroundStyle(Color.neutralColorPrimaryWhite)
                .multilineTextAlignment(.center)
                .padding(.top, 64)
                .padding(.horizontal, 48)

            ZStack {
                if item.showsPhone {
                    GifImageView(name: "fishposition")
                        .frame(width: 220, height: 220)
                        .shadow(color: Color.neutralColorPrimaryWhite.opacity(0.6), radius: 10)
                        .offset(y: fishBob)
                } else {
                    GifImageView(name: "onlyonefish")
                        .frame(width: 220, height: 220)
                        .shadow(color: Color.neutralColorPrimaryWhite.opacity(0.6), radius: 10)
                        .offset(y: fishBob)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private func continueButton(_ action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) { isPresented = false }
            action()
        } label: {
            Text("Mulai Capture")
                .font(.buttonFont)
                .foregroundStyle(Color.neutralColorPrimaryWhite)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.neutralColorPrimaryLemon)
                .clipShape(RoundedRectangle(cornerRadius: Radius.borderRadius))
        }
        .buttonStyle(.plain)
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(pages.indices, id: \.self) { index in
                dotView(for: index)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: page)
    }

    private func dotView(for index: Int) -> some View {
        let isSelected = index == page
        let color: Color = isSelected
            ? Color.brandColorPrimaryYellow
            : Color.neutralColorPrimaryWhite.opacity(0.3)

        return Capsule()
            .fill(color)
            .frame(width: isSelected ? 22 : 8, height: 8)
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    page = index
                }
            }
    }
    // MARK: - Animations

    private func startAnimations() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            appeared = true
        }
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            fishBob = -12
        }
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
            phoneNudge = 18
        }
    }

    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.25)) { isPresented = false }
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        CameraGuideView(isPresented: .constant(true))
    }
}
