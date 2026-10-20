import PourAPI
import PourDesign
import SwiftUI

/// 「钱」一个月：日常花的那个大数、月历、每一笔 / 固定的 / 收入 / 人情往来，
/// 下面是留意、花在哪、花给了谁、值不值、钱和你的日子、还在攒的。留意以下几块说的是「现在」：这个月才有
struct MoneyMonthView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(MoneyHidden.key) private var hide = false
    let month: String
    let navigate: (String) -> Void
    @State private var page: API.MoneyMonth?
    @State private var overview: API.MoneyOverview?
    @State private var findings: API.MoneyFindingsPage?
    @State private var problem: String?

    /// 花在哪：这个月说到 20 笔、两块以上才画
    static let domainsFrom = 20

    private var current: Bool { model.today.hasPrefix(month) }

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
        .moneyPage(
            prev: page?.prevMonth.map { prev in { navigate(Show.moneyPath(prev, today: model.today)) } },
            next: page?.nextMonth.map { next in { navigate(Show.moneyPath(next, today: model.today)) } }
        )
        .task(id: "\(month)-\(model.dataVersion)") { await load() }
    }

    @ViewBuilder private func content(_ page: API.MoneyMonth) -> some View {
        let name = Show.monthName(month)
        VStack(alignment: .leading, spacing: Web.space6) {
            head(page)
            hero(page, name: name)
            monthBlock(page, name: name)
            if current, let overview { WatchSection(lines: overview.watch, navigate: navigate) }
            if page.count >= Self.domainsFrom && page.domains.count >= 2 {
                ReviewSection(title: "花在哪") {
                    Text("\(name)日常花的 · 面积是钱 · 点一块看是哪几笔").font(Web.caption).foregroundStyle(Web.fgTertiary)
                    MoneyMosaic(domains: page.domains) { navigate("/money/list/\(month)?domain=\($0)") }
                    if let note = page.domainNote {
                        Text(Show.spaced(Show.maskYuan(note, hide: hide))).font(Web.body).foregroundStyle(Web.fg)
                    }
                }

            }
            if current, let who = overview?.who { WhoSection(who: who) }
            if current, let worth = overview?.worth, !worth.good.isEmpty || !worth.regret.isEmpty {
                WorthSection(worth: worth, navigate: navigate)
            }
            if current, let findings, !findings.early {
                MoneyFindingsSection(page: findings) { await loadFindings() }
            }
            if page.current { MoneyLater(page: page, overview: overview, findings: findings) }
            ReviewFoot { Text("只算你说过的钱，没说的不算 · 全部在你的电脑上") }
        }
    }

    private func head(_ page: API.MoneyMonth) -> some View {
        HStack(alignment: .top, spacing: Web.space2) {
            VStack(alignment: .leading, spacing: 0) {
                Text("钱").font(Web.title).foregroundStyle(Web.fg).accessibilityAddTraits(.isHeader)
                Text("只算你说过的钱\(page.started.map { " · \(Show.monthDay($0))开始记" } ?? "")")
                    .font(Web.caption).foregroundStyle(Web.fgTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                hide.toggle()
            } label: {
                Image(systemName: hide ? "eye.slash" : "eye").font(Web.body).foregroundStyle(Web.fgSecondary)
                    .frame(width: Web.touch, height: Web.touch).contentShape(Rectangle())
            }
            .buttonStyle(WebPressStyle(radius: Web.radiusControl))
            .padding(.top, -Web.space2).padding(.trailing, -Web.space3)
            .accessibilityLabel(Text(hide ? "显示金额" : "遮住金额"))
            .accessibilityAddTraits(hide ? .isSelected : [])
        }
    }

    private func hero(_ page: API.MoneyMonth, name: String) -> some View {
        let total = page.counts.values.reduce(0, +)
        // 还不能比的，说清楚哪天起能比
        let why =
            page.compare?.text
            ?? (total == 0
                ? "\(name)还没说到钱。"
                : page.compareFrom.flatMap { page.current ? "\(Show.monthDay($0))起，就能和上个月比了。" : nil })
        // 今天还没说到钱就不写「今天 ¥0」：没说 ≠ 没花
        let today =
            page.current && (page.todaySpent ?? 0) > 0 ? "今天 \(Show.yuan(page.todaySpent ?? 0, hide: hide)) · " : ""
        return VStack(alignment: .leading, spacing: Web.space1) {
            Text(page.current ? "\(name)到今天，日常花的" : "\(name)，日常花的").font(Web.caption).foregroundStyle(Web.fgTertiary)
            Text(Show.yuan(page.spent, hide: hide)).font(Web.displayBold).foregroundStyle(Web.fg).monospacedDigit()
            Text("\(today)\(page.current ? "这个月" : name) \(page.count) 笔").font(Web.caption)
                .foregroundStyle(Web.fgSecondary).monospacedDigit()
            if let why {
                Text(Show.spaced(Show.maskYuan(why, hide: hide))).font(Web.body).foregroundStyle(Web.fg)
                    .monospacedDigit().padding(.top, Web.space1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func monthBlock(_ page: API.MoneyMonth, name: String) -> some View {
        VStack(alignment: .leading, spacing: Web.space1) {
            HStack {
                Text(name).font(Web.bodySemibold).foregroundStyle(Web.fg).accessibilityAddTraits(.isHeader)
                Spacer()
                HStack(spacing: 0) {
                    if let prev = page.prevMonth {
                        MoneyTextLink("‹ \(Show.monthName(prev))") {
                            navigate(Show.moneyPath(prev, today: model.today))
                        }
                    }
                    if let next = page.nextMonth {
                        MoneyTextLink("\(Show.monthName(next)) ›") {
                            navigate(Show.moneyPath(next, today: model.today))
                        }
                    }
                }
                .padding(.trailing, -Web.space3)
            }
            MoneyCalendar(
                month: month, days: page.days, today: model.today, started: page.started, early: page.early != nil
            ) { navigate("/money/day/\($0)") }
            if !page.days.isEmpty {
                Text("圆越大，那天花得越多 · 点一天看花了什么").font(Web.caption).foregroundStyle(Web.fgTertiary)
            }
            MonthRows(page: page, overview: current ? overview : nil, navigate: navigate).padding(.top, Web.space3)
        }
    }

    private func load() async {
        do {
            let fresh = try await model.client.moneyMonth(month)
            page = fresh
            problem = nil
            if current {
                overview = try? await model.client.moneyOverview()
                await loadFindings()
            }
        } catch {
            problem = error.readable
        }
    }

    private func loadFindings() async { findings = try? await model.client.moneyFindings() }
}

/// 灰色的小字链接（「‹ 9月」「全部 ›」）：点的范围够大
struct MoneyTextLink: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title).font(Web.caption).foregroundStyle(Web.fgTertiary).lineLimit(1).fixedSize()
                .padding(.horizontal, Web.space3)
                .frame(minWidth: Web.touch, minHeight: Web.touch)
                .contentShape(Rectangle())
        }
        .buttonStyle(WebPressStyle(radius: Web.radiusControl))
    }
}

/// 每一笔、固定的、收入、人情往来：一行一样，左边小字的名字，中间一句，右边小箭头
private struct MonthRows: View {
    @AppStorage(MoneyHidden.key) private var hide = false
    let page: API.MoneyMonth
    let overview: API.MoneyOverview?
    let navigate: (String) -> Void

    var body: some View {
        let name = Show.monthName(page.month)
        let total = page.counts.values.reduce(0, +)
        MoneyList {
            if total > 0 {
                row("每一笔", [.init("\(name)说到 "), .bold("\(total) 笔"), .init(" · 可以搜")]) {
                    navigate("/money/list/\(page.month)")
                }
            }
            // 固定的：扣了的、还要扣的，哪样是 0 就不写那一样
            if page.fixed.paidCount > 0 || page.fixed.upcoming > 0 {
                let paid: [Segment] = page.fixed.paidCount > 0 ? [.init("已扣 "), .bold(yuan(page.fixed.paid))] : []
                let upcoming: [Segment] =
                    page.fixed.upcoming > 0 ? [.init("这个月还要扣 "), .bold(yuan(page.fixed.upcoming))] : []
                row("固定的", joined([paid, upcoming])) { navigate("/money/list/\(page.month)?kind=fixed") }
            }
            if page.income.total > 0, let last = page.income.items.first {
                let more =
                    page.income.items.count > 1
                    ? "\(page.income.items.count) 笔" : "\(Show.monthDay(last.day)) \(last.name)"
                row("收入", [.bold(yuan(page.income.total)), .init(" · \(more)")]) {
                    navigate("/money/list/\(page.month)?kind=income")
                }
            }
            // 人情往来：不分月，一共送出、收到多少
            if let renqing = overview?.renqing {
                let out: [Segment] = renqing.out > 0 ? [.init("一共送出 "), .bold(yuan(renqing.out))] : []
                let got: [Segment] = renqing.into > 0 ? [.init("收到 "), .bold(yuan(renqing.into))] : []
                let parts = out.isEmpty && got.isEmpty ? [[Segment("来往 \(renqing.times) 次")]] : [out, got]
                row("人情往来", joined(parts)) { navigate("/money/renqing") }
            }
        }
    }

    private func yuan(_ value: Double) -> String { Show.yuan(value, hide: hide) }

    /// 几段之间用「 · 」隔开，空的不算
    private func joined(_ groups: [[Segment]]) -> [Segment] {
        groups.filter { !$0.isEmpty }.enumerated().flatMap { index, group in index == 0 ? group : [.init(" · ")] + group
        }
    }

    private func row(_ label: String, _ parts: [Segment], open: @escaping () -> Void) -> some View {
        MoneyLinkRow(minHeight: Web.space12, action: open) {
            HStack(alignment: .firstTextBaseline, spacing: Web.space2) {
                Text(label).font(Web.caption).foregroundStyle(Web.fgSecondary)
                    .fixedSize().frame(minWidth: Web.space12 + Web.space2, alignment: .leading)
                Text(rich(parts)).monospacedDigit()
            }
        }
    }
}
