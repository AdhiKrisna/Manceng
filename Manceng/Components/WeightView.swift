//
//  WeightView.swift
//  Manceng
//
//  Created by Raihan Zhaky Al Hafizh on 16/06/26.
//

import SwiftUI

// MARK: - Shape Helper
struct SemicircleShape: Shape {
    let width: CGFloat
    let height: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = height / 2
        path.move(to: CGPoint(x: width, y: 0))
        path.addArc(
            center: CGPoint(x: width, y: radius),
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(90),
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - WeightView
struct WeightView: View {
    let weight: Double
    let maxWeight: Double
    let fillColor: Color = Color(red: 1, green: 0.9, blue: 0.4)

    private let height: CGFloat = 356
    private var width: CGFloat { height / 2 }

    init(weight: Double = 7, maxWeight: Double = 10) {
        self.weight = weight
        self.maxWeight = maxWeight
    }

    init(weight: Int, maxWeight: Int = 10) {
        self.weight = Double(weight)
        self.maxWeight = Double(maxWeight)
    }

    private var displayWeight: String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(weight))
            : String(format: "%.1f", weight)
    }

    private var semicircle: Path {
        var path = Path()
        let radius = height / 2
        path.move(to: CGPoint(x: width, y: 0))
        path.addArc(
            center: CGPoint(x: width, y: radius),
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(90),
            clockwise: true
        )
        path.closeSubpath()
        return path
    }

    var body: some View {
        let radius = height / 2

        ZStack {
            // Layer 1: Fill + outer drop shadow (#000 25%, blur 8)
            semicircle
                .fill(fillColor)
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 0)

            // Layer 2: Inner shadow (#000 25%, blur 2)
            semicircle
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.25), location: 0.0),
                            .init(color: .clear,               location: 0.18)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .blur(radius: 2)
                .clipShape(SemicircleShape(width: width, height: height))

            // Layer 3: Weight text
            VStack(spacing: 12) {
                Text(displayWeight)
                    .font(.system(size: height / 5, weight: .bold, design: .default))
                    .foregroundColor(.black)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text("kg")
                    .font(.system(size: height / 8, weight: .medium, design: .default))
                    .foregroundColor(.black)
            }
            .position(x: width / 2, y: radius)
        }
        .frame(width: width, height: height)
        .clipped(antialiased: true)
    }
}

// MARK: - Preview
#Preview {
    WeightView(weight: 10)
        .padding()
        .background(Color.gray.opacity(0.2))
}
