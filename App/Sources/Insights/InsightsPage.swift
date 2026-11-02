import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 3.0 感悟页（docs/3.0/01-需求文档.md 7.2、06 交互细节 5.1–5.2）：顶上搜索框（关键词 + 按意思，服务器的本地向量）；
/// 今天重温（点了翻过来看原话；收藏、分享、换一句）；一排标签胶囊带条数（全部 · 语录 ★ · 工作……）；按月分组的卡片，
/// 右上角一颗星。点一张 → 一条感悟；按住：收藏 / 取消、分享成图片、看原话、删除。右上角「＋」记一句
struct InsightsPage: View {
    @Environment(AppModel.self) private var model
    @State private var page: API.InsightsPage?
    @State private var problem: String?
    @State private var filter = InsightFilter.all
    @State private var text = ""
    @State private var searching = false
    /// 搜到的（按相关度排）；没在搜是 nil
    @State private var found: [API.InsightItem]?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.cardGap) {
                if let page {
                    if let found { results(found) } else { content(page) }
                } else if let problem {
                    ErrorState(problem.contains("连") ? .serverOff : .other) { Task { await load() } }
                } else {
                    ProgressView().frame(maxWidth: .infinity, minHeight: Theme.Size.goalCard)
                }
            }
            .padding(.horizontal, Theme.Space.screen)
            .padding(.bottom, Theme.Space.xLarge)
        }
        // 搜索框放在大标题下面（放底下会被「说一句」挡住）；在搜时「说一句」让开
        .searchable(
            text: $text, isPresented: $searching, placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text("搜感悟，按意思也能找到")
        )
        .onChange(of: searching) { _, now in model.pageSearching = now }
        .onDisappear { model.pageSearching = false }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.insight.sheet = .add
                } label: {
                    Image(systemName: Theme.Symbol.add).font(Theme.Typeface.toolbarIcon)
                }
                .accessibilityLabel(Text("记一句"))
                .accessibilityIdentifier("insights.add")
            }
        }
        .refreshable { await load() }
        .task(id: model.dataVersion) { await load() }
        .task(id: text) { await search() }
    }

    // MARK: - 第一屏和列表

    @ViewBuilder private func content(_ page: API.InsightsPage) -> some View {
        let all = shown(page)
        InsightsRevisit()
        if all.isEmpty && model.insight.pending.isEmpty {
            EmptyState("还没有感悟。想明白一件事，说一句，或者点右上角的「＋」记一句", example: "记一句") {
                model.insight.sheet = .add
            }
        } else {
            chips(all)
            let items = filter.apply(all)
            if filter.showsPending {
                ForEach(model.insight.pending) { pending in
                    InsightCard(
                        quote: pending.text, date: Show.monthDay(pending.day), tags: [], starred: true, status: "整理中",
                        fresh: true, identifier: "insight.pending", open: {}, star: nil)
                }
            }
            if items.isEmpty {
                Text("这一类还没有。").font(Theme.Typeface.body).foregroundStyle(Theme.Palette.secondaryLabel)
            }
            ForEach(Self.months(items), id: \.month) { group in
                monthHeader(group.month, count: group.items.count)
                ForEach(group.items) { card($0) }
            }
            Text("收藏的会出现在小组件「我的语录」和回顾的「你说过」里 · 全部在你的电脑上")
                .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Theme.Space.small)
        }
    }

    /// 一排标签胶囊（横着滑，带条数）：全部 · 语录 ★ · 按条数多少排的标签；再点一下选中的回到全部
    private func chips(_ all: [API.InsightItem]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.small) {
                FilterChip("全部", count: all.count, selected: filter == .all) { filter = .all }
                FilterChip("语录 ★", count: all.filter(\.isStarred).count, selected: filter == .starred) {
                    filter = filter == .starred ? .all : .starred
                }
                .accessibilityIdentifier("insights.filter.starred")
                ForEach(Self.tagCounts(all), id: \.tag) { tag, count in
                    FilterChip(tag, count: count, selected: filter == .tag(tag)) {
                        filter = filter == .tag(tag) ? .all : .tag(tag)
                    }
                }
            }
            .padding(.horizontal, Theme.Space.screen)
        }
        .padding(.horizontal, -Theme.Space.screen)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("按标签看"))
    }

    private func monthHeader(_ month: String, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(Self.monthTitle(month, today: model.today)).font(Theme.Typeface.section)
                .foregroundStyle(Theme.Palette.label).accessibilityAddTraits(.isHeader)
            Spacer()
            Text("\(count) 条").font(Theme.Typeface.footnote).monospacedDigit()
                .foregroundStyle(Theme.Palette.secondaryLabel)
        }
        .padding(.top, Theme.Space.small)
    }

    /// 一张感悟：点了打开一条感悟，星点了收藏 / 取消；按住出菜单
    private func card(_ item: API.InsightItem) -> some View {
        InsightCard(
            quote: item.quote, date: Show.monthDay(item.day), tags: item.tags, starred: item.isStarred,
            fresh: item.noteId != nil && item.noteId == model.insight.fresh, identifier: "insight.\(item.id)",
            open: { model.insight.sheet = .detail(item) }, star: { model.star(item, !item.isStarred) }
        )
        .contextMenu { InsightMenu(item: item) }
    }

    // MARK: - 搜

    @ViewBuilder private func results(_ items: [API.InsightItem]) -> some View {
        let shown = items.filter { !model.insight.removed.contains($0.id) }.map(model.insight.shown)
        Text(shown.isEmpty ? "没有搜到。换个说法试试，按意思也能找到。" : "搜到 \(shown.count) 句（意思相近的也算）")
            .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            .padding(.top, Theme.Space.small)
        ForEach(shown) { card($0) }
    }

    /// 停下来 0.3 秒再搜；连不上时在手机上存着的单子里按字找
    private func search() async {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            found = nil
            return
        }
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        do throws(APIError) {
            found = try await model.client.insights(query: query).insights
        } catch {
            found = page?.insights.filter { $0.quote.contains(query) || $0.tags.contains(query) }
        }
    }

    // MARK: - 数据

    /// 删掉的不要，改过的、点过星的先用上
    private func shown(_ page: API.InsightsPage) -> [API.InsightItem] {
        page.insights.filter { !model.insight.removed.contains($0.id) }.map(model.insight.shown)
    }

    private func load() async {
        if page == nil, let saved: API.InsightsPage = model.client.cached(APIClient.insightsPath()) { page = saved }
        do throws(APIError) {
            let fresh = try await model.client.insights()
            page = fresh
            model.insight.settle(fresh)
            problem = nil
        } catch {
            if page == nil { problem = error.message }
        }
    }

    /// 标签和条数：多的在前，一样多的照出现的先后
    static func tagCounts(_ items: [API.InsightItem]) -> [(tag: String, count: Int)] {
        var counts: [String: Int] = [:]
        var order: [String] = []
        for tag in items.flatMap(\.tags) {
            if counts[tag] == nil { order.append(tag) }
            counts[tag, default: 0] += 1
        }
        return order.enumerated()
            .sorted { (counts[$0.element] ?? 0, -$0.offset) > (counts[$1.element] ?? 0, -$1.offset) }
            .map { ($0.element, counts[$0.element] ?? 0) }
    }

    /// 按月分组（新的在前，和服务器给的顺序一样）
    static func months(_ items: [API.InsightItem]) -> [(month: String, items: [API.InsightItem])] {
        var out: [(month: String, items: [API.InsightItem])] = []
        for item in items {
            let month = String(item.day.prefix(7))
            if let last = out.indices.last, out[last].month == month {
                out[last].items.append(item)
            } else {
                out.append((month, [item]))
            }
        }
        return out
    }

    /// 「10月」；不是今年的「2025年10月」
    static func monthTitle(_ month: String, today: String) -> String {
        let name = Show.monthName(month)
        return month.prefix(4) == today.prefix(4) ? name : "\(month.prefix(4))年\(name)"
    }
}

/// 感悟页看哪一类：全部、语录 ★、一个标签
enum InsightFilter: Hashable {
    case all
    case starred
    case tag(String)

    /// 刚记下、还在整理的那几句放不放（记一句记的都是语录，没有标签）
    var showsPending: Bool {
        if case .tag = self { false } else { true }
    }

    func apply(_ items: [API.InsightItem]) -> [API.InsightItem] {
        switch self {
        case .all: items
        case .starred: items.filter(\.isStarred)
        case .tag(let tag): items.filter { $0.tags.contains(tag) }
        }
    }
}

/// 按住一张感悟（01 需求文档 7.2）：收藏 / 取消收藏、分享成图片、看原话、删除
struct InsightMenu: View {
    @Environment(AppModel.self) private var model
    let item: API.InsightItem

    var body: some View {
        Button {
            model.star(item, !item.isStarred)
        } label: {
            Label(item.isStarred ? "取消收藏" : "收藏成语录", systemImage: item.isStarred ? "star.slash" : "star")
        }
        Button {
            model.insight.sheet = .share(item)
        } label: {
            Label("分享成图片", systemImage: "square.and.arrow.up")
        }
        if let note = item.noteId {
            Button {
                model.open("/library?note=\(note)")
            } label: {
                Label("看原话", systemImage: "text.quote")
            }
        }
        Button(role: .destructive) {
            model.deleteInsight(item)
        } label: {
            Label("删除", systemImage: Theme.Symbol.delete)
        }
    }
}
