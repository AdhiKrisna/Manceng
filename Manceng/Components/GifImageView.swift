import SwiftUI
import ImageIO
import UIKit

struct GifImageView: UIViewRepresentable {
    let name: String
    let bundle: Bundle = .main

    /// Cache statis supaya GIF yang sama tidak dibaca ulang dari disk tiap kali
    /// SwiftUI memanggil `updateUIView`.
    private static var cache: [String: UIImage] = [:]

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        if let cached = Self.cache[name] {
            if uiView.image !== cached {
                uiView.image = cached
                uiView.startAnimating()
            }
            return
        }
        guard let image = loadGIF() else {
            print("[GifImageView] ❌ GIF '\(name)' tidak ditemukan. " +
                  "Pastikan file '\(name).gif' ter-copy ke bundle " +
                  "(Build Phases → Copy Bundle Resources) ATAU ada Data Set " +
                  "bernama '\(name)' di Assets.xcassets.")
            return
        }
        Self.cache[name] = image
        uiView.image = image
        uiView.startAnimating()
    }

    private func loadGIF() -> UIImage? {
        // 1) File .gif loose di bundle (paling umum).
        if let url = bundle.url(forResource: name, withExtension: "gif"),
           let data = try? Data(contentsOf: url) {
            print("[GifImageView] ✅ loaded '\(name).gif' dari bundle URL")
            return UIImage.animatedImage(with: data)
        }
        // 2) Data Asset di Assets.xcassets dengan nama persis.
        if let data = NSDataAsset(name: name, bundle: bundle)?.data {
            print("[GifImageView] ✅ loaded '\(name)' dari Data Asset")
            return UIImage.animatedImage(with: data)
        }
        // 3) Data Asset yang terlanjur dinamai dengan ekstensi .gif.
        let withExt = "\(name).gif"
        if let data = NSDataAsset(name: withExt, bundle: bundle)?.data {
            print("[GifImageView] ✅ loaded '\(withExt)' dari Data Asset")
            return UIImage.animatedImage(with: data)
        }
        return nil
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
