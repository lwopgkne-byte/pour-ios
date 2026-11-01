import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 月历（06 交互细节 3.2，产品主人点名要的）：每一格直接写那天日常花了多少（上万写「2万」，没说到钱的不写 0）；
/// 点一天，下面直接换成那天的每一笔（不跳页）；左右滑换月
struct MoneyMonthCalendar: View {
    @Environment(AppModel.self) private var model
    @AppStorage(MoneyHidden.key) private var hide = false
    let page: API.MoneyMonth
    @Binding var picked: String?
    let changeMonth: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            MoneyCardHeader("\(Show.monthName(page.month))每天花的")
            MoneyCalendarGrid(
                blanks: blanks, days: days, today: page.current ? model.today : nil, selected: picked, pick: pick
            )
            .gesture(
                DragGesture(minimumDistance: Theme.Size.touch).onEnded { drag in
                    guard abs(drag.translation.width) > abs(drag.translation.height) * 2 else { return }
                    if drag.translation.width < 0, let next = page.nextMonth { changeMonth(next) }
                    if drag.translation.width > 0, let prev = page.prevMonth { changeMonth(prev) }
                })
            if let picked { dayList(picked) }
        }
        .themeCard()
    }

    /// 点一天：下面换成那天的每一笔；再点一次收起
    private func pick(_ day: String) {
        withAnimation(Theme.Motion.standard) { picked = picked == day ? nil : day }
    }

    /// 「 · 花了 ¥1,978」；那天没说到钱是空的
    private func spentText(_ spent: Double?) -> String {
        spent.map { " · 花了 \(Show.yuan($0, hide: hide))" } ?? ""
    }

    /// 1 号前面空几格（一周从周一算）
    private var blanks: Int { PourDate.weekdayMon0("\(page.month)-01") }

    private var days: [MoneyCalendarGrid.Day] {
        // 刚用数字键盘记下、还在整理的日常的：那一格先加上
        let pending = model.moneyPending.filter { $0.kind == "daily" && $0.day.hasPrefix(page.month) }
        let spent = Dictionary(
            page.days.map { ($0.day, $0.spent) } + pending.map { ($0.day, $0.amount) }, uniquingKeysWith: +)
        let most = max(1, spent.values.max() ?? 1)
        let count = MoneyHero.days(in: page.month)
        return (1...count).map { number in
            let day = String(format: "%@-%02d", page.month, number)
            let amount = spent[day]
            let spoken = amount.map { "\(Show.monthDay(day))，花了 \(Show.yuan($0, hide: hide))" } ?? Show.monthDay(day)
            return MoneyCalendarGrid.Day(
                day: day, number: number, amount: amount.map { Show.calendarAmount($0, hide: hide) },
                weight: (amount ?? 0) / most, spoken: spoken)
        }
    }

    /// 点的那一天：「10月24日 周六 · 花了 ¥1,978」+ 那天的每一笔；那天没说到钱写清楚（没说 ≠ 没花）
    @ViewBuilder private func dayList(_ day: String) -> some View {
        let items = page.items.filter { $0.day == day }
        let spent = page.days.first { $0.day == day }?.spent
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            Button {
                model.open("/money/day/\(day)")
            } label: {
                HStack {
                    Text("\(Show.monthDay(day)) \(Show.weekday(day))\(spentText(spent))")
                        .font(Theme.Typeface.bodySemibold).monospacedDigit().foregroundStyle(Theme.Palette.label)
                    Spacer()
                    Text("那天 ›").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.accent)
                }
                .frame(minHeight: Theme.Size.touch)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("money.pickedDay")
            ForEach(model.moneyPending.filter { $0.day == day }) { MoneyPendingRow(pending: $0) }
            if items.isEmpty, !model.moneyPending.contains(where: { $0.day == day }) {
                Text("那天没说到钱（没说 ≠ 没花）").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    .padding(.bottom, Theme.Space.small)
            }
            ForEach(items, id: \.self) { item in
                Button {
                    model.openMoney(item)
                } label: {
                    MoneyItemRow(item: item).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .transition(.opacity)
    }
}

/// 卡片的标题：左边名字，右边可以有「全部 ›」
struct MoneyCardHeader: View {
    let title: String
    var link: String?
    var open: (() -> Void)?

    init(_ title: String, link: String? = nil, open: (() -> Void)? = nil) {
        self.title = title
        self.link = link
        self.open = open
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let link, let open { ThemeTextButton(link, action: open) }
        }
    }
}
