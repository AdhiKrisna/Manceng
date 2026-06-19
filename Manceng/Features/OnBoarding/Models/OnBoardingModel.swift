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
        caption: "Setiap tangkapan punya ceritanya sendiri. Abadikan momen istimewamu hanya dengan satu jepretan, dan biarkan aplikasi mengenali semua detailnya untukmu."
    ),
    OnBoardingModel(
        image: "onboarding2",
        title: "Summary",
        caption: "Tak perlu repot mencatat satu per satu. Semua detail tangkapanmu dari jenis ikan, estimasi berat, hingga lokasi tersimpan rapi secara otomatis."
    ),
    OnBoardingModel(
        image: "onboarding3",
        title: "Template",
        caption: "Setiap ikan yang kamu tangkap layak untuk dikenang. Pilih template favoritmu dan bagikan momen terbaikmu dengan tampilan yang memukau."
    )
]

