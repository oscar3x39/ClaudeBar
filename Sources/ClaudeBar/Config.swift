import Foundation

/// OAuth / API 設定。集中一處，且每項都可被環境變數覆寫（預設值僅作 fallback），
/// 方便測試注入 mock server，也避免把常數散落在邏輯各處。
struct AppConfig {
    let clientID: String
    let scopes: [String]
    let redirectURI: String
    let authorizeURL: URL
    let tokenURL: URL
    let usageURL: URL
    let userinfoURL: URL
    let oauthBetaHeader: String
    let pollInterval: TimeInterval

    /// 從環境變數載入，缺項用預設。
    static func load(env: [String: String] = ProcessInfo.processInfo.environment) -> AppConfig {
        func str(_ key: String, _ fallback: String) -> String { env[key] ?? fallback }
        func url(_ key: String, _ fallback: String) -> URL { URL(string: env[key] ?? fallback)! }
        func num(_ key: String, _ fallback: TimeInterval) -> TimeInterval {
            env[key].flatMap(TimeInterval.init) ?? fallback
        }
        return AppConfig(
            clientID: str("CLAUDEBAR_CLIENT_ID", "9d1c250a-e61b-44d9-88ed-5944d1962f5e"),
            scopes: (env["CLAUDEBAR_SCOPES"]?.split(separator: " ").map(String.init))
                ?? ["user:profile", "user:inference"],
            redirectURI: str("CLAUDEBAR_REDIRECT_URI", "https://platform.claude.com/oauth/code/callback"),
            authorizeURL: url("CLAUDEBAR_AUTHORIZE_URL", "https://claude.ai/oauth/authorize"),
            tokenURL: url("CLAUDEBAR_TOKEN_URL", "https://platform.claude.com/v1/oauth/token"),
            usageURL: url("CLAUDEBAR_USAGE_URL", "https://api.anthropic.com/api/oauth/usage"),
            userinfoURL: url("CLAUDEBAR_USERINFO_URL", "https://api.anthropic.com/api/oauth/userinfo"),
            oauthBetaHeader: str("CLAUDEBAR_OAUTH_BETA", "oauth-2025-04-20"),
            pollInterval: num("CLAUDEBAR_POLL_SECONDS", 300)
        )
    }
}
