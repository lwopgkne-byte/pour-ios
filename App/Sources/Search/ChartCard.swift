import Charts
import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 对话里的图表（网页版 components/charts/ChartSpecView.tsx，规格 5.4 的白名单）：折线、柱状、环形进度、热力图、时间轴。
/// 白底细边的卡片，上面一行小标题；颜色用设计令牌
struct ChartCard: View {
    let spec: API.ChartSpec

    var body: some View {
        if case .unknown = spec {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: Web.space2) {
                Text(spec.title).font(Web.captionMedium).foregroundStyle(Web.fgSecondary)
                switch spec {
                case .series(let series): SeriesChart(spec: series)
                case .ring(let ring): RingChart(spec: ring)
                case .heatmap(let heat): HeatChart(spec: heat)
                case .timeline(let timeline): TimelineChart(spec: timeline)
                case .unknown: EmptyView()
                }
            }
            .padding(Web.space3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Web.radiusCard).fill(Web.bg))
            .overlay(RoundedRectangle(cornerRadius: Web.radiusCard).strokeBorder(Web.line, lineWidth: 1))
        }
    }

    /// 数值的写法：时刻写成 23:40；心情写说法（「在一般和挺好之间」）；其余带单位
    static func value(_ value: Double?, unit: String) -> String {
        guard let value else { return "没有" }
        switch unit {
        case "time": return PourDate.formatTime(value)
        case "mood": return Show.between(value, words: Show.moodWords)
        case "energy": return Show.between(value, words: Show.energyWords)
        default: return "\(Show.fmtNum(value))\(unit.isEmpty ? "" : " \(unit)")"
        }
    }
}

/// 折线 / 柱状：实线是数据，虚线是趋势（移动平均），极浅的横线是目标
private struct SeriesChart: View {
    let spec: API.ChartSpec.Series

    private var mood: Bool { spec.unit == "mood" || spec.unit == "energy" }

    var body: some View {
        Chart {
            ForEach(Array(spec.points.enumerated()), id: \.offset) { index, point in
                if let value = point.value {
                    if spec.type == "bar" {
                        BarMark(x: .value("日子", label(index)), y: .value(spec.title, value), width: .fixed(Web.space6))
                            .foregroundStyle(Web.accent)
                            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 3, topTrailingRadius: 3))
                    } else {
                        LineMark(x: .value("日子", label(index)), y: .value(spec.title, value), series: .value("线", "数据"))
                            .foregroundStyle(Web.accent).lineStyle(StrokeStyle(lineWidth: 2))
                        if spec.points.count <= 14 {
                            PointMark(x: .value("日子", label(index)), y: .value(spec.title, value))
                                .foregroundStyle(Web.accent).symbolSize(Web.space6)
                        }
                    }
                }
            }
            ForEach(Array((spec.trend ?? []).enumerated()), id: \.offset) { index, value in
                if let value, index < spec.points.count {
                    LineMark(x: .value("日子", label(index)), y: .value("趋势", value), series: .value("线", "趋势"))
                        .foregroundStyle(Web.fgTertiary)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [Web.space1, Web.space1]))
                }
            }
            if let target = spec.target {
                RuleMark(y: .value("目标", target)).foregroundStyle(Web.lineStrong).lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("目标 \(ChartCard.value(target, unit: spec.unit))").font(Web.caption).foregroundStyle(
                            Web.fgTertiary)
                    }
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel().font(Web.caption).foregroundStyle(Web.fgTertiary)
            }
        }
        .chartYAxis {
            // 心情、精力只在 1、3、5 写字
            if mood {
                AxisMarks(position: .leading, values: [1.0, 3, 5]) { value in yMark(value) }
            } else {
                AxisMarks(position: .leading) { value in yMark(value) }
            }
        }
        .chartYScale(domain: mood ? 1...5 : yDomain)
        .frame(height: Web.space16 * 2.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(spec.title)的图表"))
        .accessibilityValue(
            Text(spec.points.map { "\($0.label) \(ChartCard.value($0.value, unit: spec.unit))" }.joined(separator: "，"))
        )
    }

    @AxisMarkBuilder private func yMark(_ value: AxisValue) -> some AxisMark {
        AxisGridLine().foregroundStyle(Web.line)
        AxisValueLabel {
            if let number = value.as(Double.self) {
                Text(axis(number)).font(Web.caption).foregroundStyle(Web.fgTertiary)
            }
        }
    }

    /// 横轴的字：同一个说法出现两次时（两个「周一」）也分得开
    private func label(_ index: Int) -> String {
        let text = spec.points[index].label
        return spec.points[..<index].contains { $0.label == text } ? "\(text)\u{200B}\(index)" : text
    }

    /// 时刻类不从 0 画（入睡时间挤在一起看不出），别的从 0 开始
    private var yDomain: ClosedRange<Double> {
        let values = spec.points.compactMap(\.value) + (spec.target.map { [$0] } ?? [])
        guard let low = values.min(), let high = values.max() else { return 0...1 }
        if spec.unit == "time" { return (low - 30)...(high + 30) }
        return min(0, low)...max(high * 1.1, 1)
    }

    private func axis(_ value: Double) -> String {
        switch spec.unit {
        case "time": PourDate.formatTime(value)
        case "mood": [1: "很差", 3: "一般", 5: "很好"][Int(value)] ?? ""
        case "energy": [1: "很累", 3: "一般", 5: "精力充沛"][Int(value)] ?? ""
        default: Show.fmtNum(value)
        }
    }
}

/// 环形进度：目标完成了多少
private struct RingChart: View {
    let spec: API.ChartSpec.Ring

    var body: some View {
        let share = min(1, max(0, spec.pct))
        HStack(spacing: Web.space4) {
            ZStack {
                Circle().stroke(Web.bgHover, lineWidth: Web.space1 + Web.space1 / 2)
                Circle().trim(from: 0, to: share)
                    .stroke(
                        Web.status(spec.tone),
                        style: StrokeStyle(lineWidth: Web.space1 + Web.space1 / 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text("\(Int((share * 100).rounded()))%").font(Web.bodySemibold).foregroundStyle(Web.fg)
            }
            .padding(Web.space1 / 2)
            .frame(width: Web.space16 + Web.space4, height: Web.space16 + Web.space4)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(Show.fmtNum(spec.value)) / \(Show.fmtNum(spec.target)) \(spec.unit)").font(Web.bodyMedium)
                    .foregroundStyle(Web.fg).monospacedDigit()
                Text(Show.spaced(spec.headline)).font(Web.caption).foregroundStyle(Web.fgSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// 日历热力图：一格一天，一列一周，颜色越深量越多
private struct HeatChart: View {
    let spec: API.ChartSpec.Heatmap

    var body: some View {
        let most = max(1, spec.days.map(\.value).max() ?? 1)
        let weeks = columns
        HStack(alignment: .top, spacing: Web.space1 / 2) {
            // 星期几画在图里（整张图读屏念的是每天的值）
            Canvas { context, _ in
                for (row, name) in ["一", "", "三", "", "五", "", "日"].enumerated() where !name.isEmpty {
                    let middle = (Web.space4 + Web.space1 / 2) * CGFloat(row) + Web.space4 / 2
                    context.draw(
                        Text(name).font(Web.caption).foregroundStyle(Web.fgTertiary), at: CGPoint(x: 0, y: middle),
                        anchor: .leading)
                }
            }
            .frame(width: Web.space4, height: Web.space4 * 7 + Web.space1 / 2 * 6)
            .accessibilityHidden(true)
            // 一格一天、方的；很多周放不下就横着滑，先看到最近的
            ScrollView(.horizontal) {
                HStack(spacing: Web.space1 / 2) {
                    ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: Web.space1 / 2) {
                            ForEach(Array(week.enumerated()), id: \.offset) { _, cell in
                                RoundedRectangle(cornerRadius: Web.space1 / 2)
                                    .fill(cell.map { Web.accent.opacity(0.08 + 0.92 * $0.value / most) } ?? .clear)
                                    .frame(width: Web.space4, height: Web.space4)
                            }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            // 放得下靠左；放不下先看到最近的几周
            .defaultScrollAnchor(.leading, for: .alignment)
            .defaultScrollAnchor(.trailing, for: .initialOffset)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(spec.title))
        .accessibilityValue(
            Text(
                spec.days.filter { $0.value > 0 }.map {
                    "\(Show.monthDay($0.day)) \(ChartCard.value($0.value, unit: spec.unit))"
                }
                .joined(separator: "，")))
    }

    /// 一周一列（周一在上），前面空出第一天之前的几格
    private var columns: [[API.ChartDay?]] {
        guard let first = spec.days.first?.day else { return [] }
        let cells: [API.ChartDay?] = Array(repeating: nil, count: PourDate.weekdayMon0(first)) + spec.days
        return stride(from: 0, to: cells.count, by: 7).map { start in
            let week = Array(cells[start..<min(start + 7, cells.count)])
            return week + Array(repeating: nil, count: 7 - week.count)
        }
    }
}

/// 时间轴：每天一行，0 点到 24 点，事件是一段色块
private struct TimelineChart: View {
    let spec: API.ChartSpec.Timeline

    var body: some View {
        let days = Array(Set(spec.items.map(\.day))).sorted()
        if days.isEmpty {
            Text("这段时间没有带起止时间的事件。").font(Web.caption).foregroundStyle(Web.fgTertiary)
        } else {
            VStack(alignment: .leading, spacing: Web.space2) {
                ForEach(days, id: \.self) { day in
                    HStack(spacing: Web.space2) {
                        Text("\(Int(day.dropFirst(5).prefix(2)) ?? 0)/\(Int(day.suffix(2)) ?? 0)").font(Web.caption)
                            .foregroundStyle(Web.fgTertiary).monospacedDigit().frame(
                                minWidth: Web.space8, alignment: .leading)
                        track(day)
                    }
                }
                HStack {
                    ForEach(["0 点", "6", "12", "18", "24"], id: \.self) { mark in
                        Text(mark)
                        if mark != "24" { Spacer() }
                    }
                }
                .font(Web.caption).foregroundStyle(Web.fgTertiary)
                .padding(.leading, Web.space8 + Web.space2)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(spec.title))
            .accessibilityValue(
                Text(
                    spec.items.map { "\($0.day) \($0.label) \($0.start.suffix(5))–\($0.end.suffix(5))" }.joined(
                        separator: "，")))
        }
    }

    private func track(_ day: String) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Web.bgHover)
                ForEach(Array(spec.items.filter { $0.day == day }.enumerated()), id: \.offset) { _, item in
                    let from = item.start.prefix(10) < day ? 0 : minute(item.start)
                    let until = item.end.prefix(10) > day ? 1440 : minute(item.end)
                    Capsule().fill(Web.tag(item.color).solid)
                        .frame(width: max(proxy.size.width * 0.008, proxy.size.width * Double(until - from) / 1440))
                        .offset(x: proxy.size.width * Double(from) / 1440)
                }
            }
        }
        .frame(height: Web.space3)
    }

    private func minute(_ stamp: String) -> Int {
        let clock = stamp.dropFirst(11)
        return (Int(clock.prefix(2)) ?? 0) * 60 + (Int(clock.dropFirst(3).prefix(2)) ?? 0)
    }
}
