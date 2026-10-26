import CoreGraphics
import CoreImage

/// Bright, centered artwork: patterns remain visible after the webcam's square crop.
nonisolated enum StudioCameraBackgrounds {
    struct Preset: Sendable {
        let id: String
        let title: String
        let first: [CGFloat]
        let second: [CGFloat]
    }
    static let all: [Preset] = [
        .init(id: "cyan-grid", title: "青蓝网格", first: [0.10,0.62,0.85], second: [0.30,0.86,0.94]),
        .init(id: "violet-orbit", title: "紫色光环", first: [0.49,0.30,0.85], second: [0.82,0.63,1.0]),
        .init(id: "mint-circuit", title: "薄荷电路", first: [0.12,0.66,0.57], second: [0.62,0.94,0.75]),
        .init(id: "sunrise-lines", title: "橙金光束", first: [0.93,0.43,0.18], second: [1.0,0.80,0.36]),
        .init(id: "ice-grid", title: "冰蓝矩阵", first: [0.39,0.70,0.93], second: [0.86,0.95,1.0]),
        .init(id: "rose-orbit", title: "玫瑰星环", first: [0.82,0.31,0.58], second: [1.0,0.73,0.85]),
        .init(id: "lime-circuit", title: "青柠芯片", first: [0.46,0.67,0.12], second: [0.83,0.95,0.40]),
        .init(id: "cobalt-lines", title: "钴蓝光带", first: [0.20,0.40,0.84], second: [0.43,0.77,1.0]),
        .init(id: "pearl-grid", title: "珍珠白格", first: [0.72,0.78,0.86], second: [0.96,0.98,1.0]),
        .init(id: "lavender-orbit", title: "薰衣草环", first: [0.64,0.52,0.87], second: [0.89,0.85,1.0]),
        .init(id: "teal-circuit", title: "湖绿数据", first: [0.08,0.52,0.63], second: [0.41,0.87,0.83]),
        .init(id: "coral-lines", title: "珊瑚流光", first: [0.90,0.40,0.35], second: [1.0,0.77,0.59])
    ]
    static func image(id: String, patternScale: Double) -> CIImage? {
        let index = all.firstIndex { $0.id == id } ?? 0
        let preset = all[index]
        let size = 640
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let gradient = CGGradient(colorsSpace: space, colors: [CGColor(colorSpace: space, components: preset.first + [1])!, CGColor(colorSpace: space, components: preset.second + [1])!] as CFArray, locations: [0,1]) else { return nil }
        ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 640,y:640), options: [.drawsBeforeStartLocation,.drawsAfterEndLocation])
        ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.48))
        ctx.setLineWidth(3)
        let spacing = CGFloat(64 * min(2, max(0.5, patternScale)))
        switch index % 4 {
        case 0:
            for p in stride(from: CGFloat(0), through: 640, by: spacing) {
                ctx.move(to: CGPoint(x:p,y:0));ctx.addLine(to: CGPoint(x:p,y:640))
                ctx.move(to: CGPoint(x:0,y:p));ctx.addLine(to: CGPoint(x:640,y:p))
            }
        case 1:
            for r in stride(from: spacing, through: 560, by: spacing) { ctx.addEllipse(in: CGRect(x:320-r,y:320-r,width:r*2,height:r*2)) }
        case 2:
            for p in stride(from: CGFloat(0), through: 640, by: spacing) {
                ctx.move(to: CGPoint(x:0,y:p));ctx.addLine(to: CGPoint(x:200,y:p));ctx.addLine(to: CGPoint(x:300,y:p+50));ctx.addLine(to: CGPoint(x:640,y:p+50))
                ctx.addEllipse(in:CGRect(x:190,y:p-6,width:12,height:12))
            }
        default:
            ctx.setLineWidth(12)
            for p in stride(from: CGFloat(-640), through: 640, by: spacing*1.8) { ctx.move(to:CGPoint(x:p,y:0));ctx.addLine(to:CGPoint(x:p+640,y:640)) }
        }
        ctx.strokePath()
        return ctx.makeImage().map { CIImage(cgImage: $0) }
    }
}
