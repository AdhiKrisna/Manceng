//
//  PinMap.swift
//  Manceng
//
//  Created by Trae AI on 18/06/26.
//

import SwiftUI

struct PinMap: View {
    let catchModel: CatchModel
    
    var body: some View {
        VStack(spacing: 0) {
            Image(uiImage: catchModel.image)
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white, lineWidth: 4)
                )
            
            Triangle()
                .fill(Color.white)
                .frame(width: 30, height: 20)
                .offset(y: -2)
        }
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    let sampleImage = UIImage(systemName: "fish.fill")!
    let sampleCatch = CatchModel(
        image: sampleImage,
        species: "Rainbow Trout",
        weight: 2.5,
        length: 45,
        location: "River",
        latitude: -6.2088,
        longitude: 106.8456
    )
    return PinMap(catchModel: sampleCatch)
        .padding()
        .background(Color.gray)
}
