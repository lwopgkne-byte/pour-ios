import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 每个月固定的（网页版 MoneyWatchPage 的 Fixed）：一条一个月的尺子（哪几天扣、今天在哪；已经扣过的浅一档，
/// 名字一高一低错开），下面一样一行。点一行打开最近扣的那一笔，详情里可以「不再算固定的」
struct FixedSection: View {
    @Environment(AppModel.self) private var model
    @AppStorage(MoneyHidden.key) private var hide = false
    let page: API.MoneyWatchPage

    var body: some View {
        let rows = page.fixed.rows
        let days = (28...31).last { PourDate.isValid("\(page.today.prefix(7))-\($0)") } ?? 30
        let today = Int(page.today.suffix(2)) ?? 1
        let marks = rows.map { "\($0.dayOfMonth)日\($0.name)" }.joined(separator: "，")
        ReviewSection(title: "每个月固定的 · \(Show.yuan(page.fixed.total, hide: hide))") {
            FixedRuler(rows: rows, days: days, today: today)
                .padding(.horizontal, Web.space3).padding(.top, Web.space2)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("一个月里固定的钱在哪几天扣：\(marks)；今天是\(today)日"))
            HStack {
                Text("1日")
                Spacer()
                Text("今天 \(today)日").font(Web.captionMedium).foregroundStyle(Web.fg)
                Spacer()
                Text("\(days)日")
            }
            .font(Web.caption).foregroundStyle(Web.fgTertiary).monospacedDigit()
            .padding(.top, -Web.space2)
            .accessibilityHidden(true)
            MoneyList {
                ForEach(rows, id: \.name) { row in
                    Button {
                        model.openEntry(
                            row.lastEntryId, day: row.lastDay,
                            fixed: FixedPay(dayOfMonth: row.dayOfMonth, index: row.lastIndex))
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: Web.space2) {
                            Text("\(row.dayOfMonth)日").font(Web.bodySemibold).foregroundStyle(Web.fgSecondary)
                                .monospacedDigit()
                                .fixedSize().frame(minWidth: Web.space8 + Web.space2, alignment: .leading)
                            MoneyMainSub(main: Text(Show.spaced(row.name)), sub: sub(row))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(Show.yuan(row.amount, hide: hide)).font(Web.bodySemibold).foregroundStyle(Web.fg)
                                .monospacedDigit()
                        }
                        .padding(.vertical, Web.space3)
                        .frame(minHeight: Web.space12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(WebPressStyle(radius: 0))
                    .moneyRule()
                    .accessibilityElement(children: .combine)
                }
            }
            Text("同一样东西隔一个月又扣一次、钱数一样，就认成固定的。不续了说一声，比如「健身卡退了」，就不再算。")
                .font(Web.caption).foregroundStyle(Web.fgTertiary)
        }
    }

    /// 一行下面那句：这个月扣了、还有几天、在扣钱却没说到用它
    private func sub(_ row: API.FixedRow) -> String {
        if row.unused != nil { return Show.unusedText(row) }
        if let paid = row.paidOn { return "\(Show.monthDay(paid))扣了" }
        if row.dueIn == 0 { return "今天扣" }
        if let due = row.dueIn { return "还有 \(due) 天" }
        return "这个月还没说到扣"
    }
}

/// 一个月的尺子：灰线是整个月，深一点的是已经过去的；每一样在扣钱那天一个金色的圆（钱越多越大，扣过的浅），
/// 名字在上面一高一低错开
private struct FixedRuler: View {
    let rows: [API.FixedRow]
    let days: Int
    let today: Int

    var body: some View {
        let most = max(rows.map(\.amount).max() ?? 1, 1)
        let lineY = Web.space12 + Web.space1
        GeometryReader { proxy in
            let width = proxy.size.width
            let place = { (day: Int) in CGFloat(day - 1) / CGFloat(max(1, days - 1)) * width }
            ZStack(alignment: .topLeading) {
                Capsule().fill(Web.lineStrong).frame(width: width, height: Web.space1).offset(y: lineY)
                Capsule().fill(Web.fgTertiary).frame(width: place(today), height: Web.space1).offset(y: lineY)
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    let size = Web.space2 + Web.space3 * sqrt(row.amount / most)
                    let yellow = Web.tag("yellow").solid
                    Circle().fill(row.paidOn == nil ? yellow : yellow.opacity(0.42))
                        .frame(width: size, height: size)
                        .offset(x: place(row.dayOfMonth) - size / 2, y: lineY + Web.space1 / 2 - size / 2)
                    Text(row.name).font(Web.caption).foregroundStyle(Web.fgSecondary).fixedSize()
                        .alignmentGuide(.leading) { label in
                            let at = place(row.dayOfMonth)
                            if row.dayOfMonth <= 3 { return -at }
                            if row.dayOfMonth >= days - 2 { return label.width - at }
                            return label.width / 2 - at
                        }
                        .offset(y: index % 2 == 1 ? Web.space6 - Web.space1 : 0)
                }
            }
        }
        .frame(height: Web.space16 + Web.space1)
    }
}
