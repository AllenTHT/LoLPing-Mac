import AppKit

let destination = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let pixels = size*factor
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let s = CGFloat(pixels), inset = s*0.04
        let rect = CGRect(x: inset, y: inset, width: s-inset*2, height: s-inset*2)
        NSColor(srgbRed: 0.04, green: 0.08, blue: 0.12, alpha: 1).setFill()
        NSBezierPath(roundedRect: rect, xRadius: s*0.22, yRadius: s*0.22).fill()
        let gold = NSColor(srgbRed: 0.89, green: 0.73, blue: 0.40, alpha: 1)
        gold.withAlphaComponent(0.65).setStroke()
        let ring = NSBezierPath(ovalIn: CGRect(x: s*0.2, y: s*0.2, width: s*0.6, height: s*0.6))
        ring.lineWidth = s*0.025; ring.stroke()
        let diamond = NSBezierPath()
        diamond.move(to: CGPoint(x: s*0.5, y: s*0.82)); diamond.line(to: CGPoint(x: s*0.73, y: s*0.51))
        diamond.line(to: CGPoint(x: s*0.5, y: s*0.25)); diamond.line(to: CGPoint(x: s*0.27, y: s*0.51)); diamond.close()
        gold.setFill(); diamond.fill()
        NSColor(srgbRed: 0.04, green: 0.08, blue: 0.12, alpha: 1).setFill()
        let hole = NSBezierPath()
        hole.move(to: CGPoint(x: s*0.5, y: s*0.65)); hole.line(to: CGPoint(x: s*0.60, y: s*0.51))
        hole.line(to: CGPoint(x: s*0.5, y: s*0.40)); hole.line(to: CGPoint(x: s*0.40, y: s*0.51)); hole.close(); hole.fill()
        NSGraphicsContext.restoreGraphicsState()
        let filename = "icon_\(size)x\(size)\(factor == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent(filename))
    }
}
