//
//  Color+Extension.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 10/06/26.
//

import Foundation
import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(
            in: CharacterSet.alphanumerics.inverted
        )
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 6:  // RGB
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  // ARGB
            (a, r, g, b) = (
                int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF
            )
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    static let brandColorPrimaryYellow = Color(hex:"#FFCC00")
    static let neutralColorPrimaryBrown1 = Color(hex:"#855A00").opacity(0.86)
    static let neutralColorSecondaryBrown2 = Color(hex:"#85A00").opacity(0.40)
    static let neutralColorPrimaryLemon = Color(hex:"#F9F799")
    static let neutralColorAccentOrange = Color(hex:"#FF9600")
    static let neutralColorPrimaryBlack1 = Color(hex:"#000000")
    static let neutralColorPrimaryBlack50 = Color(hex:"#000000").opacity(0.50)
    static let neutralColorPrimaryWhite = Color(hex:"#FFFFFF")
}

