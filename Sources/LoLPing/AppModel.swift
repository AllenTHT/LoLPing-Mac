import AppKit
import Combine
import PingCore

final class AppModel: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var awaitingPermission = false
    @Published private(set) var message = "全局信号已关闭。你仍可在下方预览效果。"
    @Published var chord: TriggerChord {
        didSet { defaults.set(chord.rawValue, forKey: "triggerChord"); restartInputIfNeeded() }
    }
    @Published var volume: Double {
        didSet { defaults.set(volume, forKey: "volume") }
    }
    @Published var scale: Double {
        didSet { defaults.set(scale, forKey: "effectScale"); restartInputIfNeeded() }
    }
    @Published private(set) var previewKind: PingKind = .missing
    @Published private(set) var previewToken = UUID()
    @Published private(set) var previewVisible = false
    var onStateChange: (() -> Void)?
    let defaults: UserDefaults
    private let input = GlobalInput()
    private let overlay = OverlayController()
    private let sound = SoundPlayer()
    private var previewCleanup: DispatchWorkItem?
    private var permissionTimer: Timer?
    private var observations: [NSObjectProtocol] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        chord = TriggerChord(rawValue: defaults.string(forKey: "triggerChord") ?? "") ?? .controlOptionCommand
        volume = defaults.object(forKey: "volume") == nil ? 0.55 : min(max(defaults.double(forKey: "volume"), 0), 1)
        scale = defaults.object(forKey: "effectScale") == nil ? 1 : min(max(defaults.double(forKey: "effectScale"), 0.75), 1.5)
        input.onAction = { [weak self] action in self?.handle(action) }
        input.onUnavailable = { [weak self] in
            self?.setEnabled(false)
            self?.message = "全局输入已暂停，请检查辅助功能权限后重新开启。"
        }
        let center = NotificationCenter.default
        observations.append(center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.checkPermission() })
        observations.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.cancelEffects() })
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.willSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.didActivateApplicationNotification] {
            observations.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.cancelEffects() })
        }
    }
    func restoreState() {
        if defaults.bool(forKey: "enabled") {
            if GlobalInput.isTrusted { setEnabled(true) }
            else { message = "上次已启用，但当前缺少辅助功能权限。开启开关可重新授权。" }
        }
        if !Assets.missingFiles.isEmpty { message = "素材缺失，请重新构建应用：" + Assets.missingFiles.joined(separator: "、") }
    }
    func setEnabled(_ value: Bool) {
        if !value {
            awaitingPermission = false
            permissionTimer?.invalidate(); permissionTimer = nil
            input.stop(); overlay.clear(); sound.stopAll(); stopPreview()
            isEnabled = false; defaults.set(false, forKey: "enabled")
            message = "全局信号已关闭。你仍可在下方预览效果。"
            onStateChange?()
            return
        }
        guard GlobalInput.isTrusted else {
            awaitingPermission = true
            message = "还差一步：在系统设置 → 隐私与安全性 → 辅助功能中开启 LoLPing。"
            GlobalInput.requestPermission()
            permissionTimer?.invalidate()
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in self?.checkPermission() }
            onStateChange?()
            return
        }
        do {
            try input.start(chord: chord, scale: scale)
            isEnabled = true; awaitingPermission = false
            permissionTimer?.invalidate(); permissionTimer = nil
            defaults.set(true, forKey: "enabled")
            message = "已就绪。按住 \(chord.symbols)，移动选择，松开发送。"
        } catch {
            isEnabled = false; awaitingPermission = false
            permissionTimer?.invalidate(); permissionTimer = nil
            defaults.set(false, forKey: "enabled")
            message = error.localizedDescription
        }
        onStateChange?()
    }
    func checkPermission() {
        if awaitingPermission && GlobalInput.isTrusted { setEnabled(true) }
        else if isEnabled && !GlobalInput.isTrusted {
            setEnabled(false); message = "辅助功能权限已关闭，请重新授权后开启 Ping。"
        }
    }
    func openAccessibility() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    func openInputMonitoring() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
    }
    func preview(_ kind: PingKind) {
        previewCleanup?.cancel()
        previewKind = kind; previewToken = UUID(); previewVisible = true
        sound.play(kind, volume: volume)
        let cleanup = DispatchWorkItem { [weak self] in self?.previewVisible = false }
        previewCleanup = cleanup
        DispatchQueue.main.asyncAfter(deadline: .now()+2.1, execute: cleanup)
    }
    func stopPreview() {
        previewCleanup?.cancel(); previewCleanup = nil; previewVisible = false
    }
    func cancelEffects() { input.cancelCurrent(); overlay.clear(); sound.stopAll(); stopPreview() }
    func shutdown() {
        // Preserve the user's enabled preference across an intentional app quit.
        permissionTimer?.invalidate(); input.stop(); overlay.clear(); sound.stopAll(); stopPreview()
    }
    private func restartInputIfNeeded() {
        cancelEffects()
        if isEnabled { setEnabled(true) }
        onStateChange?()
    }
    private func handle(_ action: GestureMachine.Action) {
        guard isEnabled else { return }
        switch action {
        case .show(let anchor): input.setWheelCenter(overlay.showWheel(at: anchor, scale: scale))
        case .hover(let kind, let angle): overlay.select(kind, angle: angle)
        case .hide: overlay.hideWheel(animated: false)
        case .dismiss: overlay.hideWheel()
        case .commit(let kind, let anchor):
            overlay.showPing(kind, at: anchor, scale: scale)
            sound.play(kind, volume: volume)
        case .arm: break
        }
    }
}
