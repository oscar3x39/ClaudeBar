import Foundation
import ServiceManagement

/// 開機自動啟動。用 SMAppService.mainApp（macOS 13+）以 bundle identity 註冊，
/// 由系統託管，重編／搬動 app 都不會斷；不再自己手寫記絕對路徑的 LaunchAgent plist。
enum LoginItem {
    /// 舊版手寫的 LaunchAgent plist，路徑會 rot。啟動時一律清掉，避免殘留一個壞掉的 agent。
    private static let legacyLabel = "com.claudebar.agent"
    private static var legacyPlistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(legacyLabel).plist")
    }

    /// 移除舊版 plist 並從 launchd 卸載。App 啟動時呼叫一次即可。
    static func cleanupLegacy() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: legacyPlistURL.path) else { return }
        // 先從 launchd 卸載（忽略錯誤：可能本來就沒載入），再刪檔。
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = ["bootout", "gui/\(getuid())/\(legacyLabel)"]
        try? p.run()
        p.waitUntilExit()
        try? fm.removeItem(at: legacyPlistURL)
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("ClaudeBar LoginItem \(enabled ? "register" : "unregister") failed: \(error)")
        }
    }
}
