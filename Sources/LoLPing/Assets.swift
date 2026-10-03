import AppKit
import AVFoundation
import PingCore

enum Assets {
    static let root: URL = {
        let bundled = Bundle.main.resourceURL ?? Bundle.main.bundleURL
        if FileManager.default.fileExists(atPath: bundled.appendingPathComponent("Icons").path) { return bundled }
        return URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Resources")
    }()
    private struct Vector: Decodable { let contours: [[[CGFloat]]] }
    static let paths: [PingKind: CGPath] = {
        guard let data = try? Data(contentsOf: root.appendingPathComponent("Artwork/ping-vectors.json")),
              let vectors = try? JSONDecoder().decode([String: Vector].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: PingKind.allCases.compactMap { kind in
            guard let vector = vectors[kind.rawValue] else { return nil }
            let path = CGMutablePath()
            for contour in vector.contours where contour.count >= 3 {
                let points = contour.map { CGPoint(x: $0[0], y: $0[1]) }
                // Small quadratic joins remove pixel stair steps, while keeping
                // the atlas silhouette and its sharp, geometric corners.
                func entry(_ i: Int) -> CGPoint {
                    let p = points[i], previous = points[(i+points.count-1)%points.count]
                    return CGPoint(x: p.x*0.88+previous.x*0.12, y: p.y*0.88+previous.y*0.12)
                }
                path.move(to: entry(0))
                for i in points.indices {
                    let p = points[i], next = points[(i+1)%points.count]
                    let exit = CGPoint(x: p.x*0.88+next.x*0.12, y: p.y*0.88+next.y*0.12)
                    path.addQuadCurve(to: exit, control: p)
                    path.addLine(to: entry((i+1)%points.count))
                }
                path.closeSubpath()
            }
            return (kind, path.copy()!)
        })
    }()
    static func path(_ kind: PingKind, in rect: CGRect) -> CGPath? {
        var transform = CGAffineTransform(a: rect.width, b: 0, c: 0, d: rect.height, tx: rect.minX, ty: rect.minY)
        return paths[kind]?.copy(using: &transform)
    }
    static func draw(_ kind: PingKind, in rect: CGRect, color: NSColor? = nil) {
        guard let context = NSGraphicsContext.current?.cgContext, let path = path(kind, in: rect) else { return }
        context.saveGState()
        context.setFillColor((color ?? kind.tint).cgColor)
        context.addPath(path); context.drawPath(using: .eoFill)
        context.restoreGState()
    }
    static let icons: [PingKind: NSImage] = Dictionary(uniqueKeysWithValues: PingKind.allCases.compactMap { kind in
        guard paths[kind] != nil else { return nil }
        return (kind, NSImage(size: NSSize(width: 64, height: 64), flipped: false) { rect in
            draw(kind, in: rect); return true
        })
    })
    static func icon(_ kind: PingKind) -> NSImage? { icons[kind] }
    static func sound(_ kind: PingKind) -> URL { root.appendingPathComponent("Sounds/\(kind.soundName).mp3") }
    static var missingFiles: [String] {
        PingKind.allCases.flatMap { kind in
            var missing: [String] = []
            if icon(kind) == nil { missing.append(kind.iconName + ".png") }
            if !FileManager.default.fileExists(atPath: sound(kind).path) { missing.append(kind.soundName + ".mp3") }
            return missing
        }
    }
}

extension PingKind {
    var tint: NSColor {
        switch self {
        case .retreat, .enemyVision: return NSColor(srgbRed: 1, green: 0.30, blue: 0.30, alpha: 1)
        case .missing, .allIn: return NSColor(srgbRed: 1, green: 0.80, blue: 0.02, alpha: 1)
        case .assist, .push, .needVision: return NSColor(srgbRed: 0, green: 0.89, blue: 0.60, alpha: 1)
        case .onMyWay, .generic: return NSColor(srgbRed: 0.10, green: 0.72, blue: 0.95, alpha: 1)
        }
    }
    var wheelIdleTint: NSColor {
        switch self {
        case .push, .allIn, .needVision, .enemyVision:
            return NSColor(srgbRed: 0.80, green: 0.76, blue: 0.57, alpha: 1)
        default: return tint
        }
    }
}

final class SoundPlayer: NSObject, AVAudioPlayerDelegate {
    private var data: [PingKind: Data] = [:]
    private var players: [AVAudioPlayer] = []
    private(set) var error: String?
    override init() {
        super.init()
        for kind in PingKind.allCases { data[kind] = try? Data(contentsOf: Assets.sound(kind)) }
    }
    func play(_ kind: PingKind, volume: Double) {
        guard volume > 0, let bytes = data[kind] else { return }
        do {
            let player = try AVAudioPlayer(data: bytes)
            player.volume = Float(volume)
            player.delegate = self
            player.prepareToPlay()
            // Bound simultaneous playback without imposing the game's rate limit.
            if players.count >= 12 { players.removeFirst().stop() }
            players.append(player)
            if !player.play() { error = "音效播放失败" }
        } catch { self.error = "无法读取音效：\(kind.title)" }
    }
    func stopAll() { players.forEach { $0.stop() }; players.removeAll() }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        players.removeAll { $0 === player }
    }
}
