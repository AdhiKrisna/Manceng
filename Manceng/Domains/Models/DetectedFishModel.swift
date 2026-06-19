//
//  DetectedFishModel.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 10/06/26.
//

import CoreGraphics
import Foundation

struct DetectedFish: Identifiable {
    let id = UUID()
    var boundingBox: CGRect
    let confidence: Float
    var estimatedLengthCm: Double?
    var estimatedWeightKg: Double?
    var species: String?
    var speciesConfidence: Double?
}
