import SwiftUI
import ImageIO
import UIKit

struct GifImageView: UIViewRepresentable {
    let name: String
    let bundle: Bundle = .main
    
    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        return imageView
    }
    
    func updateUIView(_ uiView: UIImageView, context: Context) {
        guard let url = bundle.url(forResource: name, withExtension: "gif") else {
            if let data = NSDataAsset(name: name)?.data {
                uiView.image = UIImage.animatedImage(with: data)
            }
            return
        }
        if let data = try? Data(contentsOf: url) {
            uiView.image = UIImage.animatedImage(with: data)
        }
    }
}

extension UIImage {
    static func animatedImage(with data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        
        let count = CGImageSourceGetCount(source)
        var images: [UIImage] = []
        var duration: TimeInterval = 0
        
        for i in 0..<count {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                images.append(UIImage(cgImage: cgImage))
            }
            
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any],
               let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any],
               let delay = gifProperties[kCGImagePropertyGIFDelayTime] as? TimeInterval {
                duration += delay
            } else {
                duration += 0.1
            }
        }
        
        return UIImage.animatedImage(with: images, duration: duration)
    }
}
