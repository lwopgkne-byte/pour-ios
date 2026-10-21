import PourAPI
import PourDesign
import SwiftUI

/// 回顾里「这一天的样子」（产品主人 2026-10-21：一天过完了才知道做了什么，总结放在回顾里，不放在画布上）：
/// 一句话总结 + 关键数字的小块（和平常比的那句写在下面），底色是这一天的心情（没记心情是平的暖灰，不猜）。
/// 卡上的字只用主字色：心情的底色上次要色不稳（ThemeColorTests.moodWashText）
struct DayLook: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let overview: String
    let numbers: [API.KeyNumber]
    /// 这一天每条心情的五级
    let levels: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            Label("这一天的样子", systemImage: "sparkles").font(Theme.Typeface.footnoteSemibold)
                .foregroundStyle(Theme.Palette.label)
                .padding(.horizontal, Theme.Space.small).frame(minHeight: Theme.Size.badge + Theme.Space.tight)
                .background(Theme.Palette.statFill, in: Capsule())
                .accessibilityAddTraits(.isHeader)
            if !overview.isEmpty {
                Text(Show.spaced(overview)).font(Theme.Typeface.summary).foregroundStyle(Theme.Palette.label)
                    .lineSpacing(Theme.Leading.summary)
            }
            if !numbers.isEmpty { tiles }
        }
        .padding(Theme.Space.regular)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                Theme.Palette.card
                MoodWash(Self.tone(levels))
            }
            .clipShape(Theme.rounded(Theme.Corner.hero))
        }
        .themeEdge(radius: Theme.Corner.hero)
        .accessibilityElement(children: .contain)
    }

    /// 关键数字：两列（字号很大时一列）
    private var tiles: some View {
        let columns = typeSize.isAccessibilitySize ? 1 : 2
        return Grid(alignment: .topLeading, horizontalSpacing: Theme.Space.small, verticalSpacing: Theme.Space.small) {
            ForEach(Array(stride(from: 0, to: numbers.count, by: columns)), id: \.self) { start in
                GridRow {
                    ForEach(start..<min(start + columns, numbers.count), id: \.self) { index in
                        tile(numbers[index])
                    }
                    if columns == 2, start + 1 >= numbers.count {
                        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("关键数字"))
    }

    private func tile(_ number: API.KeyNumber) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.hairline) {
            Text(Show.spaced(number.label)).font(Theme.Typeface.caption).foregroundStyle(Theme.Palette.label)
            FigureText(
                number.parts.map { ($0.number, $0.unit) }, numberFont: Theme.Typeface.heroMetric,
                unitFont: Theme.Typeface.caption, unitColor: Theme.Palette.label)
            if let compare = number.compare {
                Text(Show.spaced(compare)).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.label)
            }
        }
        .padding(.horizontal, Theme.Space.medium).padding(.vertical, Theme.Space.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.statFill, in: Theme.rounded(Theme.Corner.stat))
        .accessibilityElement(children: .combine)
    }

    /// 这一天的心情（CanvasPlan.mood：有好有坏是有起有落，否则看平均；没记心情不猜）
    static func tone(_ levels: [Double]) -> Theme.MoodTone {
        switch CanvasPlan.mood(levels: levels) {
        case .good: .good
        case .plain: .plain
        case .low: .low
        case .mixed: .mixed
        case .none: .none
        }
    }
}
