import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 第 1 页：「每日回顾 · 昨天」、日期、宋体那一句（「已更新」的写上）
struct StoryDayTitle: View {
    @Environment(AppModel.self) private var model
    let review: API.DailyReview

    var body: some View {
        let relative = Show.relative(review.day, today: model.today)
        StoryLabel("每日回顾\(relative.map { " · \($0)" } ?? "")\(review.updated ? " · 已更新" : "")")
        Text(Show.dayTitle(review.day, today: model.today)).font(Theme.Typeface.largeTitle)
            .accessibilityAddTraits(.isHeader)
        Text(Show.spaced(review.overview)).font(Theme.Story.serif).lineSpacing(Theme.Leading.quote)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, Theme.Space.large)
    }
}

/// 几个数和平时（上周、上个月）比
struct StoryNumbersPage: View {
    let title: String
    let numbers: [API.KeyNumber]

    var body: some View {
        StoryLabel(title)
        StoryNumbers(
            numbers.map { .init(label: $0.label, value: $0.text, compare: $0.compare) }, ink: Theme.Story.darkInk
        )
        .padding(.top, Theme.Space.small)
    }
}

/// 第 3 页：一天的样子——一行一件有时间的事（最多 6 件），下面「没说时间的」
struct StoryDayBars: View {
    @Environment(AppModel.self) private var model
    let review: API.DailyReview

    var body: some View {
        let bars = Self.bars(review)
        StoryLabel("一天的样子")
        DayBars(
            bars.prefix(6).map { item in
                DayBars.Bar(
                    id: item.entry.id, time: item.time, label: item.label, start: item.start, width: item.width,
                    color: Theme.tag(Show.meta(item.entry.category, model.categories).color).solid)
            }, ink: Theme.Story.darkInk
        )
        .padding(.top, Theme.Space.small)
        if bars.count > 6 { Text("还有 \(bars.count - 6) 件在整页里").font(Theme.Typeface.footnote).opacity(0.75) }
        let loose = Self.untimed(review)
        if !loose.isEmpty {
            Text("没说时间的：\(loose.joined(separator: " · "))").font(Theme.Typeface.footnote).opacity(0.8)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    struct Item {
        let entry: API.Entry
        let time: String
        let label: String
        let start: Double
        let width: Double
    }

    /// 这一天有时间的事：从 0 点画到 24 点（前一晚开始的那一觉从 0 点画起）
    static func bars(_ review: API.DailyReview) -> [Item] {
        let dayStart = "\(review.day)T00:00"
        let span = 24.0 * 60
        return review.entries.compactMap { entry -> Item? in
            guard case .event(let event) = entry.data, let from = event.start ?? event.end else { return nil }
            let until = event.end ?? from
            let begin = max(0, Double(PourDate.minutesBetween(dayStart, from)))
            let end = min(span, Double(PourDate.minutesBetween(dayStart, until)))
            guard end >= 0, begin <= span else { return nil }
            let time =
                event.end != nil && event.start != nil ? "\(Show.clock(from))–\(Show.clock(until))" : Show.clock(from)
            return Item(
                entry: entry, time: time, label: event.label, start: begin / span, width: max(0, end - begin) / span)
        }
        .sorted { $0.start < $1.start }
    }

    /// 没说几点的事（「16:8 轻断食」「量血压」）
    static func untimed(_ review: API.DailyReview) -> [String] {
        review.entries.compactMap { entry in
            guard case .event(let event) = entry.data, event.start == nil, event.end == nil else { return nil }
            return event.label
        }
    }
}

/// 第 4 页：心情和那一刻（几点 · 说法 · 情绪词，宋体那一刻）；感悟的那一句
struct StoryMoods: View {
    let review: API.DailyReview

    var body: some View {
        StoryLabel(review.insights.isEmpty ? "心情和那一刻" : "心情和感悟")
        ForEach(review.moods, id: \.entryId) { mood in
            HStack(alignment: .top, spacing: Theme.Space.medium) {
                MoodBadge(level: Int(mood.mood.rounded()), size: Theme.Size.touch - Theme.Space.tight)
                VStack(alignment: .leading, spacing: Theme.Space.tight) {
                    Text(
                        ([mood.at].compactMap(\.self) + [Show.moodWord(mood.mood)] + mood.emotions).joined(
                            separator: " · ")
                    )
                    .font(Theme.Typeface.footnote).monospacedDigit().opacity(0.8)
                    if let moment = mood.moment {
                        Text(Show.spaced(moment)).font(Theme.Story.serifSmall).fixedSize(
                            horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, Theme.Space.small)
            .accessibilityElement(children: .combine)
        }
        ForEach(review.insights, id: \.entryId) { insight in
            Text("「\(Show.spaced(insight.quote))」").font(Theme.Story.serifSmall)
                .fixedSize(horizontal: false, vertical: true)
                .storyGlass()
        }
    }
}

/// 第 5 页：目标（这一天推进了多少）+ 一个观察
struct StoryDayGoals: View {
    let review: API.DailyReview

    var body: some View {
        if !review.goals.isEmpty {
            StoryLabel("目标")
            ForEach(review.goals.prefix(4)) { StoryGoalRow(goal: $0) }
            if review.goals.count > 4 {
                Text("还有 \(review.goals.count - 4) 个，在整页里").font(Theme.Typeface.footnote).opacity(0.75)
            }
        }
        if let observation = review.observation {
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                Text("一个观察").font(Theme.Typeface.footnote).opacity(0.8)
                Text(Show.spaced(observation)).font(Theme.Typeface.body).fixedSize(horizontal: false, vertical: true)
            }
            .storyGlass()
            .accessibilityElement(children: .combine)
        }
    }
}

/// 目标一行：名字、推进了多少、细进度条、一句话。故事里只看不点（点哪都是翻页），整页里点了打开目标
struct StoryGoalRow: View {
    let goal: API.DayGoal

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            HStack(alignment: .firstTextBaseline) {
                Text(Show.spaced(goal.title)).font(Theme.Typeface.body).frame(maxWidth: .infinity, alignment: .leading)
                if let delta = goal.delta { Text(delta).font(Theme.Typeface.bodySemibold).monospacedDigit() }
            }
            GeometryReader { proxy in
                Capsule().fill(Theme.Story.darkInk.opacity(0.18))
                    .overlay(alignment: .leading) {
                        Capsule().frame(width: proxy.size.width * min(1, max(0, goal.pct)))
                    }
            }
            .frame(height: Theme.Size.dot / 2 + 1)
            Text(Show.spaced(goal.headline)).font(Theme.Typeface.footnote).opacity(0.8)
        }
        .padding(.vertical, Theme.Space.tight)
        .accessibilityElement(children: .combine)
    }
}

/// 第 6 页：还没收尾的（「带到今天」、拿不准的「对 / 改」）+ 自动检查查出的（「确实错了 / 没错」）
struct StoryOpen: View {
    @Environment(AppModel.self) private var model
    let review: API.DailyReview
    let findings: [API.AuditFinding]
    let reload: @MainActor () async -> Void

    var body: some View {
        StoryLabel("还没收尾的")
        ForEach(review.open.todos, id: \.entryId) { todo in
            HStack(spacing: Theme.Space.medium) {
                Circle().strokeBorder(Theme.Story.darkInk.opacity(0.6), lineWidth: 2).frame(
                    width: Theme.Size.check, height: Theme.Size.check)
                Text(Show.spaced(todo.content)).font(Theme.Typeface.body).frame(
                    maxWidth: .infinity, alignment: .leading)
                StoryButton("带到今天") { model.carryToToday(todo.entryId, content: todo.content, after: reload) }
            }
            .storyGlass()
        }
        ForEach(review.open.pending, id: \.entryId) { item in
            VStack(alignment: .leading, spacing: Theme.Space.small) {
                Text(Show.spaced(item.question)).font(Theme.Typeface.body)
                Text(Show.spaced(item.text)).font(Theme.Typeface.footnote).opacity(0.8)
                HStack(spacing: Theme.Space.small) {
                    StoryButton("对") { model.confirmOpen(item.entryId, after: reload) }
                    StoryButton("改", secondary: true) {
                        model.review.story = nil
                        model.openEntry(item.entryId, day: nil)
                    }
                }
            }
            .storyGlass()
        }
        ForEach(findings) { finding in
            VStack(alignment: .leading, spacing: Theme.Space.small) {
                Text("自动检查：\(Show.spaced(finding.reason))").font(Theme.Typeface.footnote).opacity(0.8)
                Text(Self.marked(finding)).font(Theme.Story.serifSmall).fixedSize(horizontal: false, vertical: true)
                if let after = finding.after {
                    Text("应该是：\(after.joined(separator: " · "))").font(Theme.Typeface.footnote).opacity(0.8)
                }
                HStack(spacing: Theme.Space.small) {
                    StoryButton("确实错了") { model.confirmFinding(finding, after: reload) }
                    StoryButton("没错", secondary: true) { model.dismissFinding(finding, after: reload) }
                }
            }
            .storyGlass()
        }
    }

    /// 原话里有问题的那一段加粗
    static func marked(_ finding: API.AuditFinding) -> AttributedString {
        var text = AttributedString(finding.text)
        if let range = text.range(of: finding.quote) {
            text[range].inlinePresentationIntent = .stronglyEmphasized
            text[range].underlineStyle = .single
        }
        return text
    }
}

/// 最后一页（暖白）：你说过（语录）、来自这一天的几段话 · 看这一天的画布 · 这一周的周报、「看整页」「看完了」
struct StorySaid: View {
    @Environment(AppModel.self) private var model
    let page: API.DailyReviewPage
    let ref: ReviewStoryRef

    var body: some View {
        if let quote = page.quote {
            StoryLabel("你说过")
            Text("「\(Show.spaced(quote.text))」").font(Theme.Story.serifLarge).lineSpacing(Theme.Leading.quote)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Theme.Space.small)
            Text("\(Show.dayTitle(quote.day, today: model.today)) \(quote.asked ? "记进语录的" : "说的")")
                .font(Theme.Typeface.footnote).opacity(0.7)
        } else {
            StoryLabel("这一天就是这样")
        }
        StoryEnd(source: "来自这一天的 \(page.review.notes) 段话", ref: ref) {
            HStack(spacing: Theme.Space.regular) {
                ThemeTextButton("看这一天的画布") {
                    model.review.story = nil
                    model.goHome()
                    model.show(page.review.day)
                }
                if let weekly = page.weekly {
                    ThemeTextButton("这一周的周报") { model.review.story = ReviewStoryRef(kind: "weekly", day: weekly) }
                }
            }
        }
    }
}
