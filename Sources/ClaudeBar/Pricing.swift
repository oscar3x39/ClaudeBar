import Foundation

/// 各 model 定價（per MTok，來自 claude-api skill）。cache write=1.25×input、read=0.1×input。
struct ModelPrice { let input, output, cacheWrite, cacheRead: Double }

enum Pricing {
    /// 依 model 家族定價（per MTok）。用家族而非完整 id 比對，
    /// 才不會因版本後綴（如 `[1m]`、日期、新版號）對不上而把成本算成 0。
    static let byFamily: [String: ModelPrice] = [
        "Opus":   .init(input: 5, output: 25, cacheWrite: 6.25, cacheRead: 0.5),
        "Sonnet": .init(input: 3, output: 15, cacheWrite: 3.75, cacheRead: 0.3),
        "Haiku":  .init(input: 1, output: 5,  cacheWrite: 1.25, cacheRead: 0.1),
        "Fable":  .init(input: 5, output: 25, cacheWrite: 6.25, cacheRead: 0.5),
    ]

    /// 單則訊息成本（美金）。未知家族（Other）回 0。
    static func cost(model: String, input: Int, output: Int, cacheWrite: Int, cacheRead: Int) -> Double {
        guard let p = byFamily[UsageHistory.modelFamily(model)] else { return 0 }
        return (Double(input) * p.input + Double(output) * p.output
            + Double(cacheWrite) * p.cacheWrite + Double(cacheRead) * p.cacheRead) / 1_000_000
    }
}
