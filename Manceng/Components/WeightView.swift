//
//  WeightView.swift
//  Manceng
//
//  Created by Raihan Zhaky Al Hafizh on 16/06/26.
//
//  Badge berat: lingkaran penuh yang hanya menampilkan ~30% bagian kirinya
//  (sisanya keluar dari tepi kanan layar). Tanpa inner shadow.
//

import SwiftUI

struct WeightView: View {
    let weight: Double
    var diameter: CGFloat
    /// Berapa bagian lingkaran yang terlihat (0.30 = 30%).
    var visibleFraction: CGFloat
    let fillColor: Color = Color(red: 1, green: 0.9, blue: 0.4)

    init(weight: Double = 6, diameter: CGFloat = 360, visibleFraction: CGFloat = 0.3) {
        self.weight = weight
        self.diameter = diameter
        self.visibleFraction = visibleFraction
    }

    init(weight: Int, diameter: CGFloat = 360, visibleFraction: CGFloat = 0.30) {
        self.weight = Double(weight)
        self.diameter = diameter
        self.visibleFraction = visibleFraction
    }

    private var capWidth: CGFloat { diameter * visibleFraction }

    private var displayWeight: String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(weight))
            : String(format: "%.1f", weight)
    }

    var body: some View {
        ZStack {
            // Lingkaran penuh, hanya 30% bagian kiri yang ditampilkan
            // (flat di kanan = tepi layar, lengkung di kiri masuk ke layar).
            Circle()
                .fill(fillColor)
                .frame(width: diameter, height: diameter)
                .frame(width: capWidth, height: diameter, alignment: .leading)
                .clipped()
                .shadow(color: .black.opacity(0.25), radius: 8, x: -2, y: 0)

            // Angka berat (tanpa inner shadow).
            VStack(spacing: 4) {
                Text(displayWeight)
                    .font(.system(size: diameter / 10, weight: .bold, design: .default))
                    .foregroundColor(.black)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)

                Text("kg")
                    .font(.system(size: diameter / 12, weight: .medium, design: .default))
                    .foregroundColor(.black)
            }
            .frame(width: capWidth)
        }
        .frame(width: capWidth, height: diameter, alignment: .leading)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color(red: 1.0, green: 0.80, blue: 0.0).ignoresSafeArea()
        HStack {
            Spacer()
            WeightView(weight: 7.2)
        }
    }
}
