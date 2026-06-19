
//
//  ShareTemplate.swift
//  Manceng
//
//  Created by Trae on 16/06/26.
//

import SwiftUI

struct ShareTemplate: Identifiable {
    let id = UUID()
    let name: String
    let previewImage: Image?
    let backgroundColorHex: String
    let cardColorHex: String
    let textColor: Color
    let accentColor: Color

    var backgroundColor: Color {
        Color(hex: backgroundColorHex)
    }

    var cardColor: Color {
        Color(hex: cardColorHex)
    }
}

extension ShareTemplate {
    static let all: [ShareTemplate] = [
        ShareTemplate(
            name: "Classic",
            previewImage: nil,
            backgroundColorHex: "#FFCC00",
            cardColorHex: "#8A8A8A",
            textColor: .neutralColorPrimaryBlack1,
            accentColor: .white
        ),
        ShareTemplate(
            name: "Ocean Blue",
            previewImage: nil,
            backgroundColorHex: "#1A6699",
            cardColorHex: "#0F4566",
            textColor: .white,
            accentColor: .brandColorPrimaryYellow
        ),
        ShareTemplate(
            name: "Sunset Orange",
            previewImage: nil,
            backgroundColorHex: "#E6661A",
            cardColorHex: "#A8480F",
            textColor: .white,
            accentColor: .white
        ),
        ShareTemplate(
            name: "Forest Green",
            previewImage: nil,
            backgroundColorHex: "#1A8033",
            cardColorHex: "#0F5424",
            textColor: .white,
            accentColor: .yellow
        )
    ]
}
