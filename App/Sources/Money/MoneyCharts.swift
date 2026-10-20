import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 月历（docs/prd-money.md 5.4）：日期在上，金色的圆在下，面积是那天日常花的；
/// 没说到钱的那天不画（没说 ≠ 没花）；今天一圈细框；整周都在今天以后（或开始记以前）的几行变矮。
/// 比例尺：这个月最多的一天画最大的圆；刚开始用的时候按 ¥600 一天来比
struct MoneyCalendar: View {
    @AppStorage(MoneyHidden.key) private var hide = false
    let month: String
    let days: [API.MoneySpentDay]
    let today: String
    let started: String?
    let early: Bool
    let open: (String) -> Void

    private struct Cell: Hashable {
        let day: String
        let number: Int
    }

    var body: some View {
        let spent = Dictionary(days.map { ($0.day, $0.spent) }, uniquingKeysWith: +)
        let most = max(early ? 600 : 0, days.map(\.spent).max() ?? 0)
        Grid(horizontalSpacing: Web.space1, verticalSpacing: Web.space1) {
            GridRow {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) {
                    Text($0).font(Web.caption).foregroundStyle(Web.fgTertiary).frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                let short = row.allSatisfy { cell in cell.map { faint($0.day) } ?? true }
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        if let cell {
                            dayCell(cell, spent: spent[cell.day], most: most, short: short)
                        } else {
                            Color.clear.frame(height: short ? Web.space8 : Web.space12 + Web.space2)
                        }
                    }
                }
            }
        }
    }

    /// 前面空出这个月 1 号之前的格子，后面补满一行
    private var rows: [[Cell?]] {
        let first = "\(month)-01"
        let last = (28...31).last { PourDate.isValid("\(month)-\($0)") } ?? 30
        var cells: [Cell?] = Array(repeating: nil, count: PourDate.weekdayMon0(first))
        for number in 1...last {
            cells.append(Cell(day: "\(month)-\(number < 10 ? "0" : "")\(number)", number: number))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    /// 今天以后、开始记以前：字很浅
    private func faint(_ day: String) -> Bool { day > today || started.map { day < $0 } == true }

    @ViewBuilder private func dayCell(_ cell: Cell, spent: Double?, most: Double, short: Bool) -> some View {
        let isToday = cell.day == today
        let height = short ? Web.space8 : Web.space12 + Web.space2
        if let spent, spent > 0 {
            // 圆的面积是钱：直径按平方根算，最大 30 点，最小 8 点
            let coin = Web.space2 + (Web.space6 - Web.space1 / 2) * sqrt(spent / max(most, 1))
            Button {
                open(cell.day)
            } label: {
                VStack(spacing: 0) {
                    number(cell, color: Web.fg, today: isToday)
                    Circle().fill(Web.tag("yellow").solid).frame(width: coin, height: coin)
                        .frame(maxHeight: .infinity)
                }
                .padding(.top, Web.space1)
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .top)
                .overlay(border(isToday))
                .contentShape(Rectangle())
            }
            .buttonStyle(WebPressStyle(radius: Web.radiusControl))
            .accessibilityLabel(
                Text(
                    "\(Show.monthDay(cell.day)) \(Show.weekday(cell.day))\(isToday ? "（今天）" : "")"
                        + (hide ? "" : "，花了 \(Show.yuan(spent))")))
        } else {
            number(cell, color: faint(cell.day) ? Web.lineStrong : Web.fgTertiary, today: isToday)
                .padding(.top, Web.space1)
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .top)
                .overlay(border(isToday))
                .accessibilityLabel(Text("\(Show.monthDay(cell.day))\(isToday ? "（今天）" : "")，没说到钱"))
        }
    }

    private func number(_ cell: Cell, color: Color, today: Bool) -> some View {
        Text("\(cell.number)").font(today ? Web.captionMedium : Web.caption).foregroundStyle(today ? Web.fg : color)
            .monospacedDigit()
    }

    @ViewBuilder private func border(_ today: Bool) -> some View {
        if today { RoundedRectangle(cornerRadius: Web.radiusControl).strokeBorder(Web.lineStrong, lineWidth: 1) }
    }
}

/// 花在哪（docs/prd-money.md 5.6）：方块图，面积是钱。最多的两块在上面一行，接着三块一行，
/// 其余合成一条「还有」。颜色是生活领域自己的颜色
struct MoneyMosaic: View {
    @AppStorage(MoneyHidden.key) private var hide = false
    let domains: [API.MoneyDomain]
    let open: (String) -> Void

    var body: some View {
        let top = Array(domains.prefix(2))
        let mid = Array(domains.dropFirst(2).prefix(3))
        let rest = Array(domains.dropFirst(5))
        VStack(spacing: Web.space1) {
            GrowRow(weights: top.map(\.amount)) { ForEach(top, id: \.key) { tile($0, big: true) } }
                .frame(height: Web.space16 * 2 + Web.space6 + Web.space1)
            if !mid.isEmpty {
                GrowRow(weights: mid.map(\.amount)) { ForEach(mid, id: \.key) { tile($0, big: false) } }
                    .frame(height: Web.space16 + Web.space2)
            }
            if !rest.isEmpty {
                HStack(spacing: Web.space2) {
                    Text("还有：\(rest.map(\.name).joined(separator: "、"))").frame(
                        maxWidth: .infinity, alignment: .leading)
                    Text(Show.yuan((rest.reduce(0) { $0 + $1.amount } * 100).rounded() / 100, hide: hide))
                        .monospacedDigit()
                }
                .font(Web.caption).foregroundStyle(Web.tag("gray").fg)
                .padding(.horizontal, Web.space3).frame(minHeight: Web.touch)
                .background(RoundedRectangle(cornerRadius: Web.radiusCard).fill(Web.tag("gray").bg))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func tile(_ domain: API.MoneyDomain, big: Bool) -> some View {
        let tag = Web.tag(domain.color)
        return Button {
            open(domain.key)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text(Show.yuan(domain.amount, hide: hide)).font(big ? Web.title : Web.sectionBold).monospacedDigit()
                Text(domain.name).font(big ? Web.bodySemibold : Web.captionMedium)
            }
            .lineLimit(1).fixedSize()
            .foregroundStyle(tag.fg)
            .padding(.horizontal, Web.space3).padding(.vertical, big ? Web.space3 : Web.space2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .background(RoundedRectangle(cornerRadius: Web.radiusCard).fill(tag.bg))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(domain.name) \(Show.yuan(domain.amount, hide: hide))，看是哪几笔"))
    }
}

/// 一行几块，宽窄按分量分，但再小也放得下自己的字
struct GrowRow: Layout {
    let weights: [Double]
    var spacing = Web.space1

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let widths = Self.widths(
            mins: subviews.map { $0.sizeThatFits(.unspecified).width }, weights: weights,
            space: bounds.width - spacing * CGFloat(max(0, subviews.count - 1)))
        var left = bounds.minX
        for (index, view) in subviews.enumerated() {
            view.place(
                at: CGPoint(x: left, y: bounds.minY),
                proposal: ProposedViewSize(width: widths[index], height: bounds.height))
            left += widths[index] + spacing
        }
    }

    /// 先按分量分；分到的比自己的字还窄的，就给它字那么宽，剩下的再按分量分给别的
    static func widths(mins: [CGFloat], weights: [Double], space: CGFloat) -> [CGFloat] {
        var fixed: [Int: CGFloat] = [:]
        while true {
            let free = space - fixed.values.reduce(0, +)
            let total = weights.indices.filter { fixed[$0] == nil }.reduce(0) { $0 + max(weights[$1], 0.0001) }
            let out = weights.indices.map { fixed[$0] ?? free * CGFloat(max(weights[$0], 0.0001) / total) }
            guard let short = out.indices.first(where: { fixed[$0] == nil && out[$0] < mins[$0] }) else { return out }
            fixed[short] = mins[short]
        }
    }
}
