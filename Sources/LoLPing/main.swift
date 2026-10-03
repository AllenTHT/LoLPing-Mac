import AppKit
import AVFoundation
import PingCore

if let index = CommandLine.arguments.firstIndex(of: "--visual-check"), CommandLine.arguments.count > index+1 {
    do { try VisualChecks.run(to: URL(fileURLWithPath: CommandLine.arguments[index+1])); exit(0) }
    catch { print("Visual check failed: \(error)"); exit(1) }
}

// This diagnostics mode never creates an event tap or synthesizes keyboard/mouse events.
if CommandLine.arguments.contains("--check-assets") {
    var failures = Assets.missingFiles
    for kind in PingKind.allCases {
        do {
            let player = try AVAudioPlayer(contentsOf: Assets.sound(kind))
            if player.duration <= 0 { failures.append("Invalid duration: \(kind.soundName)") }
            print("\(kind.title): image=\(Assets.icon(kind)?.size ?? .zero), sound=\(String(format: "%.2f", player.duration))s")
        } catch { failures.append("\(kind.soundName): \(error.localizedDescription)") }
    }
    if failures.isEmpty { print("All 9 icons and 9 audio files decode successfully."); exit(0) }
    failures.forEach { print($0) }; exit(1)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
