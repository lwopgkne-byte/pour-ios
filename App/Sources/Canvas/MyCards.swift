import PourAPI
import PourDesign
import SwiftUI

/// 我的卡片（docs/模块/产品优化.md R3）：说一句就建的（「加一张卡，看这个月喝了几杯咖啡」），放在推进的目标后面。
/// 里面的数、清单、小图都是服务器按这一天现算的，手机只管画；卡片底下一行写怎么查的。
/// 长按：改名字…、放到最前、不要了（轻提示上能撤销）
struct MyCards: View {
    @Environment(AppModel.self) private var model
    let day: String
    let cards: [API.CardView]
    @State private var renaming: API.CardView?
    @State private var newTitle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            SectionHeader(title: "我的卡片", trailing: "\(cards.count) 张")
            VStack(spacing: Theme.Space.medium) {
                ForEach(cards) { card in
                    MyCard(card: card, day: day)
                        .contextMenu {
                            Button("改名字…", systemImage: "pencil") {
                                newTitle = card.title
                                renaming = card
                            }
                            if card.id != cards.first?.id {
                                Button("放到最前", systemImage: "arrow.up.to.line") { model.moveCardFirst(card.id) }
                            }
                            Button("不要了", systemImage: "trash", role: .destructive) { model.deleteCard(card) }
                        }
                }
            }
        }
        .alert(
            "改名字", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } }),
            presenting: renaming
        ) { card in
            TextField("卡片的名字", text: $newTitle)
            Button("改") { model.renameCard(card.id, to: newTitle) }
            Button("取消", role: .cancel) {}
        }
    }
}

/// 一张卡：标题；一个数、一张清单或一张小图；还没说到时写一句怎么说才会有；底下一行怎么查的
private struct MyCard: View {
    @Environment(AppModel.self) private var model
    let card: API.CardView
    let day: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            HStack(spacing: Theme.Space.small) {
                IconTile(symbol: symbol, emoji: "🗂", color: Theme.tag("blue"))
                Text(Show.spaced(card.title)).font(Theme.Typeface.cardTitle).foregroundStyle(Theme.Palette.label)
                Spacer(minLength: 0)
            }
            if card.empty {
                Text(Show.spaced(card.hint ?? "说到相关的事就会出现在这里")).font(Theme.Typeface.subheadline)
                    .foregroundStyle(Theme.Palette.secondaryLabel)
            } else {
                content
            }
            // 怎么查的：次要色（三级色的小字对比度不够，审计 2026-10-26）
            Text(Show.spaced(card.basis)).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themeCard(padding: Theme.Space.regular)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mycard.\(card.id)")
    }

    private var symbol: String {
        switch card.show {
        case "list": "list.bullet"
        case "chart": "chart.bar"
        default: "number"
        }
    }

    @ViewBuilder private var content: some View {
        switch card.show {
        case "list": list
        case "chart":
            VStack(alignment: .leading, spacing: Theme.Space.small) {
                if let value = card.value { figure(value) }
                MiniBars(bars: card.bars ?? [])
            }
        default:
            if let value = card.value { figure(value) }
        }
    }

    private func figure(_ value: String) -> some View {
        let figure = CanvasPlan.figure(value)
        return FigureText(figure.parts.map { ($0.number, $0.unit) }, prefix: figure.prefix)
            .accessibilityLabel(Text(Show.spaced(value)))
    }

    /// 清单：最近的在前，点一行看那条记录
    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array((card.items ?? []).enumerated()), id: \.offset) { index, item in
                if index > 0 { Divider() }
                Button {
                    model.openEntry(item.entryId, day: item.day)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Space.small) {
                        // 能折行（没有 lineLimit），不会被截成「…」：审计量书名号量不准时按这个记号放过（AppAudit）
                        Text(Show.spaced(item.text)).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                            .accessibilityIdentifier("canWrap")
                        Spacer(minLength: Theme.Space.small)
                        Text(Show.dayTitle(item.day, today: model.today)).font(Theme.Typeface.footnote)
                            .foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                    .frame(minHeight: Theme.Size.touch)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressScale())
                // 一行一个按钮给读屏（「《人类简史》，10月20日 周二」），和画布上别的行一样
                .accessibilityElement(children: .combine)
            }
            if let more = card.more, more > 0 {
                Text("还有 \(more) 个").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    .padding(.top, Theme.Space.small)
            }
        }
    }
}

/// 小图：一根根细的圆角柱（按天、周或月），最高的那根顶满、从 0 起算；最近的一根实色，别的浅一点。
/// 两头写第一根和最后一根是哪段。读屏只念上面那个总数
private struct MiniBars: View {
    @ScaledMetric(relativeTo: .caption2) private var tickRow = Theme.Size.tickRow
    let bars: [API.CardView.Bar]

    var body: some View {
        let top = max(bars.map(\.value).max() ?? 0, 1)
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(bars.enumerated()), id: \.offset) { index, bar in
                    let latest = index == bars.count - 1
                    UnevenRoundedRectangle(topLeadingRadius: Theme.Space.tight, topTrailingRadius: Theme.Space.tight)
                        .fill(Theme.Palette.accent.opacity(bar.value <= 0 ? 0.12 : latest ? 1 : 0.4))
                        .frame(
                            width: Theme.Space.medium,
                            height: max(Theme.Space.hairline * 2, chartHeight * bar.value / top)
                        )
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: chartHeight, alignment: .bottom)
            .overlay(alignment: .bottom) { Theme.Palette.separator.frame(height: Theme.Space.hairline) }
            // 两头写第一根、最后一根是哪段：画出来（和一天的时间的刻度一样），次要色；读屏只念上面的总数
            if let first = bars.first, let last = bars.last {
                Canvas { context, size in
                    let left = context.resolve(
                        Text(verbatim: first.label).font(Theme.Typeface.tick).foregroundStyle(
                            Theme.Palette.secondaryLabel))
                    let right = context.resolve(
                        Text(verbatim: last.label).font(Theme.Typeface.tick).foregroundStyle(
                            Theme.Palette.secondaryLabel))
                    context.draw(left, at: CGPoint(x: 0, y: size.height / 2), anchor: .leading)
                    context.draw(right, at: CGPoint(x: size.width, y: size.height / 2), anchor: .trailing)
                }
                .frame(height: tickRow)
            }
        }
        .accessibilityHidden(true)
    }

    /// 柱子区的高：一天的时间那条带子的一倍半
    private var chartHeight: CGFloat { Theme.Size.ribbon * 1.5 }
}
