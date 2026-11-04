import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 3.0 钱的主页（docs/3.0/01-需求文档.md 5.2、06 交互细节 3.1–3.2）：第一屏回答「这个月花了多少、还剩多少预算、有什么要办」——
/// 大数、今天、和上个月比、每天累计的曲线、预算还能花多少、四个圆按钮；往下是月历（每一格写那天花了多少，点一天下面就是那天的每一笔）、
/// 这个月（固定的 · 收入 · 人情往来）、留意（一行一件 + 按钮）、花在哪、花给了谁、值不值、钱和你的日子、固定的、还在攒的。
/// 数字全部是服务器现算的（`/api/money/home` 一次拿全）
struct MoneyHomePage: View {
    @Environment(AppModel.self) private var model
    @AppStorage(MoneyHidden.key) private var hide = false
    let month: String
    @State private var home: API.MoneyHome?
    @State private var problem: String?
    /// 月历上点的那一天（下面换成那天的每一笔）
    @State private var picked: String?
    /// 留意里刚办完的那几条：先收起来（服务器的单子回来以前）
    @State private var settled: Set<String> = []

    private var path: String { "/api/money/home?month=\(month)" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.cardGap) {
                if let home {
                    content(home)
                } else if let problem {
                    ErrorState(problem.contains("连") ? .serverOff : .other) { Task { await load() } }
                } else {
                    ProgressView().frame(maxWidth: .infinity, minHeight: Theme.Size.goalCard)
                }
            }
            .padding(.horizontal, Theme.Space.screen)
            .padding(.bottom, Theme.Space.xLarge)
        }
        .toolbar { toolbar }
        .refreshable { await load() }
        .task(id: "\(month)-\(model.dataVersion)") { await load() }
        .onChange(of: month) { picked = nil }
        // 刚用数字键盘记了一笔：月历选到今天，下面那一行「整理中」看得见
        .onChange(of: model.moneyPending.count) { before, now in
            if now > before, month == String(model.today.prefix(7)) { picked = model.today }
        }
    }

    @ViewBuilder private func content(_ home: API.MoneyHome) -> some View {
        let page = home.month
        MoneyHero(home: home)
        MoneyActions(month: month, watchCount: home.overview?.watch.count ?? 0)
        MoneyMonthCalendar(page: page, picked: $picked) { go($0) }
        // 照原型：留意在前，这个月在后
        if let overview = home.overview {
            MoneyWatchCard(lines: overview.watch.filter { !settled.contains($0.key) }) { settled.insert($0) }
        }
        MoneyThisMonth(page: page, renqing: home.overview?.renqing)
        MoneyDomainsCard(page: page)
        if let who = home.overview?.who { MoneyWhoCard(who: who) }
        if let worth = home.overview?.worth, !worth.good.isEmpty || !worth.regret.isEmpty {
            MoneyWorthStrip(worth: worth)
        }
        if let findings = home.findings, !findings.early, !findings.findings.isEmpty {
            MoneyFindingsCard(page: findings) { await load() }
        }
        if !page.fixed.series.isEmpty { MoneyFixedCard(page: page) }
        if page.current { MoneyLaterCard(page: page, overview: home.overview, findings: home.findings) }
        Text("只算你说过的钱，没说的不算 · 全部在你的电脑上").font(Theme.Typeface.footnote)
            .foregroundStyle(Theme.Palette.secondaryLabel)
            .frame(maxWidth: .infinity)
            .padding(.top, Theme.Space.small)
    }

    // MARK: - 右上角：换月、遮住金额

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                if let prev = home?.month.prevMonth { go(prev) }
            } label: {
                Image(systemName: "chevron.left").font(Theme.Typeface.toolbarIcon)
            }
            .disabled(home?.month.prevMonth == nil)
            .accessibilityLabel(Text("上个月"))
            .accessibilityIdentifier("money.prev")
            Button {
                if let next = home?.month.nextMonth { go(next) }
            } label: {
                Image(systemName: "chevron.right").font(Theme.Typeface.toolbarIcon)
            }
            .disabled(home?.month.nextMonth == nil)
            .accessibilityLabel(Text("下个月"))
            .accessibilityIdentifier("money.next")
            Button {
                hide.toggle()
            } label: {
                Image(systemName: hide ? "eye.slash" : "eye").font(Theme.Typeface.toolbarIcon)
            }
            .accessibilityLabel(Text(hide ? "显示金额" : "遮住金额"))
            .accessibilityIdentifier("money.hide")
        }
    }

    /// 换一个月（同一种页面：换掉这一页，不再往里推）
    private func go(_ other: String) {
        model.open(Show.moneyPath(other, today: model.today))
    }

    private func load() async {
        if home == nil, let saved: API.MoneyHome = model.client.cached(path) { home = saved }
        do throws(APIError) {
            home = try await model.client.moneyHome(month)
            problem = nil
            settled = []
            if picked == nil, let page = home?.month, page.current, page.days.contains(where: { $0.day == model.today })
            {
                picked = model.today
            }
        } catch {
            if home == nil { problem = error.message }
        }
    }
}

extension API.WatchLine {
    /// 一条留意的键（刚办完先收起来用）
    var key: String { "\(kind)-\(name)-\(entryId ?? 0)" }
}
