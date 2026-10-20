public import SwiftUI

// 柱和横条（docs/归档/设计规范/09-数据可视化.md）：对比横条、一周七天。从 Charts.swift 分出来（文件太长）

// MARK: - 对比横条（2.5，发现卡）

public struct PourCompareBars: View {
    let theseLabel: String
    let these: Double
    let othersLabel: String
    let others: Double
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(theseLabel: String, these: Double, othersLabel: String, others: Double) {
        self.theseLabel = theseLabel
        self.these = these
        self.othersLabel = othersLabel
        self.others = others
    }

    /// 字按自己的宽度排，不用固定宽度（固定宽度在大字号时把「这些日子」挤成一个字一行——M1 自验收）。
    /// 大字号时一条一行：上面「名字 … 百分比」，下面整行的横条
    public var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: PourSpace.element) {
                    stacked(theseLabel, these, PourColor.chartPrimary)
                    stacked(othersLabel, others, PourColor.chartSecondary)
                }
            } else {
                Grid(alignment: .leading, horizontalSpacing: PourSpace.related, verticalSpacing: PourSpace.related) {
                    row(theseLabel, these, PourColor.chartPrimary)
                    row(othersLabel, others, PourColor.chartSecondary)
                }
            }
        }
        .frame(minHeight: PourSize.minTap)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(theseLabel) \(percent(these))，\(othersLabel) \(percent(others))"))
    }

    private func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }

    private func row(_ label: String, _ value: Double, _ color: ColorToken) -> some View {
        GridRow {
            Text(label).pourText(.caption).foregroundStyle(PourColor.inkSecondary.color)
            track(value, color)
            valueText(value).gridColumnAlignment(.trailing)
        }
    }

    private func stacked(_ label: String, _ value: Double, _ color: ColorToken) -> some View {
        VStack(alignment: .leading, spacing: PourSpace.tight) {
            HStack(alignment: .firstTextBaseline, spacing: PourSpace.related) {
                Text(label).pourText(.caption).foregroundStyle(PourColor.inkSecondary.color)
                Spacer(minLength: PourSpace.related)
                valueText(value)
            }
            track(value, color)
        }
    }

    private func valueText(_ value: Double) -> some View {
        Text(verbatim: percent(value)).pourText(.caption).monospacedDigit().foregroundStyle(PourColor.ink.color)
    }

    private func track(_ value: Double, _ color: ColorToken) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(PourColor.fillSelected.color)
                Capsule().fill(color.color).frame(width: max(8, proxy.size.width * min(max(value, 0), 1)))
            }
        }
        .frame(height: 8)
    }
}

// MARK: - 一周七天（2.4）

public struct PourWeekBars: View {
    let values: [Double]
    /// 要说「哪天最高 / 最低」时，那一根用墨色并在上方写字
    let highlightIndex: Int?
    let highlightLabel: String?
    let barHeight: CGFloat
    let showsDays: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        _ values: [Double], highlightIndex: Int? = nil, highlightLabel: String? = nil,
        barHeight: CGFloat = 80, showsDays: Bool = true
    ) {
        self.values = Array(values.prefix(7))
        self.highlightIndex = highlightIndex
        self.highlightLabel = highlightLabel
        self.barHeight = barHeight
        self.showsDays = showsDays
    }

    public var body: some View {
        let top = max(values.max() ?? 1, 0.0001)
        let days = ["一", "二", "三", "四", "五", "六", "日"]
        // 大字号时柱子上方一格放不下「最多」（会折成「最 / 多」）：改成图上方一整行「周日 · 最多」
        let labelAbove = dynamicTypeSize.isAccessibilitySize
        VStack(alignment: .leading, spacing: PourSpace.tight) {
            if labelAbove, let highlightIndex, let highlightLabel {
                Text(verbatim: "周\(days[highlightIndex]) · \(highlightLabel)").pourText(.micro)
                    .foregroundStyle(PourColor.ink.color)
            }
            grid(top: top, days: days, labelInChart: !labelAbove)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("一周七天"))
        .accessibilityValue(
            Text(values.indices.map { "周\(days[$0]) \(Int(values[$0].rounded()))" }.joined(separator: "，")))
    }

    // 柱子区高度固定；上面的标注、下面的星期按字自己的大小排——字调大时整张图跟着长高，不挤字
    private func grid(top: Double, days: [String], labelInChart: Bool) -> some View {
        Grid(horizontalSpacing: PourSpace.related, verticalSpacing: PourSpace.tight) {
            if labelInChart, let highlightIndex, let highlightLabel {
                GridRow {
                    ForEach(values.indices, id: \.self) { index in
                        Text(index == highlightIndex ? highlightLabel : " ").pourText(.micro)
                            .foregroundStyle(PourColor.ink.color)
                    }
                }
            }
            GridRow(alignment: .bottom) {
                ForEach(values.indices, id: \.self) { index in
                    UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4, style: .continuous)
                        .fill((index == highlightIndex ? PourColor.chartSelected : PourColor.chartPrimary).color)
                        .frame(height: max(2, barHeight * CGFloat(values[index] / top)))
                        .frame(maxWidth: .infinity, maxHeight: barHeight, alignment: .bottom)
                }
            }
            if showsDays {
                GridRow {
                    ForEach(values.indices, id: \.self) { index in
                        Text(days[index]).pourText(.micro).foregroundStyle(PourColor.chartLabel.color)
                    }
                }
            }
        }
    }
}
