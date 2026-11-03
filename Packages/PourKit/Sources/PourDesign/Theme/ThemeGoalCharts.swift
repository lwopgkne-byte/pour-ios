import Charts
public import SwiftUI

// 3.0 目标的图（docs/3.0/06-交互细节.md 12.3）：都能**按住左右拖**看每一天、每一周，竖着划照常滚页面（系统的 chartXSelection）

// MARK: - 应达和实际 + 预测带

/// 实际一条实线（落后是黄）、应达一条灰虚线、今天以后一段浅蓝的预测带（慢的时候到快的时候）；上面一行写按住的那一天
public struct GoalLineChart: View {
    let actual: [Double]
    let expected: [Double]
    let today: Int
    let slow: Double?
    let fast: Double?
    let target: Double
    let behind: Bool
    let ticks: [(at: Int, text: String)]
    /// 按住第几天时上面那一行写什么（没按住是 nil：写今天）
    let caption: (Int?) -> String
    @State private var picked: Int?

    public init(
        actual: [Double], expected: [Double], today: Int, slow: Double?, fast: Double?, target: Double, behind: Bool,
        ticks: [(at: Int, text: String)], caption: @escaping (Int?) -> String
    ) {
        self.actual = actual
        self.expected = expected
        self.today = today
        self.slow = slow
        self.fast = fast
        self.target = target
        self.behind = behind
        self.ticks = ticks
        self.caption = caption
    }

    private var color: Color { behind ? Theme.Palette.warn : Theme.Palette.good }
    private var now: Double { actual.last ?? 0 }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text(caption(picked)).font(Theme.Typeface.footnote).monospacedDigit()
                .foregroundStyle(Theme.Palette.secondaryLabel).frame(minHeight: Theme.Size.tickRow, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("goal.chart.caption")
            chart
            HStack(spacing: Theme.Space.medium) {
                legend(color, "实际", dashed: false)
                legend(Theme.Palette.tertiaryLabel, "应达", dashed: true)
                if slow != nil {
                    HStack(spacing: Theme.Space.tight) {
                        RoundedRectangle(cornerRadius: Theme.Corner.bar).fill(Theme.Palette.accent.opacity(0.16))
                            .frame(width: Theme.Space.regular, height: Theme.Space.small)
                        Text("照最近的速度").font(Theme.Typeface.tick).foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                }
            }
            .accessibilityHidden(true)
        }
    }

    private var chart: some View {
        Chart {
            if let slow, let fast {
                ForEach(today..<expected.count, id: \.self) { day in
                    AreaMark(
                        x: .value("第几天", day),
                        yStart: .value("慢", min(target * 1.1, now + slow * Double(day - today))),
                        yEnd: .value("快", min(target * 1.1, now + fast * Double(day - today)))
                    )
                    .foregroundStyle(Theme.Palette.accent.opacity(0.12))
                }
            }
            ForEach(Array(expected.enumerated()), id: \.offset) { day, value in
                LineMark(x: .value("第几天", day), y: .value("应达", value), series: .value("线", "应达"))
                    .foregroundStyle(Theme.Palette.tertiaryLabel).lineStyle(StrokeStyle(lineWidth: 1.6, dash: [5, 5]))
            }
            ForEach(Array(actual.enumerated()), id: \.offset) { day, value in
                LineMark(x: .value("第几天", day), y: .value("实际", value), series: .value("线", "实际"))
                    .foregroundStyle(color).lineStyle(StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
            }
            if let picked {
                RuleMark(x: .value("第几天", picked)).foregroundStyle(Theme.Palette.separator)
                if actual.indices.contains(picked) {
                    PointMark(x: .value("第几天", picked), y: .value("实际", actual[picked])).foregroundStyle(color)
                        .symbolSize(60)
                }
            }
        }
        .chartXScale(domain: 0...max(1, expected.count - 1))
        .chartYScale(domain: 0...max(target, 1))
        .chartXSelection(value: $picked)
        .chartXAxis {
            AxisMarks(values: ticks.map(\.at)) { value in
                AxisValueLabel {
                    if let at = value.as(Int.self), let tick = ticks.first(where: { $0.at == at }) {
                        Text(tick.text).font(Theme.Typeface.tick).foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, target / 2, target]) { _ in
                AxisGridLine().foregroundStyle(Theme.Palette.separator)
                AxisValueLabel().font(Theme.Typeface.tick).foregroundStyle(Theme.Palette.secondaryLabel)
            }
        }
        .frame(height: Theme.Size.goalChart)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("应达和实际"))
        .accessibilityValue(Text(caption(nil)))
    }

    private func legend(_ color: Color, _ text: String, dashed: Bool) -> some View {
        HStack(spacing: Theme.Space.tight) {
            Capsule().stroke(color, style: StrokeStyle(lineWidth: 2, dash: dashed ? [3, 2] : []))
                .frame(width: Theme.Space.regular, height: Theme.Space.hairline)
            Text(text).font(Theme.Typeface.tick).foregroundStyle(Theme.Palette.secondaryLabel)
        }
    }
}

// MARK: - 按周的柱子

/// 平均、每周几次、不超过：按周的柱子 + 目标虚线；按住拖动看每一周（这周到今天的浅一点）
public struct WeekBarsChart: View {
    public struct Bar: Hashable, Sendable {
        public var label: String
        public var value: Double
        public var current: Bool

        public init(label: String, value: Double, current: Bool) {
            self.label = label
            self.value = value
            self.current = current
        }
    }

    let bars: [Bar]
    let line: Double?
    let tint: Color
    let caption: (Int) -> String
    @State private var picked: Int?

    /// 柱子占一格的 62%：左右各一半
    static let half = 0.31

    /// 一根柱子。横轴是数（按住选哪一周要用数），按比例的宽度在数的轴上没有「一格」可比，画出来是 0 宽：
    /// 每根柱子自己写左右两边
    private func column(_ index: Int, _ bar: Bar, shown: Int) -> some ChartContent {
        let left = Double(index) - Self.half
        let right = Double(index) + Self.half
        let color = tint.opacity(Self.strength(index == shown, current: bar.current))
        return RectangleMark(
            xStart: .value("哪一周", left), xEnd: .value("哪一周", right), yStart: .value("多少", 0.0),
            yEnd: .value("多少", bar.value)
        )
        .foregroundStyle(color)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Corner.bar))
    }

    /// 按住的那一根最深，这周到今天的浅一点
    static func strength(_ picked: Bool, current: Bool) -> Double {
        if picked { return 1 }
        return current ? 0.4 : 0.62
    }

    public init(bars: [Bar], line: Double?, tint: Color, caption: @escaping (Int) -> String) {
        self.bars = bars
        self.line = line
        self.tint = tint
        self.caption = caption
    }

    public var body: some View {
        let shown = picked ?? bars.count - 1
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text(caption(min(max(0, shown), max(0, bars.count - 1)))).font(Theme.Typeface.footnote).monospacedDigit()
                .foregroundStyle(Theme.Palette.secondaryLabel).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("goal.bars.caption")
            Chart {
                ForEach(Array(bars.enumerated()), id: \.offset) { index, bar in
                    column(index, bar, shown: shown)
                }
                if let line {
                    RuleMark(y: .value("目标", line)).foregroundStyle(Theme.Palette.tertiaryLabel)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                }
            }
            .chartXScale(domain: -0.5...Double(max(bars.count, 1)) - 0.5)
            .chartXSelection(value: $picked)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: Array(bars.indices)) { value in
                    AxisValueLabel {
                        if let index = value.as(Int.self), bars.indices.contains(index) {
                            Text(bars[index].label).font(Theme.Typeface.tick)
                                .foregroundStyle(index == shown ? Theme.Palette.label : Theme.Palette.tertiaryLabel)
                        }
                    }
                }
            }
            .frame(height: Theme.Size.weekBars)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("每一周"))
            .accessibilityValue(Text(bars.indices.map(caption).joined(separator: "；")))
        }
    }
}

// MARK: - 往下的小曲线（体重）

/// 每个点是一周的平均
public struct SmallCurve: View {
    let points: [(label: String, value: Double)]
    let tint: Color

    public init(points: [(label: String, value: Double)], tint: Color) {
        self.points = points
        self.tint = tint
    }

    public var body: some View {
        let values = points.map(\.value)
        let low = (values.min() ?? 0) - 0.3
        let high = (values.max() ?? 1) + 0.3
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                LineMark(x: .value("哪一周", index), y: .value("多少", point.value)).foregroundStyle(tint)
                    .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round))
                PointMark(x: .value("哪一周", index), y: .value("多少", point.value)).foregroundStyle(tint).symbolSize(36)
                    .annotation(position: .top) {
                        Text(String(format: "%.1f", point.value)).font(Theme.Typeface.tick).monospacedDigit()
                            .foregroundStyle(Theme.Palette.secondaryLabel)
                    }
            }
        }
        .chartYScale(domain: low...high)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: Array(points.indices)) { value in
                AxisValueLabel {
                    if let index = value.as(Int.self), points.indices.contains(index) {
                        Text(points[index].label).font(Theme.Typeface.tick).foregroundStyle(Theme.Palette.tertiaryLabel)
                    }
                }
            }
        }
        .frame(height: Theme.Size.weekBars)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("每周的平均"))
        .accessibilityValue(
            Text(points.map { "\($0.label) \(String(format: "%.1f", $0.value))" }.joined(separator: "，")))
    }
}

#Preview("目标的图") {
    VStack(spacing: Theme.Space.large) {
        GoalLineChart(
            actual: [10, 18.2, 18.2, 30.7, 45.7, 45.7, 55.5, 69.9, 69.9, 84, 92.4],
            expected: (0..<100).map { Double($0 + 1) * 5 },
            today: 10, slow: 1.09, fast: 1.54, target: 500, behind: true,
            ticks: [(0, "9/23"), (39, "11月"), (99, "12/31")]
        ) { day in day.map { "第 \($0) 天" } ?? "今天：实际 92.4 · 到昨天应达 170 公里" }
        WeekBarsChart(
            bars: [.init(label: "10/5", value: 2, current: false), .init(label: "10/26", value: 1, current: true)],
            line: 2, tint: Theme.Palette.good
        ) { "第 \($0) 周" }
        SmallCurve(
            points: [("10/1", 72), ("10/5", 71.9), ("10/12", 71.7), ("10/19", 71.6), ("10/26", 71.4)],
            tint: Theme.Palette.warn)
    }
    .padding()
    .background(Theme.Palette.background)
}
