
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
    
    init(image: Image, title: String, caption: String) {
        self.image = image
        self.title = title
        self.caption = caption
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Gambar full-width (edge-to-edge), scaledToFit agar utuh seperti desain.
            image
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)

            Spacer().frame(height: 48)

            VStack(spacing: 15) {
                Text(title)
                    .font(.Title1Semibold)
                    .foregroundColor(.NeutralColorPrimaryBlack1)
                    .multilineTextAlignment(.center)

                Text(caption)
                    .font(.CaptionRegular)
                    .foregroundColor(.NeutralColorPrimaryBlack1)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
        }
    }
}

#Preview {
    Group {
        OnBoarding(
            image: Image("onboarding"),
            title: "FiShare",
            caption: "Welcome Angler! identify your catch instantly with AR-powered camera technology. Fast, easy and fun."
        )
    }
}

