import Charts
import PourAPI
import PourDesign
import SwiftUI

/// 心情和精力（看板并进「心情」那一页，网页版 about-board.tsx 的 MoodEnergy、charts/MoodChart.tsx）：
/// 纵轴固定 1–5，写「很差 / 一般 / 很好」；没记的天断开、不连线；按天看时每一条心情一个浅色的点
struct MoodEnergy: View {
    @Environment(AppModel.self) private var model
    @State private var dim = "day"
    @State private var mood: API.BoardTrend?
    @State private var energy: API.BoardTrend?

    private static let dims = [
        (key: "day", label: "日"), (key: "week", label: "周"), (key: "month", label: "月"), (key: "year", label: "年"),
    ]

    var body: some View {
        // 先放一个看不见的：数据还没回来时这一块是空的，空的不会开始加载
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 0)
            if let mood, !mood.points.allSatisfy({ $0.value == nil }) {
                ReviewSection(title: "心情和精力") {
                    WebSegmented("维度", options: Self.dims, selected: dim) { dim = $0 }
                    MoodChart(mood: mood, energy: energy, each: dim == "day" ? mood.each : nil)
                    MeNote("从很差到很好，是 AI 从你的话里听出来的；精力只在你说到时才有。\(dim == "day" ? "线是一天的平均，浅色的点是每一条心情。" : "")")
                }
            }
        }
        .task(id: "\(dim)-\(model.dataVersion)") {
            mood = try? await model.client.trend("mood:mood", dim: dim)
            energy = try? await model.client.trend("mood:energy", dim: dim)
        }
    }
}

/// 两条线：心情（粉）、精力（蓝，一次都没说过就不画）；没记的天断开
private struct MoodChart: View {
    let mood: API.BoardTrend
    let energy: API.BoardTrend?
    let each: [[Double]]?

    private struct Point: Identifiable {
        let id: String
        let index: Int
        let value: Double
        let series: String
        /// 断开的地方换一段，线就不连过去
        let segment: Int
    }

    private func points(_ trend: API.BoardTrend?, _ name: String) -> [Point] {
        guard let trend else { return [] }
        var segment = 0
        var out: [Point] = []
        for (index, point) in trend.points.enumerated() {
            guard let value = point.value else {
                segment += 1
                continue
            }
            out.append(
                Point(
                    id: "\(name)-\(index)", index: index, value: (value * 10).rounded() / 10, series: name,
                    segment: segment))
        }
        return out
    }

    var body: some View {
        let moodPoints = points(mood, "心情")
        let energyPoints = points(energy, "精力")
        let labels = mood.points.map(\.label)
        VStack(alignment: .leading, spacing: Web.space2) {
            Chart {
                ForEach(Array((each ?? []).enumerated()), id: \.offset) { index, day in
                    ForEach(Array(day.enumerated()), id: \.offset) { _, value in
                        PointMark(x: .value("日子", index), y: .value("心情", value))
                            .foregroundStyle(Web.tag("pink").solid.opacity(0.3)).symbolSize(Web.space8 + Web.space4)
                    }
                }
                ForEach(moodPoints) { point in
                    LineMark(
                        x: .value("日子", point.index), y: .value("心情", point.value),
                        series: .value("线", "心情\(point.segment)")
                    )
                    .foregroundStyle(Web.tag("pink").solid).lineStyle(StrokeStyle(lineWidth: 2))
                    PointMark(x: .value("日子", point.index), y: .value("心情", point.value))
                        .foregroundStyle(Web.tag("pink").solid).symbolSize(Web.space6)
                }
                ForEach(energyPoints) { point in
                    LineMark(
                        x: .value("日子", point.index), y: .value("精力", point.value),
                        series: .value("线", "精力\(point.segment)")
                    )
                    .foregroundStyle(Web.tag("blue").solid).lineStyle(StrokeStyle(lineWidth: 2))
                    PointMark(x: .value("日子", point.index), y: .value("精力", point.value))
                        .foregroundStyle(Web.tag("blue").solid).symbolSize(Web.space6)
                }
            }
            .chartYScale(domain: 1...5)
            .chartXScale(domain: -0.5...Double(max(labels.count, 1)) - 0.5)
            .chartYAxis {
                AxisMarks(position: .leading, values: [1.0, 3, 5]) { value in
                    AxisGridLine().foregroundStyle(Web.line)
                    AxisValueLabel {
                        if let level = value.as(Double.self) {
                            Text([1: "很差", 3: "一般", 5: "很好"][Int(level)] ?? "").font(Web.caption).foregroundStyle(
                                Web.fgTertiary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisValueLabel {
                        if let index = value.as(Int.self), labels.indices.contains(index) {
                            Text(labels[index]).font(Web.caption).foregroundStyle(Web.fgTertiary)
                        }
                    }
                }
            }
            .frame(height: Web.space16 * 2.5)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("心情和精力的曲线"))
            .accessibilityValue(Text(summary(labels)))
            HStack(spacing: Web.space4) {
                legend(Web.tag("pink").solid, "心情")
                if !energyPoints.isEmpty { legend(Web.tag("blue").solid, "精力") }
            }
            .font(Web.caption).foregroundStyle(Web.fgSecondary)
        }
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: Web.space1) {
            Circle().fill(color).frame(width: Web.space2, height: Web.space2)
            Text(text)
        }
    }

    private func summary(_ labels: [String]) -> String {
        mood.points.enumerated().compactMap { index, point in
            point.value.map { "\(labels[index]) 心情 \(Show.between($0, words: Show.moodWords))" }
        }
        .joined(separator: "，")
    }
}

/// 心情从哪来（看板并进「心情」那一页）：30 天、90 天、今年
struct MoodFrom: View {
    @Environment(AppModel.self) private var model
    @State private var range = "30d"
    @State private var data: API.MoodSources?
    @State private var problem: String?

    private static let ranges = [(key: "30d", label: "30 天"), (key: "90d", label: "90 天"), (key: "year", label: "今年")]

    var body: some View {
        ReviewSection(title: "心情从哪来") {
            WebSegmented("范围", options: Self.ranges, selected: range) { range = $0 }
            if let data {
                MoodSourcesView(data: data, interactive: true)
            } else if let problem {
                WebErrorState(problem) { Task { await load() } }
            } else {
                WebSkeleton(height: Web.space16)
            }
        }
        .task(id: "\(range)-\(model.dataVersion)") { await load() }
    }

    private func load() async {
        do {
            data = try await model.client.moodSources(range)
            problem = nil
        } catch {
            problem = error.readable
        }
    }
}
