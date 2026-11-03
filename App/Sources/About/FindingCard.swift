import PourAPI
import PourDesign
import SwiftUI

/// 一条发现（「钱和你的日子」「关于我」的新发现，全产品一种画法）：
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
                withAnimation(Theme.Motion.standard) { open = !shown }
            } label: {
                main.padding(.horizontal, Theme.Space.regular).padding(.top, Theme.Space.regular).padding(
                    .bottom, Theme.Space.tight
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityValue(Text(shown ? "展开了" : "收着"))
            if shown { days.padding(.horizontal, Theme.Space.regular).padding(.top, Theme.Space.small) }
            if let vote { votes(vote) }
        }
        .background(RoundedRectangle(cornerRadius: Theme.Corner.chip).fill(Theme.Palette.fill))
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Show.spaced(mask(finding.sentence))).font(Theme.Typeface.section).foregroundStyle(Theme.Palette.label)
                .fixedSize(horizontal: false, vertical: true)
            Grid(alignment: .leading, horizontalSpacing: Theme.Space.small, verticalSpacing: Theme.Space.small) {
                ForEach(finding.bars, id: \.label) { bar in
                    GridRow {
                        Text(bar.label).foregroundStyle(Theme.Palette.secondaryLabel)
                        MoneyBar(share: max(0.02, bar.share), color: color(bar)).frame(
                            minWidth: (Theme.Size.touch + Theme.Space.tight))
                        Text(mask(bar.value)).foregroundStyle(Theme.Palette.secondaryLabel).monospacedDigit()
                            .gridColumnAlignment(.trailing)
                    }
                }
            }
            .font(Theme.Typeface.footnote)
            .padding(.top, Theme.Space.regular)
            Text(Show.spaced(finding.sub)).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                .padding(.top, Theme.Space.small)
        }
    }

    /// 有这个样子的那根：要留意的黄、好事绿；别的日子灰
    private func color(_ bar: API.FindingView.Bar) -> Color {
        bar.strong ? Theme.Palette.status(finding.tone == "good" ? "good" : "warn") : Theme.Palette.separator
    }

    private var days: some View {
        MoneyList {
            if finding.vote == "wrong" {
                Text("是不是哪天记错了？点进那天，能看到你的原话，也能改。").font(Theme.Typeface.footnote).foregroundStyle(
                    Theme.Palette.secondaryLabel
                )
                .padding(.vertical, Theme.Space.small).frame(maxWidth: .infinity, alignment: .leading).moneyRule()
            }
            ForEach(finding.days, id: \.day) { day in
                MoneyLinkRow(minHeight: (Theme.Size.touch + Theme.Space.tight)) {
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
                    Text(label).font(picked ? Theme.Typeface.footnoteSemibold : Theme.Typeface.footnote)
                        .foregroundStyle(picked ? Theme.Palette.label : Theme.Palette.secondaryLabel)
                        .frame(maxWidth: .infinity, minHeight: Theme.Size.touch).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(picked ? .isSelected : [])
            }
        }
        .padding(.horizontal, Theme.Space.tight).padding(.bottom, Theme.Space.tight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("这条说得怎么样"))
    }
}

/// 一根横条：浅灰的底，按几分之几画
struct MoneyBar: View {
    let share: Double
    let color: Color

    var body: some View {
        Capsule().fill(Theme.Palette.fill).frame(height: Theme.Space.small)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule().fill(color).frame(width: proxy.size.width * min(1, max(0, share)))
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }
}
