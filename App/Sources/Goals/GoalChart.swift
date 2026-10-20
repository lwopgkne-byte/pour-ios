import PourAPI
import PourDesign
import SwiftUI

/// 应达 vs 实际（规格 8.5）：实线是实际，虚线是应达（平均型的虚线是目标值）；
/// 最新的一点是个圆点。下面一行是起止日期和图例
struct GoalChart: View {
    let series: [API.GoalPoint]
    let unit: String
    let tone: String
    let avg: Bool
    var lte = false

    var body: some View {
        VStack(spacing: Web.space1) {
            Canvas { context, size in draw(in: &context, size: size) }
                .frame(height: Web.space16 * 2)
                .accessibilityLabel(Text("实际和应达的对比，最高 \(Show.fmtNum(scale.max)) \(unit)"))
            HStack {
                Text(Show.spaced(Self.monthDay(series.first?.day ?? "")))
                Spacer()
                legend
                Spacer()
                Text(Show.spaced(Self.monthDay(series.last?.day ?? "")))
            }
            .font(Web.caption).foregroundStyle(Web.fgTertiary)
        }
    }

    private var legend: some View {
        HStack(spacing: Web.space1) {
            Capsule().fill(Web.status(tone)).frame(width: Web.space3, height: Web.space1)
            Text("实际")
            Rectangle().stroke(style: StrokeStyle(lineWidth: 1, dash: [Web.space1, Web.space1 / 2]))
                .frame(width: Web.space3, height: 1).padding(.leading, Web.space2)
            Text(avg ? "目标" : lte ? "允许" : "应达")
        }
        .accessibilityElement(children: .combine)
    }

    /// 纵轴的范围：最高多 8%；平均型从最低的 90% 起（看得出起伏）
    private var scale: (min: Double, max: Double) {
        let values = series.flatMap { [$0.actual, $0.expected] }.compactMap { $0 }
        let high = (values.max() ?? 0) * 1.08
        return (avg ? (values.min() ?? 0) * 0.9 : 0, high == 0 ? 1 : high)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        guard series.count > 1 else { return }
        let pad = Web.space1
        let (low, high) = scale
        func point(_ index: Int, _ value: Double) -> CGPoint {
            let x = pad + CGFloat(index) / CGFloat(series.count - 1) * (size.width - pad * 2)
            let span = high - low == 0 ? 1 : high - low
            return CGPoint(x: x, y: size.height - pad - CGFloat((value - low) / span) * (size.height - pad * 2))
        }
        func line(_ pick: (API.GoalPoint) -> Double?) -> Path {
            var path = Path()
            for (index, item) in series.enumerated() {
                guard let value = pick(item) else { continue }
                if path.isEmpty { path.move(to: point(index, value)) } else { path.addLine(to: point(index, value)) }
            }
            return path
        }
        var axis = Path()
        axis.move(to: CGPoint(x: pad, y: size.height - pad))
        axis.addLine(to: CGPoint(x: size.width - pad, y: size.height - pad))
        context.stroke(axis, with: .color(Web.line), lineWidth: 1)
        context.stroke(
            line(\.expected), with: .color(Web.fgTertiary),
            style: StrokeStyle(lineWidth: 1.5, dash: [Web.space1, Web.space1]))
        let color = Web.status(tone)
        context.stroke(line(\.actual), with: .color(color), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        // 最新的一点：圆点
        if let index = series.lastIndex(where: { $0.actual != nil }), let value = series[index].actual {
            let center = point(index, value)
            let dot = CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)
            context.fill(Path(ellipseIn: dot), with: .color(color))
        }
    }

    /// 「2026-09-15」→「9月15日」
    static func monthDay(_ day: String) -> String {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        return parts.count == 3 ? "\(parts[1])月\(parts[2])日" : ""
    }
}

/// 连续型：最近每一天有没有做到，一格一天
struct StreakStrip: View {
    let days: [API.StreakDay]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: Web.space3), spacing: Web.space1)], spacing: Web.space1) {
            ForEach(days, id: \.day) { day in
                RoundedRectangle(cornerRadius: Web.radiusControl)
                    .fill(day.met ? Web.status("good") : Web.bgHover)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("最近 \(days.count) 天里做到了 \(days.filter(\.met).count) 天"))
    }
}
