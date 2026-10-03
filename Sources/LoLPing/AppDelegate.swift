import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private var statusItem: NSStatusItem!
    private var enableItem: NSMenuItem!
    private var stateItem: NSMenuItem!
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildMainMenu()
        buildStatusMenu()
        let controller = NSHostingController(rootView: ControlView(model: model))
        window = NSWindow(contentViewController: controller)
        window.title = "LoLPing · 桌面信号"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 680, height: 800))
        window.minSize = NSSize(width: 640, height: 680)
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(srgbRed: 0.035, green: 0.055, blue: 0.08, alpha: 1)
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.delegate = self
        window.center()
        model.onStateChange = { [weak self] in self?.updateStatus() }
        model.restoreState(); updateStatus()
        showWindow()
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    func applicationWillTerminate(_ notification: Notification) { model.shutdown() }
    func windowWillClose(_ notification: Notification) { model.cancelEffects() }

    @objc func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func toggleEnabled() { model.setEnabled(!(model.isEnabled || model.awaitingPermission)) }
    @objc private func quit() { NSApp.terminate(nil) }

    private func buildMainMenu() {
        let menu = NSMenu()
        let application = NSMenuItem()
        let submenu = NSMenu(title: "LoLPing")
        submenu.addItem(withTitle: "打开控制窗口", action: #selector(showWindow), keyEquivalent: ",").target = self
        submenu.addItem(.separator())
        submenu.addItem(withTitle: "退出 LoLPing", action: #selector(quit), keyEquivalent: "q").target = self
        application.submenu = submenu; menu.addItem(application)
        NSApp.mainMenu = menu
    }
    private func buildStatusMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "location.circle", accessibilityDescription: "LoLPing")
        statusItem.button?.setAccessibilityLabel("LoLPing 菜单")
        let menu = NSMenu()
        stateItem = NSMenuItem(title: "LoLPing · 已关闭", action: nil, keyEquivalent: "")
        menu.addItem(stateItem)
        enableItem = NSMenuItem(title: "启用 Ping", action: #selector(toggleEnabled), keyEquivalent: "")
        enableItem.target = self; menu.addItem(enableItem)
        menu.addItem(withTitle: "打开控制窗口…", action: #selector(showWindow), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 LoLPing", action: #selector(quit), keyEquivalent: "").target = self
        statusItem.menu = menu
    }
    private func updateStatus() {
        let state = model.isEnabled ? "已开启" : (model.awaitingPermission ? "等待授权" : "已关闭")
        stateItem.title = "LoLPing · \(state)"
        enableItem.state = model.isEnabled ? .on : (model.awaitingPermission ? .mixed : .off)
        enableItem.title = model.awaitingPermission ? "取消启用" : "启用 Ping"
        statusItem.button?.toolTip = "LoLPing · \(state)"
        statusItem.button?.image = NSImage(systemSymbolName: model.isEnabled ? "location.circle.fill" : "location.circle", accessibilityDescription: "LoLPing · \(state)")
    }
}
