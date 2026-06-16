//
//  AppIcons.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 10/06/26.
//

import SwiftUI
enum AppIcons {
    case home
    case map
    case camera
    case history

    var systemName: String {
        switch self {
        case .home:
            return "house.fill"
        case .map:
            return "map.fill"
        case .camera:
            return "camera.fill"
        case .history:
            return "fish.fill"
        }
    }

    var size: CGFloat {
        switch self {
        case .camera:
            return 44
        case .home, .map, .history:
            return 30
        }
    }
}
