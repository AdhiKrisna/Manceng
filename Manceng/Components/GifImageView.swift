import SwiftUI
import ImageIO
import UIKit

struct GifImageView: UIViewRepresentable {
    let name: String
    let bundle: Bundle = .main

    /// Cache statis supaya GIF yang sama tidak di-decode ulang tiap kali
    /// SwiftUI memanggil `updateUIView`.
    private static var cache: [String: GifAsset] = [:]

    func makeUIView(context: Context) -> AnimatedGifView {
        let view = AnimatedGifView()
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        // Supaya SwiftUI `.frame(...)` dihormati dan UIImageView tidak memaksa
        // pakai intrinsicContentSize dari GIF (yang bisa sangat besar).
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }

    func updateUIView(_ uiView: AnimatedGifView, context: Context) {
        if let cached = Self.cache[name] {
            uiView.configure(with: cached)
            return
        }
        guard let asset = loadAsset() else {
            print("[GifImageView] ❌ GIF '\(name)' tidak ditemukan. " +
                  "Pastikan file '\(name).gif' ter-copy ke bundle " +
                  "(Build Phases → Copy Bundle Resources) ATAU ada Data Set " +
                  "bernama '\(name)' di Assets.xcassets.")
            return
        }
        Self.cache[name] = asset
        uiView.configure(with: asset)
    }

    private func loadAsset() -> GifAsset? {
        // 1) File .gif loose di bundle (paling umum).
        if let url = bundle.url(forResource: name, withExtension: "gif"),
           let data = try? Data(contentsOf: url),
           let asset = GifAsset(data: data) {
            return asset
        }
        // 2) Data Asset di Assets.xcassets dengan nama persis.
        if let data = NSDataAsset(name: name, bundle: bundle)?.data,
           let asset = GifAsset(data: data) {
            return asset
        }
        // 3) Data Asset yang terlanjur dinamai dengan ekstensi .gif.
        if let data = NSDataAsset(name: "\(name).gif", bundle: bundle)?.data,
           let asset = GifAsset(data: data) {
            return asset
        }
        return nil
    }
}

/// GIF hasil decode: frames + per-frame delay (detik).
struct GifAsset {
    let frames: [UIImage]
    let delays: [TimeInterval]

    init?(data: Data) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }

        var frames: [UIImage] = []
        var delays: [TimeInterval] = []
        frames.reserveCapacity(count)
        delays.reserveCapacity(count)

        for i in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            frames.append(UIImage(cgImage: cgImage))
            delays.append(Self.frameDelay(at: i, in: source))
        }

        guard !frames.isEmpty else { return nil }
        self.frames = frames
        self.delays = delays
    }

    private static func frameDelay(at index: Int, in source: CGImageSource) -> TimeInterval {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gifProps = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] else {
            return 0.1
        }
        // Prefer unclamped (delay asli dari GIF spec) over clamped (>= 0.1s).
        var delay: TimeInterval = 0
        if let unclamped = gifProps[kCGImagePropertyGIFUnclampedDelayTime] as? TimeInterval {
            delay = unclamped
        } else if let clamped = gifProps[kCGImagePropertyGIFDelayTime] as? TimeInterval {
            delay = clamped
        }
        // Minimum 20ms (50fps cap) supaya tidak ada frame 0-detik yang bikin loop spin.
        return delay > 0.02 ? delay : 0.1
    }
}

/// `UIImageView` subclass yang memainkan `GifAsset` dengan timing per-frame
/// yang benar via `CADisplayLink`. Otomatis pause saat view lepas dari window.
final class AnimatedGifView: UIImageView {
    private var asset: GifAsset?
    private var displayLink: CADisplayLink?
    private var currentFrameIndex = 0
    private var accumulator: CFTimeInterval = 0
    private var lastTimestamp: CFTimeInterval = 0

    func configure(with asset: GifAsset) {
        // Skip kalau asset yang sama sudah jalan.
        if let current = self.asset,
           current.frames.first === asset.frames.first,
           current.frames.count == asset.frames.count {
            restartFromBeginning()
            ensureDisplayLink()
            return
        }
        self.asset = asset
        restartFromBeginning()
        ensureDisplayLink()
    }

    private func ensureDisplayLink() {
        guard window != nil,
              let asset = asset,
              asset.frames.count > 1,
              displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func tick(_ link: CADisplayLink) {
        guard let asset = asset else { return }
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            return
        }
        let delta = link.timestamp - lastTimestamp
        lastTimestamp = link.timestamp
        accumulator += delta

        // Advance frame berdasarkan akumulasi waktu — loop kalau delta besar
        // (mis. setelah pause) supaya tidak ada drift.
        var advanced = false
        if accumulator >= asset.delays[currentFrameIndex] {
            accumulator -= asset.delays[currentFrameIndex]
            currentFrameIndex = (currentFrameIndex + 1) % asset.frames.count
            advanced = true
        }
        if advanced {
            image = asset.frames[currentFrameIndex]
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            displayLink?.invalidate()
            displayLink = nil
            lastTimestamp = 0
        } else {
            restartFromBeginning()
            ensureDisplayLink()
        }
    }

    private func restartFromBeginning() {
        currentFrameIndex = 0
        accumulator = 0
        lastTimestamp = 0
        if let firstFrame = asset?.frames.first {
            image = firstFrame
        }
    }

    deinit {
        displayLink?.invalidate()
    }
}
