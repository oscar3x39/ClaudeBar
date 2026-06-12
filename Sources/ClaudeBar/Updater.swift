import Foundation
import AppKit

/// 從 GitHub Releases 做自我更新：比對 tag 與本機版本，下載 .zip 資產，
/// 換掉執行中的 .app bundle 後重新啟動。非官方 API 以外的唯一更新來源。
@MainActor
final class Updater: ObservableObject {
    /// 有可更新版本時為新版的 tag（如 "v0.2.0"），否則 nil。
    @Published private(set) var latestTag: String?
    @Published private(set) var installing = false
    @Published private(set) var checking = false
    @Published private(set) var error: String?
    /// 手動檢查後的回饋（如 "Already on latest v0.1.0"）；偵測到新版時為 nil（改由橫幅顯示）。
    @Published private(set) var statusNote: String?

    private var downloadURL: URL?
    private var lastCheck: Date?

    private let repo = "oscar3x39/ClaudeBar"

    /// 本機版本（Info.plist 的 CFBundleShortVersionString）。
    static var current: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
    }

    private struct Release: Decodable {
        let tag_name: String
        let assets: [Asset]
        struct Asset: Decodable { let name: String; let browser_download_url: String }
    }

    /// 查最新 release。silent=true（背景/輪詢）時每小時最多查一次、不報錯。
    func check(silent: Bool = true) async {
        if silent, let l = lastCheck, Date().timeIntervalSince(l) < 3600 { return }
        lastCheck = Date()
        if !silent { checking = true; error = nil; statusNote = nil }
        defer { checking = false }
        do {
            var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, resp) = try await URLSession.shared.data(for: req)
            let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
            // 404 = repo 尚無任何 release，等同目前就是最新版，不視為錯誤。
            if status == 404 {
                latestTag = nil; downloadURL = nil
                if !silent { statusNote = "Already on latest v\(Self.current)" }
                return
            }
            guard status == 200 else {
                if !silent { error = "GitHub HTTP \(status)" }
                return
            }
            let rel = try JSONDecoder().decode(Release.self, from: data)
            guard Self.isNewer(rel.tag_name, than: Self.current),
                  let asset = rel.assets.first(where: { $0.name.hasSuffix(".zip") }),
                  let url = URL(string: asset.browser_download_url) else {
                latestTag = nil; downloadURL = nil
                if !silent { statusNote = "Already on latest v\(Self.current)" }
                return
            }
            latestTag = rel.tag_name
            downloadURL = url
            statusNote = nil
        } catch {
            if !silent { self.error = error.localizedDescription }
        }
    }

    /// 下載新版、解壓、換掉本 bundle 並重啟。失敗時保留原版、回報錯誤。
    func installAndRelaunch() async {
        guard let url = downloadURL, !installing else { return }
        installing = true; error = nil
        let fm = FileManager.default
        do {
            let (tmp, _) = try await URLSession.shared.download(from: url)
            let zip = tmp.appendingPathExtension("zip")
            try? fm.removeItem(at: zip)
            try fm.moveItem(at: tmp, to: zip)

            let unpack = fm.temporaryDirectory
                .appendingPathComponent("ClaudeBar-update-\(UUID().uuidString)")
            try fm.createDirectory(at: unpack, withIntermediateDirectories: true)
            try run("/usr/bin/ditto", ["-x", "-k", zip.path, unpack.path])

            guard let newApp = try newestApp(in: unpack) else {
                throw NSError(domain: "Updater", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "zip 內找不到 .app"])
            }
            try swapAndRelaunch(newApp: newApp.path, dest: Bundle.main.bundlePath)
            NSApp.terminate(nil)
        } catch {
            installing = false
            self.error = "更新失敗：\(error.localizedDescription)"
        }
    }

    // MARK: - helpers

    /// 比較版本字串（去掉前置 v、只取數字段），remote 是否比 local 新。
    static func isNewer(_ remote: String, than local: String) -> Bool {
        let r = semver(remote), l = semver(local)
        for i in 0..<max(r.count, l.count) {
            let a = i < r.count ? r[i] : 0
            let b = i < l.count ? l[i] : 0
            if a != b { return a > b }
        }
        return false
    }

    private static func semver(_ s: String) -> [Int] {
        let core = s.drop { !$0.isNumber }.prefix { $0.isNumber || $0 == "." }
        return core.split(separator: ".").map { Int($0) ?? 0 }
    }

    private func newestApp(in dir: URL) throws -> URL? {
        try FileManager.default
            .contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .first { $0.pathExtension == "app" }
    }

    @discardableResult
    private func run(_ launchPath: String, _ args: [String]) throws -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launchPath)
        p.arguments = args
        try p.run()
        p.waitUntilExit()
        return p.terminationStatus
    }

    /// 啟動一個脫離本程式的 sh：等本程式結束後換掉 bundle 再 open 重啟。
    private func swapAndRelaunch(newApp: String, dest: String) throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        // 先 ditto 到 sibling 暫存，成功才換掉舊 bundle（mv 同卷為原子操作）。
        // ditto 失敗時原 bundle 不動，避免「舊的刪了、新的沒進來」的壞狀態。
        let staged = dest + ".new"
        let script = """
        while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
        rm -rf '\(staged)'
        /usr/bin/ditto '\(newApp)' '\(staged)' || exit 1
        rm -rf '\(dest)'
        mv '\(staged)' '\(dest)'
        open '\(dest)'
        """
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", script]
        try p.run() // 不 wait：交給它在背景完成替換
    }
}
