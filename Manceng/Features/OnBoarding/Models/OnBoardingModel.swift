//
//  OnBoardingModel.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 10/06/26.
//

import Foundation

struct OnBoardingModel: Identifiable {
    let id = UUID()
    let image: String
    let title: String
    let caption: String
}

let onBoardingData: [OnBoardingModel] = [
    OnBoardingModel(
        image: "onboarding",
        title: "FiShare",
        caption: "Welcome Angler!\nidentify your catch instantly with AR-powered camera technology. Fast, easy and fun."
    ),
    OnBoardingModel(
        image: "onboarding1",
        title: "Capture",
        caption: "Every catch has a story. Capture your special moment with a single shot, and let the app identify all the details for you."
    ),
    OnBoardingModel(
        image: "onboarding2",
        title: "Summary",
        caption: "No need to keep track of everything manually. Your catch details, including species, estimated weight, length, and location, are automatically organized in one place."
    ),
    OnBoardingModel(
        image: "onboarding3",
        title: "Template",
        caption: "Every fish you catch is worth remembering. Choose your favorite template and share your best catches with a stunning presentation."
    )
]

