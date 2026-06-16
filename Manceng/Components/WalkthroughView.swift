
//
//  WalkthroughView.swift
//  Manceng
//
//  Created by Raihan Zhaky Al Hafizh on 16/06/26.
//

import SwiftUI

struct WalkthroughStep: Identifiable {
    let id = UUID()
    let text: String
}

struct WalkthroughView: View {
    let steps: [WalkthroughStep]
    @Binding var currentStep: Int
    let onNext: () -> Void
    
    init(
        steps: [WalkthroughStep] = [
            WalkthroughStep(text: "View your 5 latest, heaviest, or longest catches"),
            WalkthroughStep(text: "Take photos of your catches with AR measurement"),
            WalkthroughStep(text: "Save and share your fishing history"),
            WalkthroughStep(text: "Discover new fishing spots nearby")
        ],
        currentStep: Binding<Int> = .constant(0),
        onNext: @escaping () -> Void = {}
    ) {
        self.steps = steps
        self._currentStep = currentStep
        self.onNext = onNext
    }
    
    var body: some View {
        Button(action: onNext) {
            VStack(spacing: 0) {
                Text(steps[currentStep].text)
                    .font(.system(size: 28, weight: .bold, design: .default))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                
                HStack(spacing: 16) {
                    Text("\(currentStep + 1)/\(steps.count)")
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundColor(.black)
                    
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 40, weight: .regular))
                        .foregroundColor(.black)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.white.opacity(0.95))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct WalkthroughContainerView: View {
    let steps: [WalkthroughStep]
    @State private var currentStep = 0
    
    init(steps: [WalkthroughStep] = [
        WalkthroughStep(text: "View your 5 latest, heaviest, or longest catches"),
        WalkthroughStep(text: "Take photos of your catches with AR measurement"),
        WalkthroughStep(text: "Save and share your fishing history"),
        WalkthroughStep(text: "Discover new fishing spots nearby")
    ]) {
        self.steps = steps
    }
    
    var body: some View {
        WalkthroughView(
            steps: steps,
            currentStep: $currentStep,
            onNext: {
                if currentStep < steps.count - 1 {
                    currentStep += 1
                }
            }
        )
    }
}

#Preview {
    WalkthroughContainerView()
        .padding()
        .background(Color.yellow.opacity(0.8))
}
