import Foundation

/// 開機自動啟動。裸執行檔（非 .app bundle）不能用 SMAppService，改用 LaunchAgent plist。
/// 之後若打包成 .app，可換成 SMAppService.mainApp。
enum LoginItem {
    static let label = "com.claudebar.agent"

    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    static func set(_ enabled: Bool) {
        let fm = FileManager.default
        if enabled {
            let exe = Bundle.main.executablePath ?? CommandLine.arguments.first ?? ""
            let dict: [String: Any] = [
                "Label": label,
                "ProgramArguments": [exe],
                "RunAtLoad": true,
            ]
            try? fm.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let data = try? PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0) {
                try? data.write(to: plistURL)
            }
        } else {
            try? fm.removeItem(at: plistURL)
        }
    }
}
