import AppKit
import AVFoundation
import PingCore

/// Captures this app's own renderer, not the desktop. Does not request screen
/// recording permission, create input taps, or alter the user's preferences.
enum VisualChecks {
    static func bitmap(size: CGSize, pixelScale: CGFloat = 2, draw: () -> Void) -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width*pixelScale), pixelsHigh: Int(size.height*pixelScale), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        let graphics = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.current = graphics
        // NSGraphicsContext derives the pixel transform from rep.size.
        NSColor(srgbRed: 0.04, green: 0.065, blue: 0.09, alpha: 1).setFill()
        NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
        draw()
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }
    static func draw(_ view: NSView, at point: CGPoint) {
        let context = NSGraphicsContext.current!.cgContext
        context.saveGState(); context.translateBy(x: point.x, y: point.y)
        view.draw(view.bounds)
        // Composite the transparent app layer onto the export backdrop. Some
        // image viewers ignore alpha; opaque exports also show the actual glow.
        context.setBlendMode(.destinationOver)
        context.setFillColor(NSColor(srgbRed: 0.04, green: 0.065, blue: 0.09, alpha: 1).cgColor)
        context.fill(view.bounds)
        context.restoreGState()
    }
    static func save(_ rep: NSBitmapImageRep, to url: URL) throws {
        try rep.representation(using: .png, properties: [:])!.write(to: url)
    }
    static func run(to directory: URL) throws {
        _ = NSApplication.shared
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try checkEffectLifecycle()
        for scale in [0.75, 1.0, 1.5] {
            let side = CGFloat(300*scale), spacing = CGFloat(16)
            let rep = bitmap(size: CGSize(width: side*3+spacing*4, height: side*3+spacing*4)) {
                for (index, kind) in PingKind.allCases.enumerated() {
                    let view = WheelView(frame: CGRect(x: 0, y: 0, width: side, height: side))
                    let angle: CGFloat? = kind == .generic ? nil : CGFloat(PingKind.wheel.firstIndex(of: kind)!) * .pi/4
                    view.setSelection(kind, angle: angle, animated: false)
                    draw(view, at: CGPoint(x: spacing+CGFloat(index%3)*(side+spacing), y: spacing+CGFloat(2-index/3)*(side+spacing)))
                }
            }
            try save(rep, to: directory.appendingPathComponent("wheel-\(Int(scale*100))-retina.png"))
        }
        // 1x output also catches reliance on Retina-only sampling.
        let view = WheelView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        view.setSelection(.missing, angle: -.pi/2, animated: false)
        try save(bitmap(size: CGSize(width: 300, height: 300), pixelScale: 1) { draw(view, at: .zero) }, to: directory.appendingPathComponent("wheel-100-1x.png"))
        let times = [0.08, 0.25, 0.65, 1.3, 1.85]
        let phases = bitmap(size: CGSize(width: 900, height: 180*9)) {
            for (row, kind) in PingKind.allCases.enumerated() {
                for (column, time) in times.enumerated() {
                    let effect = PingEffectView(frame: CGRect(x: 0, y: 0, width: 180, height: 180), kind: kind, scale: 1)
                    effect.seek(to: time)
                    draw(effect, at: CGPoint(x: column*180, y: (8-row)*180))
                }
            }
        }
        try save(phases, to: directory.appendingPathComponent("effect-phases-retina.png"))
        try movie(to: directory.appendingPathComponent("LoLPing-effects-demo.mov"))
        print("Visual snapshots and renderer demo saved: \(directory.path)")
    }
    private static func checkEffectLifecycle() throws {
        let size = CGSize(width: 220, height: 220)
        func pixels(_ rep: NSBitmapImageRep) -> Data {
            Data(bytes: rep.bitmapData!, count: rep.bytesPerRow*rep.pixelsHigh)
        }
        let backdrop = pixels(bitmap(size: size) {})
        for kind in PingKind.allCases {
            let effect = PingEffectView(frame: CGRect(origin: .zero, size: size), kind: kind, scale: 1)
            effect.seek(to: 0.25)
            let early = pixels(bitmap(size: size) { draw(effect, at: .zero) })
            effect.seek(to: 1.5)
            let late = pixels(bitmap(size: size) { draw(effect, at: .zero) })
            effect.stop()
            let stopped = pixels(bitmap(size: size) { draw(effect, at: .zero) })
            guard early != backdrop, early != late, stopped == backdrop else {
                throw NSError(domain: "VisualChecks", code: 4, userInfo: [NSLocalizedDescriptionKey: "Animation/stop check failed: \(kind.title)"])
            }
        }
        print("PASS 9 effects: visible animation changes and immediate stop (27 pixel comparisons).")
    }
    private static func movie(to url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        let size = CGSize(width: 960, height: 720), fps = 30, frames = 330
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: Int(size.width), AVVideoHeightKey: Int(size.height)])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: Int(size.width), kCVPixelBufferHeightKey as String: Int(size.height), kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error! }
        writer.startSession(atSourceTime: .zero)
        let wheel = WheelView(frame: CGRect(x: 0, y: 0, width: 450, height: 450))
        var previous = -1
        for frame in 0..<frames {
            let t = Double(frame)/Double(fps)
            let rep = bitmap(size: size, pixelScale: 1) {
                if t < 7 {
                    let segment = max(-1, Int((t-0.6)/0.65))
                    let kind: PingKind = t < 0.6 ? .generic : (segment < 8 ? PingKind.wheel[segment] : .generic)
                    let angle: CGFloat? = kind == .generic ? nil : CGFloat(segment) * .pi/4 + CGFloat(sin(t*7))*0.15
                    if segment != previous { wheel.setSelection(wheel.selected, angle: wheel.direction, animated: false); previous = segment }
                    wheel.setSelection(kind, angle: angle)
                    wheel.sampleTransition(elapsed: t < 0.6 ? 1 : (t-0.6).truncatingRemainder(dividingBy: 0.65))
                    draw(wheel, at: CGPoint(x: 255, y: 135))
                    caption("轮盘：放大 · 方向指示 · 中央说明", center: CGPoint(x: 480, y: 70))
                } else {
                    let age = (t-7).truncatingRemainder(dividingBy: 2)
                    for (index, kind) in PingKind.allCases.enumerated() {
                        let effect = PingEffectView(frame: CGRect(x: 0, y: 0, width: 240, height: 200), kind: kind, scale: 1.2)
                        effect.seek(to: age)
                        draw(effect, at: CGPoint(x: 120+(index%3)*240, y: 65+(2-index/3)*205))
                    }
                    caption("九种信号：浮起 · 光圈扩散 · 淡出", center: CGPoint(x: 480, y: 35))
                }
            }
            while !input.isReadyForMoreMediaData { RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.005)) }
            var buffer: CVPixelBuffer?
            guard let pool = adaptor.pixelBufferPool, CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess, let buffer else { throw NSError(domain: "VisualChecks", code: 1) }
            CVPixelBufferLockBaseAddress(buffer, [])
            let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
            context.setFillColor(NSColor(srgbRed: 0.04, green: 0.065, blue: 0.09, alpha: 1).cgColor); context.fill(CGRect(origin: .zero, size: size))
            context.draw(rep.cgImage!, in: CGRect(origin: .zero, size: size))
            CVPixelBufferUnlockBaseAddress(buffer, [])
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: Int32(fps))) else { throw writer.error ?? NSError(domain: "VisualChecks", code: 2) }
        }
        input.markAsFinished()
        let done = DispatchSemaphore(value: 0)
        writer.finishWriting { done.signal() }
        done.wait()
        guard writer.status == .completed else { throw writer.error ?? NSError(domain: "VisualChecks", code: 3) }
    }
    private static func caption(_ string: String, center: CGPoint) {
        let text = NSAttributedString(string: string, attributes: [.font: NSFont.systemFont(ofSize: 20, weight: .medium), .foregroundColor: NSColor(white: 0.8, alpha: 1)])
        text.draw(at: CGPoint(x: center.x-text.size().width/2, y: center.y))
    }
}
