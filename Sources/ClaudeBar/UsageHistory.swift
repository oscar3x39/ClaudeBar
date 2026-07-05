import Foundation

/// 某一天的用量（成本），依 model 家族細分。
struct DayCost: Identifiable {
    let date: Date
    let byModel: [String: Double] // model 家族（Opus/Sonnet/Haiku/Other）-> 成本
    var cost: Double { byModel.values.reduce(0, +) }
    var id: Date { date }
    var label: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US")
        f.dateFormat = "M/d"; return f.string(from: date)
    }
    var weekday: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEE" // 短版星期，例：Wed
        return f.string(from: date)
    }
}

/// 從本機 Claude Code JSONL 算每日用量成本。官方 usage API 沒有歷史，這是唯一能做「每日」的來源。
enum UsageHistory {
    /// 把 model id（如 claude-opus-4-…）正規化成顯示家族。
    static func modelFamily(_ model: String) -> String {
        let m = model.lowercased()
        if m.contains("opus") { return "Opus" }
        if m.contains("sonnet") { return "Sonnet" }
        if m.contains("haiku") { return "Haiku" }
        if m.contains("fable") { return "Fable" }
        return "Other"
    }

    private struct LogLine: Decodable {
        let timestamp: String?
        let message: Msg?
        struct Msg: Decodable { let id: String?; let model: String?; let usage: Usage? }
        struct Usage: Decodable {
            let input_tokens: Int?
            let output_tokens: Int?
            let cache_creation_input_tokens: Int?
            let cache_read_input_tokens: Int?
        }
    }

    /// 最近 `days` 天（含今天，無資料補 0），按本地日期、message.id 去重後加總成本。
    static func recentDays(_ days: Int = 7,
                           projectsDir: URL = FileManager.default.homeDirectoryForCurrentUser
                            .appendingPathComponent(".claude/projects")) -> [DayCost] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }

        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoPlain = ISO8601DateFormatter(); isoPlain.formatOptions = [.withInternetDateTime]
        let decoder = JSONDecoder()
        let fm = FileManager.default
        var totals: [Date: [String: Double]] = [:]
        var seen = Set<String>()

        if let en = fm.enumerator(at: projectsDir, includingPropertiesForKeys: [.contentModificationDateKey]) {
            for case let url as URL in en where url.pathExtension == "jsonl" {
                if let m = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                   m < start { continue } // 視窗外的檔案跳過
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
                for line in content.split(separator: "\n") {
                    guard let data = line.data(using: .utf8),
                          let ll = try? decoder.decode(LogLine.self, from: data),
                          let u = ll.message?.usage,
                          let ts = ll.timestamp,
                          let d = iso.date(from: ts) ?? isoPlain.date(from: ts) else { continue }
                    let day = cal.startOfDay(for: d)
                    if day < start { continue }
                    if let id = ll.message?.id { if seen.contains(id) { continue }; seen.insert(id) }
                    let model = ll.message?.model ?? ""
                    let fam = modelFamily(model)
                    let c = Pricing.cost(
                        model: model,
                        input: u.input_tokens ?? 0, output: u.output_tokens ?? 0,
                        cacheWrite: u.cache_creation_input_tokens ?? 0, cacheRead: u.cache_read_input_tokens ?? 0)
                    totals[day, default: [:]][fam, default: 0] += c
                }
            }
        }

        return (0..<days).compactMap { off -> DayCost? in
            guard let day = cal.date(byAdding: .day, value: -off, to: today) else { return nil }
            return DayCost(date: day, byModel: totals[day] ?? [:])
        }.reversed()
    }
}
