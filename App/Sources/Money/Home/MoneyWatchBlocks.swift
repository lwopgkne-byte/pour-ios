import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 每个月固定的（06 交互细节 10.2）：月尺（1 日到月底一条线，扣钱的几天是点、上面写名字，「今天 27 日」一根蓝线）；
/// 下面一行一笔写「几号扣了 / 还有几天」；在扣钱却很久没说到用的那笔有「不再算」（左滑也行）。点一行打开最近扣的那一笔
struct MoneyFixedSection: View {
    @Environment(AppModel.self) private var model
    @AppStorage(MoneyHidden.key) private var hide = false
    let page: API.MoneyWatchPage

    var body: some View {
        let rows = page.fixed.rows
        let days = (28...31).last { PourDate.isValid("\(page.today.prefix(7))-\($0)") } ?? 30
        let today = Int(page.today.suffix(2)) ?? 1
        Section {
            MoneyMonthRuler(
                marks: rows.map { .init(day: $0.dayOfMonth, name: $0.name, paid: $0.paidOn != nil) }, days: days,
                today: today
            )
            .padding(.vertical, Theme.Space.small)
            ForEach(rows, id: \.name) { row($0) }
        } header: {
            MoneySectionHeader("每个月固定的", value: Show.yuan(page.fixed.total, hide: hide))
        } footer: {
            Text("同一样东西隔一个月又扣一次、钱数一样，就认成固定的。不续了说一声，比如「健身卡退了」，就不再算。")
                .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
        }
    }

    private func row(_ row: API.FixedRow) -> some View {
        let stop = {
            model.endFixed(
                .init(entryId: row.lastEntryId, index: row.lastIndex), ended: true, said: "不再算固定的了：\(row.name)")
        }
        return HStack(alignment: .firstTextBaseline, spacing: Theme.Space.medium) {
            Button {
                model.moneyDetail = MoneyDetailRef(item: API.MoneyItem(fixed: row))
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.medium) {
                    Text("\(row.dayOfMonth)日").font(Theme.Typeface.subheadline).monospacedDigit()
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                        .frame(minWidth: Theme.Size.touch - Theme.Space.small, alignment: .leading)
                    VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                        Text(Show.spaced(row.name)).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                        Text(sub(row)).font(Theme.Typeface.footnote)
                            .foregroundStyle(row.unused != nil ? Theme.Palette.warnInk : Theme.Palette.secondaryLabel)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(Show.yuan(row.amount, hide: hide)).font(Theme.Typeface.rowNumber).monospacedDigit()
                        .foregroundStyle(Theme.Palette.label)
                }
                .frame(minHeight: Theme.Size.touch).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            if row.unused != nil { ThemeTextButton("不再算", action: stop).accessibilityIdentifier("watch.stopFixed") }
        }
        .swipeActions(edge: .trailing) {
            Button("不再算", action: stop).tint(Theme.Palette.warn)
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

/// 月尺：1 日到月底一条线；扣钱的那几天一个点（扣过的浅），名字在点上面一高一低错开；今天一根蓝线
struct MoneyMonthRuler: View {
    struct Mark: Hashable {
        let day: Int
        let name: String
        let paid: Bool
    }

    let marks: [Mark]
    let days: Int
    /// 今天几号；看的不是这个月（以前的月份）是 nil，不画「今天」
    let today: Int?

    var body: some View {
        let lineY = Theme.Space.xLarge + Theme.Space.medium
        VStack(spacing: Theme.Space.tight) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let place = { (day: Int) in CGFloat(day - 1) / CGFloat(max(1, days - 1)) * width }
                ZStack(alignment: .topLeading) {
                    Capsule().fill(Theme.Palette.fill).frame(width: width, height: Theme.Space.tight).offset(y: lineY)
                    if let today {
                        // 从线往下，指着下面的「今天 20 日」（名字都在线上面，不会压到）
                        Capsule().fill(Theme.Palette.accent)
                            .frame(width: Theme.Space.hairline * 2, height: Theme.Space.large)
                            .offset(x: place(today) - Theme.Space.hairline, y: lineY)
                    }
                    ForEach(Array(marks.enumerated()), id: \.offset) { index, mark in
                        let size = Theme.Space.small + Theme.Space.tight
                        Circle().fill(mark.paid ? Theme.Palette.tertiaryLabel : Theme.Palette.label)
                            .frame(width: size, height: size)
                            .offset(x: place(mark.day) - size / 2, y: lineY + Theme.Space.tight / 2 - size / 2)
                        let at = place(mark.day)
                        Text(mark.name).font(Theme.Typeface.caption).foregroundStyle(Theme.Palette.secondaryLabel)
                            .fixedSize()
                            .alignmentGuide(.leading) { label in Self.centered(label.width, at: at, width: width) }
                            .offset(y: index % 2 == 1 ? Theme.Space.large - Theme.Space.tight : 0)
                    }
                }
            }
            .frame(height: lineY + Theme.Space.large)
            GeometryReader { proxy in
                let width = proxy.size.width
                let at = CGFloat((today ?? 1) - 1) / CGFloat(max(1, days - 1)) * width
                ZStack(alignment: .topLeading) {
                    Text("1日").frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(days)日").frame(maxWidth: .infinity, alignment: .trailing)
                    if let today, today > 3, today < days - 3 {
                        Text("今天 \(today) 日").font(Theme.Typeface.footnoteSemibold).foregroundStyle(
                            Theme.Palette.accent
                        )
                        .fixedSize()
                        .alignmentGuide(.leading) { label in Self.centered(label.width, at: at, width: width) }
                    }
                }
            }
            .font(Theme.Typeface.caption).monospacedDigit().foregroundStyle(Theme.Palette.secondaryLabel)
            .frame(height: Theme.Space.large)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(
                "一个月里固定的钱在哪几天扣：\(marks.map { "\($0.day)日\($0.name)" }.joined(separator: "，"))"
                    + (today.map { "；今天是\($0)日" } ?? "")))
    }

    /// 一段字放在 at 的正下方；挨着两头的不出界
    /// 只是算数：对齐的闭包不在主线程上也能调
    nonisolated private static func centered(_ label: CGFloat, at: CGFloat, width: CGFloat) -> CGFloat {
        -min(max(0, at - label / 2), max(0, width - label))
    }
}

/// 买了还没用完的（课时、次卡）：一节一个点，说到上过的涂深；「每节 ¥120 · 你说到上过 4 节：哪几天 · 还剩 20 节」
struct MoneyPacksSection: View {
    @Environment(AppModel.self) private var model
    @AppStorage(MoneyHidden.key) private var hide = false
    let packs: [API.PackRow]

    var body: some View {
        Section {
            ForEach(packs, id: \.entryId) { pack in
                Button {
                    model.open("/money/thing/\(pack.entryId)")
                } label: {
                    row(pack).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } header: {
            MoneySectionHeader("买了还没用完的")
        }
    }

    private func row(_ pack: API.PackRow) -> some View {
        let unit = pack.name.contains("课") ? "节" : "次"
        let owner = !pack.who.isEmpty && pack.who != "自己" && pack.who != "一家人" ? "\(pack.who)的" : ""
        let used = pack.used.map(Show.monthDay).joined(separator: "、")
        let each = Show.yuan((pack.amount / Double(max(1, pack.pack))).rounded(), hide: hide)
        let said = "你说到\(unit == "节" ? "上过" : "用了") \(pack.used.count) \(unit)\(used.isEmpty ? "" : "：\(used)")"
        let left = max(0, pack.pack - pack.used.count)
        return VStack(alignment: .leading, spacing: Theme.Space.small) {
            MoneyWatchTitle("\(owner)\(pack.name) · \(pack.pack) \(unit)", amount: Show.yuan(pack.amount, hide: hide))
            PourFlowLayout(spacing: Theme.Space.snug, lineSpacing: Theme.Space.snug) {
                ForEach(0..<pack.pack, id: \.self) { index in
                    Circle().fill(index < pack.used.count ? Theme.Palette.secondaryLabel : Theme.Palette.fill)
                        .frame(width: Theme.Space.medium, height: Theme.Space.medium)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(pack.pack) \(unit)里你说到上过 \(pack.used.count) \(unit)"))
            Text("\(Show.monthDay(pack.day))买的，每\(unit) \(each) · \(said) · 还剩 \(left) \(unit)")
                .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
        }
        .padding(.vertical, Theme.Space.small)
    }
}

/// 常买的：大约多久买一次、最近三次的日子和价钱、按平常下次大约哪天、价钱怎么变
struct MoneyFrequentSection: View {
    @AppStorage(MoneyHidden.key) private var hide = false
    let rows: [API.FrequentRow]
    let today: String

    var body: some View {
        Section {
            ForEach(rows, id: \.name) { row($0) }
        } header: {
            MoneySectionHeader("常买的")
        }
    }

    private func row(_ row: API.FrequentRow) -> some View {
        let every = row.every >= 14 ? "大约 \(Int((Double(row.every) / 7).rounded())) 周买一次" : "大约 \(row.every) 天买一次"
        let next = Show.monthDay(row.next)
        return VStack(alignment: .leading, spacing: Theme.Space.small) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.name).font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                Spacer()
                Text(every).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            }
            HStack(spacing: Theme.Space.small) {
                ForEach(row.recent, id: \.day) { buy in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Show.monthDay(buy.day)).font(Theme.Typeface.caption)
                            .foregroundStyle(Theme.Palette.secondaryLabel)
                        Text(Show.yuan(buy.amount, hide: hide)).font(Theme.Typeface.subheadline)
                            .foregroundStyle(Theme.Palette.label)
                    }
                    .monospacedDigit()
                    .padding(.vertical, Theme.Space.tight).padding(.horizontal, Theme.Space.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Palette.background, in: Theme.rounded(Theme.Corner.tile))
                    .accessibilityElement(children: .combine)
                }
            }
            Text(LocalizedStringKey(row.next >= today ? "按平常，**\(next)前后**又该买了" : "按平常，**\(next)**就该买了"))
                .font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.label)
            if let price = row.price {
                Text(Show.maskYuan(price, hide: hide)).font(Theme.Typeface.footnote)
                    .foregroundStyle(Theme.Palette.secondaryLabel)
            }
        }
        .padding(.vertical, Theme.Space.small)
    }
}
