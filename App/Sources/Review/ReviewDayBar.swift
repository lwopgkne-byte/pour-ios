import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 每日回顾的「一天的样子」（照原型）：一根 12 点高的浅底细条，0:00 到 24:00，有时间的事按类别色铺在上面
/// （前一天晚上开始的睡眠从 0:00 画起，很短的至少画一小截）；下面写 0:00 6:00 12:00 18:00 24:00。
/// 只是看：每件事在下面「做了什么」里能点开；读屏把整条读成一句（按时间列出每件事）
struct ReviewDayBar: View {
    @Environment(AppModel.self) private var model
    @ScaledMetric(relativeTo: .caption2) private var tickRow = Theme.Size.tickRow
    let day: String
    let items: [RibbonItem]

    var body: some View {
        VStack(spacing: Theme.Space.tight) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Palette.fill)
                    ForEach(items) { item in
                        if let place = place(item) {
                            Capsule().fill(color(item))
                                .frame(width: max(Self.least, geometry.size.width * place.width))
                                .offset(x: geometry.size.width * place.start)
                        }
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: Self.height)
            // 刻度画出来（和画布带子的刻度一样）：第三层字只给刻度（≥ 3:1）；读屏整条念一句，不单独念
            Canvas { context, size in
                for (index, tick) in Self.ticks.enumerated() {
                    let place = Double(index) / Double(Self.ticks.count - 1)
                    let anchor: UnitPoint = index == 0 ? .leading : index == Self.ticks.count - 1 ? .trailing : .center
                    let text = Text(verbatim: tick).font(Theme.Typeface.tick).monospacedDigit()
                        .foregroundStyle(Theme.Palette.tertiaryLabel)
                    context.draw(text, at: CGPoint(x: size.width * place, y: size.height / 2), anchor: anchor)
                }
            }
            .frame(height: tickRow)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("一天的样子"))
        .accessibilityValue(Text(RibbonTrack.spoken(items)))
    }

    /// 原型：12 高；很短的事至少 4 宽（看得见一小截）
    private static let height: CGFloat = 12
    private static let least: CGFloat = 4
    private static let ticks = ["0:00", "6:00", "12:00", "18:00", "24:00"]

    /// 在这一天的 0:00–24:00 里从哪到哪（0–1）；整个在这一天外面的不画
    private func place(_ item: RibbonItem) -> (start: Double, width: Double)? {
        guard let span = item.span else { return nil }
        let midnight = "\(day)T00:00"
        let total = Double(24 * 60)
        let start = min(total, max(0, Double(PourDate.minutesBetween(midnight, span.start))))
        let end = min(total, max(0, Double(PourDate.minutesBetween(midnight, span.end))))
        guard start < total, end > 0 || start > 0 else { return nil }
        return (start / total, (end - start) / total)
    }

    private func color(_ item: RibbonItem) -> Color {
        Theme.tag(Show.meta(item.category, model.categories).color).solid.opacity(item.pending ? 0.5 : 1)
    }
}
