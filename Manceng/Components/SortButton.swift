//
//  SortButton.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 17/06/26.
//

import SwiftUI

enum SortOption: String, CaseIterable, Identifiable {
    case latest = "Latest"
    case weight = "Heaviest"
    case length = "Longest"

    var id: String { rawValue }
}

struct SortButton: View {
    @Binding var selectedSort: SortOption

    var body: some View {
        Menu {
            ForEach(SortOption.allCases) { option in
                Button {
                    selectedSort = option
                } label: {
                    HStack {
                        Text(option.rawValue)

                        if selectedSort == option {
                            Image(systemName: "checkmark").foregroundStyle(Color.neutralColorPrimaryBlack1)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 43, height: 43)
                .glassStyle(Circle())
        }
        .buttonStyle(GlassPressStyle())
    }
}

#Preview {
    SortButton(selectedSort: .constant(.latest))
        .padding()
}
