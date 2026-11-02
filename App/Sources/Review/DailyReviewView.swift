import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 每日回顾的整页（docs/prd-review.md；3.0 故事最后「看整页」、页面地址 /review/2026-10-18）：一块一张卡——
/// 这一天的样子（一句话 + 关键数字）、一天的样子、做了什么、目标、心情和感悟、一个观察、还没收尾的（含自动检查）、
/// 今天（只在昨天那一页）、你说过、最下面来自几段话 · 看这一天的画布 · 这一周的周报。空的部分不出现，数字和列表是服务器现算的
struct DailyReviewView: View {
    @Environment(AppModel.self) private var model
    let day: String
    let navigate: (String) -> Void
    @State private var page: API.DailyReviewPage?
    @State private var findings: [API.AuditFinding] = []
    @State private var problem: String?

    var body: some View {
        Group {
            if let page {
                content(page)
            } else if let problem {
                ErrorState(problem.contains("连") ? .serverOff : .other) { Task { await load() } }
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: Theme.Size.goalCard)
            }
        }
        .reviewPage(
            prev: page?.prev.map { prev in { navigate("/review/\(prev)") } },
            next: page?.next.map { next in { navigate("/review/\(next)") } }
        )
        .task(id: "\(day)-\(model.dataVersion)") { await load() }
    }

    @ViewBuilder private func content(_ page: API.DailyReviewPage) -> some View {
        let review = page.review
        ReviewHead(
            title: Show.dayTitle(day, today: model.today), relative: Show.relative(day, today: model.today),
            updated: review.updated)
        // 这一天的总结和关键数字（以前在画布上的「今天的样子」，产品主人 2026-10-21 挪到回顾里）
        DayLook(overview: review.overview, numbers: review.numbers, levels: review.moods.map(\.mood))
        let bars = StoryDayBars.bars(review)
        if !bars.isEmpty {
            ReviewSection(title: "一天的样子") {
                DayBars(
                    bars.map { item in
                        DayBars.Bar(
                            id: item.entry.id, time: item.time, label: item.label, start: item.start,
                            width: item.width,
                            color: Theme.tag(Show.meta(item.entry.category, model.categories).color).solid)
                    }, ink: Theme.Palette.label)
                let loose = StoryDayBars.untimed(review)
                if !loose.isEmpty {
                    Text("没说时间的：\(loose.joined(separator: " · "))").font(Theme.Typeface.footnote)
                        .foregroundStyle(Theme.Palette.secondaryLabel).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        if !review.groups.isEmpty { groups(review.groups) }
        if !review.goals.isEmpty {
            ReviewSection(title: "目标") { ForEach(review.goals) { ReviewGoalRow(goal: $0) } }
        }
        if !review.moods.isEmpty || !review.insights.isEmpty { moods(review) }
        if let observation = review.observation {
            ReviewSection(title: "一个观察") {
                Text(Show.spaced(observation)).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                    .lineSpacing(Theme.Leading.body).fixedSize(horizontal: false, vertical: true)
            }
        }
        rest(page)
    }

    /// 后半页：还没收尾的、今天、你说过、最下面一行
    @ViewBuilder private func rest(_ page: API.DailyReviewPage) -> some View {
        let review = page.review
        // 过去的日子才有「还没收尾的」；「今天」只放在昨天那一页
        if day < model.today, !review.open.todos.isEmpty || !review.open.pending.isEmpty || !findings.isEmpty {
            ReviewSection(title: "还没收尾的") { OpenItems(open: review.open, findings: findings, reload: load) }
        }
        if day == PourDate.addDays(model.today, -1), !review.today.todos.isEmpty || !review.today.goals.isEmpty {
            ReviewSection(title: "今天") {
                VStack(alignment: .leading, spacing: Theme.Space.tight) {
                    ForEach(review.today.todos, id: \.self) {
                        Text(Show.spaced($0)).foregroundStyle(Theme.Palette.label)
                    }
                    // 目标只列最要紧的两个：多了就不像一句提醒了
                    ForEach(review.today.goals.prefix(2), id: \.self) {
                        Text(Show.spaced($0)).foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                }
                .font(Theme.Typeface.body)
            }
        }
        if let quote = page.quote {
            ReviewSection(title: "你说过") {
                VStack(alignment: .leading, spacing: Theme.Space.tight) {
                    Text("「\(Show.spaced(quote.text))」").font(Theme.Typeface.quoteLarge)
                        .foregroundStyle(Theme.Palette.label).lineSpacing(Theme.Leading.quote)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(Show.dayTitle(quote.day, today: model.today)) \(quote.asked ? "记进语录的" : "说的")")
                        .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                }
                .accessibilityElement(children: .combine)
            }
        }
        ReviewFoot {
            Text("来自这一天的 \(review.notes) 段话").frame(minHeight: Theme.Size.touch)
            ThemeTextButton("看这一天的画布") {
                model.goHome()
                model.show(day)
            }
            if let weekly = page.weekly {
                ThemeTextButton("这一周的周报") { navigate(Show.reportPath("weekly", from: weekly)) }
            }
        }
    }

    /// 做了什么：一个领域一组，组里一条一条能点开
    private func groups(_ groups: [API.ReviewGroup]) -> some View {
        ReviewSection(title: "做了什么") {
            ForEach(groups, id: \.key) { group in
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(group.emoji) \(group.name)").font(Theme.Typeface.footnote)
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(Text(group.name))
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("canWrap")
                    ForEach(group.items ?? [], id: \.entryId) { item in
                        ReviewLine {
                            model.openEntry(item.entryId, day: day)
                        } label: {
                            Text(Show.spaced(item.text)).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
            }
        }
    }

    /// 心情和感悟：每条心情一行（点了打开那一条）；感悟的那一句
    private func moods(_ review: API.DailyReview) -> some View {
        let quotes = review.insights.map(\.quote)
        let showTime = Set(review.moods.compactMap(\.at)).count > 1
        return ReviewSection(title: "心情和感悟") {
            ForEach(review.moods, id: \.entryId) { mood in
                ReviewLine {
                    model.openEntry(mood.entryId, day: day)
                } label: {
                    ReviewMoodRow(mood: mood, quotes: quotes, showTime: showTime)
                }
            }
            ForEach(review.insights, id: \.entryId) { insight in
                ReviewLine {
                    model.openEntry(insight.entryId, day: day)
                } label: {
                    Text("「\(Show.spaced(insight.quote))」").font(Theme.Typeface.quote)
                        .foregroundStyle(Theme.Palette.label).multilineTextAlignment(.leading)
                }
            }
        }
    }

    private func load() async {
        do {
            let fresh = try await model.client.dailyReview(day)
            page = fresh
            problem = nil
            // 打开就算看过
            if let id = fresh.messageId, !fresh.read { try? await model.client.markRead(message: id) }
            // 自动检查只查过去的日子
            if day < model.today { findings = (try? await model.client.auditFindings(day)) ?? [] }
        } catch {
            problem = error.readable
        }
    }
}

/// 还没收尾的：没做完的待办（带到今天）、拿不准的（对 / 改）、自动检查发现的
private struct OpenItems: View {
    @Environment(AppModel.self) private var model
    let open: API.DailyReview.Open
    let findings: [API.AuditFinding]
    let reload: @MainActor () async -> Void

    var body: some View {
        ForEach(open.todos, id: \.entryId) { todo in
            HStack(spacing: Theme.Space.medium) {
                OpenDot(pending: false)
                Text(Show.spaced(todo.content)).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ThemeTextButton("带到今天") { model.carryToToday(todo.entryId, content: todo.content, after: reload) }
            }
            .frame(minHeight: Theme.Size.touch)
        }
        ForEach(open.pending, id: \.entryId) { item in
            HStack(spacing: Theme.Space.medium) {
                OpenDot(pending: true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(Show.spaced(item.question)).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                    Text(Show.spaced(item.text)).font(Theme.Typeface.footnote)
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ThemeTextButton("对") { model.confirmOpen(item.entryId, after: reload) }
                ThemeTextButton("改") { model.openEntry(item.entryId, day: nil) }
            }
            .frame(minHeight: Theme.Size.touch)
        }
        AuditFindingsView(findings: findings, reload: reload)
    }
}

/// 还没收尾的那一行前面的空心圈；拿不准的是虚线
struct OpenDot: View {
    let pending: Bool

    var body: some View {
        Circle()
            .strokeBorder(
                Theme.Palette.tertiaryLabel,
                style: StrokeStyle(lineWidth: 1.5, dash: pending ? [Theme.Space.hairline, Theme.Space.hairline] : [])
            )
            .frame(width: Theme.Size.check - Theme.Space.tight, height: Theme.Size.check - Theme.Space.tight)
            .accessibilityHidden(true)
    }
}
