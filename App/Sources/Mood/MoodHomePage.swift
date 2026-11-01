import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 3.0 心情页（docs/3.0/01-需求文档.md 6.2、06 交互细节 4.1–4.4）：第一屏「现在心情怎么样」五个表情（点一个就记）+ 今天的每一刻；
/// 往下是这个月（每一格是那天的表情，点一天下面出现那天的每一刻）、一周里、好时刻、发现、变化、心情分析。
/// 数字全部是服务器现算的（`/api/mood/page` 一次拿全）
struct MoodHomePage: View {
    @Environment(AppModel.self) private var model
    let month: String
    @State private var page: API.MoodPage?
    @State private var problem: String?
    /// 月历上点的那一天（下面换成那天的每一刻）
    @State private var picked: String?

    private var current: Bool { month == String(model.today.prefix(7)) }
    private var path: String { current ? "/api/mood/page" : "/api/mood/page?month=\(month)" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.cardGap) {
                if let page {
                    content(page)
                } else if let problem {
                    ErrorState(problem.contains("连") ? .serverOff : .other) { Task { await load() } }
                } else {
                    ProgressView().frame(maxWidth: .infinity, minHeight: Theme.Size.goalCard)
                }
            }
            .padding(.horizontal, Theme.Space.screen)
            .padding(.bottom, Theme.Space.xLarge)
        }
        .refreshable { await load() }
        .task(id: "\(month)-\(model.dataVersion)") { await load() }
        .onChange(of: month) { picked = nil }
    }

    @ViewBuilder private func content(_ page: API.MoodPage) -> some View {
        MoodNowCard()
        MoodTodayCard(page: page)
        MoodMonthCard(page: page, picked: $picked) { other in model.open("/mood/\(other)") }
        if let week = page.week, week.bars.contains(where: { $0.value != nil }) { MoodWeekCard(week: week) }
        if page.good.total > 0 { MoodGoodCard(good: page.good) }
        if !page.findings.isEmpty { MoodFindingsCard(findings: page.findings) { await load() } }
        if !page.changes.isEmpty { MoodChangesCard(changes: page.changes) }
        MoodAnalysisLink()
        Text("情绪词只写你说出来的 · 全部在你的电脑上").font(Theme.Typeface.footnote)
            .foregroundStyle(Theme.Palette.secondaryLabel)
            .frame(maxWidth: .infinity)
            .padding(.top, Theme.Space.small)
    }

    private func load() async {
        if page == nil || page?.month != month, let saved: API.MoodPage = model.client.cached(path) { page = saved }
        do throws(APIError) {
            page = try await model.client.moodPage(current ? nil : month)
            problem = nil
        } catch {
            if page == nil { problem = error.message }
        }
    }
}

/// 现在心情怎么样：五个表情，点一个 → 记心情弹层（那一档已经选好）
struct MoodNowCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            Text("现在心情怎么样？").font(Theme.Typeface.cardTitle).foregroundStyle(Theme.Palette.label)
                .accessibilityAddTraits(.isHeader)
            MoodCheckinRow { model.checkinMood($0) }
        }
        .themeCard()
    }
}

/// 卡片的标题：左边名字，右边可以有一句（「2 刻 · 有起有落」）或者「全部 ›」
struct MoodCardHeader: View {
    let title: String
    var detail: String?
    var link: String?
    var action: (() -> Void)?

    init(_ title: String, detail: String? = nil, link: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.detail = detail
        self.link = link
        self.action = action
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(Theme.Typeface.cardTitle).foregroundStyle(Theme.Palette.label)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let detail {
                Text(detail).font(Theme.Typeface.footnote).monospacedDigit()
                    .foregroundStyle(Theme.Palette.secondaryLabel)
            }
            if let link, let action { ThemeTextButton(link, action: action) }
        }
    }
}
