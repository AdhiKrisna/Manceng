//
//  OnBoardingView.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 10/06/26.
//

import SwiftUI

struct OnBoardingView: View {
    let data: [OnBoardingModel] = onBoardingData
    let onComplete: () -> Void
    @State private var currentPage = 0
    
    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }
    
    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                ForEach(data.indices, id: \.self) { index in
                    let item = data[index]
                    OnBoarding(
                        image: Image(item.image),
                        title: item.title,
                        caption: item.caption,
                        imageSize: item.image == "onboarding" ? CGSize(width: 250, height: 250) : nil,
                        containerSize: item.image == "onboarding" ? CGSize(width: 400, height: 300) : nil,
                        imageOffsetY: item.image == "onboarding" ? 0 : 30
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            Spacer().frame(height: 80)
            
            CustomButton(title: currentPage == data.count - 1 ? "Start" : "Next") {
                if currentPage < data.count - 1 {
                    currentPage += 1
                } else {
                    onComplete()
                }
            }
        }
        .background(Color.brandColorPrimaryYellow.ignoresSafeArea())
    }
}

#Preview {
    OnBoardingView {}
}
