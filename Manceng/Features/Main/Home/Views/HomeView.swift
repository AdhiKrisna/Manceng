//
//  HomeView.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 15/06/26.
//

import SwiftUI
import RealityKit

struct HomeView: View {
    @State private var rotationAngle: Angle = .zero
    
    var body: some View {
        ZStack {
            Color.BrandColorPrimaryYellow
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // 3D Model tenggiri.usdc with rotation gesture
                RealityView { content in
                    if let entity = try? await Entity.load(named: "tenggiri.usdc") {
                        content.add(entity)
                    }
                }
                .rotation3DEffect(rotationAngle, axis: (x: 0, y: 1, z: 0))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            rotationAngle = .degrees(Double(value.translation.width))
                        }
                )
                .frame(width: 200, height: 200)
                
                VStack(spacing: 8) {
                    Text("No catches recorded  yet!")
                        .font(.Title1Semibold)
                        .foregroundColor(.NeutralColorPrimaryBlack1)
                    
                    Text("Tap camera button bellow to get started!")
                        .font(.Caption1Bold)
                        .foregroundColor(.NeutralColorPrimaryBlack1.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
        }
    }
}

#Preview {
    HomeView()
}
