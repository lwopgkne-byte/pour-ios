import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 周报 / 月报（docs/prd-report.md）：和每日回顾同一套样子——一页全部展开，
/// 一个焦点（四个大数字），靠留白分组，空的部分不出现。AI 只写一句话、几个观察、感悟里的主题和建议
struct PeriodReviewView: View {
    @Environment(AppModel.self) private var model
    /// weekly、monthly
    let kind: String
    /// 那一期的第一天
    let day: String
    let navigate: (String) -> Void
    @State private var page: API.PeriodReviewPage?
    @State private var problem: String?

    private var weekly: Bool { kind == "weekly" }

    var body: some View {
        Group {
            if let page {
                content(page.review)
            } else if let problem {
                WebErrorState(problem) { Task { await load() } }
            } else {
                ReviewSkeleton()
            }
        }
        .reviewPage(
            prev: page?.prev.map { prev in { navigate(Show.reportPath(kind, from: prev)) } },
            next: page?.next.map { next in { navigate(Show.reportPath(kind, from: next)) } }
        )
        .task(id: "\(kind)-\(day)-\(model.dataVersion)") { await load() }
    }

    @ViewBuilder private func content(_ review: API.PeriodReview) -> some View {
        let scope = Show.periodScope(kind)
        // 只有一两天有记录：只留一句话、做了什么、心情和感悟，不摆空架子
        let thin = review.daysRecorded <= 2
        VStack(alignment: .leading, spacing: 0) {
            ReviewHead(
                kicker: weekly ? "周报" : "月报", updated: review.updated, title: review.title,
                relative: Show.periodRelative(kind, from: review.period.from, today: model.today),
                overview: review.overview
            ) { navigate("/review") }
            // 记得少：只说记到的，不和上一期比
            if review.sparse {
                Text("\(scope)只有 \(review.daysRecorded) 天有记录，下面只说记到的。").font(Web.caption)
                    .foregroundStyle(Web.fgTertiary).padding(.top, Web.space2)
            }
            if !thin { KeyNumbers(numbers: review.numbers) }
            if !thin {
                ReviewSection(title: weekly ? "一周的样子" : "一个月的样子") {
                    if weekly {
                        WeekStrip(days: review.days, entries: review.entries) { navigate("/review/\($0)") }
                    } else {
                        MonthGrid(days: review.days, weeklyReports: review.weeklyReports, navigate: navigate)
                    }
                }
            }
            if !review.groups.isEmpty || !review.money.isEmpty { groups(review) }
            if !thin, !review.goals.isEmpty {
                ReviewSection(title: "目标") {
                    VStack(alignment: .leading, spacing: Web.space4) {
                        ForEach(review.goals) { ReviewGoalRow(goal: $0) }
                    }
                }
            }
            if review.mood != nil || !review.themes.isEmpty || review.moodSources != nil { mood(review, scope: scope) }
            rest(review, scope: scope, thin: thin)
        }
    }

    /// 后半页：几个观察、这周 / 这个月、顺手整理、最下面一行
    @ViewBuilder private func rest(_ review: API.PeriodReview, scope: String, thin: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !thin, !review.highlights.isEmpty || !review.concerns.isEmpty { notes(review) }
            if !thin, let next = review.next, !next.todos.isEmpty || !next.goals.isEmpty || !next.suggestions.isEmpty {
                ReviewSection(title: scope) {
                    VStack(alignment: .leading, spacing: Web.space1) {
                        ForEach(next.todos, id: \.self) { Text(Show.spaced($0)).foregroundStyle(Web.fg) }
                        ForEach(next.goals.prefix(3), id: \.self) {
                            Text(Show.spaced($0)).foregroundStyle(Web.fgSecondary)
                        }
                        ForEach(next.suggestions, id: \.self) {
                            Text(Show.spaced("试试：\($0)")).foregroundStyle(Web.fgSecondary)
                        }
                    }
                    .font(Web.body)
                }
            }
            if !review.categorySuggestions.isEmpty {
                ReviewSection(title: "顺手整理") {
                    VStack(alignment: .leading, spacing: Web.space1) {
                        ForEach(review.categorySuggestions, id: \.self) {
                            Text(Show.spaced($0)).font(Web.body).foregroundStyle(Web.fgSecondary)
                        }
                    }
                    WebTextButton("去设置里整理") { model.open("/settings") }
                }
            }
            ReviewFoot { Text("来自\(weekly ? "这一周" : "这个月") \(review.daysRecorded) 天的 \(review.notes) 段话") }
        }
    }

    /// 做了什么：一个领域一行；钱在最下面，上面一条细线隔开
    private func groups(_ review: API.PeriodReview) -> some View {
        ReviewSection(title: "做了什么") {
            VStack(alignment: .leading, spacing: Web.space3) {
                ForEach(review.groups, id: \.key) { group in
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
                        line(group.text ?? "", compare: group.compare)
                    }
                }
                if !review.money.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("钱").font(Web.caption).foregroundStyle(Web.fgTertiary)
                        ForEach(review.money, id: \.text) { line($0.text, compare: $0.compare) }
                        // 月报的钱点进「钱」的那个月：每一天、每一笔都在那儿
                        if !weekly {
                            let month = String(review.period.from.prefix(7))
                            WebTextButton("看\(Show.monthName(month))的钱 ›", font: Web.caption, color: Web.fgTertiary) {
                                model.open("/money/\(month)")
                            }
                            .frame(minHeight: Web.touch)
                        }
                    }
                    .padding(.top, Web.space3)
                    .overlay(alignment: .top) { Rectangle().fill(Web.line).frame(height: 1) }
                    .padding(.top, Web.space2)
                }
            }
        }
    }

    private func line(_ text: String, compare: String?) -> some View {
        Text(spans([(text, Web.fg)] + (compare.map { [(" · \($0)", Web.fgTertiary)] } ?? [])))
            .font(Web.body).padding(.vertical, Web.space1)
    }

    /// 心情和感悟：几条心情、好时刻、感悟里的主题
    private func mood(_ review: API.PeriodReview, scope: String) -> some View {
        ReviewSection(title: "心情和感悟") {
            if let mood = review.mood {
                let parts =
                    ["\(scope) \(mood.total) 条心情"] + (mood.good > 0 ? ["挺好以上 \(mood.good) 条"] : [])
                    + (mood.bad > 0 ? ["不太好以下 \(mood.bad) 条"] : [])
                let rest = parts.dropFirst().joined(separator: "，")
                Text(Show.spaced("\(parts[0])\(rest.isEmpty ? "" : "：\(rest)")。")).font(Web.body).foregroundStyle(
                    Web.fg)
            }
            if let note = review.moodNote { Text(Show.spaced(note)).font(Web.body).foregroundStyle(Web.fg) }
            if let moments = review.mood?.moments, !moments.isEmpty { momentList(moments) }
            if !review.themes.isEmpty { themeList(review.themes) }
            if let sources = review.moodSources { MoodSourcesView(data: sources).padding(.top, Web.space3) }
        }
    }

    /// 好时刻：最多 3 个，点了打开那天的回顾
    private func momentList(_ moments: [API.PeriodMood.Moment]) -> some View {
        VStack(alignment: .leading, spacing: Web.space1) {
            Text("好时刻").font(Web.caption).foregroundStyle(Web.fgTertiary)
            ForEach(moments, id: \.entryId) { moment in
                ReviewLine {
                    navigate("/review/\(moment.day)")
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: Web.space4) {
                        Text(
                            weekly
                                ? String(Show.weekRowLabel(moment.day).prefix(2))
                                : GoalChart.monthDay(moment.day)
                        )
                        .font(Web.caption).foregroundStyle(Web.fgTertiary)
                        .frame(minWidth: Web.space12 + Web.space2, alignment: .leading)
                        Text(Show.spaced(moment.text)).font(Web.body).foregroundStyle(Web.fg)
                    }
                }
            }
        }
        .padding(.top, Web.space3)
    }

    /// 感悟里的主题，带着原话；点原话去笔记库（没有原话编号就去那一天的画布）
    private func themeList(_ themes: [API.Theme]) -> some View {
        VStack(alignment: .leading, spacing: Web.space1) {
            Text("感悟里的主题").font(Web.caption).foregroundStyle(Web.fgTertiary)
            ForEach(themes, id: \.theme) { theme in
                VStack(alignment: .leading, spacing: Web.space1) {
                    Text(Show.spaced(theme.theme)).font(Web.bodySemibold).foregroundStyle(Web.fg)
                    ForEach(Array(theme.quotes.enumerated()), id: \.offset) { _, quote in
                        ReviewLine {
                            if let note = quote.noteId {
                                model.open("/library?note=\(note)")
                            } else {
                                model.goHome()
                                model.show(quote.day)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: Web.space1) {
                                QuoteText(text: quote.text)
                                Text(Show.dayTitle(quote.day, today: model.today)).font(Web.caption)
                                    .foregroundStyle(Web.fgTertiary)
                            }
                            .padding(.vertical, Web.space1)
                        }
                    }
                }
            }
        }
        .padding(.top, Web.space3)
    }

    /// 几个观察：做得好的绿点、要留意的黄点
    private func notes(_ review: API.PeriodReview) -> some View {
        ReviewSection(title: "几个观察") {
            VStack(alignment: .leading, spacing: Web.space1) {
                ForEach(review.highlights, id: \.self) { note("good", $0) }
                ForEach(review.concerns, id: \.self) { note("warn", $0) }
            }
        }
    }

    private func note(_ tone: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Web.space2) {
            ToneDot(tone: tone).alignmentGuide(.firstTextBaseline) { $0[.bottom] }
            Text(Show.spaced(text)).font(Web.body).foregroundStyle(Web.fg).lineSpacing(Web.quoteLineSpacing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(tone == "good" ? "做得好" : "要留意")：\(text)"))
    }

    private func load() async {
        do {
            let fresh = try await model.client.periodReview(kind, day)
            page = fresh
            problem = nil
            if let id = fresh.messageId, !fresh.read { try? await model.client.markRead(message: id) }
        } catch {
            problem = error.readable
        }
    }
}
