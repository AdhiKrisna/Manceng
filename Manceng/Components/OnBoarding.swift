
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
    let imageSize: CGSize?
    let containerSize: CGSize?
    
    init(image: Image, title: String, caption: String, imageSize: CGSize? = nil, containerSize: CGSize? = nil) {
        self.image = image
        self.title = title
        self.caption = caption
        self.imageSize = imageSize
        self.containerSize = containerSize
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Gambar full-width (edge-to-edge), scaledToFit agar utuh seperti desain.
            if let containerSize = containerSize {
                ZStack(alignment: .bottom) {
                    if let size = imageSize {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: size.width, height: size.height)
                    } else {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(width: containerSize.width, height: containerSize.height)
                .padding(.top, 120)
            } else {
                if let size = imageSize {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: size.width, height: size.height)
                } else {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                }
            }

            Spacer(minLength: 105)

            VStack(spacing: 15) {
                Text(title)
                    .font(.title1Semibold)
                    .foregroundColor(.neutralColorPrimaryBlack1)
                    .multilineTextAlignment(.center)

                Text(caption)
                    .font(.captionRegular)
                    .foregroundColor(.neutralColorPrimaryBlack1)
                    .multilineTextAlignment(.center)
                    .frame(width: 363)
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
            caption: "Welcome Angler!\nidentify your catch instantly with AR-powered camera technology. Fast, easy and fun.",
            imageSize: CGSize(width: 190.75, height: 202.87),
            containerSize: CGSize(width: 363, height: 441)
        )
    }
}

