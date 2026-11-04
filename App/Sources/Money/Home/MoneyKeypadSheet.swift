import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 记一笔（01 需求文档 5.4、06 交互细节 3.4）：3 秒记完——点 2、5，点「午饭」，点「记下」。
/// 上面大大的金额；下面「买了什么」可以改；「你常买的」点一下连名字带价钱填好；能报销 · 借给别人 · 是收入 · 给谁；
/// 自己画的数字键盘（每一下轻轻一震）。记下的是一句原话（「午饭 25」），Pour 照常整理
struct MoneyKeypadSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var name = ""
    @State private var who = ""
    @State private var kind = Kind.daily
    @State private var asking = false
    @State private var quick: [API.MoneyQuickItem] = []
    @FocusState private var editing: Field?

    enum Kind: String, CaseIterable {
        case daily, reimburse, lend, income

        var title: String {
            switch self {
            case .daily: "日常"
            case .reimburse: "能报销"
            case .lend: "借给别人"
            case .income: "是收入"
            }
        }
    }

    enum Field { case name, who }

    var body: some View {
        VStack(spacing: Theme.Space.medium) {
            header
            Text("¥\(amount.isEmpty ? "0" : amount)").font(Theme.Typeface.bigNumber).monospacedDigit()
                .foregroundStyle(amount.isEmpty ? Theme.Palette.tertiaryLabel : Theme.Palette.label)
                .contentTransition(.numericText())
                .animation(Theme.Motion.quick, value: amount)
                .accessibilityLabel(Text(amount.isEmpty ? "还没输金额" : "¥\(amount)"))
                .accessibilityIdentifier("keypad.amount")
            fields
            if !quick.isEmpty { quickChips }
            options
            Text("记下的是一句原话「\(text.isEmpty ? "午饭 25" : text)」，Pour 照常整理")
                .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            NumberKeypad { amount = KeypadAmount.apply($0, to: amount) }
            Button(action: save) {
                Text(value > 0 ? "记下 \(Show.yuan(value))" : "记下").font(Theme.Typeface.bodySemibold)
                    .foregroundStyle(value > 0 ? Theme.Palette.onAccent : Theme.Palette.tertiaryLabel)
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.composer)
                    // 照原型：「记下」是钱的颜色
                    .background(
                        value > 0 ? Theme.Quick.moneyButton : Theme.Palette.fill,
                        in: Theme.rounded(Theme.Corner.hubTile))
            }
            .buttonStyle(PressScale())
            .disabled(value <= 0)
            .accessibilityIdentifier("keypad.save")
        }
        .padding(.horizontal, Theme.Space.regular)
        .padding(.bottom, Theme.Space.small)
        .background(Theme.Palette.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task { await loadQuick() }
    }

    private var value: Double { Double(amount) ?? 0 }

    /// 照原型：左边「记一笔」，右上角灰圆的关闭
    private var header: some View {
        LeadingSheetHeader("记一笔") { SheetCloseButton { dismiss() } }
    }

    /// 买了什么（可以不填）；选了「借给别人」或点了「给谁」：写给谁
    private var fields: some View {
        VStack(spacing: Theme.Space.small) {
            TextField(kind == .income ? "什么收入（可以不填）" : "买了什么（可以不填）", text: $name)
                .font(Theme.Typeface.body).focused($editing, equals: .name).submitLabel(.done)
                .padding(.horizontal, Theme.Space.regular).frame(minHeight: Theme.Size.touch)
                .background(Theme.Palette.card, in: Theme.rounded(Theme.Corner.hubTile))
                .accessibilityIdentifier("keypad.name")
            if asking || kind == .lend {
                TextField(kind == .lend ? "借给谁" : "给谁（比如：儿子）", text: $who)
                    .font(Theme.Typeface.body).focused($editing, equals: .who).submitLabel(.done)
                    .padding(.horizontal, Theme.Space.regular).frame(minHeight: Theme.Size.touch)
                    .background(Theme.Palette.card, in: Theme.rounded(Theme.Corner.hubTile))
                    .accessibilityIdentifier("keypad.who")
            }
        }
    }

    /// 你常买的：点一下连名字带价钱一起填好（再点「记下」就完了）
    private var quickChips: some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            Text("你常买的").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            chipRow
        }
    }

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.small) {
                ForEach(quick) { item in
                    FilterChip("\(item.name) \(Show.amount(item.amount))", selected: name == item.name) {
                        name = item.name
                        amount = Show.amount(item.amount)
                    }
                }
            }
        }
        .accessibilityLabel(Text("你常买的"))
    }

    /// 能报销 · 借给别人 · 是收入（三样只能选一样）· 给谁
    private var options: some View {
        HStack(spacing: Theme.Space.small) {
            ForEach([Kind.reimburse, .lend, .income], id: \.self) { option in
                FilterChip(option.title, selected: kind == option) {
                    kind = kind == option ? .daily : option
                }
            }
            if kind != .lend {
                FilterChip(who.isEmpty ? "给谁" : "给\(who)", selected: asking || !who.isEmpty) {
                    asking.toggle()
                    if asking { editing = .who }
                }
            }
        }
    }

    /// 生成的原话：「午饭 25」「打车 58 能报销」「借给小王 500」「工资 18500 收入」「给儿子买鞋 259」
    var text: String {
        guard value > 0 else { return "" }
        let money = Show.amount(value)
        let thing = name.trimmingCharacters(in: .whitespaces)
        let person = who.trimmingCharacters(in: .whitespaces)
        switch kind {
        case .reimburse: return "\(thing.isEmpty ? "" : "\(thing) ")\(money) 能报销"
        case .lend: return "借给\(person.isEmpty ? "别人" : person) \(money)"
        case .income: return "\(thing.isEmpty ? "收入" : thing) \(money)\(thing.isEmpty ? "" : " 收入")"
        case .daily:
            let head = person.isEmpty ? thing : "给\(person)\(thing)"
            return head.isEmpty ? "花了 \(money)" : "\(head) \(money)"
        }
    }

    private func save() {
        guard value > 0 else { return }
        let thing = name.trimmingCharacters(in: .whitespaces)
        let shown =
            switch kind {
            case .lend: "借给\(who.isEmpty ? "别人" : who)"
            case .income: thing.isEmpty ? "收入" : thing
            default: thing.isEmpty ? "记一笔" : thing
            }
        let now = PourDate.localDateTime(Date(), in: .current)
        model.record(
            money: text,
            pending: PendingMoney(
                clientId: UUID().uuidString, name: shown, amount: value, kind: kind.rawValue, day: model.today,
                time: String(now.suffix(5))))
        dismiss()
    }

    private func loadQuick() async {
        if let saved: [API.MoneyQuickItem] = cachedQuick() { quick = saved }
        if let fresh = try? await model.client.moneyQuick() { quick = fresh }
    }

    private func cachedQuick() -> [API.MoneyQuickItem]? {
        struct Page: Decodable { let items: [API.MoneyQuickItem] }
        let page: Page? = model.client.cached("/api/money/quick")
        return page?.items
    }
}
