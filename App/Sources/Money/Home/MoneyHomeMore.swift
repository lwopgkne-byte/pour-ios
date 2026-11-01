import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 钱和你的日子（发现卡，和关于我同一种）：一句话、两根横条、依据；点开是那几天（点进那天）；
/// 下面四个反馈「说中了 · 早知道 · 没意思 · 不对」，点了的深一点，再点一次撤销；点「不对」问一句是不是哪天记错了
struct MoneyFindingsCard: View {
    @Environment(AppModel.self) private var model
    @AppStorage(MoneyHidden.key) private var hide = false
    let page: API.MoneyFindingsPage
    let reload: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            MoneyCardHeader("钱和你的日子")
            ForEach(page.findings, id: \.key) { finding in
                FindingCardView(
                    finding: finding, mask: { Show.maskYuan($0, hide: hide) },
                    openDay: { model.open("/money/day/\($0)") }, vote: { vote(finding.key, $0) })
            }
        }
        .themeCard()
    }

    private func vote(_ key: String, _ vote: String?) {
        let client = model.client
        Task {
            do throws(APIError) {
                try await client.vote(finding: key, vote)
                await reload()
            } catch {
                model.toast(error.message)
            }
        }
    }
}

/// 一条发现（3.0 的样子；01 需求文档 3.2「发现卡」）
struct FindingCardView: View {
    let finding: API.FindingView
    let mask: (String) -> String
    let openDay: (String) -> Void
    let vote: (String?) -> Void
    @State private var open = false

    private static let votes = [("right", "说中了"), ("known", "早知道"), ("boring", "没意思"), ("wrong", "不对")]

    var body: some View {
        let shown = open || finding.vote == "wrong"
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Button {
                withAnimation(Theme.Motion.standard) { open = !shown }
            } label: {
                main.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityValue(Text(shown ? "展开了" : "收着"))
            if shown { days }
            votes
        }
        .padding(Theme.Space.medium)
        .background(Theme.Palette.background, in: Theme.rounded(Theme.Corner.stat))
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text(mask(finding.sentence)).font(Theme.Typeface.bodySemibold)
                .foregroundStyle(Theme.Palette.label).fixedSize(horizontal: false, vertical: true)
            ForEach(finding.bars, id: \.label) { bar in
                HStack(spacing: Theme.Space.small) {
                    Text(bar.label).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                        .frame(minWidth: Theme.Size.touch, alignment: .leading)
                    GeometryReader { proxy in
                        Capsule().fill(color(bar)).frame(width: max(Theme.Space.tight, proxy.size.width * bar.share))
                            .frame(maxHeight: .infinity, alignment: .center)
                    }
                    .frame(height: Theme.Space.snug)
                    Text(mask(bar.value)).font(Theme.Typeface.footnote).monospacedDigit()
                        .foregroundStyle(Theme.Palette.secondaryLabel).fixedSize()
                }
            }
            Text(finding.sub).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
        }
    }

    /// 有这个样子的那根：要留意的黄、好事绿；别的日子灰
    private func color(_ bar: API.FindingView.Bar) -> Color {
        guard bar.strong else { return Theme.Palette.tertiaryLabel }
        return finding.tone == "good" ? Theme.Palette.good : Theme.Palette.warn
    }

    private var days: some View {
        VStack(alignment: .leading, spacing: 0) {
            if finding.vote == "wrong" {
                Text("是不是哪天记错了？点进那天，能看到你的原话，也能改。").font(Theme.Typeface.footnote)
                    .foregroundStyle(Theme.Palette.secondaryLabel).padding(.vertical, Theme.Space.tight)
            }
            ForEach(finding.days, id: \.day) { day in
                Button {
                    openDay(day.day)
                } label: {
                    VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                        Text("\(Show.monthDay(day.day)) \(Show.weekday(day.day))").font(Theme.Typeface.body)
                            .foregroundStyle(Theme.Palette.label)
                        if !day.text.isEmpty {
                            Text(mask(day.text)).font(Theme.Typeface.footnote).foregroundStyle(
                                Theme.Palette.secondaryLabel)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.touch, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var votes: some View {
        HStack(spacing: 0) {
            ForEach(Self.votes, id: \.0) { key, label in
                let picked = finding.vote == key
                Button {
                    vote(picked ? nil : key)
                } label: {
                    Text(label).font(picked ? Theme.Typeface.footnoteSemibold : Theme.Typeface.footnote)
                        .foregroundStyle(picked ? Theme.Palette.label : Theme.Palette.secondaryLabel)
                        .frame(maxWidth: .infinity, minHeight: Theme.Size.touch)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(picked ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("这条说得怎么样"))
    }
}

/// 固定的（01 需求文档 5.2 第 7 块）：一条一个月的尺子（哪几天扣、今天在哪）+ 下一笔哪天扣；点了看固定的每一笔
struct MoneyFixedCard: View {
    @Environment(AppModel.self) private var model
    @AppStorage(MoneyHidden.key) private var hide = false
    let page: API.MoneyMonth

    var body: some View {
        let series = page.fixed.series.filter { $0.ended != true }
        let days = MoneyHero.days(in: page.month)
        let today = page.current ? Int(model.today.suffix(2)) ?? 1 : days
        Button {
            model.open("/money/list/\(page.month)?kind=fixed")
        } label: {
            VStack(alignment: .leading, spacing: Theme.Space.small) {
                MoneyCardHeader("每个月固定的 · \(Show.yuan(page.fixed.monthly, hide: hide))")
                // 和「留意的」同一把月尺：扣钱的几天是点、上面写名字，今天一根蓝线
                MoneyMonthRuler(
                    marks: series.map { .init(day: $0.dayOfMonth, name: $0.name, paid: $0.dayOfMonth <= today) },
                    days: days, today: page.current ? today : nil
                )
                .accessibilityHidden(true)
                if let next = page.current
                    ? series.filter({ $0.dayOfMonth > today }).min(by: { $0.dayOfMonth < $1.dayOfMonth }) : nil
                {
                    Text("下一笔：\(next.dayOfMonth)日 \(Show.spaced(next.name)) \(Show.yuan(next.amount, hide: hide))")
                        .font(Theme.Typeface.footnote).monospacedDigit().foregroundStyle(Theme.Palette.secondaryLabel)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .themeCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Text("每个月固定的：\(series.map { "\($0.dayOfMonth)日\($0.name)" }.joined(separator: "，"))；今天是\(today)日"))
    }
}

/// 还在攒的（不到 20 笔、不到 4 周）：每样写清楚什么时候能看，不用进度条
struct MoneyLaterCard: View {
    /// 花在哪、花给了谁：说到 20 笔以后才有
    static let enough = 20
    let page: API.MoneyMonth
    let overview: API.MoneyOverview?
    let findings: API.MoneyFindingsPage?

    var body: some View {
        let rows = lines
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.small) {
                MoneyCardHeader("还在攒的")
                ForEach(rows, id: \.0) { name, when in
                    VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                        Text(name).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                        Text(when).font(Theme.Typeface.footnote).foregroundStyle(
                            Theme.Palette.secondaryLabel)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .themeCard()
        }
    }

    private var lines: [(String, String)] {
        var rows: [(String, String)] = []
        if (1..<Self.enough).contains(page.count) {
            rows.append(("花在哪", "这个月说到 \(Self.enough) 笔以后能看（现在 \(page.count) 笔）"))
        }
        if let overview, overview.who == nil, overview.whoCount < Self.enough {
            rows.append(("花给了谁", "说到 \(Self.enough) 笔以后能看（现在 \(overview.whoCount) 笔）"))
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
