public import SwiftUI

// 3.0 回顾（docs/3.0/06-交互细节.md 第 6 节、10.4）：回顾页的一张卡、「需要留意」、故事（全屏，一页一个底色、
// 顶上一排进度条）、故事里的四个数和一天的样子

extension Theme {
    /// 故事的底：六种深色轮着用，最后一页暖白（字用深色）；深色上的字是白的
    public enum Story {
        static let pairs: [(UInt32, UInt32)] = [
            (0x2E3A55, 0x1D2433), (0x3B3242, 0x24202B), (0x283B3A, 0x1A2625), (0x4A2F3E, 0x2A1C24),
            (0x2B3A4A, 0x1B242E), (0x3C3424, 0x241F15),
        ]
        static let light: (UInt32, UInt32) = (0xFBF8F1, 0xEFE9DC)
        /// 深色底上的字、暖白底上的字
        public static let darkInk = Tokens.one(0xFFFFFF).color
        public static let lightInk = Tokens.one(0x2A2723).color
        /// 深色底上一块玻璃（四个数、观察、还没收尾的一行）
        public static let glass = Tokens.one(0xFFFFFF, opacity: 0.1).color
        public static let lightGlass = Tokens.one(0x2A2723, opacity: 0.05).color
        /// 故事上的按钮：深色底上白底深字，暖白底上深底白字
        public static let buttonOnDark = Tokens.one(0xFFFFFF).color
        public static let buttonOnLight = Tokens.one(0x2A2723).color

        /// 故事里的宋体：第一页那一句、好时刻；最后一页的「你说过」更大
        public static let serif = Font.custom("Songti SC", size: 24, relativeTo: .title2)
        public static let serifSmall = Font.custom("Songti SC", size: 19, relativeTo: .body)
        public static let serifLarge = Font.custom("Songti SC", size: 30, relativeTo: .title)
        /// 自动翻页：一页 5.5 秒
        public static let pageSeconds = 5.5

        /// 第几页的底（从 0 数）；last 是最后一页（暖白）
        public static func background(page: Int, last: Bool) -> LinearGradient {
            let pair = last ? light : pairs[page % pairs.count]
            return LinearGradient(
                colors: [Tokens.one(pair.0).color, Tokens.one(pair.1).color], startPoint: .topLeading,
                endPoint: .bottomTrailing)
        }

        /// 测对比度用：这一页底色较浅的那一头
        public static func lighterToken(page: Int, last: Bool) -> ColorToken {
            Tokens.one(last ? light.1 : pairs[page % pairs.count].0)
        }

        public static func ink(last: Bool) -> Color { last ? lightInk : darkInk }
    }
}

/// 回顾页的一张卡（06 交互细节第 6 节）：日期（没看过的粗体、深色）、「已更新」「新」两个小签，一句话（最多三行），
/// 一排几个数的小胶囊。看过的日期和一句话都变成次要色（不打红点）
public struct ReviewListCard: View {
    let title: String
    let summary: String
    let chips: [String]
    let read: Bool
    let updated: Bool
    let action: () -> Void

    public init(
        title: String, summary: String, chips: [String], read: Bool, updated: Bool, action: @escaping () -> Void
    ) {
        self.title = title
        self.summary = summary
        self.chips = chips
        self.read = read
        self.updated = updated
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Theme.Space.small) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.snug) {
                    Text(title).font(read ? Theme.Typeface.bodyMedium : Theme.Typeface.bodySemibold)
                        .foregroundStyle(read ? Theme.Palette.secondaryLabel : Theme.Palette.label)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if updated { tag("已更新", fill: Theme.Palette.fill, ink: Theme.Palette.secondaryLabel) }
                    if read {
                        Image(systemName: "chevron.right").font(Theme.Typeface.glyph)
                            .foregroundStyle(Theme.Palette.tertiaryLabel)
                    } else {
                        tag("新", fill: Theme.Palette.remindFill, ink: Theme.Palette.accent)
                    }
                }
                Text(summary).font(Theme.Typeface.body)
                    .foregroundStyle(read ? Theme.Palette.secondaryLabel : Theme.Palette.label)
                    .lineLimit(3).multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !chips.isEmpty {
                    PourFlowLayout(spacing: Theme.Space.snug, lineSpacing: Theme.Space.snug) {
                        ForEach(chips, id: \.self) { chip in
                            Text(chip).font(Theme.Typeface.footnoteMedium).monospacedDigit()
                                .foregroundStyle(Theme.Palette.secondaryLabel)
                                .padding(.horizontal, Theme.Space.small).frame(minHeight: Theme.Size.badge + 2)
                                .background(Theme.Palette.fill, in: Capsule())
                        }
                    }
                }
            }
            .themeCard()
        }
        .buttonStyle(PressScale())
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(read ? "看过了" : "新"))
    }

    private func tag(_ text: String, fill: Color, ink: Color) -> some View {
        Text(text).font(Theme.Typeface.caption).foregroundStyle(ink)
            .padding(.horizontal, Theme.Space.snug).padding(.vertical, Theme.Space.hairline)
            .background(fill, in: Capsule())
    }
}

/// 需要留意（回顾页最上面，有才出现）：浅黄底，「需要留意 · 2 件」，一行一件，「知道了」收起
public struct AttentionCard: View {
    let lines: [String]
    let dismiss: () -> Void

    public init(lines: [String], dismiss: @escaping () -> Void) {
        self.lines = lines
        self.dismiss = dismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            HStack {
                Label("需要留意 · \(lines.count) 件", systemImage: "exclamationmark.triangle.fill")
                    .font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.warnInk)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(action: dismiss) {
                    Text("知道了").font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.warnInk)
                        .frame(minWidth: Theme.Size.touch, minHeight: Theme.Size.touch).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("review.attention.dismiss")
            }
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                if index > 0 { Divider().overlay(Theme.Palette.warnInk.opacity(0.2)) }
                Text(line).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label).monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Theme.Space.regular).padding(.bottom, Theme.Space.regular)
        .padding(.top, Theme.Space.tight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.warnFill, in: Theme.rounded(Theme.Corner.card))
        .accessibilityElement(children: .contain)
    }
}

/// 故事顶上的一排进度条：看过的满、正在看的按 progress 走、后面的空
public struct StoryProgress: View {
    let count: Int
    let current: Int
    let progress: Double
    let ink: Color

    public init(count: Int, current: Int, progress: Double, ink: Color) {
        self.count = count
        self.current = current
        self.progress = progress
        self.ink = ink
    }

    public var body: some View {
        HStack(spacing: Theme.Space.tight) {
            ForEach(0..<count, id: \.self) { index in
                GeometryReader { proxy in
                    let filled = index < current ? 1 : index == current ? max(0, min(1, progress)) : 0
                    Capsule().fill(ink.opacity(0.3))
                        .overlay(alignment: .leading) {
                            Capsule().fill(ink).frame(width: proxy.size.width * filled)
                        }
                }
                .frame(height: Theme.Size.dot / 2 - 1)
            }
        }
        // 读屏能上下轻扫换页：这一条要够大（看起来还是细细的一排）
        .frame(minHeight: Theme.Size.touch)
        .contentShape(Rectangle())
        .accessibilityElement()
        .accessibilityLabel(Text("第 \(current + 1) 页，共 \(count) 页"))
    }
}

/// 故事里的四个数（和平时、上周、上个月比）：两列玻璃块，名字、大数字、比较
public struct StoryNumbers: View {
    public struct Item: Hashable, Sendable {
        let label: String
        let value: String
        let compare: String?

        public init(label: String, value: String, compare: String?) {
            self.label = label
            self.value = value
            self.compare = compare
        }
    }

    let items: [Item]
    let ink: Color

    public init(_ items: [Item], ink: Color) {
        self.items = items
        self.ink = ink
    }

    public var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: Theme.Space.medium), GridItem(.flexible())],
            spacing: Theme.Space.medium
        ) {
            ForEach(items, id: \.self) { item in
                VStack(alignment: .leading, spacing: Theme.Space.tight) {
                    Text(item.label).font(Theme.Typeface.footnote).opacity(0.8)
                    Text(item.value).font(item.value.count > 6 ? Theme.Typeface.heroMetric : Theme.Typeface.bigNumber)
                        .monospacedDigit().fixedSize(horizontal: false, vertical: true)
                    if let compare = item.compare { Text(compare).font(Theme.Typeface.footnote).opacity(0.8) }
                }
                .foregroundStyle(ink)
                .padding(Theme.Space.regular)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.goalCard * 0.7, alignment: .topLeading)
                .background(Theme.Story.glass, in: Theme.rounded(Theme.Corner.card))
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// 一天的样子（故事第 3 页）：一行一件有时间的事，几点到几点、在一天里的位置（一条横条）、名字
public struct DayBars: View {
    public struct Bar: Hashable, Sendable, Identifiable {
        public let id: Int
        let time: String
        let label: String
        /// 在一天里从哪开始、占多宽（0…1）
        let start: Double
        let width: Double
        let color: Color

        public init(id: Int, time: String, label: String, start: Double, width: Double, color: Color) {
            self.id = id
            self.time = time
            self.label = label
            self.start = start
            self.width = width
            self.color = color
        }
    }

    let bars: [Bar]
    let ink: Color

    public init(_ bars: [Bar], ink: Color) {
        self.bars = bars
        self.ink = ink
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            ForEach(bars) { bar in
                VStack(alignment: .leading, spacing: Theme.Space.tight) {
                    Text(bar.time).font(Theme.Typeface.footnote).monospacedDigit().opacity(0.8)
                    GeometryReader { proxy in
                        Capsule().fill(ink.opacity(0.14))
                            .overlay(alignment: .leading) {
                                Capsule().fill(bar.color)
                                    .frame(width: max(proxy.size.width * bar.width, Theme.Size.bar))
                                    .offset(x: proxy.size.width * bar.start)
                            }
                    }
                    .frame(height: Theme.Size.bar + Theme.Space.tight)
                    Text(bar.label).font(Theme.Typeface.body)
                }
                .foregroundStyle(ink)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

#Preview("回顾：卡片、需要留意、故事的几块") {
    ScrollView {
        VStack(spacing: Theme.Space.regular) {
            AttentionCard(lines: ["睡眠连续 3 天变短：7 小时 30 分 → 6 小时", "目标「每周外卖不超过 2 次」用满了"]) {}
            ReviewListCard(
                title: "昨天 · 10月26日 周一", summary: "睡了 6 小时 50 分，16:8 轻断食，外卖沙拉 ¥38，背单词。",
                chips: ["睡眠 6:50", "专注 12:25", "心情 有起有落"], read: false, updated: false
            ) {}
            ReviewListCard(
                title: "10月24日 周六", summary: "跑步 8.4 公里，陪儿子去公园一个半小时。", chips: ["运动 1:30"], read: true,
                updated: true
            ) {}
            VStack(spacing: Theme.Space.large) {
                StoryProgress(count: 7, current: 2, progress: 0.4, ink: Theme.Story.darkInk)
                StoryNumbers(
                    [
                        .init(label: "睡眠", value: "6 小时 50 分", compare: "和平时差不多"),
                        .init(label: "心情", value: "有起有落", compare: nil),
                    ], ink: Theme.Story.darkInk)
                DayBars(
                    [
                        .init(
                            id: 1, time: "0:00–6:50", label: "睡觉", start: 0, width: 0.28,
                            color: Theme.tag("purple").solid),
                        .init(
                            id: 2, time: "8:00–19:10", label: "上班", start: 0.33, width: 0.46,
                            color: Theme.tag("brown").solid),
                    ], ink: Theme.Story.darkInk)
            }
            .padding()
            .background(Theme.Story.background(page: 0, last: false))
        }
        .padding()
    }
    .background(Theme.Palette.background)
}
