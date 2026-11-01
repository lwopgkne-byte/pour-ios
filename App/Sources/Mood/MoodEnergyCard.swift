import Charts
import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 心情和精力（06 交互细节 10.1）：日 / 周 / 月 / 年；粉线是心情、蓝点是精力（一次都没说过就不画）；
/// 纵轴固定 1–5，没记的天断开不连线；按住拖动，上面一行写「10/27：心情 一般 · 精力 有点累」
struct MoodEnergyCard: View {
    @Environment(AppModel.self) private var model
    @State private var dim = "day"
    @State private var mood: API.BoardTrend?
    @State private var energy: API.BoardTrend?
    @State private var picked: Int?

    private static let dims = [("day", "日"), ("week", "周"), ("month", "月"), ("year", "年")]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            MoodCardHeader("心情和精力")
            Picker("按什么看", selection: $dim) {
                ForEach(Self.dims, id: \.0) { key, name in Text(name).tag(key) }
            }
            .pickerStyle(.segmented)
            Text(caption).font(Theme.Typeface.footnote).monospacedDigit().foregroundStyle(Theme.Palette.secondaryLabel)
                .lineLimit(2)
            if let mood, mood.points.contains(where: { $0.value != nil }) {
                chart(mood)
            } else {
                Text("这段时间还没说到心情。").font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
            }
            Text("从很差到很好，是 AI 从你的话里听出来的；精力只在你说到时才有。按住拖动看每一个点。")
                .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
        }
        .themeCard()
        .task(id: "\(dim)-\(model.dataVersion)") {
            picked = nil
            mood = try? await model.client.trend("mood:mood", dim: dim)
            energy = try? await model.client.trend("mood:energy", dim: dim)
        }
    }

    /// 没按住时是图例；按住了写那一个点的心情、精力
    private var caption: String {
        guard let picked, let mood, mood.points.indices.contains(picked) else {
            return energy?.points.contains(where: { $0.value != nil }) == true ? "━ 心情（粉）· ● 精力（蓝）" : "━ 心情"
        }
        let point = mood.points[picked]
        let moodText = point.value.map { "心情 \(Show.between($0, words: Show.moodWords))" } ?? "没说心情"
        let energyValue = energy.flatMap { $0.points.indices.contains(picked) ? $0.points[picked].value : nil }
        return "\(point.label)：\(moodText)\(energyValue.map { " · 精力 \(Show.energyWord($0))" } ?? "")"
    }

    private func chart(_ mood: API.BoardTrend) -> some View {
        let moodLine = segments(mood)
        let energyDots = segments(energy)
        let labels = mood.points.map(\.label)
        return Chart {
            ForEach(moodLine, id: \.index) { point in
                LineMark(
                    x: .value("第几个", point.index), y: .value("心情", point.value),
                    series: .value("段", "心情\(point.segment)")
                )
                .foregroundStyle(Theme.Mood.fill(5)).lineStyle(StrokeStyle(lineWidth: 2, lineJoin: .round))
                PointMark(x: .value("第几个", point.index), y: .value("心情", point.value))
                    .foregroundStyle(Theme.Mood.fill(5)).symbolSize(24)
            }
            ForEach(energyDots, id: \.index) { point in
                PointMark(x: .value("第几个", point.index), y: .value("精力", point.value))
                    .foregroundStyle(Theme.Palette.accent).symbolSize(30)
            }
            if let picked {
                RuleMark(x: .value("第几个", picked)).foregroundStyle(Theme.Palette.separator)
            }
        }
        .chartYScale(domain: 1...5)
        .chartXScale(domain: -0.5...Double(max(labels.count, 1)) - 0.5)
        .chartXSelection(value: $picked)
        .chartYAxis {
            AxisMarks(position: .leading, values: [1.0, 3, 5]) { value in
                AxisGridLine().foregroundStyle(Theme.Palette.separator)
                AxisValueLabel {
                    if let level = value.as(Double.self) {
                        Text([1: "很差", 3: "一般", 5: "很好"][Int(level)] ?? "").font(Theme.Typeface.caption)
                            .foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel {
                    if let index = value.as(Int.self), labels.indices.contains(index) {
                        Text(labels[index]).font(Theme.Typeface.caption).foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                }
            }
        }
        .frame(height: Theme.Size.curve * 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("心情和精力的曲线"))
        .accessibilityValue(Text(spoken(mood)))
    }

    private struct Point {
        let index: Int
        let value: Double
        /// 断开的地方换一段，线就不连过去
        let segment: Int
    }

    private func segments(_ trend: API.BoardTrend?) -> [Point] {
        guard let trend else { return [] }
        var segment = 0
        var out: [Point] = []
        for (index, point) in trend.points.enumerated() {
            guard let value = point.value else {
                segment += 1
                continue
            }
            out.append(Point(index: index, value: (value * 10).rounded() / 10, segment: segment))
        }
        return out
    }

    private func spoken(_ mood: API.BoardTrend) -> String {
        mood.points.compactMap { point in
            point.value.map { "\(point.label) 心情 \(Show.between($0, words: Show.moodWords))" }
        }
        .joined(separator: "，")
    }
}
