import SwiftUI
import Charts

/// 每日用量長條圖，依 model 家族堆疊。資料來自本機 JSONL（非官方 API）。
/// 可切換刻度：$ 絕對成本 / % 相對當期最高日（最高=100%）。
struct DailyChartView: View {
    let days: [DayCost]
    @State private var percent = true // 預設顯示 %

    private let ink = Color(white: 0.13)
    private let sub = Color(white: 0.40)

    /// 核心三家族固定列出（即使當期沒用到也保留圖例），Other 才依實際出現與否。
    private var families: [String] {
        let core = ["Opus", "Sonnet", "Haiku", "Fable"]
        let present = Set(days.flatMap { $0.byModel.keys })
        return present.contains("Other") ? core + ["Other"] : core
    }
    private func color(_ family: String) -> Color {
        switch family {
        case "Opus": return Color(red: 0.55, green: 0.36, blue: 0.86)   // 紫
        case "Sonnet": return Color(red: 0.20, green: 0.78, blue: 0.35) // 綠
        case "Haiku": return Color(red: 0.95, green: 0.62, blue: 0.20)  // 橘
        case "Fable": return Color(red: 0.90, green: 0.35, blue: 0.60)  // 粉
        default: return Color(white: 0.55)                              // 灰
        }
    }

    private var weekdayByLabel: [String: String] {
        Dictionary(days.map { ($0.label, $0.weekday) }, uniquingKeysWith: { a, _ in a })
    }

    private var maxCost: Double { days.map(\.cost).max() ?? 0 }
    private func yValue(_ d: DayCost, _ family: String) -> Double {
        let c = d.byModel[family] ?? 0
        return percent ? (maxCost > 0 ? c / maxCost * 100 : 0) : c
    }
    private var todayText: String {
        guard let t = days.last else { return "" }
        return percent
            ? String(format: "Today %.0f%%", maxCost > 0 ? t.cost / maxCost * 100 : 0)
            : String(format: "Today $%.0f", t.cost)
    }
    /// 當日堆疊總量標籤（掛在最頂端 segment 上）。
    private func totalLabel(_ d: DayCost) -> String {
        guard d.cost > 0 else { return "" }
        return percent
            ? String(format: "%.0f%%", maxCost > 0 ? d.cost / maxCost * 100 : 0)
            : String(format: "$%.0f", d.cost)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Daily Usage").font(.system(size: 15.6, weight: .semibold)).foregroundColor(ink)
                toggle
                Spacer()
                Text(todayText).font(.system(size: 13.2)).foregroundColor(sub)
            }
            Chart {
                ForEach(days) { d in
                    ForEach(Array(families.enumerated()), id: \.element) { idx, fam in
                        BarMark(x: .value("日期", d.label), y: .value("用量", yValue(d, fam)))
                            .foregroundStyle(by: .value("Model", fam))
                            .cornerRadius(2)
                            .annotation(position: .top, spacing: 2) {
                                if idx == families.count - 1 {
                                    Text(totalLabel(d))
                                        .font(.system(size: 9.6, weight: .semibold))
                                        .foregroundColor(sub)
                                }
                            }
                    }
                }
            }
            .chartForegroundStyleScale(domain: families, range: families.map(color))
            .chartLegend(position: .bottom, spacing: 6)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Color.black.opacity(0.06))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(percent ? "\(Int(v))%" : "$\(Int(v))")
                                .font(.system(size: 10.8)).foregroundColor(sub)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let s = value.as(String.self) {
                            VStack(spacing: 1) {
                                Text(s).font(.system(size: 10.8)).foregroundColor(sub)
                                Text(weekdayByLabel[s] ?? "").font(.system(size: 10.8)).foregroundColor(sub)
                            }
                        }
                    }
                }
            }
            .frame(height: 160)
        }
    }

    private var toggle: some View {
        Button { percent.toggle() } label: {
            Text(percent ? "%" : "$")
                .font(.system(size: 13.2, weight: .bold)).foregroundColor(ink)
                .frame(width: 20, height: 18)
                .background(Capsule().stroke(Color.black.opacity(0.18), lineWidth: 1))
        }.buttonStyle(.plain)
    }
}
