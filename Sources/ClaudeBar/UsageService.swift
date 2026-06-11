import Foundation
import AppKit

/// ViewModel：持有 UI 狀態（@Published），編排 OAuthClient 做登入與抓用量。不碰網路細節。
@MainActor
final class UsageService: ObservableObject {
    @Published private(set) var isAuthed: Bool
    @Published private(set) var awaitingCode = false
    @Published private(set) var usage: UsageResponse?
    @Published private(set) var email: String?
    @Published private(set) var fullName: String?
    @Published private(set) var plan: String?
    @Published private(set) var updatedAt: Date?
    @Published private(set) var errorText: String?
    @Published private(set) var daily: [DayCost] = []
    @Published private(set) var launchAtLogin = LoginItem.isEnabled

    func setLaunchAtLogin(_ on: Bool) {
        LoginItem.set(on)
        launchAtLogin = LoginItem.isEnabled
    }

    private let config: AppConfig
    private let store: CredentialStore
    private let client: OAuthClient
    private let openURL: (URL) -> Void
    private var pending: PendingAuth?

    /// 下次背景刷新的預估時間（上次成功抓取 + 輪詢間隔）。
    var nextUpdate: Date? { updatedAt.map { $0.addingTimeInterval(config.pollInterval) } }

    /// 任何狀態變動後通知外層（給 AppDelegate 更新 menu bar 標題）。
    var onChange: (() -> Void)?

    private struct UsageCache: Codable { let usage: UsageResponse; let updatedAt: Date }
    private let cacheURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/claudebar/usage-cache.json")

    init(config: AppConfig = .load(),
         store: CredentialStore = FileCredentialStore(),
         openURL: @escaping (URL) -> Void = { NSWorkspace.shared.open($0) }) {
        self.config = config
        self.store = store
        self.client = OAuthClient(config: config, store: store)
        self.openURL = openURL
        self.isAuthed = (store.load() != nil)
        // 重啟時先載入上次快取，避免被限流時顯示空白/0%
        if let d = try? Data(contentsOf: cacheURL),
           let c = try? JSONDecoder().decode(UsageCache.self, from: d) {
            usage = c.usage; updatedAt = c.updatedAt
        }
    }

    private func saveCache() {
        guard let u = usage, let at = updatedAt,
              let d = try? JSONEncoder().encode(UsageCache(usage: u, updatedAt: at)) else { return }
        try? d.write(to: cacheURL, options: .atomic)
    }

    // MARK: 登入流程

    func startSignIn() {
        let p = client.beginAuthorization()
        pending = p
        awaitingCode = true
        errorText = nil
        openURL(p.authorizeURL)
        onChange?()
    }

    func submitCode(_ raw: String) async {
        guard let p = pending else { errorText = "No sign-in in progress"; return }
        do {
            _ = try await client.exchangeCode(raw, pending: p)
            isAuthed = true; awaitingCode = false; pending = nil; errorText = nil
            onChange?()
            await refreshUsage()
            await refreshEmail()
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            onChange?()
        }
    }

    /// 取消進行中的授權（例如使用者關了瀏覽器），回到未登入起點。
    func cancelSignIn() {
        awaitingCode = false; pending = nil; errorText = nil
        onChange?()
    }

    func signOut() {
        store.clear()
        isAuthed = false; usage = nil; email = nil; fullName = nil; plan = nil; updatedAt = nil; errorText = nil
        onChange?()
    }

    // MARK: 抓資料

    private var lastFetch: Date?
    private let minInterval: TimeInterval = 60 // 節流：兩次抓取至少間隔 60 秒

    /// force=true 略過節流（手動 Refresh 用）。
    func refreshUsage(force: Bool = false) async {
        guard isAuthed else { return }
        if !force, let last = lastFetch, Date().timeIntervalSince(last) < minInterval { return }
        lastFetch = Date() // 任何嘗試都計入節流，避免被限流後狂打
        do {
            let (data, http) = try await client.authorizedGET(config.usageURL)
            if http.statusCode == 429 {
                // 被限流：保留上次資料，靜默等下次輪詢，不報錯
                errorText = nil; onChange?(); return
            }
            guard http.statusCode == 200 else {
                if http.statusCode == 401 { isAuthed = false }
                errorText = "usage HTTP \(http.statusCode)"; onChange?(); return
            }
            usage = try JSONDecoder().decode(UsageResponse.self, from: data)
            updatedAt = Date(); errorText = nil
            saveCache()
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? "Failed to load"
        }
        onChange?()
    }

    /// 從本機 JSONL 計算每日成本（背景執行，不卡 UI）。
    func loadHistory() {
        Task.detached(priority: .utility) {
            let d = UsageHistory.recentDays(7)
            await MainActor.run { self.daily = d; self.onChange?() }
        }
    }

    /// 從 /api/oauth/profile 取得帳號 email、姓名、方案等級。
    func refreshEmail() async {
        guard isAuthed,
              let (data, http) = try? await client.authorizedGET(config.userinfoURL),
              http.statusCode == 200,
              let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        let acc = j["account"] as? [String: Any]
        email = (acc?["email"] as? String) ?? (acc?["email_address"] as? String) ?? (j["email"] as? String)
        fullName = (acc?["full_name"] as? String) ?? (acc?["display_name"] as? String)
        plan = Self.planLabel(account: acc, organization: j["organization"] as? [String: Any])
        onChange?()
    }

    /// 把 profile 的方案資訊翻成顯示用標籤，如 "Max 5x" / "Max 20x" / "Pro"。
    private static func planLabel(account: [String: Any]?, organization: [String: Any]?) -> String? {
        let tier = (organization?["rate_limit_tier"] as? String)?.lowercased() ?? ""
        if account?["has_claude_max"] as? Bool == true {
            if tier.contains("20x") { return "Max 20x" }
            if tier.contains("5x") { return "Max 5x" }
            return "Max"
        }
        if account?["has_claude_pro"] as? Bool == true { return "Pro" }
        let orgType = (organization?["organization_type"] as? String)?.lowercased() ?? ""
        if orgType.contains("max") { return "Max" }
        if orgType.contains("pro") { return "Pro" }
        return nil
    }
}
