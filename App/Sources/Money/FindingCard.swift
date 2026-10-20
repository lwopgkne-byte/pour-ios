import PourAPI
import PourDesign
import SwiftUI

/// 一条发现（网页版 components/finding/FindingCard.tsx：「钱和你的日子」「关于我」的新发现，全产品一种画法）：
/// 一句话、两根横条、依据；整张卡能点，点开是那几天，再点进那天。
/// 下面一排安静的文字按钮，点了的深一点，再点一次撤销；点「不对」问一句是不是哪天记错了，顺手把那几天打开
struct FindingCard: View {
    let finding: API.FindingView
    var mask: (String) -> String = { $0 }
    let openDay: (String) -> Void
    var vote: ((String?) -> Void)?
    @State private var open = false

    private static let votes = [("right", "说中了"), ("known", "早知道"), ("boring", "没意思"), ("wrong", "不对")]

    var body: some View {
        let shown = open || finding.vote == "wrong"
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(Web.fast) { open = !shown }
            } label: {
                main.padding(.horizontal, Web.space4).padding(.top, Web.space4).padding(.bottom, Web.space1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(WebPressStyle(radius: Web.radiusPanel))
            .accessibilityElement(children: .combine)
            .accessibilityValue(Text(shown ? "展开了" : "收着"))
            if shown { days.padding(.horizontal, Web.space4).padding(.top, Web.space2) }
            if let vote { votes(vote) }
        }
        .background(RoundedRectangle(cornerRadius: Web.radiusPanel).fill(Web.bgSubtle))
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Show.spaced(mask(finding.sentence))).font(Web.sectionSemibold).foregroundStyle(Web.fg)
                .fixedSize(horizontal: false, vertical: true)
            Grid(alignment: .leading, horizontalSpacing: Web.space2, verticalSpacing: Web.space2) {
                ForEach(finding.bars, id: \.label) { bar in
                    GridRow {
                        Text(bar.label).foregroundStyle(Web.fgSecondary)
                        MoneyBar(share: max(0.02, bar.share), color: color(bar)).frame(minWidth: Web.space12)
                        Text(mask(bar.value)).foregroundStyle(Web.fgSecondary).monospacedDigit()
                            .gridColumnAlignment(.trailing)
                    }
                }
            }
            .font(Web.caption)
            .padding(.top, Web.space4)
            Text(Show.spaced(finding.sub)).font(Web.caption).foregroundStyle(Web.fgTertiary).padding(.top, Web.space2)
        }
    }

    /// 有这个样子的那根：要留意的黄、好事绿；别的日子灰
    private func color(_ bar: API.FindingView.Bar) -> Color {
        bar.strong ? Web.status(finding.tone == "good" ? "good" : "warn") : Web.lineStrong
    }

    private var days: some View {
        MoneyList {
            if finding.vote == "wrong" {
                Text("是不是哪天记错了？点进那天，能看到你的原话，也能改。").font(Web.caption).foregroundStyle(Web.fgSecondary)
                    .padding(.vertical, Web.space2).frame(maxWidth: .infinity, alignment: .leading).moneyRule()
            }
            ForEach(finding.days, id: \.day) { day in
                MoneyLinkRow(minHeight: Web.space12) {
                    openDay(day.day)
                } label: {
                    MoneyMainSub(
                        main: Text("\(Show.monthDay(day.day)) \(Show.weekday(day.day))"),
                        sub: day.text.isEmpty ? nil : mask(day.text))
                }
            }
        }
    }

    private func votes(_ vote: @escaping (String?) -> Void) -> some View {
        HStack(spacing: 0) {
            ForEach(Self.votes, id: \.0) { key, label in
                let picked = finding.vote == key
                Button {
                    vote(picked ? nil : key)
                } label: {
                    Text(label).font(picked ? Web.captionMedium : Web.caption)
                        .foregroundStyle(picked ? Web.fg : Web.fgSecondary)
                        .frame(maxWidth: .infinity, minHeight: Web.touch).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(picked ? .isSelected : [])
            }
        }
        .padding(.horizontal, Web.space1).padding(.bottom, Web.space1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("这条说得怎么样"))
    }
}
