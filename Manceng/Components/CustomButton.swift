
//
//  CustomButton.swift
//  Manceng
//
//  Created by Raihan Zhaky Al Hafizh on 16/06/26.
//

import SwiftUI

struct CustomButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.buttonFont)
                    .foregroundColor(.neutralColorPrimaryLemon)
            }
            .frame(width: 363, height: 58, alignment: .center)
            .background(Color.neutralColorPrimaryBrown1)
            .clipShape(RoundedRectangle(cornerRadius: Radius.borderRadius))
        }
    }
}

#Preview {
    CustomButton(title: "Next", action: {})
}
