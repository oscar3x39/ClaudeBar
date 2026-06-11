import Foundation

/// 官方 /api/oauth/usage 回傳的單一視窗。
struct UsageBucket: Codable {
    let utilization: Double?      // 0..100
    let resets_at: String?

    var fraction: Double { (utilization ?? 0) / 100.0 }

    var resetDate: Date? {
        guard let s = resets_at else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }
}

/// /api/oauth/usage 完整回傳。
struct UsageResponse: Codable {
    let five_hour: UsageBucket?
    let seven_day: UsageBucket?
    let seven_day_opus: UsageBucket?
    let seven_day_sonnet: UsageBucket?
}

/// 重置倒數字串。
func resetCountdown(to date: Date?, now: Date = Date()) -> String {
    guard let d = date else { return "—" }
    let secs = max(0, Int(d.timeIntervalSince(now)))
    let h = secs / 3600, m = (secs % 3600) / 60
    if h >= 24 { return "\(h / 24)d \(h % 24)h" }
    return h > 0 ? "\(h)h \(m)m" : "\(m)m"
}
