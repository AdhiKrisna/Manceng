
//
//  ShareTemplate.swift
//  Manceng
//
//  Created by Trae on 16/06/26.
//

import SwiftUI

struct ShareTemplate: Identifiable {
    enum Kind {
        case template1
        case template2
        case template3
    }

    let id: Int
    let kind: Kind
    let name: String
    let assetName: String
    let backgroundColorHex: String
    let textColor: Color
    let accentColor: Color

    var backgroundColor: Color {
        Color(hex: backgroundColorHex)
    }
}

extension ShareTemplate {
    static let all: [ShareTemplate] = [
        ShareTemplate(
            id: 0,
            kind: .template1,
            name: "Template 1",
            assetName: "shareTemplate1",
            backgroundColorHex: "#DEDEDE",
            textColor: .neutralColorPrimaryBlack1,
            accentColor: .neutralColorPrimaryBlack1
        ),
        ShareTemplate(
            id: 1,
            kind: .template2,
            name: "Template 2",
            assetName: "shareTemplate2",
            backgroundColorHex: "#DEDEDE",
            textColor: .neutralColorPrimaryBlack1,
            accentColor: .neutralColorPrimaryBlack1
        ),
        ShareTemplate(
            id: 2,
            kind: .template3,
            name: "Template 3",
            assetName: "shareTemplate3",
            backgroundColorHex: "#1E3458",
            textColor: .white,
            accentColor: .white
        )
    ]
}
