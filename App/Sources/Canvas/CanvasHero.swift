import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 今天的样子：AI 写的一句话 + 程序挑的最多 3 个亮点 + 要你确认的；底色是这一天的心情（没记心情是中性的暖灰，不猜）。
/// 心情的底色上的字只用主字色（小胶囊、亮点垫一层 `statFill`：亮色一层白，深色压暗一点），蓝色只给图标——
/// 次要色、蓝色的字在有的心情底色上对比度不够（ThemeColorTests.heroText 按最坏的情况算）
struct CanvasHero: View {
    @Environment(AppModel.self) private var model
    let day: API.DayView
    /// 点亮点、「要你确认」时滚到那张卡
    let scrollTo: (String) -> Void

    var body: some View {
        let highlights = CanvasPlan.highlights(day.entries, model.categories)
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            header
            HeroSummary(day: day)
            if !highlights.isEmpty { HighlightRow(highlights: highlights, scrollTo: scrollTo) }
            pending
        }
        .padding(Theme.Space.regular)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                Theme.Palette.card
                MoodWash(Self.tone(CanvasPlan.mood(day.entries)))
            }
            .clipShape(Theme.rounded(Theme.Corner.hero))
        }
        .themeEdge(radius: Theme.Corner.hero)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("today.hero")
    }

    private var header: some View {
        HStack(spacing: Theme.Space.small) {
            Label("今天的样子", systemImage: "sparkles").font(Theme.Typeface.footnoteSemibold)
                .foregroundStyle(Theme.Palette.label)
                .padding(.horizontal, Theme.Space.small).frame(minHeight: Theme.Size.badge + Theme.Space.tight)
                .background(Theme.Palette.statFill, in: Capsule())
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            if let mood = dayMood {
                Text("心情 · \(mood)").font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.label)
                    .padding(.horizontal, Theme.Space.small).frame(minHeight: Theme.Size.badge + Theme.Space.tight)
                    .background(Theme.Palette.statFill, in: Capsule())
            }
        }
    }

    /// 有待确认的记录：最下面一行「有 2 条要你确认一下 ›」，点了滚到第一条
    @ViewBuilder private var pending: some View {
        let waiting = day.entries.filter(\.pending)
        if let first = waiting.first {
            Button {
                scrollTo(Show.group(first, model.categories))
            } label: {
                HStack(spacing: Theme.Space.tight) {
                    Image(systemName: "questionmark.circle").foregroundStyle(Theme.Palette.accent)
                    Text("有 \(waiting.count) 条要你确认一下").foregroundStyle(Theme.Palette.label)
                    Spacer(minLength: Theme.Space.tight)
                    Image(systemName: "chevron.right").font(Theme.Typeface.caption)
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                }
                .font(Theme.Typeface.footnoteSemibold)
                .padding(.horizontal, Theme.Space.medium)
                .frame(minHeight: Theme.Size.touch)
                .background(Theme.Palette.statFill, in: Theme.rounded(Theme.Corner.stat))
                .contentShape(Theme.rounded(Theme.Corner.stat))
            }
            .buttonStyle(.plain)
        }
    }

    /// 标题右边写这一天的心情说法（「有起有落」「挺好」）
    private var dayMood: String? {
        let levels = day.entries.compactMap { if case .mood(let mood) = $0.data { mood.mood } else { nil } }
        return Show.dayMood(levels)
    }

    static func tone(_ mood: CanvasPlan.Mood) -> Theme.MoodTone {
        switch mood {
        case .good: .good
        case .plain: .plain
        case .low: .low
        case .mixed: .mixed
        case .none: .none
        }
    }
}

/// 一句话：AI 写的总结；空的一天写以前的那几句；有记录但总结还没写出来时一条骨架灰条；正在整理时下面一行在呼吸
private struct HeroSummary: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let day: API.DayView

    var body: some View {
        let progress = CanvasEmpty.progress(model.dayNotes)
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            if day.entries.isEmpty && progress == nil {
                Text(Show.spaced(CanvasEmpty.text(model))).font(Theme.Typeface.summary)
                    .foregroundStyle(Theme.Palette.label).lineSpacing(Theme.Leading.summary)
            } else if let text = day.summary, !text.isEmpty {
                Text(Show.spaced(text)).font(Theme.Typeface.summary).foregroundStyle(Theme.Palette.label)
                    .lineSpacing(Theme.Leading.summary)
                    .accessibilityIdentifier("today.summary")
            } else {
                SkeletonBlock(height: Theme.Size.skeletonLine, radius: Theme.Corner.bar)
                    .frame(maxWidth: Theme.Size.skeletonWidth)
            }
            if let progress {
                Button {
                    withAnimation(Theme.Motion.pick(Theme.Motion.standard, reduceMotion: reduceMotion)) {
                        model.chatOpen = true
                    }
                } label: {
                    Label(progress, systemImage: "sparkles").font(Theme.Typeface.footnoteMedium)
                        .foregroundStyle(Theme.Palette.label)
                        .symbolEffect(.breathe, options: .repeating, isActive: !reduceMotion)
                        .padding(.horizontal, Theme.Space.medium).frame(minHeight: Theme.Size.capsule)
                        .background(Theme.Palette.statFill, in: Capsule())
                        .frame(minHeight: Theme.Size.touch)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// 亮点：等宽的几块，数字大、名字小；点了滚到那张卡。字号调到辅助功能那几档时一块一行
private struct HighlightRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let highlights: [CanvasPlan.Highlight]
    let scrollTo: (String) -> Void

    var body: some View {
        let layout =
            typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Space.small))
            : AnyLayout(HStackLayout(spacing: Theme.Space.small))
        layout {
            ForEach(highlights, id: \.self) { highlight in
                Button {
                    scrollTo(highlight.target)
                } label: {
                    VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                        Text(highlight.label).font(Theme.Typeface.caption).foregroundStyle(Theme.Palette.label)
                            .lineLimit(typeSize > .large ? nil : 1)
                        FigureText(
                            highlight.parts.map { ($0.number, $0.unit) }, prefix: highlight.prefix,
                            numberFont: Theme.Typeface.heroMetric, unitFont: Theme.Typeface.caption,
                            unitColor: Theme.Palette.label)
                    }
                    .padding(.horizontal, Theme.Space.medium).padding(.vertical, Theme.Space.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Palette.statFill, in: Theme.rounded(Theme.Corner.stat))
                    .contentShape(Theme.rounded(Theme.Corner.stat))
                }
                .buttonStyle(PressScale())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(highlight.label) \(highlight.prefix ?? "")\(spoken(highlight))"))
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("today.highlight.\(highlight.target)")
            }
        }
    }

    private func spoken(_ highlight: CanvasPlan.Highlight) -> String {
        highlight.parts.map { "\($0.number)\($0.unit)" }.joined()
    }
}

/// 空的一天、整理进度：沿用以前画布上的说法
enum CanvasEmpty {
    /// 今天「还是空白…」，以前的日子「没有留下记录」，以后的日子「还没到」；说过话但没整理出记录的也说一声
    @MainActor static func text(_ model: AppModel) -> String {
        if !model.dayNotes.isEmpty { return "说过的话里没有整理出记录。" }
        let offset = PourDate.diffDays(model.shownDay, model.today)
        if offset == 0 { return "今天还是空白。说说你做了什么，这里会自己长出来。" }
        return offset > 0 ? "这一天还没到。" : "这一天没有留下记录。"
    }

    /// 还在整理、等着、没整理成的话：一行安静的字，点一下打开对话
    static func progress(_ notes: [API.Note]) -> String? {
        let count = { (status: String) in notes.filter { $0.status == status }.count }
        let parts = [
            count("processing") > 0 ? "正在整理…" : nil,
            count("pending") > 0 ? "\(count("pending")) 段等待整理" : nil,
            count("failed") > 0 ? "\(count("failed")) 段处理失败" : nil,
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// 区块标题：「今天推进的目标」「一天的时间」，右边一个小字
struct SectionHeader: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(Theme.Typeface.section).foregroundStyle(Theme.Palette.label)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Theme.Space.small)
            if let trailing {
                Text(trailing).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
            }
        }
    }
}
