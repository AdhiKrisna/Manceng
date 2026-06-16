//
//  FishSegmentationService.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 10/06/26.
//

import UIKit

final class CameraService {
    private let segmentationService = FishSegmentationService()

    func segment(image: UIImage, completion: @escaping ([SegmentedFish]) -> Void) {
        segmentationService.segment(image: image, completion: completion)
    }
}

