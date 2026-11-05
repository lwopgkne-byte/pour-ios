import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 周报 / 月报的整页（docs/prd-report.md；3.0 故事最后「看整页」、/review/week/…、/review/month/…）：一块一张卡——
/// 一句话、几个数、一周的样子（一个月的样子 + 每一周的周报）、做了什么和钱、目标、心情和感悟（月报带心情从哪来）、
/// 几个观察、这周 / 这个月还有、顺手整理、来自几段话。只有一两天有记录的只留一句话、做了什么、心情和感悟
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
                ErrorState(problem.contains("连") ? .serverOff : .other) { Task { await load() } }
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: Theme.Size.goalCard)
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
        let thin = review.daysRecorded <= 2
        ReviewHead(
            title: review.title, relative: Show.periodRelative(kind, from: review.period.from, today: model.today),
            updated: review.updated, overview: review.overview)
        // 记得少：只说记到的，不和上一期比
        if review.sparse {
            Text("\(scope)只有 \(review.daysRecorded) 天有记录，下面只说记到的。").font(Theme.Typeface.footnote)
                .foregroundStyle(Theme.Palette.secondaryLabel)
        }
        if !thin, !review.numbers.isEmpty { ReviewNumbers(numbers: review.numbers) }
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
            ReviewSection(title: "目标") { ForEach(review.goals) { ReviewGoalRow(goal: $0) } }
        }
        if review.mood != nil || !review.themes.isEmpty { mood(review, scope: scope) }
        if let sources = review.moodSources { MoodSourcesCard(fixed: sources) }
        rest(review, scope: scope, thin: thin)
    }

    /// 后半页：几个观察、这周 / 这个月还有、顺手整理、最下面一行
    @ViewBuilder private func rest(_ review: API.PeriodReview, scope: String, thin: Bool) -> some View {
        if !thin, !review.highlights.isEmpty || !review.concerns.isEmpty {
            ReviewSection(title: "几个观察") {
                ForEach(review.highlights, id: \.self) { note($0, good: true) }
                ForEach(review.concerns, id: \.self) { note($0, good: false) }
            }
        }
        if !thin, let next = review.next, !next.todos.isEmpty || !next.goals.isEmpty || !next.suggestions.isEmpty {
            ReviewSection(title: scope) {
                VStack(alignment: .leading, spacing: Theme.Space.tight) {
                    ForEach(next.todos, id: \.self) { Text(Show.spaced($0)).foregroundStyle(Theme.Palette.label) }
                    ForEach(next.goals.prefix(3), id: \.self) {
                        Text(Show.spaced($0)).foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                    ForEach(next.suggestions, id: \.self) {
                        Text(Show.spaced("试试：\($0)")).foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                }
                .font(Theme.Typeface.body)
            }
        }
        if !review.categorySuggestions.isEmpty {
            ReviewSection(title: "顺手整理") {
                ForEach(review.categorySuggestions, id: \.self) {
                    Text(Show.spaced($0)).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ThemeTextButton("去设置里整理") { model.open("/settings") }
            }
        }
        ReviewFoot {
            Text("来自\(weekly ? "这一周" : "这个月") \(review.daysRecorded) 天的 \(review.notes) 段话")
                .frame(minHeight: Theme.Size.touch)
        }
    }

    /// 做了什么：一个领域一行（和上一期比）；钱在最下面
    private func groups(_ review: API.PeriodReview) -> some View {
        ReviewSection(title: "做了什么") {
            ForEach(review.groups, id: \.key) { group in
                VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                    Text(group.name).font(Theme.Typeface.footnote)
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(Text(group.name))
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("canWrap")
                    line(group.text ?? "", compare: group.compare)
                }
            }
            if !review.money.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                    Text("钱").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    ForEach(review.money, id: \.text) { line($0.text, compare: $0.compare) }
                    // 钱点进「钱」的那个月：每一天、每一笔都在那儿
                    let month = String(review.period.from.prefix(7))
                    ThemeTextButton("看\(Show.monthName(month))的钱 ›") { model.open("/money/\(month)") }
                }
            }
        }
    }

    private func line(_ text: String, compare: String?) -> some View {
        var value = AttributedString(Show.spaced(text))
        value.foregroundColor = Theme.Palette.label
        if let compare {
            var tail = AttributedString(Show.spaced(" · \(compare)"))
            tail.foregroundColor = Theme.Palette.secondaryLabel
            value += tail
        }
        return Text(value).font(Theme.Typeface.body).monospacedDigit().fixedSize(horizontal: false, vertical: true)
    }

    /// 心情和感悟：几条心情、好时刻（点了看那天）、感悟里的主题（点原话去笔记库）
    private func mood(_ review: API.PeriodReview, scope: String) -> some View {
        ReviewSection(title: "心情和感悟") {
            if let mood = review.mood {
                let parts =
                    (mood.good > 0 ? ["挺好以上 \(mood.good) 条"] : []) + (mood.bad > 0 ? ["不太好以下 \(mood.bad) 条"] : [])
                Text("\(scope) \(mood.total) 条心情\(parts.isEmpty ? "" : "：\(parts.joined(separator: "，"))")。")
                    .font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
            }
            if let note = review.moodNote {
                Text(Show.spaced(note)).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let moments = review.mood?.moments, !moments.isEmpty {
                Text("好时刻").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                ForEach(moments, id: \.entryId) { moment in
                    ReviewLine {
                        navigate("/review/\(moment.day)")
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.medium) {
                            Text(weekly ? String(Show.weekRowLabel(moment.day).prefix(2)) : Show.monthDay(moment.day))
                                .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel).fixedSize()
                            Text(Show.spaced(moment.text)).font(Theme.Typeface.quote).foregroundStyle(
                                Theme.Palette.label
                            )
                            .multilineTextAlignment(.leading)
                        }
                    }
                }
            }
            ForEach(review.themes, id: \.theme) { theme in
                Text("感悟里的主题：\(Show.spaced(theme.theme))").font(Theme.Typeface.bodySemibold)
                    .foregroundStyle(Theme.Palette.label)
                ForEach(Array(theme.quotes.enumerated()), id: \.offset) { _, quote in
                    ReviewLine {
                        if let note = quote.noteId {
                            model.open("/library?note=\(note)")
                        } else {
                            model.goHome()
                            model.show(quote.day)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                            Text("「\(Show.spaced(quote.text))」").font(Theme.Typeface.quote)
                                .foregroundStyle(Theme.Palette.label).multilineTextAlignment(.leading)
                            Text(Show.dayTitle(quote.day, today: model.today)).font(Theme.Typeface.footnote)
                                .foregroundStyle(Theme.Palette.secondaryLabel)
                        }
                    }
                }
            }
        }
    }

    /// 几个观察：做得好的绿点、要留意的黄点
    private func note(_ text: String, good: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.small) {
            Circle().fill(good ? Theme.Palette.good : Theme.Palette.warn)
                .frame(width: Theme.Size.dot, height: Theme.Size.dot)
            Text(Show.spaced(text)).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(good ? "做得好" : "要留意")：\(text)"))
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
