import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 故事的一页（06 交互细节第 6 节、10.4）。空的那一页不出现
enum StoryPage: Hashable {
    // 每日回顾
    case dayTitle(API.DailyReview)
    case numbers(String, [API.KeyNumber])
    case dayBars(API.DailyReview)
    case moods(API.DailyReview)
    case goals(API.DailyReview)
    case open(API.DailyReview, [API.AuditFinding])
    case said(API.DailyReviewPage)
    // 周报月报
    case periodTitle(API.PeriodReview)
    case week(API.PeriodReview)
    case month(API.PeriodReview)
    case done(API.PeriodReview)
    case periodGoals(API.PeriodReview)
    case periodMood(API.PeriodReview)
    case periodRest(API.PeriodReview)

    /// 每日回顾：一句话 → 几个数和平时比 → 一天的样子 → 心情和那一刻 → 目标和一个观察 → 还没收尾的和自动检查 → 你说过
    static func daily(_ page: API.DailyReviewPage, findings: [API.AuditFinding], today: String) -> [StoryPage] {
        let review = page.review
        var out: [StoryPage] = [.dayTitle(review)]
        if !review.numbers.isEmpty {
            out.append(.numbers("\(Self.count(review.numbers.count)) · 和平时比", review.numbers))
        }
        if !StoryDayBars.bars(review).isEmpty { out.append(.dayBars(review)) }
        if !review.moods.isEmpty || !review.insights.isEmpty { out.append(.moods(review)) }
        if !review.goals.isEmpty || review.observation != nil { out.append(.goals(review)) }
        let open = review.open
        if review.day < today, !open.todos.isEmpty || !open.pending.isEmpty || !findings.isEmpty {
            out.append(.open(review, findings))
        }
        out.append(.said(page))
        return out
    }

    /// 周报七页、月报六页：一句话 → 几个数和上一期比 → 一周 / 一个月的样子 → 做了什么和钱（月报：钱和目标）→ 目标 →
    /// 心情和感悟 → 几个观察、这周还有、试试、顺手整理。记录少（一两天）的只留一句话、心情和最后一页
    static func period(_ review: API.PeriodReview) -> [StoryPage] {
        let weekly = review.kind == "weekly"
        let thin = review.daysRecorded <= 2
        var out: [StoryPage] = [.periodTitle(review)]
        if !thin, !review.numbers.isEmpty {
            out.append(.numbers("\(Self.count(review.numbers.count)) · \(weekly ? "和上周比" : "和上个月比")", review.numbers))
        }
        if !thin { out.append(weekly ? .week(review) : .month(review)) }
        if weekly {
            if !review.groups.isEmpty || !review.money.isEmpty { out.append(.done(review)) }
            if !thin, !review.goals.isEmpty { out.append(.periodGoals(review)) }
        } else if !review.money.isEmpty || !review.goals.isEmpty {
            out.append(.done(review))
        }
        if review.mood != nil || !review.themes.isEmpty { out.append(.periodMood(review)) }
        out.append(.periodRest(review))
        return out
    }

    /// 「四个数」「三个数」
    static func count(_ number: Int) -> String {
        ["一个数", "两个数", "三个数", "四个数"][min(max(number, 1), 4) - 1]
    }
}

/// 一页故事的内容
struct StoryPageView: View {
    let page: StoryPage
    let ref: ReviewStoryRef
    let reload: @MainActor () async -> Void

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }.scrollIndicators(.hidden)
        }
    }

    @ViewBuilder private var content: some View {
        VStack(alignment: .leading, spacing: Theme.Space.regular) {
            switch page {
            case .dayTitle(let review): StoryDayTitle(review: review)
            case .numbers(let title, let numbers): StoryNumbersPage(title: title, numbers: numbers)
            case .dayBars(let review): StoryDayBars(review: review)
            case .moods(let review): StoryMoods(review: review)
            case .goals(let review): StoryDayGoals(review: review)
            case .open(let review, let findings): StoryOpen(review: review, findings: findings, reload: reload)
            case .said(let page): StorySaid(page: page, ref: ref)
            case .periodTitle(let review): StoryPeriodTitle(review: review)
            case .week(let review): StoryWeek(review: review)
            case .month(let review): StoryMonth(review: review)
            case .done(let review): StoryDone(review: review)
            case .periodGoals(let review): StoryPeriodGoals(review: review)
            case .periodMood(let review): StoryPeriodMood(review: review)
            case .periodRest(let review): StoryPeriodRest(review: review, ref: ref)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Space.regular)
    }
}

/// 一页上面的小标题（「四个数 · 和平时比」）
struct StoryLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text).font(Theme.Typeface.cardTitle).opacity(0.8).accessibilityAddTraits(.isHeader)
    }
}

/// 故事上的按钮（「带到今天」「看整页」）：深色底上白底深字；暖白底上深底白字。secondary 是半透明的那种
struct StoryButton: View {
    @Environment(\.storyLight) private var light
    let title: String
    var secondary = false
    let action: () -> Void

    init(_ title: String, secondary: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.secondary = secondary
        self.action = action
    }

    var body: some View {
        let solid = light ? Theme.Story.buttonOnLight : Theme.Story.buttonOnDark
        let text = light ? Theme.Story.darkInk : Theme.Story.lightInk
        Button(action: action) {
            Text(title).font(Theme.Typeface.footnoteSemibold)
                .foregroundStyle(secondary ? Theme.Story.ink(last: light) : text)
                .padding(.horizontal, Theme.Space.regular).frame(minHeight: Theme.Size.capsule + Theme.Space.tight)
                .background(secondary ? Theme.Story.ink(last: light).opacity(0.12) : solid, in: Capsule())
                .frame(minHeight: Theme.Size.touch).contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
    }
}

extension View {
    /// 一块玻璃（深色底上浅一点；暖白底上深一点）
    func storyGlass(_ light: Bool = false) -> some View {
        padding(Theme.Space.inset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(light ? Theme.Story.lightGlass : Theme.Story.glass, in: Theme.rounded(Theme.Corner.stat))
    }
}

extension EnvironmentValues {
    /// 这一页是暖白的最后一页（按钮、玻璃换成深色的）
    @Entry var storyLight = false
}

/// 最后一页下面：来自几段话（和几个去处），「看整页」「看完了」
struct StoryEnd<Links: View>: View {
    @Environment(AppModel.self) private var model
    let source: String
    let ref: ReviewStoryRef
    @ViewBuilder let links: () -> Links

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text(source).font(Theme.Typeface.footnote).opacity(0.7)
            links()
            HStack(spacing: Theme.Space.small) {
                StoryButton("看整页") { model.openFullReview(ref) }
                    .accessibilityIdentifier("story.full")
                StoryButton("看完了", secondary: true) { model.review.story = nil }
                    .accessibilityIdentifier("story.done")
            }
        }
        .padding(.top, Theme.Space.regular)
        .environment(\.storyLight, true)
    }
}
