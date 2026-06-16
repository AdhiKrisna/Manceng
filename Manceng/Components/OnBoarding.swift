
//
//  OnBoarding.swift
//  Manceng
//
//  Created by Raihan Zhaky Al Hafizh on 16/06/26.
//

import SwiftUI

struct OnBoarding: View {
    let image: Image
    let title: String
    let caption: String
    let showDots: Bool
    
    init(image: Image, title: String, caption: String, showDots: Bool = false) {
        self.image = image
        self.title = title
        self.caption = caption
        self.showDots = showDots
    }
    
    var body: some View {
        VStack(spacing: 0) {
            image
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 248)
            
            Spacer().frame(height: 84)
            
            if showDots {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.NeutralColorPrimaryBlack2)
                        .frame(width: 8, height: 8)
                    Circle()
                        .fill(Color.NeutralColorPrimaryBlack2)
                        .frame(width: 8, height: 8)
                    Circle()
                        .fill(Color.NeutralColorPrimaryBlack2)
                        .frame(width: 8, height: 8)
                }
                .padding(.bottom, 84)
            }
            
            VStack(spacing: 15) {
                Text(title)
                    .font(.Title1Semibold)
                    .foregroundColor(.NeutralColorPrimaryBlack1)
                    .multilineTextAlignment(.center)
                
                Text(caption)
                    .font(.Caption1Bold)
                    .foregroundColor(.NeutralColorPrimaryBlack1)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 32)
    }
}

#Preview {
    Group {
        OnBoarding(
            image: Image(systemName: "fish"),
            title: "FiShare",
            caption: "Welcome Angler! identify your catch instantly with AR-powered camera technology. Fast, easy and fun."
        )
    }
}

