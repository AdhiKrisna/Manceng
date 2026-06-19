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
                    OnBoarding(
                        image: Image(data[index].image),
                        title: data[index].title,
                        caption: data[index].caption
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            CustomButton(title: currentPage == data.count - 1 ? "Start" : "Next") {
                if currentPage < data.count - 1 {
                    currentPage += 1
                } else {
                    onComplete()
                }
            }
        }
        .background(Color.BrandColorPrimaryYellow.ignoresSafeArea())
    }
}

#Preview {
    OnBoardingView {}
}
