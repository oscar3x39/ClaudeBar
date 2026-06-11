import SwiftUI
import Charts

/// 每日用量長條圖。資料來自本機 JSONL（非官方 API）。
/// 可切換刻度：$ 絕對成本 / % 相對當期最高日（最高=100%）。
struct DailyChartView: View {
    let days: [DayCost]
    @State private var percent = true // 預設顯示 %

    private let ink = Color(white: 0.13)
    private let sub = Color(white: 0.40)
    private let green = Color(red: 0.20, green: 0.78, blue: 0.35)

    private var maxCost: Double { days.map(\.cost).max() ?? 0 }
    private func yValue(_ d: DayCost) -> Double {
        percent ? (maxCost > 0 ? d.cost / maxCost * 100 : 0) : d.cost
    }
    private var todayText: String {
        guard let t = days.last else { return "" }
        return percent
            ? String(format: "Today %.0f%%", maxCost > 0 ? t.cost / maxCost * 100 : 0)
            : String(format: "Today $%.0f", t.cost)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Daily Usage").font(.system(size: 13, weight: .semibold)).foregroundColor(ink)
                toggle
                Spacer()
                Text(todayText).font(.system(size: 11)).foregroundColor(sub)
            }
            Chart(days) { d in
                BarMark(x: .value("日期", d.label), y: .value("用量", yValue(d)))
                    .foregroundStyle(d.id == days.last?.id ? green : green.opacity(0.45))
                    .cornerRadius(3)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Color.black.opacity(0.06))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(percent ? "\(Int(v))%" : "$\(Int(v))")
                                .font(.system(size: 9)).foregroundColor(sub)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let s = value.as(String.self) {
                            Text(s).font(.system(size: 9)).foregroundColor(sub)
                        }
                    }
                }
            }
            .frame(height: 110)
        }
    }

    private var toggle: some View {
        Button { percent.toggle() } label: {
            Text(percent ? "%" : "$")
                .font(.system(size: 11, weight: .bold)).foregroundColor(ink)
                .frame(width: 20, height: 18)
                .background(Capsule().stroke(Color.black.opacity(0.18), lineWidth: 1))
        }.buttonStyle(.plain)
    }
}
