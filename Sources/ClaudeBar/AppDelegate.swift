import AppKit
import SwiftUI

/// 可成為 key 的無邊框面板，讓登入輸入框能接收鍵盤。
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// AppKit 殼：menu bar status item + 無箭頭面板 + 輪詢計時器。不含業務邏輯。
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let config = AppConfig.load()
    private let svc = UsageService()
    private let updater = Updater()
    private var statusItem: NSStatusItem!
    private var panel: KeyablePanel!
    private var timer: Timer?
    private var clickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.action = #selector(togglePanel)
        statusItem.button?.target = self

        installEditMenu() // accessory app 無選單列,手動接上 Cmd+C/V/X/A 給輸入框

        svc.onChange = { [weak self] in self?.updateTitle() }
        let host = NSHostingController(rootView:
            PopoverView(svc: svc, updater: updater, onQuit: { NSApp.terminate(nil) }))
        host.sizingOptions = [.preferredContentSize]

        // 無邊框面板：沒有 NSPopover 的箭頭。圓角 + 陰影由內容層處理。
        let p = KeyablePanel(contentRect: .zero,
                             styleMask: [.borderless, .nonactivatingPanel],
                             backing: .buffered, defer: false)
        p.contentViewController = host
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .popUpMenu
        p.hidesOnDeactivate = false
        p.isMovableByWindowBackground = false
        p.animationBehavior = .utilityWindow
        panel = p

        updateTitle()
        svc.loadHistory()
        Task { await svc.refreshUsage(force: true); await svc.refreshEmail() }
        Task { await updater.check() }

        timer = Timer.scheduledTimer(withTimeInterval: config.pollInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.svc.loadHistory()
            Task { await self.svc.refreshUsage() }
            Task { await self.updater.check() }
        }

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(closePanel),
                       name: NSApplication.didResignActiveNotification, object: nil)
        nc.addObserver(self, selector: #selector(closePanel),
                       name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    @objc private func closePanel() {
        guard panel?.isVisible == true else { return }
        panel.orderOut(nil)
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
    }

    /// 用 nil-target 走 responder chain，讓焦點輸入框收到剪貼簿快捷鍵。
    private func installEditMenu() {
        let mainMenu = NSMenu()
        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editItem.submenu = editMenu
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApp.mainMenu = mainMenu
    }

    private func updateTitle() {
        statusItem.button?.title = ""
        statusItem.button?.image = MenuBarIcon.make(
            pct5h: svc.usage?.five_hour?.utilization ?? 0,
            authed: svc.isAuthed)
    }

    @objc private func togglePanel() {
        if panel.isVisible { closePanel() } else { showPanel() }
    }

    private func showPanel() {
        guard let button = statusItem.button, let btnWin = button.window else { return }

        // 依內容自適應大小，置於 status item 正下方並貼齊右緣不超出螢幕。
        panel.layoutIfNeeded()
        let size = panel.contentView?.fittingSize ?? NSSize(width: 320, height: 400)
        panel.setContentSize(size)

        let rectInScreen = btnWin.convertToScreen(button.convert(button.bounds, to: nil))
        var x = rectInScreen.midX - size.width / 2
        let y = rectInScreen.minY - size.height - 6
        if let vf = (btnWin.screen ?? NSScreen.main)?.visibleFrame {
            x = min(max(x, vf.minX + 8), vf.maxX - size.width - 8)
        }
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // 點面板外（含桌面 / 其他 app）即關閉。
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }
    }
}
