import PourAPI
import PourCore
import PourDesign
import SwiftUI

extension MoneyDetailSheet {
    // MARK: - 补充、改

    /// 补充 / 改一样：值不值点「值」「后悔」再写一句；别的直接写（几个用顿号隔开）
    func editor(_ fact: MoneyFact) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text(value(of: fact) == nil ? "补充\(fact.title)" : "改\(fact.title)").font(Theme.Typeface.subheadline)
                .foregroundStyle(Theme.Palette.secondaryLabel)
            if fact == .verdict {
                HStack(spacing: Theme.Space.small) {
                    FilterChip("值", selected: false) { saveVerdict("good") }
                    FilterChip("后悔", selected: false) { saveVerdict("regret") }
                }
                TextField("你怎么说的（可以不写）", text: $draft).font(Theme.Typeface.body)
            } else {
                HStack(spacing: Theme.Space.small) {
                    TextField(placeholder(fact), text: $draft).font(Theme.Typeface.body).focused($focused)
                        .submitLabel(.done).onSubmit { save(fact) }
                        .accessibilityIdentifier("moneyDetail.edit")
                    ThemeTextButton("好") { save(fact) }
                }
            }
        }
        .padding(Theme.Space.regular)
        .themeCard(padding: 0)
    }

    private func placeholder(_ fact: MoneyFact) -> String {
        switch fact {
        case .places: "在哪（比如：楼下超市）"
        case .forWhom: "给谁（比如：儿子）"
        case .people: "和谁（几个用顿号隔开）"
        case .from: "谁给的"
        default: ""
        }
    }

    private func save(_ fact: MoneyFact) {
        let words = draft.split(whereSeparator: { "、，, ".contains($0) }).map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        editing = nil
        switch fact {
        case .places: model.update(item.entryId, ["places": .array(words.map(JSONValue.string))])
        case .people: model.update(item.entryId, ["people": .array(words.map(JSONValue.string))])
        case .forWhom: saveMetric { $0.forWhom = words.first }
        case .from: saveMetric { $0.from = words.first }
        default: break
        }
    }

    private func saveVerdict(_ tone: String) {
        let said = draft.trimmingCharacters(in: .whitespaces)
        editing = nil
        model.update(
            item.entryId,
            [
                "verdict": .object([
                    "tone": .string(tone), "quote": .string(said.isEmpty ? (tone == "good" ? "值" : "后悔") : said),
                ])
            ])
    }

    /// 改这一笔钱（给谁、谁给的）：整件事的每一样钱照旧发回去，只换这一样
    func saveMetric(_ change: (inout API.Metric) -> Void) {
        guard var metrics = event?.metrics, item.index < metrics.count else { return }
        change(&metrics[item.index])
        model.update(item.entryId, ["metrics": .array(metrics.map { $0.json(value: $0.value) })])
    }

    // MARK: - 改金额

    /// 大金额：点一下就能改（改的是说的那个数；有回来的钱照旧扣掉）
    @ViewBuilder var amountRow: some View {
        let plus = ["income", "back", "gift"].contains(item.kind)
        if amountDraft != nil {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.small) {
                Text("¥").font(Theme.Typeface.section).foregroundStyle(Theme.Palette.secondaryLabel)
                // 不用 Binding($amountDraft)：改完变回 nil 时它会强行解开，闪退
                TextField("金额", text: amountText)
                    .font(Theme.Typeface.bigNumber).monospacedDigit().keyboardType(.decimalPad).focused($amountFocused)
                    .accessibilityIdentifier("moneyDetail.amountField")
                ThemeTextButton("好") { saveAmount() }.accessibilityIdentifier("moneyDetail.amountSave")
            }
        } else {
            Button(action: startAmount) {
                Text(Show.yuan(amount, hide: hide, plus: plus)).font(Theme.Typeface.bigNumber).monospacedDigit()
                    .foregroundStyle(Theme.Palette.label).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("点了改金额"))
            .accessibilityIdentifier("moneyDetail.amount")
        }
    }

    private var amountText: Binding<String> {
        Binding(get: { amountDraft ?? "" }, set: { amountDraft = $0 })
    }

    /// 现在的金额：拿到整条记录以后用记录里的（改了马上看得到）
    private var amount: Double {
        guard let metric else { return item.amount }
        return (max(0, metric.value - (metric.returned?.amount ?? 0)) * 100).rounded() / 100
    }

    private func startAmount() {
        editing = nil
        amountDraft = Show.amount(metric?.value ?? item.amount)
        amountFocused = true
    }

    private func saveAmount() {
        let value = Double(amountDraft ?? "") ?? 0
        amountDraft = nil
        guard value > 0, value != metric?.value else { return }
        saveMetric { $0.value = (value * 100).rounded() / 100 }
    }

    /// 每一笔长按「改金额」「改给谁」打开的：等弹层出来再进到那一样
    func begin() async {
        guard let start = ref.start else { return }
        try? await Task.sleep(for: .milliseconds(450))
        switch start {
        case .amount: startAmount()
        case .fact(let fact): self.start(fact)
        }
    }

    // MARK: - 原话

    func quote(_ source: API.Source) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            QuoteBlock(source.text, highlight: item.name, lineLimit: 4)
            Button {
                dismiss()
                model.openLink("/library?note=\(source.noteId)")
            } label: {
                Text("\(TodoBoard.saidAt(source.createdAt) ?? Show.monthDay(item.day)) 你说的 · 在笔记库看 ›")
                    .font(Theme.Typeface.footnote).monospacedDigit().foregroundStyle(Theme.Palette.accent)
                    .frame(minHeight: Theme.Size.touch).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 对应的按钮

    @ViewBuilder var buttons: some View {
        let ref = API.MoneyRef(entryId: item.entryId, index: item.index)
        let settled = (metric?.settled ?? item.settled) == true
        let flag = metric?.flag ?? item.flag
        VStack(spacing: Theme.Space.small) {
            if flag == "reimburse" || item.kind == "reimburse" {
                action(settled ? "已报销 · 改为还没报" : "标记为已报销", id: "moneyDetail.reimbursed") {
                    model.settle([ref], settled: !settled, said: settled ? nil : "报销了：\(item.name)")
                }
            }
            if flag == "lend" || item.kind == "lend" {
                action(settled ? "已还 · 改为还没还" : "已经还了", id: "moneyDetail.repaid") {
                    model.settle([ref], settled: !settled, said: settled ? nil : "还回来了：\(item.name)")
                }
            }
            if !(event?.things ?? item.things ?? []).isEmpty, ["daily", "fixed"].contains(item.kind) {
                action("用了几次、每次多少钱 ›", id: "moneyDetail.thing") {
                    dismiss()
                    model.open("/money/thing/\(item.entryId)")
                }
            }
        }
    }

    private func action(_ title: String, id: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Text(title).font(Theme.Typeface.bodyMedium).foregroundStyle(Theme.Palette.accent)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.touch)
                .background(Theme.Palette.card, in: Theme.rounded(Theme.Corner.hubTile))
        }
        .buttonStyle(PressScale())
        .accessibilityIdentifier(id)
    }

    // MARK: - 人情、固定的

    /// 人情（「结婚 · 你送的」）；没说是人情是 nil
    var renqingLine: String? {
        guard let renqing = event?.renqing else { return nil }
        let what =
            renqing.treat == true
            ? (renqing.dir == "out" ? "你请的" : "请你的") : (renqing.dir == "out" ? "你送的" : "收到的")
        return renqing.occasion == "请客" || renqing.occasion == "其他" ? what : "\(renqing.occasion) · \(what)"
    }

    /// 人情：什么事、和 TA 的来往 ›、不算人情
    func renqingRow(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            factRowPlain("人情", text)
            HStack(spacing: Theme.Space.small) {
                if let person = counterpart {
                    ThemeTextButton("和\(person)的来往 ›") {
                        dismiss()
                        model.open("/money/renqing/\(person)")
                    }
                }
                ThemeTextButton("不算人情") { model.update(item.entryId, ["renqing": .null]) }
            }
        }
    }

    /// 来往的那个人：给谁、谁给的、和谁（家里人不算）
    private var counterpart: String? {
        let names = [metric?.forWhom, metric?.from].compactMap { $0 } + (event?.people ?? [])
        return names.first { name in
            !name.isEmpty && name.wholeMatch(of: /我|自己|一家人|全家|家里|老婆|老公|儿子|女儿|孩子|爸爸?|妈妈?|爸妈|父母/) == nil
        }
    }

    /// 每个月固定扣的：几号
    var fixedDay: Int? {
        item.kind == "fixed" ? Int(item.day.suffix(2)) : nil
    }

    /// 固定的 · 每个月几日 · 不再算固定的（再点一次改回来）
    func fixedRow(_ day: Int) -> some View {
        let ended = metric?.ended == true
        return HStack(alignment: .firstTextBaseline, spacing: Theme.Space.medium) {
            Text("固定的").font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
                .frame(minWidth: Theme.Size.touch + Theme.Space.regular, alignment: .leading)
            Text("每个月 \(day) 日").font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
            Spacer()
            ThemeTextButton(ended ? "已不再算 · 改回来" : "不再算固定的") {
                model.endFixed(
                    .init(entryId: item.entryId, index: item.index), ended: !ended, said: ended ? nil : "不再算固定的了")
            }
            .accessibilityIdentifier("moneyDetail.fixed")
        }
        .frame(minHeight: Theme.Size.touch)
    }

    private func factRowPlain(_ title: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.medium) {
            Text(title).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
                .frame(minWidth: Theme.Size.touch + Theme.Space.regular, alignment: .leading)
            Text(Show.spaced(text)).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
        }
        .frame(minHeight: Theme.Size.touch)
    }

    // MARK: - 数据

    func load() async {
        if entry == nil, model.shownDay == item.day,
            let found = model.day?.entries.first(where: { $0.id == item.entryId })
        {
            entry = found
        }
        if let view = try? await model.client.day(item.day) {
            entry = view.entries.first { $0.id == item.entryId }
        }
    }
}
