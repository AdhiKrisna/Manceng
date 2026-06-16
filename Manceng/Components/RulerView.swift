//
//  RulerView.swift
//  Manceng
//
//  Created by Raihan Zhaky Al Hafizh on 16/06/26.
//
//  Standard penggaris nyata:
//  - 1 cm  : garis paling panjang
//  - 0.5 cm: garis medium
//  - 1 mm  : garis pendek
//

import SwiftUI
import UIKit

extension UIScreen {
    static var pointsPerCm: CGFloat {
        let ppi: CGFloat = 163.0 * UIScreen.main.nativeScale
        let pixelsPerCm = ppi / 2.54
        return pixelsPerCm / UIScreen.main.nativeScale
    }
}

struct RulerView: View {
    let totalCm: Int
    let scaleFactor: CGFloat

    private let rulerWidth: CGFloat = 120
    private let backgroundColor: Color = Color(red: 1.0, green: 0.80, blue: 0.0)
    private let borderColor: Color = .black
    private let tickColor: Color = .black

    var rulerHeight: CGFloat {
        CGFloat(totalCm) * scaleFactor * UIScreen.pointsPerCm
    }

    private var tickCm: CGFloat { rulerWidth * 0.78 }
    private var tickHalfCm: CGFloat { rulerWidth * 0.52 }
    private var tickMm: CGFloat { rulerWidth * 0.30 }
    private var totalTicks: Int { totalCm * 10 }

    init(totalCm: Int = 10, scaleFactor: CGFloat = 10.0) {
        self.totalCm = totalCm
        self.scaleFactor = scaleFactor
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            backgroundColor

            Rectangle()
                .stroke(borderColor, lineWidth: 1)

            Canvas { context, size in
                let spacing = size.height / CGFloat(totalTicks)

                for i in 0...totalTicks {
                    let y = CGFloat(i) * spacing

                    let tickLen: CGFloat
                    if i % 10 == 0 {
                        tickLen = tickCm
                    } else if i % 5 == 0 {
                        tickLen = tickHalfCm
                    } else {
                        tickLen = tickMm
                    }

                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: tickLen, y: y))

                    context.stroke(path, with: .color(tickColor), lineWidth: 1)
                }
            }
        }
        .frame(width: rulerWidth, height: rulerHeight)
        .clipShape(Rectangle())
    }
}

#Preview {
    ScrollView {
        RulerView(totalCm: 23, scaleFactor: 1.0)
            .padding()
            .background(Color.gray.opacity(0.15))
    }
}
