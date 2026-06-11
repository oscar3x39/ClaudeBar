import Foundation

/// 某一天的用量（成本）。
struct DayCost: Identifiable {
    let date: Date
    let cost: Double
    var id: Date { date }
    var label: String {
        let f = DateFormatter(); f.dateFormat = "M/d"; return f.string(from: date)
    }
}

/// 從本機 Claude Code JSONL 算每日用量成本。官方 usage API 沒有歷史，這是唯一能做「每日」的來源。
enum UsageHistory {
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
        var totals: [Date: Double] = [:]
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
                    totals[day, default: 0] += Pricing.cost(
                        model: ll.message?.model ?? "",
                        input: u.input_tokens ?? 0, output: u.output_tokens ?? 0,
                        cacheWrite: u.cache_creation_input_tokens ?? 0, cacheRead: u.cache_read_input_tokens ?? 0)
                }
            }
        }

        return (0..<days).compactMap { off -> DayCost? in
            guard let day = cal.date(byAdding: .day, value: -off, to: today) else { return nil }
            return DayCost(date: day, cost: totals[day] ?? 0)
        }.reversed()
    }
}
