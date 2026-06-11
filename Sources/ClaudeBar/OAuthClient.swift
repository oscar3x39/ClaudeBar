import Foundation

enum AuthError: Error, LocalizedError {
    case network
    case tokenExchange(status: Int, body: String)
    case badResponse
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .network: return "Network error"
        case .tokenExchange(let s, let b): return "Token exchange failed (HTTP \(s)) \(b)"
        case .badResponse: return "Bad response"
        case .notSignedIn: return "Not signed in"
        }
    }
}

/// 一次 OAuth 授權的暫態（PKCE verifier + state）。
struct PendingAuth {
    let verifier: String
    let state: String
    let authorizeURL: URL
}

/// 純網路 / 認證層：OAuth PKCE flow、token refresh、帶 token 的 GET。無 UI、無狀態（憑證放 store）。
struct OAuthClient {
    let config: AppConfig
    let store: CredentialStore
    var session: URLSession = .shared

    // MARK: OAuth flow

    func beginAuthorization() -> PendingAuth {
        let verifier = PKCE.randomToken()
        let state = PKCE.randomToken()
        var c = URLComponents(url: config.authorizeURL, resolvingAgainstBaseURL: false)!
        c.queryItems = [
            .init(name: "code", value: "true"),
            .init(name: "client_id", value: config.clientID),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: config.redirectURI),
            .init(name: "scope", value: config.scopes.joined(separator: " ")),
            .init(name: "code_challenge", value: PKCE.challenge(for: verifier)),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
        ]
        return PendingAuth(verifier: verifier, state: state, authorizeURL: c.url!)
    }

    /// 使用者貼回的字串格式為 "code#state"，回傳並儲存憑證。
    func exchangeCode(_ raw: String, pending: PendingAuth) async throws -> Credentials {
        let parts = raw.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "#", maxSplits: 1)
        guard let code = parts.first.map(String.init), !code.isEmpty else { throw AuthError.badResponse }
        let body = [
            "grant_type": "authorization_code", "code": code, "state": pending.state,
            "client_id": config.clientID, "redirect_uri": config.redirectURI,
            "code_verifier": pending.verifier,
        ]
        let (data, http) = try await postJSON(config.tokenURL, body)
        guard http.statusCode == 200, let creds = Self.parseCredentials(data, config: config) else {
            throw AuthError.tokenExchange(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        store.save(creds)
        return creds
    }

    // MARK: Token refresh + authorized requests

    @discardableResult
    func refresh() async -> Bool {
        guard let cur = store.load(), let rt = cur.refreshToken, !rt.isEmpty else { return false }
        var body = ["grant_type": "refresh_token", "refresh_token": rt, "client_id": config.clientID]
        if !cur.scopes.isEmpty { body["scope"] = cur.scopes.joined(separator: " ") }
        guard let (data, http) = try? await postJSON(config.tokenURL, body),
              http.statusCode == 200,
              let creds = Self.parseCredentials(data, fallback: cur, config: config) else { return false }
        store.save(creds)
        return true
    }

    /// 帶 Bearer 的 GET，過期先 refresh，遇 401 再 refresh 重試一次。
    func authorizedGET(_ url: URL) async throws -> (Data, HTTPURLResponse) {
        guard var cur = store.load() else { throw AuthError.notSignedIn }
        if cur.isExpired(), await refresh() { cur = store.load() ?? cur }

        var res = try await send(url, token: cur.accessToken)
        if res.1.statusCode == 401, await refresh(), let c2 = store.load() {
            res = try await send(url, token: c2.accessToken)
        }
        return res
    }

    // MARK: Private

    private func send(_ url: URL, token: String) async throws -> (Data, HTTPURLResponse) {
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(config.oauthBetaHeader, forHTTPHeaderField: "anthropic-beta")
        guard let (d, r) = try? await session.data(for: req), let h = r as? HTTPURLResponse else {
            throw AuthError.network
        }
        return (d, h)
    }

    private func postJSON(_ url: URL, _ body: [String: String]) async throws -> (Data, HTTPURLResponse) {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (d, r) = try? await session.data(for: req), let h = r as? HTTPURLResponse else {
            throw AuthError.network
        }
        return (d, h)
    }

    static func parseCredentials(_ data: Data, fallback: Credentials? = nil, config: AppConfig) -> Credentials? {
        guard let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let at = j["access_token"] as? String, !at.isEmpty else { return nil }
        let scopes = (j["scope"] as? String)?.split(whereSeparator: \.isWhitespace).map(String.init)
            ?? fallback?.scopes ?? config.scopes
        var exp: Date?
        if let s = j["expires_in"] as? Double { exp = Date().addingTimeInterval(s) }
        else if let n = j["expires_in"] as? NSNumber { exp = Date().addingTimeInterval(n.doubleValue) }
        return Credentials(accessToken: at,
                           refreshToken: (j["refresh_token"] as? String) ?? fallback?.refreshToken,
                           expiresAt: exp ?? fallback?.expiresAt,
                           scopes: scopes)
    }
}
