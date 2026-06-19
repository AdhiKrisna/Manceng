//
//  SegmentedFishModel.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 10/06/26.
//

import UIKit

struct SegmentedFish: Identifiable {
    let id = UUID()
    var fish: DetectedFish
    let maskImage: UIImage
}
