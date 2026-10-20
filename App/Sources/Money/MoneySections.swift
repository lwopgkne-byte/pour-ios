import PourAPI
import PourDesign
import SwiftUI

/*
 * 「钱」主页下面几块（网页版 money-sections.tsx，这个月才有）：留意、花给了谁、值不值、钱和你的日子、还在攒的。
 * 数字和句子都是服务器算好的，这里只摆出来
 */

/// 留意：最多 4 条；「全部 ›」到「留意的」那一页。不推送、不打红点
struct WatchSection: View {
    @AppStorage(MoneyHidden.key) private var hide = false
    let lines: [API.WatchLine]
    let navigate: (String) -> Void

    var body: some View {
        ReviewSection(title: "留意") {
            if lines.isEmpty {
                Text("没有要你马上办的。课时、常买的在「全部」里").font(Web.caption).foregroundStyle(Web.fgTertiary)
            } else {
                MoneyList {
                    ForEach(lines, id: \.self) { line in
                        MoneyLinkRow {
                            navigate("/money/watch")
                        } label: {
                            MoneyMainSub(
                                main: Text(rich([.init("\(line.name) "), .bold(Show.yuan(line.amount, hide: hide))])),
                                sub: line.sub)
                        }
                    }
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            MoneyTextLink("全部 ›") { navigate("/money/watch") }
                .padding(.top, Web.space12 - (Web.touch - Web.space4) / 2).padding(.trailing, -Web.space3)
        }
    }
}

/// 花给了谁（5.7）：一家人一起的单独一句，不画进横条；横条只比给一个人的，按其中最多的一个来比；
/// 下面那句比较的两个深一点
struct WhoSection: View {
    @AppStorage(MoneyHidden.key) private var hide = false
    let who: API.MoneyWho

    var body: some View {
        let most = max(who.people.map(\.amount).max() ?? 1, 1)
        ReviewSection(title: "花给了谁") {
            Text("\(Show.monthDay(who.from))以来日常花的 \(Show.yuan(who.total, hide: hide))").font(Web.caption)
                .foregroundStyle(Web.fgTertiary)
            if let family = who.family {
                Text(
                    rich([
                        .init("一家人一起的（吃的、玩的、家里用的）"), .bold(Show.yuan(family.amount, hide: hide)),
                        .init("，占了\(family.share)。给一个人的："),
                    ]))
            }
            VStack(spacing: 0) {
                ForEach(who.people, id: \.name) { person in
                    HStack(spacing: Web.space2) {
                        Text(person.name).font(Web.body).foregroundStyle(Web.fg)
                            .fixedSize().frame(minWidth: Web.space12, alignment: .leading)
                        MoneyBar(
                            share: max(0.02, person.amount / most),
                            color: person.strong ? Web.fgTertiary : Web.lineStrong)
                        Text(Show.yuan(person.amount, hide: hide)).font(Web.body).foregroundStyle(Web.fgSecondary)
                            .monospacedDigit().lineLimit(1).fixedSize()
                            .frame(minWidth: Web.space16, alignment: .trailing)
                    }
                    .frame(minHeight: Web.touch)
                    .accessibilityElement(children: .combine)
                }
            }
            // 这句话里没有钱数，遮住金额时照常显示
            if let sentence = who.sentence { Text(Show.spaced(sentence)).font(Web.body).foregroundStyle(Web.fg) }
        }
    }
}

/// 一根横条：浅灰的底，按几分之几画
struct MoneyBar: View {
    let share: Double
    let color: Color

    var body: some View {
        Capsule().fill(Web.bgHover).frame(height: Web.space2)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule().fill(color).frame(width: proxy.size.width * min(1, max(0, share)))
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }
}

/// 值不值 · 你自己说的（5.8）：你说值的最多 3 样，其余一行「还有」；你说后悔的
struct WorthSection: View {
    let worth: API.MoneyWorth
    let navigate: (String) -> Void

    var body: some View {
        ReviewSection(title: "值不值 · 你自己说的") {
            VStack(alignment: .leading, spacing: Web.space3) {
                if !worth.good.isEmpty {
                    group(
                        tone: "good", title: "你说值的", items: Array(worth.good.prefix(3)),
                        more: Array(worth.good.dropFirst(3)))
                }
                if !worth.regret.isEmpty { group(tone: "warn", title: "你说后悔的", items: worth.regret, more: []) }
            }
            Text("值不值只听你自己说的。「用了几次」是你之后说到用它的次数，没说的不算。").font(Web.caption)
                .foregroundStyle(Web.fgTertiary)
        }
    }

    private func group(tone: String, title: String, items: [API.MoneyThing], more: [API.MoneyThing]) -> some View {
        VStack(alignment: .leading, spacing: Web.space1) {
            HStack(spacing: Web.space2) {
                Circle().fill(Web.status(tone)).frame(width: Web.space2, height: Web.space2)
                Text(title).font(Web.caption).foregroundStyle(Web.fgSecondary)
            }
            MoneyList {
                ForEach(items, id: \.entryId) { WorthItem(thing: $0) { navigate("/money/thing/\($0)") } }
                if !more.isEmpty {
                    Text("还有 \(more.count) 样：\(more.map(\.name).joined(separator: "、"))").font(Web.caption)
                        .foregroundStyle(Web.fgSecondary).frame(
                            maxWidth: .infinity, minHeight: Web.space12, alignment: .leading
                        )
                        .moneyRule()
                }
            }
        }
    }
}

/// 值不值里的一样东西：点开是「一样东西的那一页」
private struct WorthItem: View {
    @AppStorage(MoneyHidden.key) private var hide = false
    let thing: API.MoneyThing
    let open: (Int) -> Void

    var body: some View {
        Button {
            open(thing.entryId)
        } label: {
            VStack(alignment: .leading, spacing: Web.space1) {
                HStack(alignment: .firstTextBaseline, spacing: Web.space2) {
                    Text(Show.spaced(thing.name)).font(Web.bodySemibold).frame(maxWidth: .infinity, alignment: .leading)
                    Text(Show.yuan(thing.amount, hide: hide)).font(Web.bodySemibold).monospacedDigit()
                }
                .foregroundStyle(Web.fg)
                if let verdict = thing.verdict { Text("「\(verdict.quote)」").font(Web.quote).foregroundStyle(Web.fg) }
                Text(Show.spaced(Show.maskYuan(thing.sub, hide: hide))).font(Web.caption).foregroundStyle(
                    Web.fgTertiary
                )
                .monospacedDigit()
            }
            .padding(.vertical, Web.space3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(WebPressStyle(radius: 0))
        .moneyRule()
        .accessibilityElement(children: .combine)
    }
}

/// 钱和你的日子（5.9）：这一周挑的一两条；一条也没有时说一句
struct MoneyFindingsSection: View {
    @Environment(AppModel.self) private var model
    @AppStorage(MoneyHidden.key) private var hide = false
    let page: API.MoneyFindingsPage
    let reload: () async -> Void

    var body: some View {
        ReviewSection(title: "钱和你的日子") {
            if page.findings.isEmpty {
                Text("这周没找到站得住的。每周找一次，只给你看前后两段都成立、不是碰巧的。").font(Web.caption)
                    .foregroundStyle(Web.fgTertiary)
            } else {
                ForEach(page.findings, id: \.key) { finding in
                    FindingCard(
                        finding: finding, mask: { Show.maskYuan($0, hide: hide) },
                        openDay: { model.open("/money/day/\($0)") }, vote: { vote(finding.key, $0) })
                }
            }
        }
    }

    /// 说中了 · 早知道 · 没意思 · 不对（nil 是撤销）：按钮自己显示点了哪个，不弹提示
    private func vote(_ key: String, _ vote: String?) {
        let client = model.client
        Task {
            do {
                try await client.vote(finding: key, vote)
                await reload()
            } catch {
                model.toast(error.readable)
            }
        }
    }
}

/// 还在攒的（5.11）：写清楚每样什么时候能看，不用进度条
struct MoneyLater: View {
    let page: API.MoneyMonth
    let overview: API.MoneyOverview?
    let findings: API.MoneyFindingsPage?

    var body: some View {
        let rows = rowsToShow
        if !rows.isEmpty {
            ReviewSection(title: "还在攒的") {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(rows, id: \.0) { name, when in
                        VStack(alignment: .leading, spacing: 0) {
                            Text(name).font(Web.body).foregroundStyle(Web.fg)
                            Text(Show.spaced(when)).font(Web.caption).foregroundStyle(Web.fgTertiary)
                        }
                        .padding(.vertical, Web.space2)
                        .frame(maxWidth: .infinity, minHeight: Web.space16, alignment: .leading)
                        .moneyRule()
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private var rowsToShow: [(String, String)] {
        let from = MoneyMonthView.domainsFrom
        var rows: [(String, String)] = []
        if (1..<from).contains(page.count) {
            rows.append(("花在哪", "这个月说到 \(from) 笔以后能看（现在 \(page.count) 笔）"))
        }
        if let overview, overview.who == nil, overview.whoCount < from {
            rows.append(("花给了谁", "说到 \(from) 笔以后能看（现在 \(overview.whoCount) 笔）"))
        }
        if page.early != nil && page.fixed.series.isEmpty {
            rows.append(("固定的", "同一样东西隔一个月又扣一次，就能认出来"))
        }
        if page.early != nil, let overview, overview.worth.good.isEmpty && overview.worth.regret.isEmpty {
            rows.append(("值不值", "买东西的时候顺口说一句值不值，这里就会有"))
        }
        if let findings, findings.early {
            rows.append(("钱和你的日子", "记到 4 周左右以后能看（现在 \(findings.recorded) 天）"))
        }
        return rows
    }
}
