import AppKit
import SwiftUI

/// AppKit 殼：menu bar status item + popover 掛載 + 輪詢計時器。不含業務邏輯。
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let config = AppConfig.load()
    private let svc = UsageService()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self
        popover.behavior = .transient

        installEditMenu() // accessory app 無選單列,手動接上 Cmd+C/V/X/A 給輸入框

        svc.onChange = { [weak self] in self?.updateTitle() }
        let host = NSHostingController(rootView: PopoverView(svc: svc, onQuit: { NSApp.terminate(nil) }))
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host

        updateTitle()
        svc.loadHistory()
        Task { await svc.refreshUsage(force: true); await svc.refreshEmail() }

        timer = Timer.scheduledTimer(withTimeInterval: config.pollInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.svc.loadHistory()
            Task { await self.svc.refreshUsage() }
        }

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(closePopover),
                       name: NSApplication.didResignActiveNotification, object: nil)
        nc.addObserver(self, selector: #selector(closePopover),
                       name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    @objc private func closePopover() { if popover.isShown { popover.performClose(nil) } }

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

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            if svc.isAuthed { Task { await svc.refreshUsage() } }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
