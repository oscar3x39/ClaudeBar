import Foundation

/// OAuth 憑證。
struct Credentials: Codable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date?
    var scopes: [String]

    func isExpired(leeway: TimeInterval = 300, now: Date = Date()) -> Bool {
        guard let e = expiresAt else { return false }
        return e <= now.addingTimeInterval(leeway)
    }
    var hasRefreshToken: Bool { !(refreshToken ?? "").isEmpty }
}

/// 憑證持久化（檔案 0600）。協定化以便測試注入。
protocol CredentialStore {
    func load() -> Credentials?
    func save(_ c: Credentials)
    func clear()
}

struct FileCredentialStore: CredentialStore {
    private let fileURL: URL

    init(directory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/claudebar", isDirectory: true)) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("credentials.json")
    }

    func load() -> Credentials? {
        guard let d = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Credentials.self, from: d)
    }

    func save(_ c: Credentials) {
        guard let d = try? JSONEncoder().encode(c) else { return }
        try? d.write(to: fileURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    func clear() { try? FileManager.default.removeItem(at: fileURL) }
}
