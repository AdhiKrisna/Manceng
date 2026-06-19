//
//  RulerView.swift
//  Manceng
//
//  Created by Raihan Zhaky Al Hafizh on 16/06/26.
//
//  Penggaris vertikal dinamis sesuai desain:
//  - Angka paling atas = panjang ikan (maxCm), angka bawah = 0.
//  - Tinggi tetap (mengisi layar); jarak antar-cm menyesuaikan panjang ikan,
//    jadi ikan 40 cm tampil lebih renggang daripada 70 cm.
//  - Tick per-cm: panjang tiap 10 cm, medium tiap 5 cm, pendek tiap 1 cm.
//

import SwiftUI

struct RulerView: View {
    let maxCm: Int
    /// Jarak antar-cm KONSTAN (tidak ikut meregang mengikuti panjang ikan).
    var cmSpacing: CGFloat

    private let tickAreaWidth: CGFloat = 58
    private let tickColor: Color = .black

    init(maxCm: Int, cmSpacing: CGFloat = 8) {
        self.maxCm = max(1, maxCm)
        self.cmSpacing = cmSpacing
    }

    private var tickHeight: CGFloat { CGFloat(maxCm) * cmSpacing }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Label paling atas = panjang ikan.
            label(maxCm, faded: false)

            // Area tick: 0 di bawah, maxCm di atas. Jarak antar-cm konstan.
            Canvas { context, size in
                for cm in 0...maxCm {
                    let y = CGFloat(maxCm - cm) * cmSpacing

                    let tickLen: CGFloat
                    let lineWidth: CGFloat
                    if cm % 10 == 0 {
                        tickLen = tickAreaWidth
                        lineWidth = 1.6
                    } else if cm % 5 == 0 {
                        tickLen = tickAreaWidth * 0.62
                        lineWidth = 1.2
                    } else {
                        tickLen = tickAreaWidth * 0.34
                        lineWidth = 1.0
                    }

                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: tickLen, y: y))
                    context.stroke(path, with: .color(tickColor), lineWidth: lineWidth)
                }
            }
            .frame(width: tickAreaWidth, height: tickHeight)

            // Label paling bawah = 0 (lebih pudar, seperti desain).
            label(0, faded: true)
        }
        .fixedSize()
    }

    private func label(_ value: Int, faded: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text("\(value)")
                .font(.system(size: 30, weight: .bold))
            Text("cm")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(Color.black.opacity(faded ? 0.45 : 1.0))
    }
}

#Preview {
    HStack(spacing: 40) {
        RulerView(maxCm: 80)
        RulerView(maxCm: 40)
    }
    .padding()
    .background(Color(red: 1.0, green: 0.80, blue: 0.0))
}
