import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 每一笔（01 需求文档 5.3、06 交互细节 3.6）：系统的搜索框（名目、人、领域、你说的话）；一排筛选胶囊带笔数
/// （全部 · 日常 · 固定 · 收入 · 等报销 · 借出 · 人情 · 回来的）；按天分组，组头吸顶写那天花了多少；
/// 左滑「已报销 / 已还」（对应的才有）「删除」；按住：看原话、改金额、改给谁、不算固定的；点一行打开一笔的详情。
/// 数字键盘刚记下的一笔马上在这里多一行，右边小字「整理中」
struct MoneyEachPage: View {
    @Environment(AppModel.self) private var model
    @AppStorage(MoneyHidden.key) private var hide = false
    let month: String
    let filter: MoneyFilter
    @State private var page: API.MoneyMonth?
    @State private var problem: String?
    @State private var text = ""
    /// 选的那个种类（nil 是全部）；从别处点进来带着的种类、领域先用上
    @State private var kind: String?
    @State private var domain: String?
    @State private var started = false
    @State private var searching = false

    var body: some View {
        List {
            if let page {
                let items = shown(page)
                let pending = pendingShown
                Section {
                    chips(page)
                    Text(summary(page, items)).font(Theme.Typeface.footnote).monospacedDigit()
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                        .listRowInsets(
                            EdgeInsets(top: 0, leading: Theme.Space.regular, bottom: 0, trailing: Theme.Space.regular)
                        )
                        .accessibilityIdentifier("money.each.summary")
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                if items.isEmpty, pending.isEmpty {
                    Text(text.isEmpty ? "\(Show.monthName(page.month))还没说到钱。" : "没有搜到。").font(Theme.Typeface.body)
                        .foregroundStyle(Theme.Palette.secondaryLabel).listRowBackground(Color.clear)
                }
                ForEach(days(items, pending), id: \.self) { day in
                    Section {
                        ForEach(pending.filter { $0.day == day }) { MoneyPendingRow(pending: $0) }
                            .listRowBackground(Theme.Palette.card)
                        ForEach(items.filter { $0.day == day }, id: \.self) { row($0) }
                    } header: {
                        header(day, spent: spent(page, day))
                    }
                }
            } else if let problem {
                ErrorState(problem.contains("连") ? .serverOff : .other) { Task { await load() } }
                    .listRowBackground(Color.clear)
            } else {
                ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(.compact)
        .scrollContentBackground(.hidden)
        .background(Theme.Palette.background)
        // 搜索框放在大标题下面（放底下会被「说一句」挡住）
        .searchable(
            text: $text, isPresented: $searching, placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text("搜：外卖、儿子、动物园……")
        )
        .onChange(of: searching) { _, now in model.pageSearching = now }
        .onDisappear { model.pageSearching = false }
        .refreshable { await load() }
        .task(id: "\(month)-\(model.dataVersion)") { await load() }
        .onAppear {
            guard !started else { return }
            started = true
            kind = filter.kind
            domain = filter.domain
        }
    }

    // MARK: - 筛选

    /// 一排筛选胶囊（带笔数）；从「花在哪」点进来的领域单独一个「只看饮食 ×」
    private func chips(_ page: API.MoneyMonth) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.small) {
                if let domain, let name = page.domains.first(where: { $0.key == domain })?.name {
                    FilterChip("只看\(name) ✕", selected: true) { self.domain = nil }
                        .accessibilityLabel(Text("只看\(name)，点了看全部"))
                }
                ForEach(Self.kinds, id: \.key) { key, title in
                    let count = key.map { count(page, $0) } ?? page.items.count
                    if key == nil || count > 0 {
                        FilterChip(title, count: count, selected: kind == key) { kind = key }
                    }
                }
            }
            .padding(.horizontal, Theme.Space.regular)
            .padding(.vertical, Theme.Space.tight)
        }
        .listRowInsets(EdgeInsets())
    }

    private static let kinds: [(key: String?, title: String)] = [
        (nil, "全部"), ("daily", "日常"), ("fixed", "固定"), ("income", "收入"), ("reimburse", "等报销"),
        ("lend", "借出"), ("renqing", "人情"), ("back", "回来的"),
    ]

    /// 一种几笔（人情是送出的人情 + 收到的）
    private func count(_ page: API.MoneyMonth, _ key: String) -> Int {
        key == "renqing" ? page.items.filter(Self.isRenqing).count : page.items.filter { $0.kind == key }.count
    }

    private static func isRenqing(_ item: API.MoneyItem) -> Bool { item.renqing != nil || item.kind == "gift" }

    private func shown(_ page: API.MoneyMonth) -> [API.MoneyItem] {
        let words = text.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        return page.items.filter { item in
            if let kind, kind == "renqing" ? !Self.isRenqing(item) : item.kind != kind { return false }
            if let domain, item.domain.key != domain || item.kind != "daily" { return false }
            // 名目、人、领域、你说的话（值不值那句）、提到的东西和地方
            let fields = [item.name, item.label, item.who, Show.whoLabel(item), item.domain.name]
            let said = [item.verdict?.quote ?? ""] + (item.people ?? []) + (item.things ?? []) + (item.places ?? [])
            let hay = (fields + said).joined(separator: " ")
                .lowercased()
            return words.allSatisfy { hay.contains($0) }
        }
    }

    /// 刚记下、还在整理的（没在搜、没只看一个领域，种类对得上才列）
    private var pendingShown: [PendingMoney] {
        guard text.isEmpty, domain == nil else { return [] }
        return model.moneyPending.filter { $0.day.hasPrefix(month) && (kind == nil || kind == $0.kind) }
    }

    /// 有钱的日子，新的在前
    private func days(_ items: [API.MoneyItem], _ pending: [PendingMoney]) -> [String] {
        Set(items.map(\.day) + pending.map(\.day)).sorted(by: >)
    }

    /// 「10月日常 81 笔，一共 ¥9,942」；只看一种、一个领域时是这些一共多少；搜的时候是搜到几笔
    private func summary(_ page: API.MoneyMonth, _ items: [API.MoneyItem]) -> String {
        if !text.isEmpty { return "搜到 \(items.count) 笔" }
        guard kind != nil || domain != nil else {
            return "\(Show.monthName(page.month))日常 \(page.count) 笔，一共 \(Show.yuan(page.spent, hide: hide))"
        }
        // 人情有送出去的也有收到的：加在一起没有意思，只写几笔
        let total = (items.map(\.amount).reduce(0, +) * 100).rounded() / 100
        return kind == "renqing" ? "这些 \(items.count) 笔" : "这些 \(items.count) 笔，一共 \(Show.yuan(total, hide: hide))"
    }

    // MARK: - 一天、一行

    /// 那天日常一共花的（和月历一样；搜的、只看一种的时候也写整天的）+ 刚记下还在整理的
    private func spent(_ page: API.MoneyMonth, _ day: String) -> Double {
        let pending = model.moneyPending.filter { $0.day == day && $0.kind == "daily" }.map(\.amount)
        let total = (page.days.first { $0.day == day }?.spent ?? 0) + pending.reduce(0, +)
        return (total * 100).rounded() / 100
    }

    /// 组头（吸顶）：「10月24日 周六 · 花了 ¥1,978」
    private func header(_ day: String, spent: Double) -> some View {
        let relative = Show.daySeparator(day, today: model.today)
        let title = Show.dayTitle(day, today: model.today)
        return HStack(alignment: .firstTextBaseline) {
            Text(relative == title ? title : "\(relative) · \(title)").font(Theme.Typeface.bodySemibold)
                .foregroundStyle(Theme.Palette.label)
            Spacer()
            if spent > 0 {
                Text("花了 \(Show.yuan(spent, hide: hide))").font(Theme.Typeface.footnote).monospacedDigit()
                    .foregroundStyle(Theme.Palette.secondaryLabel)
            }
        }
        .textCase(nil)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func row(_ item: API.MoneyItem) -> some View {
        Button {
            model.openMoney(item)
        } label: {
            MoneyItemRow(item: item).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Theme.Palette.card)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                model.delete(item.entryId)
            } label: {
                Label("删除", systemImage: Theme.Symbol.delete)
            }
            .tint(Theme.Palette.bad)
            if let done = settleTitle(item) {
                Button(done) { settle(item) }.tint(Theme.Palette.accentFill)
            }
        }
        .contextMenu { menu(item) }
        .accessibilityIdentifier("money.item")
    }

    /// 按住：看原话、改金额、改给谁、不算固定的、已报销 / 已还、删除
    @ViewBuilder private func menu(_ item: API.MoneyItem) -> some View {
        Button {
            model.openMoney(item)
        } label: {
            Label("看原话", systemImage: "text.quote")
        }
        Button {
            model.moneyDetail = MoneyDetailRef(item: item, start: .amount)
        } label: {
            Label("改金额", systemImage: "yensign")
        }
        if !["income", "back", "gift"].contains(item.kind) {
            Button {
                model.moneyDetail = MoneyDetailRef(item: item, start: .fact(.forWhom))
            } label: {
                Label("改给谁", systemImage: Theme.Symbol.people)
            }
        }
        if item.kind == "fixed" {
            Button {
                model.endFixed(.init(entryId: item.entryId, index: item.index), ended: true, said: "不再算固定的了")
            } label: {
                Label("不算固定的", systemImage: "pin.slash")
            }
        }
        if let done = settleTitle(item) {
            Button {
                settle(item)
            } label: {
                Label(done, systemImage: Theme.Symbol.done)
            }
        }
        Divider()
        Button(role: .destructive) {
            model.delete(item.entryId)
        } label: {
            Label("删除", systemImage: Theme.Symbol.delete)
        }
    }

    /// 等报销的「已报销」、借出去的「已还」（办过的没有）
    private func settleTitle(_ item: API.MoneyItem) -> String? {
        guard item.settled != true else { return nil }
        switch item.kind {
        case "reimburse": return "已报销"
        case "lend": return "已还"
        default: return nil
        }
    }

    private func settle(_ item: API.MoneyItem) {
        model.settle(
            [.init(entryId: item.entryId, index: item.index)], settled: true,
            said: item.kind == "lend" ? "还回来了：\(item.name)" : "报销了：\(item.name)")
    }

    private func load() async {
        let path = "/api/money/\(month)"
        if page == nil, let saved: API.MoneyMonth = model.client.cached(path) { page = saved }
        do throws(APIError) {
            page = try await model.client.moneyMonth(month)
            problem = nil
        } catch {
            if page == nil { problem = error.message }
        }
    }
}
