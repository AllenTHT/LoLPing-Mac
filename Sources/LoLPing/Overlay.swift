import AppKit
import QuartzCore
import PingCore

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    init(frame: NSRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false; backgroundColor = .clear; hasShadow = false
        ignoresMouseEvents = true; hidesOnDeactivate = false; isReleasedWhenClosed = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .canJoinAllApplications, .ignoresCycle]
        animationBehavior = .none; isExcludedFromWindowsMenu = true
    }
}

private let wheelGold = NSColor(srgbRed: 0.78, green: 0.66, blue: 0.40, alpha: 1)
private let wheelCyan = NSColor(srgbRed: 0.02, green: 0.81, blue: 0.77, alpha: 1)
private func clamp01(_ value: Double) -> Double { min(1, max(0, value)) }
private func ease(_ value: Double) -> Double { let t = clamp01(value); return t*t*(3-2*t) }
private func mix(_ a: NSColor, _ b: NSColor, _ amount: Double) -> NSColor {
    a.blended(withFraction: CGFloat(clamp01(amount)), of: b) ?? b
}
private func text(_ string: String, at center: CGPoint, size: CGFloat, color: NSColor, weight: NSFont.Weight = .regular) {
    let label = NSAttributedString(string: string, attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
    label.draw(at: CGPoint(x: center.x-label.size().width/2, y: center.y-label.size().height/2))
}

/// The atlas silhouettes, sector glow, center ornament and type are drawn
/// independently at the current backing scale. No bitmap is magnified here.
final class WheelView: NSView {
    private(set) var selected: PingKind = .generic
    private(set) var direction: CGFloat?
    private var weights = Array(repeating: 0.0, count: 8)
    private var origins = Array(repeating: 0.0, count: 8)
    private var transitionStart: CFTimeInterval = 0
    private var openingStart: CFTimeInterval?
    private var timer: Timer?

    override init(frame: NSRect) { super.init(frame: frame); wantsLayer = true }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }
    override var isOpaque: Bool { false }
    override func viewDidChangeBackingProperties() { super.viewDidChangeBackingProperties(); needsDisplay = true }

    func open() { openingStart = CACurrentMediaTime(); startTimer() }
    func setSelection(_ kind: PingKind, angle: CGFloat?, animated: Bool = true) {
        direction = kind == .generic ? nil : angle
        if !animated {
            selected = kind; weights = PingKind.wheel.map { $0 == kind ? 1 : 0 }
            origins = weights; transitionStart = 0; stop(); needsDisplay = true
            return
        }
        updateAnimation(at: CACurrentMediaTime())
        if kind != selected {
            origins = weights; selected = kind; transitionStart = CACurrentMediaTime()
            startTimer()
        }
        needsDisplay = true
    }
    func stop() { timer?.invalidate(); timer = nil; layer?.removeAllAnimations() }
    // Diagnostics sample the same interpolation used by the live timer.
    func sampleTransition(elapsed: Double) {
        updateAnimation(at: transitionStart+elapsed); openingStart = nil; needsDisplay = true
    }
    private func startTimer() {
        guard timer == nil else { return }
        let next = Timer(timeInterval: 1.0/60, repeats: true) { [weak self] _ in
            guard let self else { return }
            let now = CACurrentMediaTime()
            self.updateAnimation(at: now); self.needsDisplay = true
            if now-self.transitionStart >= 0.12 && (self.openingStart == nil || now-self.openingStart! >= 0.09) {
                self.stop(); self.openingStart = nil
            }
        }
        timer = next; RunLoop.main.add(next, forMode: .common)
    }
    private func updateAnimation(at now: CFTimeInterval) {
        guard transitionStart > 0 else { return }
        let progress = ease((now-transitionStart)/0.12)
        weights = PingKind.wheel.enumerated().map { index, kind in
            origins[index] + ((kind == selected ? 1.0 : 0.0)-origins[index])*progress
        }
    }
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(bounds)
        context.saveGState()
        if let start = openingStart { context.setAlpha(CGFloat(ease((CACurrentMediaTime()-start)/0.09))) }
        let s = bounds.width/300, c = CGPoint(x: bounds.midX, y: bounds.midY)
        let outer = WheelGeometry.outerRadius*s, inner = WheelGeometry.centerRadius*s
        for (index, kind) in PingKind.wheel.enumerated() {
            let degrees = CGFloat(90-index*45), theta = degrees * .pi/180
            let sector = NSBezierPath()
            sector.appendArc(withCenter: c, radius: outer, startAngle: degrees+22.5, endAngle: degrees-22.5, clockwise: true)
            sector.appendArc(withCenter: c, radius: inner, startAngle: degrees-22.5, endAngle: degrees+22.5, clockwise: false)
            sector.close()
            context.saveGState(); sector.addClip()
            NSGradient(colors: [NSColor(white: 0.035, alpha: 0.60), NSColor(white: 0.025, alpha: 0)])?.draw(fromCenter: c, radius: inner, toCenter: c, radius: outer, options: [.drawsBeforeStartingLocation])
            let weight = weights[index]
            if weight > 0.001 {
                NSGradient(colorsAndLocations: (wheelCyan.withAlphaComponent(0.85*weight), 0), (wheelCyan.withAlphaComponent(0.32*weight), 0.6), (wheelCyan.withAlphaComponent(0), 1))?.draw(fromCenter: c, radius: inner, toCenter: c, radius: outer, options: [.drawsBeforeStartingLocation])
            }
            context.restoreGState()
            let boundary = (degrees+22.5) * .pi/180
            let divider = NSBezierPath()
            divider.move(to: CGPoint(x: c.x+cos(boundary)*inner, y: c.y+sin(boundary)*inner))
            divider.line(to: CGPoint(x: c.x+cos(boundary)*outer, y: c.y+sin(boundary)*outer))
            wheelGold.withAlphaComponent(0.30).setStroke(); divider.lineWidth = 0.55*s; divider.stroke()
            let p = CGPoint(x: c.x+cos(theta)*WheelGeometry.iconRadius*s, y: c.y+sin(theta)*WheelGeometry.iconRadius*s)
            let side = CGFloat(22+8*weight)*s
            let color = mix(kind.wheelIdleTint, kind.tint, weight)
            Assets.draw(kind, in: CGRect(x: p.x-side/2, y: p.y-side/2, width: side, height: side), color: color)
        }
        let coreRect = CGRect(x: c.x-inner, y: c.y-inner, width: inner*2, height: inner*2)
        let core = NSBezierPath(ovalIn: coreRect)
        NSColor(white: 0.025, alpha: 0.94).setFill(); core.fill()
        if selected == .generic {
            context.saveGState(); core.addClip()
            NSGradient(colors: [NSColor(white: 0.03, alpha: 0), wheelCyan.withAlphaComponent(0.19)])?.draw(fromCenter: c, radius: 0, toCenter: c, radius: inner, options: [])
            context.restoreGState()
        }
        wheelGold.withAlphaComponent(0.70).setStroke(); core.lineWidth = 1.2*s; core.stroke()
        let ring = NSBezierPath(ovalIn: coreRect.insetBy(dx: 3*s, dy: 3*s))
        wheelGold.setStroke(); ring.lineWidth = 1.4*s; ring.stroke()
        if let angle = direction {
            let theta = CGFloat.pi/2-angle
            func point(_ radius: CGFloat, _ offset: CGFloat = 0) -> CGPoint {
                CGPoint(x: c.x+cos(theta+offset)*radius, y: c.y+sin(theta+offset)*radius)
            }
            let notch = NSBezierPath()
            notch.move(to: point(inner, 0.06)); notch.line(to: point(inner+6*s)); notch.line(to: point(inner, -0.06))
            wheelGold.setStroke(); notch.lineWidth = 1.7*s; notch.lineJoinStyle = .miter; notch.stroke()
            let arc = NSBezierPath()
            let degrees = theta*180 / .pi
            arc.appendArc(withCenter: c, radius: inner-7*s, startAngle: degrees-18, endAngle: degrees+18)
            wheelCyan.setStroke(); arc.lineWidth = 1.8*s; arc.stroke()
        }
        if selected == .generic {
            Assets.draw(.generic, in: CGRect(x: c.x-11*s, y: c.y+18*s, width: 22*s, height: 22*s))
            text("信号", at: CGPoint(x: c.x, y: c.y+1*s), size: 13*s, color: PingKind.generic.tint, weight: .semibold)
        } else {
            text(selected.title, at: c, size: 13*s, color: selected.tint, weight: .semibold)
        }
        text("右键取消", at: CGPoint(x: c.x, y: c.y-31*s), size: 8.5*s, color: NSColor(white: 0.52, alpha: 0.9))
        context.restoreGState()
    }
}

/// One renderer is used by live overlays, window previews and the exported
/// animation demo. Ground light, ripples, particles and silhouette have their
/// own timelines. Drawing paths avoids blurry raster scaling on Retina.
final class PingEffectView: NSView {
    let kind: PingKind
    let effectScale: CGFloat
    private(set) var elapsed: Double = 2
    private var started: CFTimeInterval = 0
    private var timer: Timer?
    init(frame: NSRect, kind: PingKind, scale: CGFloat) {
        self.kind = kind; self.effectScale = scale
        super.init(frame: frame); wantsLayer = true; layer?.masksToBounds = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }
    override var isOpaque: Bool { false }
    override func viewDidChangeBackingProperties() { super.viewDidChangeBackingProperties(); needsDisplay = true }
    func start() {
        timer?.invalidate(); started = CACurrentMediaTime(); seek(to: 0)
        let next = Timer(timeInterval: 1.0/60, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            self.seek(to: CACurrentMediaTime()-self.started)
            if self.elapsed >= 2 { timer.invalidate(); self.timer = nil }
        }
        timer = next; RunLoop.main.add(next, forMode: .common)
    }
    func seek(to time: Double) { elapsed = time; needsDisplay = true }
    func stop() { timer?.invalidate(); timer = nil; elapsed = 2; layer?.removeAllAnimations(); needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(bounds)
        let t = elapsed
        guard t >= 0, t < 2 else { return }
        let s = effectScale
        let ground = CGPoint(x: bounds.midX, y: bounds.midY-13*s)
        let alpha = ease(t/0.08)*(1-ease((t-1.25)/0.75))
        // The footprint stays on the original cursor anchor while the glyph rises.
        context.saveGState(); context.setAlpha(CGFloat(alpha))
        context.translateBy(x: ground.x, y: ground.y); context.scaleBy(x: 1, y: 0.52)
        NSGradient(colorsAndLocations: (kind.tint.withAlphaComponent(0.10), 0), (kind.tint.withAlphaComponent(0.32*(1-ease(t/1.2))), 0.6), (kind.tint.withAlphaComponent(0), 1))?.draw(fromCenter: .zero, radius: 0, toCenter: .zero, radius: 48*s, options: [])
        context.restoreGState()
        // Two staggered expanding waves, independent of the rising icon.
        for i in 0..<2 {
            let age = t-Double(i)*0.24
            guard age >= 0, age < 1.15 else { continue }
            let progress = age/1.15, radius = CGFloat(10+49*(1-pow(1-progress, 2)))*s
            let ringAlpha = ease(age/0.045)*pow(1-progress, 1.5)
            let ring = NSBezierPath(ovalIn: CGRect(x: ground.x-radius, y: ground.y-radius*0.52, width: radius*2, height: radius*1.04))
            context.saveGState()
            context.setShadow(offset: .zero, blur: 4*s, color: kind.tint.withAlphaComponent(ringAlpha*0.65).cgColor)
            kind.tint.withAlphaComponent(ringAlpha*0.88).setStroke(); ring.lineWidth = (i == 0 ? 1.9 : 1.1)*s; ring.stroke()
            context.restoreGState()
        }
        // Brief sparks make the appearance visibly animate beyond image scaling.
        if t < 0.65 {
            let p = t/0.65
            for i in 0..<5 {
                let angle = CGFloat(i)*2 * .pi/5 + .pi/7
                let distance = CGFloat(10+31*p)*s
                let x = ground.x+cos(angle)*distance, y = ground.y+sin(angle)*distance*0.6
                kind.tint.withAlphaComponent((1-p)*0.7).setFill()
                NSBezierPath(ovalIn: CGRect(x: x-s, y: y-s, width: 2*s, height: 2*s)).fill()
            }
        }
        let pop: Double
        if t < 0.12 { pop = 0.50+0.58*ease(t/0.12) }
        else if t < 0.25 { pop = 1.08-0.08*ease((t-0.12)/0.13) }
        else { pop = 1 }
        let lift = CGFloat(9*ease(t/0.30)+2*sin(min(t,1.4)*Double.pi))*s
        let side = CGFloat(43*pop)*s
        let rect = CGRect(x: ground.x-side/2, y: ground.y+8*s+lift, width: side, height: side)
        // Separate glow and crisp foreground silhouette; never blur the icon body.
        context.saveGState(); context.setAlpha(CGFloat(alpha)*0.40)
        context.setShadow(offset: .zero, blur: 6*s, color: kind.tint.cgColor)
        Assets.draw(kind, in: rect)
        context.restoreGState()
        context.saveGState(); context.setAlpha(CGFloat(alpha))
        Assets.draw(kind, in: rect)
        context.restoreGState()
    }
}

final class OverlayController {
    private var wheel: OverlayPanel?
    private var wheelView: WheelView?
    private var retiring: [(OverlayPanel, DispatchWorkItem)] = []
    private var effects: [(UUID, OverlayPanel, DispatchWorkItem)] = []
    @discardableResult func showWheel(at anchor: CGPoint, scale: Double) -> CGPoint {
        hideWheel(animated: false)
        let side = CGFloat(300*scale)
        let screen = NSScreen.screens.first(where: { NSMouseInRect(anchor, $0.frame, false) }) ?? NSScreen.main
        let center = WheelGeometry.clampedCenter(anchor: anchor, frame: screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900), radius: side/2)
        let panel = OverlayPanel(frame: CGRect(x: center.x-side/2, y: center.y-side/2, width: side, height: side))
        let view = WheelView(frame: CGRect(x: 0, y: 0, width: side, height: side))
        panel.contentView = view; panel.orderFrontRegardless(); view.open()
        wheel = panel; wheelView = view
        return center
    }
    func select(_ kind: PingKind, angle: CGFloat?) { wheelView?.setSelection(kind, angle: angle) }
    func hideWheel(animated: Bool = true) {
        guard let panel = wheel else { return }
        wheelView?.stop(); wheel = nil; wheelView = nil
        guard animated else { panel.orderOut(nil); panel.close(); return }
        NSAnimationContext.runAnimationGroup { context in context.duration = 0.09; panel.animator().alphaValue = 0 }
        let cleanup = DispatchWorkItem { [weak self, weak panel] in
            panel?.close(); self?.retiring.removeAll { $0.0 === panel }
        }
        retiring.append((panel, cleanup))
        DispatchQueue.main.asyncAfter(deadline: .now()+0.10, execute: cleanup)
    }
    func showPing(_ kind: PingKind, at point: CGPoint, scale: Double) {
        if effects.count >= 16 { let oldest = effects.removeFirst(); oldest.2.cancel(); closeEffect(oldest.1) }
        let side = CGFloat(220*scale)
        // The footprint (13 points below the view center) is exactly the anchor.
        let panel = OverlayPanel(frame: CGRect(x: point.x-side/2, y: point.y-side/2+13*scale, width: side, height: side))
        let view = PingEffectView(frame: CGRect(x: 0, y: 0, width: side, height: side), kind: kind, scale: CGFloat(scale))
        panel.contentView = view; panel.orderFrontRegardless(); view.start()
        let id = UUID()
        let cleanup = DispatchWorkItem { [weak self, weak panel] in
            if let panel { self?.closeEffect(panel) }; self?.effects.removeAll { $0.0 == id }
        }
        effects.append((id, panel, cleanup))
        DispatchQueue.main.asyncAfter(deadline: .now()+2.05, execute: cleanup)
    }
    private func closeEffect(_ panel: OverlayPanel) { (panel.contentView as? PingEffectView)?.stop(); panel.close() }
    func clear() {
        hideWheel(animated: false)
        retiring.forEach { $0.1.cancel(); $0.0.contentView?.layer?.removeAllAnimations(); $0.0.close() }; retiring.removeAll()
        effects.forEach { $0.2.cancel(); closeEffect($0.1) }; effects.removeAll()
    }
}
