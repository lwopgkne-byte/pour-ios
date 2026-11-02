import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 周报 / 月报第 1 页：「周报 · 上周」、那一周 / 那个月、宋体那一句；记得少的说一声
struct StoryPeriodTitle: View {
    @Environment(AppModel.self) private var model
    let review: API.PeriodReview

    var body: some View {
        let weekly = review.kind == "weekly"
        let relative = Show.periodRelative(review.kind, from: review.period.from, today: model.today)
        StoryLabel("\(weekly ? "周报" : "月报")\(relative.map { " · \($0)" } ?? "")\(review.updated ? " · 已更新" : "")")
        Text(Show.spaced(review.title)).font(Theme.Typeface.largeTitle).accessibilityAddTraits(.isHeader)
        Text(Show.spaced(review.overview)).font(Theme.Story.serif).lineSpacing(Theme.Leading.quote)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, Theme.Space.large)
        if review.sparse {
            Text("\(Show.periodScope(review.kind))只有 \(review.daysRecorded) 天有记录，下面只说记到的。")
                .font(Theme.Typeface.footnote).opacity(0.8)
        }
    }
}

/// 周报第 3 页：一周的样子——每一行是一天，从前一晚 9 点画到半夜（最左边是那一觉），右边那天的心情。
/// 故事里只看不点（点哪都是翻页）；整页里点一行看那天
struct StoryWeek: View {
    @Environment(AppModel.self) private var model
    let review: API.PeriodReview

    private static let span = 27.0 * 60

    var body: some View {
        StoryLabel("一周的样子")
        VStack(spacing: Theme.Space.small) {
            ForEach(review.days, id: \.day) { day in
                HStack(spacing: Theme.Space.medium) {
                    Text(Show.weekRowLabel(day.day)).font(Theme.Typeface.footnote).monospacedDigit().fixedSize()
                        .frame(minWidth: Theme.Size.touch + Theme.Space.medium, alignment: .leading)
                    track(day.day)
                    Text(day.recorded ? (day.mood ?? "") : "—").font(Theme.Typeface.footnote).opacity(0.8)
                        .fixedSize().frame(minWidth: Theme.Size.touch + Theme.Space.small, alignment: .trailing)
                }
                .frame(minHeight: Theme.Size.touch - Theme.Space.small)
                .opacity(day.recorded ? 1 : 0.6)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    Text(
                        "\(Show.dayTitle(day.day, today: model.today))，\(day.mood ?? (day.recorded ? "没说心情" : "没有记录"))")
                )
            }
        }
        Text("每一行是一天，从前一晚 9 点画到半夜，最左边是那一觉；没说几点的事不画。看整页时点一行看那天。")
            .font(Theme.Typeface.footnote).opacity(0.75).fixedSize(horizontal: false, vertical: true)
    }

    private func track(_ day: String) -> some View {
        GeometryReader { proxy in
            Capsule().fill(Theme.Story.darkInk.opacity(0.14)).frame(height: Theme.Size.bar)
                .overlay(alignment: .leading) {
                    ZStack(alignment: .leading) {
                        ForEach(blocks(day), id: \.id) { block in
                            Capsule().fill(block.color)
                                .frame(
                                    width: max(proxy.size.width * block.width, Theme.Size.bar / 2),
                                    height: Theme.Size.bar
                                )
                                .offset(x: proxy.size.width * block.left)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
        }
        .frame(height: Theme.Size.bar * 2)
    }

    private struct Block {
        let id: Int
        let left: Double
        let width: Double
        let color: Color
    }

    private func blocks(_ day: String) -> [Block] {
        let start = "\(PourDate.addDays(day, -1))T21:00"
        return review.entries.compactMap { entry in
            guard entry.day == day, case .event(let event) = entry.data, let from = event.start ?? event.end else {
                return nil
            }
            let until = event.end ?? from
            let begin = Double(PourDate.minutesBetween(start, from))
            let end = Double(PourDate.minutesBetween(start, until))
            guard end >= 0, begin <= Self.span else { return nil }
            let left = max(0, begin) / Self.span
            let color = Theme.tag(Show.meta(entry.category, model.categories).color).solid
            return Block(id: entry.id, left: left, width: min(Self.span, end) / Self.span - left, color: color)
        }
    }
}

/// 月报第 3 页：一个月的样子——月历每格那天的表情（没说心情的一个点，没记的空着）+ 每一周的周报
struct StoryMonth: View {
    @Environment(AppModel.self) private var model
    let review: API.PeriodReview

    var body: some View {
        StoryLabel("一个月的样子")
        let columns = Array(repeating: GridItem(.flexible(), spacing: Theme.Space.tight), count: 7)
        LazyVGrid(columns: columns, spacing: Theme.Space.small) {
            ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) {
                Text($0).font(Theme.Typeface.caption).opacity(0.7).accessibilityHidden(true)
            }
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                if let cell { self.cell(cell) } else { Color.clear.frame(height: Theme.Size.tile) }
            }
        }
        if !review.weeklyReports.isEmpty {
            Text("每一周的周报").font(Theme.Typeface.footnote).opacity(0.8).padding(.top, Theme.Space.small)
            PourFlowLayout(spacing: Theme.Space.small, lineSpacing: Theme.Space.small) {
                ForEach(review.weeklyReports.sorted(), id: \.self) { monday in
                    StoryButton("\(Show.monthDay(monday))那周", secondary: true) {
                        model.review.story = ReviewStoryRef(kind: "weekly", day: monday)
                    }
                }
            }
        }
    }

    private var cells: [API.PeriodDay?] {
        guard let first = review.days.first?.day else { return [] }
        return Array(repeating: nil, count: PourDate.weekdayMon0(first)) + review.days
    }

    @ViewBuilder private func cell(_ day: API.PeriodDay) -> some View {
        let number = Int(day.day.suffix(2)) ?? 0
        Group {
            if let level = day.level {
                MoodBadge(level: Int(level.rounded()), size: Theme.Size.tile)
            } else if day.recorded {
                Text("\(number)").font(Theme.Typeface.caption).monospacedDigit()
            } else {
                Text("\(number)").font(Theme.Typeface.caption).monospacedDigit().opacity(0.4)
            }
        }
        .frame(height: Theme.Size.tile)
        .accessibilityElement()
        .accessibilityLabel(Text("\(Show.monthDay(day.day))，\(day.mood ?? (day.recorded ? "没说心情" : "没有记录"))"))
    }
}

/// 周报第 4 页：做了什么 + 钱（「看 10 月的钱 ›」）；月报：钱和目标
struct StoryDone: View {
    @Environment(AppModel.self) private var model
    let review: API.PeriodReview

    var body: some View {
        let weekly = review.kind == "weekly"
        StoryLabel(weekly ? "做了什么" : "钱和目标")
        if weekly {
            ForEach(review.groups.prefix(4), id: \.key) { group in
                VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                    Text("\(group.emoji) \(group.name)").font(Theme.Typeface.footnote).opacity(0.8)
                    Text(Show.spaced([group.text, group.compare].compactMap(\.self).joined(separator: " · ")))
                        .font(Theme.Typeface.body).fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
        if !review.money.isEmpty {
            let month = String(review.period.from.prefix(7))
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                Text("钱").font(Theme.Typeface.footnote).opacity(0.8)
                ForEach(review.money, id: \.text) { line in
                    Text(Show.spaced([line.text, line.compare].compactMap(\.self).joined(separator: " · ")))
                        .font(Theme.Typeface.body).monospacedDigit().fixedSize(horizontal: false, vertical: true)
                }
                StoryButton("看\(Show.monthName(month))的钱 ›") {
                    model.review.story = nil
                    model.open("/money/\(month)")
                }
            }
            .storyGlass()
        }
        if !weekly { ForEach(review.goals.prefix(3)) { StoryGoalRow(goal: $0) } }
    }
}

/// 周报第 5 页：目标（一行一个，写推进了多少和进度条）
struct StoryPeriodGoals: View {
    let review: API.PeriodReview

    var body: some View {
        StoryLabel("目标")
        ForEach(review.goals.prefix(5)) { StoryGoalRow(goal: $0) }
        if review.goals.count > 5 {
            Text("还有 \(review.goals.count - 5) 个，在整页里").font(Theme.Typeface.footnote).opacity(0.75)
        }
    }
}

/// 心情和感悟：几条、挺好以上几条、好时刻、感悟里的主题
struct StoryPeriodMood: View {
    @Environment(AppModel.self) private var model
    let review: API.PeriodReview

    var body: some View {
        let scope = Show.periodScope(review.kind)
        StoryLabel("心情和感悟")
        if let mood = review.mood {
            let parts = (mood.good > 0 ? ["挺好以上 \(mood.good) 条"] : []) + (mood.bad > 0 ? ["不太好以下 \(mood.bad) 条"] : [])
            Text("\(scope) \(mood.total) 条心情\(parts.isEmpty ? "" : "：\(parts.joined(separator: "，"))")。")
                .font(Theme.Typeface.summary).fixedSize(horizontal: false, vertical: true)
        }
        if let note = review.moodNote {
            Text(Show.spaced(note)).font(Theme.Typeface.body).opacity(0.9).fixedSize(horizontal: false, vertical: true)
        }
        if let moments = review.mood?.moments, !moments.isEmpty {
            Text("好时刻").font(Theme.Typeface.footnote).opacity(0.8).padding(.top, Theme.Space.small)
            ForEach(moments.prefix(2), id: \.entryId) { moment in
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.medium) {
                    Text(
                        review.kind == "weekly"
                            ? String(Show.weekRowLabel(moment.day).prefix(2)) : Show.monthDay(moment.day)
                    )
                    .font(Theme.Typeface.footnote).opacity(0.75).fixedSize()
                    Text(Show.spaced(moment.text)).font(Theme.Story.serifSmall).fixedSize(
                        horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
        if let theme = review.themes.first {
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                Text("感悟里的主题").font(Theme.Typeface.footnote).opacity(0.8)
                Text(Show.spaced(theme.theme)).font(Theme.Typeface.bodySemibold)
                if let quote = theme.quotes.first {
                    Text("「\(Show.spaced(quote.text))」").font(Theme.Story.serifSmall).opacity(0.9)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .storyGlass()
            .accessibilityElement(children: .combine)
        }
    }
}

/// 最后一页（暖白）：几个观察、这周 / 这个月还有、试试、顺手整理；来自几天的几段话、「看整页」「看完了」
struct StoryPeriodRest: View {
    @Environment(AppModel.self) private var model
    let review: API.PeriodReview
    let ref: ReviewStoryRef

    var body: some View {
        let weekly = review.kind == "weekly"
        if !review.highlights.isEmpty || !review.concerns.isEmpty {
            StoryLabel("几个观察")
            ForEach(review.highlights, id: \.self) { note($0, good: true) }
            ForEach(review.concerns, id: \.self) { note($0, good: false) }
        }
        if let next = review.next, !next.todos.isEmpty || !next.goals.isEmpty || !next.suggestions.isEmpty {
            Text(weekly ? "这周还有" : "这个月还有").font(Theme.Typeface.cardTitle).opacity(0.8).padding(.top, Theme.Space.small)
            // 一页放得下：待办写一行（最多三件），目标、试试各一条；全部在整页里
            let todos =
                next.todos.prefix(3).joined(separator: " · ") + (next.todos.count > 3 ? " 等 \(next.todos.count) 件" : "")
            let lines =
                [todos].filter { !$0.isEmpty } + next.goals.prefix(1) + next.suggestions.prefix(1).map { "试试：\($0)" }
            ForEach(lines, id: \.self) { line in
                Text(Show.spaced(line)).font(Theme.Typeface.body).fixedSize(horizontal: false, vertical: true)
            }
        }
        if !review.categorySuggestions.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                Text("顺手整理：\(Show.spaced(review.categorySuggestions[0]))").font(Theme.Typeface.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                ThemeTextButton("去设置里整理 ›") {
                    model.review.story = nil
                    model.open("/settings")
                }
            }
            .storyGlass(true)
        }
        StoryEnd(source: "来自\(weekly ? "这一周" : "这个月") \(review.daysRecorded) 天的 \(review.notes) 段话", ref: ref) {
            EmptyView()
        }
    }

    private func note(_ text: String, good: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.small) {
            Circle().fill(good ? Theme.Palette.good : Theme.Palette.warn).frame(
                width: Theme.Size.dot, height: Theme.Size.dot)
            Text(Show.spaced(text)).font(Theme.Typeface.body).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(good ? "做得好" : "要留意")：\(text)"))
    }
}
