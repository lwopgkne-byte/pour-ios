import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 每日回顾（docs/prd-review.md）：把昨天整理成一页。
/// 一页只有一个视觉焦点——关键数字；全部展开，靠留白分组，空的部分不出现。数字和列表是服务器现算的
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
                WebErrorState(problem) { Task { await load() } }
            } else {
                ReviewSkeleton()
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
        VStack(alignment: .leading, spacing: 0) {
            ReviewHead(
                kicker: "每日回顾", updated: review.updated, title: Show.dayTitle(day, today: model.today),
                relative: Show.relative(day, today: model.today), overview: ""
            ) { navigate("/review") }
            // 这一天的总结和关键数字（以前在画布上的「今天的样子」，产品主人 2026-10-21 挪到回顾里）
            DayLook(overview: review.overview, numbers: review.numbers, levels: review.moods.map(\.mood))
                .padding(.top, Theme.Space.large)
            if review.entries.contains(where: { $0.kind == "event" }) {
                ReviewSection(title: "一天的样子") {
                    TimelineStrip(day: day, entries: review.entries, categories: model.categories)
                }
            }
            if !review.groups.isEmpty { groups(review.groups) }
            if !review.goals.isEmpty {
                ReviewSection(title: "目标") {
                    VStack(alignment: .leading, spacing: Web.space4) {
                        ForEach(review.goals) { ReviewGoalRow(goal: $0) }
                    }
                }
            }
            if !review.moods.isEmpty || !review.insights.isEmpty { moods(review) }
            rest(page)
        }
    }

    /// 后半页：一个观察、还没收尾的、今天、最下面一行
    @ViewBuilder private func rest(_ page: API.DailyReviewPage) -> some View {
        let review = page.review
        let past = day < model.today
        let yesterday = day == PourDate.addDays(model.today, -1)
        VStack(alignment: .leading, spacing: 0) {
            if let observation = review.observation {
                ReviewSection(title: "一个观察") {
                    Text(Show.spaced(observation)).font(Web.body).foregroundStyle(Web.fg).lineSpacing(
                        Web.quoteLineSpacing)
                }
            }
            // 过去的日子才有「还没收尾的」；「今天」只放在昨天那一页
            if past, !review.open.todos.isEmpty || !review.open.pending.isEmpty || !findings.isEmpty {
                ReviewSection(title: "还没收尾的") {
                    OpenItems(open: review.open, findings: findings) { await load() }
                }
            }
            if yesterday, !review.today.todos.isEmpty || !review.today.goals.isEmpty {
                ReviewSection(title: "今天") {
                    VStack(alignment: .leading, spacing: Web.space1) {
                        ForEach(review.today.todos, id: \.self) { Text(Show.spaced($0)).foregroundStyle(Web.fg) }
                        // 目标只列最要紧的两个：多了就不像一句提醒了
                        ForEach(review.today.goals.prefix(2), id: \.self) {
                            Text(Show.spaced($0)).foregroundStyle(Web.fgSecondary)
                        }
                    }
                    .font(Web.body)
                }
            }
            if let quote = page.quote { saidSection(quote) }
            ReviewFoot {
                Text("来自这一天的 \(review.notes) 段话 · ")
                WebTextButton("看这一天的画布", font: Web.caption, color: Web.fgSecondary) {
                    model.page = .canvas
                    model.show(day)
                }
                if let weekly = page.weekly {
                    Text(" · ")
                    WebTextButton("这一周的周报", font: Web.caption, color: Web.fgSecondary) {
                        navigate(Show.reportPath("weekly", from: weekly))
                    }
                }
            }
        }
    }

    /// 最后一句「你说过」：自己说过的一句话，服务器按日子轮着挑（docs/模块/产品优化.md R4）
    private func saidSection(_ quote: API.MyQuote) -> some View {
        ReviewSection(title: "你说过") {
            VStack(alignment: .leading, spacing: Web.space1) {
                Text(Show.spaced("「\(quote.text)」")).font(Web.body).foregroundStyle(Web.fg)
                    .lineSpacing(Web.quoteLineSpacing)
                Text("\(Show.dayTitle(quote.day, today: model.today))\(quote.asked ? "让记下的" : "说的")")
                    .font(Web.caption).foregroundStyle(Web.fgTertiary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// 做了什么：上面是领域，下面是这一天做的事（手机上一列）
    private func groups(_ groups: [API.ReviewGroup]) -> some View {
        ReviewSection(title: "做了什么") {
            VStack(alignment: .leading, spacing: Web.space3) {
                ForEach(groups, id: \.key) { group in
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: Web.space2) {
                            Text(group.emoji)
                            Text(group.name)
                        }
                        .font(Web.caption).foregroundStyle(Web.fgTertiary)
                        // 一个领域的小标题：读屏只念名字（表情是图）
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(group.name))
                        .accessibilityAddTraits(.isHeader)
                        ForEach(group.items ?? [], id: \.entryId) { item in
                            ReviewLine {
                                model.openEntry(item.entryId, day: day)
                            } label: {
                                Text(Show.spaced(item.text)).font(Web.body).foregroundStyle(Web.fg)
                            }
                        }
                    }
                }
            }
        }
    }

    /// 心情和感悟：每条心情一行，和画布同一个样子；感悟的原话
    private func moods(_ review: API.DailyReview) -> some View {
        let quotes = review.insights.map(\.quote)
        let showTimes = Set(review.moods.compactMap(\.at)).count > 1
        return ReviewSection(title: "心情和感悟") {
            ForEach(review.moods, id: \.entryId) { mood in
                ReviewLine {
                    model.openEntry(mood.entryId, day: day)
                } label: {
                    MoodLine(mood: mood.data, quotes: quotes, time: showTimes ? mood.at : nil)
                }
            }
            ForEach(review.insights, id: \.entryId) { insight in
                ReviewLine {
                    model.openEntry(insight.entryId, day: day)
                } label: {
                    QuoteText(text: insight.quote)
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
    let reload: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(open.todos, id: \.entryId) { todo in
                row(pending: false) {
                    Text(Show.spaced(todo.content)).font(Web.body).foregroundStyle(Web.fg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    WebTextButton("带到今天") {
                        act("「\(todo.content)」带到今天了") { try await $0.carry(entry: todo.entryId) }
                    }
                }
            }
            ForEach(open.pending, id: \.entryId) { item in
                row(pending: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Show.spaced(item.question)).font(Web.body).foregroundStyle(Web.fg)
                        Text(Show.spaced(item.text)).font(Web.caption).foregroundStyle(Web.fgTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    WebTextButton("对") { act("确认了") { try await $0.confirm(entry: item.entryId) } }
                    WebTextButton("改") { model.openEntry(item.entryId, day: nil) }
                }
            }
            AuditFindingsView(findings: findings, reload: reload)
        }
    }

    private func row<Content: View>(pending: Bool, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: Web.space3) {
            OpenDot(pending: pending)
            content()
        }
        .frame(minHeight: Web.touch)
        .overlay(alignment: .bottom) { Rectangle().fill(Web.line).frame(height: 1) }
    }

    private func act(_ done: String, _ work: @escaping @Sendable (APIClient) async throws -> Void) {
        let client = model.client
        Task {
            do {
                try await work(client)
                model.dataChanged()
                await reload()
                model.toast(done)
            } catch {
                model.toast(error.readable)
            }
        }
    }
}

/// 还没收尾的那一行前面的空心圈；拿不准的是虚线
struct OpenDot: View {
    let pending: Bool

    var body: some View {
        Circle()
            .strokeBorder(
                Web.lineStrong, style: StrokeStyle(lineWidth: 1, dash: pending ? [Web.space1 / 2, Web.space1 / 2] : [])
            )
            .frame(width: Web.space3, height: Web.space3)
            .accessibilityHidden(true)
    }
}
