import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 打开的那一笔钱（钱的主页、每一笔、一天的钱点一行）
struct MoneyDetailRef: Identifiable, Hashable {
    /// 打开就改的那一样（每一笔长按「改金额」「改给谁」）
    enum Start: Hashable { case amount, fact(MoneyFact) }

    let item: API.MoneyItem
    var start: Start?
    var id: String { "\(item.entryId)-\(item.index)" }
}

/// 一笔的详情（01 需求文档 5.5、06 交互细节 3.5）：顶上领域图标、名字、大金额、种类标签；一段话里好几样先写合计、再一样一行；
/// **只列有的**（地方、时间、给谁、和谁、你说的值不值、回来的钱、谁给的、人情、固定的），没说的不写「没说」，缺的放进「补充」；
/// 点大金额就能改；原话和说的时刻；对应的按钮（已报销 · 已经还了 · 不再算固定的 · 用了几次）；删除带撤销。改了马上生效（交给服务器改）
struct MoneyDetailSheet: View {
    @Environment(AppModel.self) var model
    @Environment(\.dismiss) var dismiss
    @AppStorage(MoneyHidden.key) var hide = false
    let ref: MoneyDetailRef
    @State var entry: API.Entry?
    /// 正在补充 / 改的那一样
    @State var editing: MoneyFact?
    @State var draft = ""
    @FocusState var focused: Bool
    /// 正在改的金额（nil 是没在改）
    @State var amountDraft: String?
    @FocusState var amountFocused: Bool

    var item: API.MoneyItem { ref.item }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader("") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.regular) {
                    head
                    if let event, moneyMetrics(event).count > 1 { pieces(event) }
                    facts
                    if !missing.isEmpty { supplement }
                    if let editing { editor(editing) }
                    if let source = entry?.sources.first { quote(source) }
                    buttons
                    Button(role: .destructive) {
                        dismiss()
                        model.delete(item.entryId)
                    } label: {
                        Text("删除这一笔").font(Theme.Typeface.body).foregroundStyle(Theme.Palette.bad)
                            .frame(maxWidth: .infinity, minHeight: Theme.Size.touch).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("moneyDetail.delete")
                }
                .padding(.horizontal, Theme.Space.regular)
                .padding(.bottom, Theme.Space.xLarge)
            }
        }
        .background(Theme.Palette.background)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task(id: model.dataVersion) { await load() }
        .task { await begin() }
    }

    var event: API.EventData? {
        if case .event(let data) = entry?.data { return data }
        return nil
    }

    var metric: API.Metric? {
        guard let metrics = event?.metrics, item.index < metrics.count else { return nil }
        return metrics[item.index]
    }

    // MARK: - 顶上：图标、名字、标签、大金额

    private var head: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            HStack(spacing: Theme.Space.medium) {
                MoneyDomainIcon(domain: item.domain)
                Text(Show.spaced(item.name)).font(Theme.Typeface.section).foregroundStyle(Theme.Palette.label)
                    .accessibilityAddTraits(.isHeader)
            }
            amountRow
            HStack(spacing: Theme.Space.snug) {
                ForEach(tags, id: \.self) { MoneyKindTagView($0) }
                Text(item.domain.name).font(Theme.Typeface.caption).foregroundStyle(Theme.Palette.secondaryLabel)
                    .padding(.horizontal, Theme.Space.snug).padding(.vertical, Theme.Space.hairline)
                    .background(Theme.Palette.fill, in: Capsule())
            }
        }
    }

    private var tags: [MoneyKindTag] {
        switch item.kind {
        case "reimburse": [.reimburse]
        case "lend": [.lend]
        case "fixed": [.fixed]
        case "income": [.income]
        case "back": [.returned]
        case "gift": [.renqing]
        default: item.renqing != nil ? [.renqing] : []
        }
    }

    /// 这件事里的每一样钱
    private func moneyMetrics(_ event: API.EventData) -> [API.Metric] {
        (event.metrics ?? []).filter { $0.unit == "元" }
    }

    /// 一段话里好几样（超市买了洗衣液、面包、葡萄……）：先是合计，下面一样一行
    private func pieces(_ event: API.EventData) -> some View {
        let all = moneyMetrics(event)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("这段话一共").font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
                Spacer()
                Text(Show.yuan(all.map(\.value).reduce(0, +), hide: hide)).font(Theme.Typeface.rowNumber)
                    .monospacedDigit()
            }
            .frame(minHeight: Theme.Size.touch)
            ForEach(Array(all.enumerated()), id: \.offset) { _, piece in
                HStack {
                    Text(piece.item ?? piece.name).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                    Spacer()
                    Text(Show.yuan(piece.value, hide: hide)).font(Theme.Typeface.subheadline).monospacedDigit()
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                }
                .frame(minHeight: Theme.Size.touch)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, Theme.Space.regular)
        .themeCard(padding: 0)
    }

    // MARK: - 只列有的

    @ViewBuilder private var facts: some View {
        let rows = MoneyFact.allCases.compactMap { fact in value(of: fact).map { (fact, $0) } }
        if !rows.isEmpty || renqingLine != nil || fixedDay != nil {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(rows, id: \.0) { fact, text in
                    factRow(fact.title, text, edit: fact == .time ? nil : { start(fact) })
                }
                if let returned = metric?.returned {
                    let actual = max(0, ((item.amount + returned.amount) * 100).rounded() / 100)
                    factRow("回来的钱", "\(Show.returnedNote(returned)) · 实际花 \(Show.yuan(item.amount, hide: hide))")
                        .accessibilityHint(Text("原来是 \(Show.yuan(actual, hide: hide))"))
                }
                if let renqing = renqingLine { renqingRow(renqing) }
                if let day = fixedDay { fixedRow(day) }
            }
            .padding(.horizontal, Theme.Space.regular)
            .themeCard(padding: 0)
        }
    }

    func factRow(_ title: String, _ text: String, edit: (() -> Void)? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.medium) {
            Text(title).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
                .frame(minWidth: Theme.Size.touch + Theme.Space.regular, alignment: .leading)
            Text(Show.spaced(text)).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let edit { ThemeTextButton("改", action: edit) }
        }
        .frame(minHeight: Theme.Size.touch)
        .accessibilityElement(children: .combine)
    }

    /// 这一样有没有、写什么（没有是 nil：不列出来，放进「补充」）
    func value(of fact: MoneyFact) -> String? {
        // 先用这一笔钱自带的（服务器算好的），拿到整条记录以后用记录里的（改了马上看得到）
        let joined = { (words: [String]?) -> String? in
            guard let words, !words.isEmpty else { return nil }
            return words.joined(separator: "、")
        }
        switch fact {
        case .places: return joined(event?.places ?? item.places)
        case .time: return item.time.map { "\(Show.monthDay(item.day)) \($0)" }
        case .forWhom:
            guard item.kind != "gift" else { return nil }
            let who = metric?.forWhom ?? (item.who == "自己" ? nil : item.who)
            return who.flatMap { $0.isEmpty ? nil : $0 }
        case .people: return joined(event?.people ?? item.people)
        case .verdict: return (event?.verdict ?? item.verdict).map { "「\($0.quote)」\($0.tone == "good" ? "值" : "后悔")" }
        case .from:
            guard item.kind == "gift" else { return nil }
            let from = metric?.from ?? item.who
            return from.isEmpty ? nil : from
        }
    }

    /// 补充：缺什么点什么（「+ 和谁 · + 给谁 · + 值不值 · + 地方」）
    private var missing: [MoneyFact] {
        [.people, .forWhom, .verdict, .places].filter { fact in
            value(of: fact) == nil && (fact != .forWhom || !["income", "back", "gift"].contains(item.kind))
        }
    }

    private var supplement: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text("补充").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            PourFlowLayout(spacing: Theme.Space.small, lineSpacing: Theme.Space.small) {
                ForEach(missing, id: \.self) { fact in
                    FilterChip("＋ \(fact.title)", selected: editing == fact) { start(fact) }
                }
            }
        }
    }

    func start(_ fact: MoneyFact) {
        amountDraft = nil
        editing = fact
        draft =
            value(of: fact).map { text in
                fact == .verdict ? (event?.verdict?.quote ?? "") : text
            } ?? ""
        focused = fact != .verdict
    }
}

/// 一笔钱的一样（只列有的、补充的）
enum MoneyFact: CaseIterable, Hashable {
    case time, places, forWhom, people, from, verdict

    var title: String {
        switch self {
        case .time: "时间"
        case .places: "地方"
        case .forWhom: "给谁"
        case .people: "和谁"
        case .from: "谁给的"
        case .verdict: "值不值"
        }
    }
}
