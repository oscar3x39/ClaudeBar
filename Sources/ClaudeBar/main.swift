import AppKit

// 進入點：menu-bar only（不顯示 Dock 圖示），其餘邏輯在各模組。
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.run()
