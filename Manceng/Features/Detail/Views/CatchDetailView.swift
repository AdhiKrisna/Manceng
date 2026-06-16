//
//  CatchDetailView.swift
//  Manceng
//
//  Halaman detail tangkapan: area model 3D yang berganti mengikuti baris
//  statistik yang dipilih (Length → penggaris+ikan, Weight → timbangan,
//  Location → globe), judul nama ikan, dan tiga baris statistik.
//

import SwiftUI

struct CatchDetailView: View {
    var speciesName: String = "BARRAMUNDI FISH"
    var length: String = "50 cm"
    var weight: String = "7.2 Kg"
    var location: String = "Batam"

    enum Stat: Hashable { case length, weight, location }

    @Environment(\.dismiss) private var dismiss

    @StateObject private var motion = Model3DMotionManager()
    @State private var lengthInteraction = FishInteractionState()
    @State private var weightInteraction = FishInteractionState()

    @State private var selected: Stat = .length

    var body: some View {
        ZStack {
            Color.BrandColorPrimaryYellow
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                // --- Area model 3D / ilustrasi (berganti mengikuti pilihan) ---
                ZStack {
                    switch selected {
                    case .length:
                        FishLengthModelView(motion: motion, interaction: lengthInteraction)
                    case .weight:
                        ScaleModelView(motion: motion, interaction: weightInteraction)
                    case .location:
                        locationGlobe
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // --- Judul nama ikan ---
                Text(speciesName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.NeutralColorPrimaryBlack1)
                    .padding(.bottom, 28)

                // --- Tiga baris statistik ---
                VStack(spacing: 14) {
                    statRow(label: "Length", value: length, stat: .length)
                    statRow(label: "Weight", value: weight, stat: .weight)
                    statRow(label: "Location", value: location, stat: .location)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { motion.start() }
        .onDisappear { motion.stop() }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            circleButton(systemName: "chevron.left") { dismiss() }

            Spacer()

            HStack(spacing: 6) {
                circleButton(systemName: "square.and.arrow.up") {}
                circleButton(systemName: "trash") {}
            }
            .padding(.horizontal, 6)
            .background(Capsule().fill(.background.secondary))
        }
    }

    private func circleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.NeutralColorPrimaryBlack1)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.background.secondary))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stat row

    private func statRow(label: String, value: String, stat: Stat) -> some View {
        let isSelected = selected == stat
        let foreground = isSelected ? Color.NeutralColorPrimaryWhite : Color.NeutralColorPrimaryBlack1

        return Button {
            selected = stat
        } label: {
            HStack(spacing: 10) {
                Text(label)
                    .font(.system(size: 16, weight: .medium))

                Rectangle()
                    .fill(foreground.opacity(0.6))
                    .frame(height: 1)

                Text(value)
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundStyle(foreground)
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .background {
                if isSelected {
                    Capsule().fill(
                        LinearGradient(
                            colors: [Color(hex: "#5A4500"), Color(hex: "#2C2300")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Location globe

    private var locationGlobe: some View {
        Image(systemName: "globe.asia.australia.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(Color.NeutralColorPrimaryBlack1)
            .frame(width: 360)
            .offset(x: 70, y: -10)
            .clipped()
    }
}

#Preview {
    CatchDetailView()
}
