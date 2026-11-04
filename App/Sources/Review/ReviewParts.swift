import PourAPI
import PourCore
import PourDesign
import SwiftUI

/*
 * 3.0「看整页」（故事最后一页进来，07 开发任务清单 6.4a）：每日回顾、周报、月报的长页面，和待办、钱、心情同一种卡片。
 * 现在长页面里有的一块不少（做了什么全部领域、目标全部、今天、来源几段话、看这一天的画布、这一周的周报……）
 */

/// 一页的开头：日子（或那一周、那个月）和「昨天」「上周」、「已更新」；周报月报下面一句话
struct ReviewHead: View {
    let title: String
    let relative: String?
    let updated: Bool
    var overview = ""
    /// 一行小字（每日回顾：大标题已经是那一天，这里只写「每日回顾 · 昨天」）
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.small) {
                if compact {
                    Text([title, relative].compactMap { $0 }.joined(separator: " · ")).font(Theme.Typeface.footnote)
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                } else {
                    Text(Show.spaced(title)).font(Theme.Typeface.section).foregroundStyle(Theme.Palette.label)
                    if let relative {
                        Text(relative).font(Theme.Typeface.section).foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                }
                Spacer(minLength: 0)
                if updated {
                    Text("已更新").font(Theme.Typeface.caption).foregroundStyle(Theme.Palette.secondaryLabel)
                        .padding(.horizontal, Theme.Space.snug).padding(.vertical, Theme.Space.hairline)
                        .background(Theme.Palette.fill, in: Capsule())
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            if !overview.isEmpty {
                Text(Show.spaced(overview)).font(Theme.Typeface.summary).foregroundStyle(Theme.Palette.label)
                    .lineSpacing(Theme.Leading.summary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// 一块：标题在卡片外面，下面一张卡（照原型「每日回顾」）
struct ReviewSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        PageSection(title: title) {
            VStack(alignment: .leading, spacing: Theme.Space.medium) { content() }
        }
    }
}

/// 周报月报的四个数：两列浅灰块，大数字（单位小一号）、名字、和上一期比
struct ReviewNumbers: View {
    let numbers: [API.KeyNumber]

    var body: some View {
        Grid(alignment: .topLeading, horizontalSpacing: Theme.Space.small, verticalSpacing: Theme.Space.small) {
            ForEach(Array(stride(from: 0, to: numbers.count, by: 2)), id: \.self) { start in
                GridRow {
                    ForEach(start..<min(start + 2, numbers.count), id: \.self) { tile(numbers[$0]) }
                    if start + 1 >= numbers.count { Color.clear.gridCellUnsizedAxes([.horizontal, .vertical]) }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("几个数"))
    }

    private func tile(_ number: API.KeyNumber) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.hairline) {
            FigureText(
                number.parts.map { ($0.number, $0.unit) }, numberFont: Theme.Typeface.heroMetric,
                unitFont: Theme.Typeface.caption, unitColor: Theme.Palette.secondaryLabel)
            Text(Show.spaced(number.label)).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.label)
            if let compare = number.compare {
                Text(Show.spaced(compare)).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.Space.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.background, in: Theme.rounded(Theme.Corner.stat))
        .accessibilityElement(children: .combine)
    }
}

/// 目标一行：名字、这一天 / 这一期推进了多少、细进度条、一句话；点了打开目标
struct ReviewGoalRow: View {
    @Environment(AppModel.self) private var model
    let goal: API.DayGoal

    var body: some View {
        Button {
            model.openGoal(goal.id)
        } label: {
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                HStack(alignment: .firstTextBaseline) {
                    Text(Show.spaced(goal.title)).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let delta = goal.delta {
                        Text(Show.spaced(Show.grouped(delta))).font(Theme.Typeface.bodySemibold).monospacedDigit()
                            .foregroundStyle(Theme.Palette.label)
                    }
                }
                GeometryReader { proxy in
                    Capsule().fill(Theme.Palette.fill)
                        .overlay(alignment: .leading) {
                            Capsule().fill(Self.tone(goal.tone))
                                .frame(width: proxy.size.width * min(1, max(0, goal.pct)))
                        }
                }
                .frame(height: Theme.Size.dot / 2 + 1)
                Text(Show.spaced(goal.headline)).font(Theme.Typeface.footnote)
                    .foregroundStyle(Theme.Palette.secondaryLabel)
            }
            .padding(.vertical, Theme.Space.tight)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .accessibilityElement(children: .combine)
    }

    /// 不落后绿、稍微落后黄、落后较多红；没有说法的用强调色
    static func tone(_ tone: String) -> Color {
        switch tone {
        case "good": Theme.Palette.good
        case "warn": Theme.Palette.warn
        case "bad": Theme.Palette.bad
        default: Theme.Palette.accentFill
        }
    }
}

/// 能点的一行：整行都能点，按下去轻轻一缩
struct ReviewLine<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action) {
            label().frame(maxWidth: .infinity, minHeight: Theme.Size.touch, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .accessibilityElement(children: .combine)
    }
}

/// 一条心情：小表情、几点 · 说法 · 情绪词，下面宋体的那一刻（已经在当天某条感悟里整句出现的不再写）
struct ReviewMoodRow: View {
    let mood: API.ReviewMood
    let quotes: [String]
    let showTime: Bool

    var body: some View {
        let squash = { (text: String) in text.filter { !$0.isWhitespace && !$0.isPunctuation } }
        let moment = mood.moment.flatMap { moment in
            quotes.contains { squash($0).contains(squash(moment)) } ? nil : moment
        }
        HStack(alignment: .top, spacing: Theme.Space.medium) {
            MoodBadge(level: Int(mood.mood.rounded()), size: Theme.Size.capsule)
            VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                let head = (showTime ? [mood.at].compactMap(\.self) : []) + [Show.moodWord(mood.mood)] + mood.emotions
                Text(head.joined(separator: " · ")).font(Theme.Typeface.subheadline).monospacedDigit()
                    .foregroundStyle(Theme.Palette.label)
                if let moment {
                    Text(Show.spaced(moment)).font(Theme.Typeface.quote).foregroundStyle(Theme.Palette.label)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// 最下面的小字：来自几段话、去画布、这一周的周报
struct ReviewFoot<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        PourFlowLayout(spacing: Theme.Space.small, lineSpacing: 0) { content() }
            .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Theme.Space.small)
    }
}

extension View {
    /// 回顾一页的外框：上下滚；左右滑翻上一篇（往右滑）、下一篇（往左滑）；右上角也能翻
    func reviewPage(prev: (() -> Void)?, next: (() -> Void)?) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.cardGap) { self }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Space.screen)
                .padding(.bottom, Theme.Space.xLarge)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: Theme.Space.xLarge).onEnded { drag in
                let across = drag.translation.width
                guard abs(across) > Theme.Space.section * 2, abs(across) > abs(drag.translation.height) * 2 else {
                    return
                }
                if across > 0 { prev?() } else { next?() }
            }
        )
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    prev?()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(prev == nil)
                .accessibilityLabel(Text("上一篇"))
                Button {
                    next?()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(next == nil)
                .accessibilityLabel(Text("下一篇"))
            }
        }
    }
}
