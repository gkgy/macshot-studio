import Foundation
import CoreImage
import Vision

/// Serializes Vision requests. Face anchoring uses the current frame only: seeking
/// and export frame scheduling cannot change the resulting portrait position.
nonisolated final class StudioBackgroundProcessor: @unchecked Sendable {
    private let lock = NSLock()
    private let request = VNGeneratePersonSegmentationRequest()
    private let faces = VNDetectFaceRectanglesRequest()
    private let customBackground: CIImage?
    private var artwork: [String: CIImage] = [:]
    init() {
        request.qualityLevel = .balanced
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        let custom = StudioPreferences.backgroundPath
        let url = custom.isEmpty ? Bundle.main.url(forResource: "StudioBackground", withExtension: "png") : URL(fileURLWithPath: custom)
        customBackground = url.flatMap { CIImage(contentsOf: $0) }
    }

    /// Translation only, with bounds and a user-adjustable strength. No zooming
    /// from face-box size, which would amplify detector noise and head rotation.
    static func anchoring(face: CGRect, extent: CGRect, strength: Double) -> CGAffineTransform {
        let amount = CGFloat(min(1, max(0, strength)))
        let dx = min(extent.width * 0.22, max(-extent.width * 0.22, (0.5 - face.midX) * extent.width))
        let dy = min(extent.height * 0.25, max(-extent.height * 0.25, (0.66 - face.midY) * extent.height))
        return CGAffineTransform(translationX: dx * amount, y: dy * amount)
    }
    func composite(_ frame: CIImage, style: VideoCameraStyle) -> CIImage {
        guard frame.extent.width > 0, frame.extent.height > 0 else { return frame }
        lock.lock(); defer { lock.unlock() }
        do {
            let origin = frame.extent.origin
            let normalized = frame.transformed(by: CGAffineTransform(translationX: -origin.x, y: -origin.y))
            let extent = normalized.extent
            let scale = min(1, 640 / max(extent.width, extent.height))
            let small = normalized.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            var requests: [VNRequest] = []
            if style.techBackground { requests.append(request) }
            if style.stabilizePerson { requests.append(faces) }
            try VNImageRequestHandler(ciImage: small, options: [:]).perform(requests)
            var transform = CGAffineTransform.identity
            if style.stabilizePerson, let face = faces.results?.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }) {
                transform = Self.anchoring(face: face.boundingBox, extent: extent, strength: style.stabilizationStrength)
            }
            var result: CIImage
            if style.techBackground, let matte = request.results?.first?.pixelBuffer {
                let mask = CIImage(cvPixelBuffer: matte)
                let fitted = mask.transformed(by: CGAffineTransform(scaleX: extent.width / mask.extent.width, y: extent.height / mask.extent.height))
                    .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.65]).cropped(to: extent)
                let key = "\(style.backgroundPreset)-\(style.backgroundPatternScale)"
                let bg: CIImage
                if style.backgroundPreset == "custom", let customBackground { bg = customBackground }
                else if let cached = artwork[key] { bg = cached }
                else if let built = StudioCameraBackgrounds.image(id: style.backgroundPreset, patternScale: style.backgroundPatternScale) {
                    artwork[key] = built; bg = built
                } else { return frame }
                let s = max(extent.width / bg.extent.width, extent.height / bg.extent.height)
                let scaled = bg.transformed(by: CGAffineTransform(scaleX: s, y: s))
                let backdrop = scaled.transformed(by: CGAffineTransform(translationX: (extent.width - scaled.extent.width) / 2, y: (extent.height - scaled.extent.height) / 2)).cropped(to: extent)
                    .applyingFilter("CIColorControls", parameters: [kCIInputBrightnessKey: style.backgroundBrightness])
                // Move foreground and matte together; the new background stays still.
                let foreground = normalized.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: CIImage(color: .clear).cropped(to: extent), kCIInputMaskImageKey: fitted])
                result = foreground.transformed(by: transform).composited(over: backdrop).cropped(to: extent)
            } else {
                // Original-background mode uses edge extension to avoid black borders.
                result = normalized.clampedToExtent().transformed(by: transform).cropped(to: extent)
            }
            return result.transformed(by: CGAffineTransform(translationX: origin.x, y: origin.y))
        } catch { return frame }
    }
}
