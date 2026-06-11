import Foundation

/// 各 model 定價（per MTok，來自 claude-api skill）。cache write=1.25×input、read=0.1×input。
struct ModelPrice { let input, output, cacheWrite, cacheRead: Double }

enum Pricing {
    static let table: [String: ModelPrice] = [
        "claude-opus-4-8": .init(input: 5, output: 25, cacheWrite: 6.25, cacheRead: 0.5),
        "claude-haiku-4-5": .init(input: 1, output: 5, cacheWrite: 1.25, cacheRead: 0.1),
        "claude-haiku-4-5-20251001": .init(input: 1, output: 5, cacheWrite: 1.25, cacheRead: 0.1),
    ]

    /// 單則訊息成本（美金）。未知 model 回 0。
    static func cost(model: String, input: Int, output: Int, cacheWrite: Int, cacheRead: Int) -> Double {
        guard let p = table[model] else { return 0 }
        return (Double(input) * p.input + Double(output) * p.output
            + Double(cacheWrite) * p.cacheWrite + Double(cacheRead) * p.cacheRead) / 1_000_000
    }
}
