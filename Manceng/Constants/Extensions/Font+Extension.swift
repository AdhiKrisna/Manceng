//
//  Font+Extension.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 10/06/26.
//


import SwiftUI

extension Font {
    static let largeTitleBlack = Font.system(size: 34, weight: .black, design: .serif)
    static let title1Bold = Font.system(size: 34, weight: .bold, design: .serif)
    static let title1Semibold = Font.system(size: 28, weight: .semibold, design: .serif)
    static let title2Bold = Font.system(size: 28, weight: .bold, design: .serif)
    static let caption1Bold = Font.system(size: 22, weight: .bold, design: .serif)
    static let buttonFont = Font.system(size: 20, weight: .semibold, design: .serif)
    static let captionRegular = Font.system(size: 15, weight: .regular, design: .serif)
    static let kgCmFont = Font.system(size: 17, weight: .bold, design: .serif)

    static func impactRegular(size: CGFloat) -> Font {
        Font.custom("Impact", size: size)
    }
}
