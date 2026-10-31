import PourAPI
import PourDesign
import SwiftUI

/// 3.0「我的」= 全部功能（docs/3.0/01-需求文档.md 2.3、06 交互细节第 7 节、可交互原型「我的」）：画布左上角「我」进来。
/// 从上到下：头（记了几天、几段话，Pour 认识你）→ 四个快捷大按钮 → 常用（管理）→ 五组功能格子 → 设置。
/// 顶上往下拉出搜索框搜功能；长按格子加到常用 / 移出常用；角上的字只在有要你处理的事时才有，不用红色
struct HubPage: View {
    @Environment(AppModel.self) private var model
    @State private var hub: API.HubPage?
    @State private var problem: String?
    /// 常用：先用默认的，拿到服务器的换上（改了先改界面再存，没存上退回来）
    @State private var favorites = HubCatalog.defaultFavorites
    @State private var editing = false
    @State private var query = ""
    @State private var confirmReal = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    header
                    if let problem { problemCard(problem) }
                    quickActions.padding(.top, Theme.Space.regular)
                    favoritesSection
                    ForEach(HubCatalog.groups, id: \.name) { group in
                        groupCard(group.name, tiles: group.tiles).padding(.top, Theme.Space.cardGap)
                    }
                    bottomRows.padding(.top, Theme.Space.cardGap)
                } else {
                    searchResults
                }
            }
            .padding(.horizontal, Theme.Space.screen)
            .padding(.bottom, Theme.Space.section)
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "搜功能，比如：报销")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.open("/settings")
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(Text("设置"))
                .accessibilityIdentifier("hub.settings")
            }
        }
        .task(id: model.dataVersion) { await load() }
        .confirmationDialog("回到真实数据？", isPresented: $confirmReal, titleVisibility: .visible) {
            Button("回到真实数据") { Task { await model.switchData(to: "real") } }
        } message: {
            Text("现在看的是演示数据，你的真实数据没有变化。")
        }
        .sensoryFeedback(Theme.Haptics.select, trigger: editing)
    }

    // MARK: - 头

    private var header: some View {
        HStack(spacing: Theme.Space.inset) {
            MeAvatar(size: Theme.Size.avatar)
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                HStack(spacing: Theme.Space.small) {
                    Text(hub.map { "记了 \($0.days) 天 · \($0.notes) 段话" } ?? "我")
                        .font(Theme.Typeface.subheadline).monospacedDigit()
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                        .contentTransition(.numericText())
                    if model.demo { demoTag }
                }
                Button {
                    model.open("/about")
                } label: {
                    HStack(spacing: Theme.Space.hairline) {
                        Text(knownLine).font(Theme.Typeface.footnoteSemibold)
                        Image(systemName: "chevron.right").font(Theme.Typeface.glyph)
                    }
                    .foregroundStyle(Theme.Palette.accent)
                    .frame(minHeight: Theme.Size.touch)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("hub.known")
            }
            Spacer(minLength: 0)
        }
        .padding(.top, Theme.Space.small)
    }

    /// 「Pour 认识你 12 个人、8 件事」；还没认识谁时「Pour 还在认识你」
    private var knownLine: String {
        guard let known = hub?.known, known.people + known.habits > 0 else { return "Pour 还在认识你" }
        return "Pour 认识你 \(known.people) 个人、\(known.habits) 件事"
    }

    /// 演示数据时名字旁边一个小标签：点了问一句「回到真实数据？」
    private var demoTag: some View {
        Button {
            confirmReal = true
        } label: {
            Text("演示数据").font(Theme.Typeface.caption).foregroundStyle(Theme.Palette.warn)
                .padding(.horizontal, Theme.Space.small).frame(minHeight: Theme.Size.badge)
                .background(Theme.Palette.warn.opacity(0.12), in: Capsule())
                .frame(minHeight: Theme.Size.touch)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("现在看的是演示数据。点一下可以回到真实数据"))
        .accessibilityIdentifier("hub.demo")
    }

    private func problemCard(_ problem: String) -> some View {
        HStack(spacing: Theme.Space.small) {
            Text(Show.spaced(problem)).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            Spacer(minLength: 0)
            Button("再试一次") { Task { await load() } }
                .font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.accent)
                .buttonStyle(.plain).frame(minHeight: Theme.Size.touch)
        }
        .padding(.top, Theme.Space.small)
    }

    // MARK: - 四个快捷大按钮（这一步先接到对话：填好开头，第 2–5 步换成正式的弹层）

    private var quickActions: some View {
        HStack(spacing: 0) {
            quick("记一笔", symbol: "yensign", color: Theme.Quick.money, start: "/记 ")
            quick("记心情", symbol: "face.smiling", color: Theme.Quick.mood, start: "心情：")
            quick("记一句", symbol: "lightbulb.fill", color: Theme.Quick.idea, start: "记一句：")
            quick("加待办", symbol: "plus", color: Theme.Quick.todo, start: "待办：")
        }
        .padding(.vertical, Theme.Space.regular)
        .themeCard(padding: 0)
    }

    private func quick(_ title: String, symbol: String, color: Color, start: String) -> some View {
        Button {
            model.startSaying(start)
        } label: {
            QuickActionLabel(title, symbol: symbol, color: color)
        }
        .buttonStyle(PressScale())
        .accessibilityIdentifier("hub.quick.\(title)")
    }

    // MARK: - 常用

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            HStack {
                Text("常用").font(Theme.Typeface.section).foregroundStyle(Theme.Palette.label)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(editing ? "完成" : "管理") {
                    withAnimation(Theme.Motion.standard) { editing.toggle() }
                }
                .font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.accent)
                .buttonStyle(.plain).frame(minHeight: Theme.Size.touch)
                .accessibilityIdentifier("hub.manage")
            }
            grid(
                favorites.compactMap { HubCatalog.tiles[$0] }.map { HubCell.tile($0, inFavorites: true) }
                    + (editing && favorites.count < HubCatalog.maxFavorites ? [.empty] : [])
            )
            .padding(.vertical, Theme.Space.regular)
            .themeCard(padding: 0)
            if editing {
                Text("点 − 拿出来，在下面点 + 放进去；最多 \(HubCatalog.maxFavorites) 个")
                    .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    .padding(.horizontal, Theme.Space.small)
            }
        }
        .padding(.top, Theme.Space.xLarge)
    }

    private var emptySlot: some View {
        VStack(spacing: Theme.Space.small) {
            Image(systemName: "plus").font(Theme.Typeface.section).foregroundStyle(Theme.Palette.tertiaryLabel)
                .frame(width: Theme.Size.hubIcon, height: Theme.Size.hubIcon)
                .overlay(
                    Theme.rounded(Theme.Corner.hubTile)
                        .strokeBorder(Theme.Palette.tertiaryLabel, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
            Text("空位").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.tertiaryLabel)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("空位：在下面点加号放进来"))
    }

    // MARK: - 全部功能

    private func groupCard(_ name: String, tiles: [String]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(name).font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.secondaryLabel)
                .padding(.leading, Theme.Space.regular).padding(.top, Theme.Space.inset)
                .accessibilityAddTraits(.isHeader)
            grid(tiles.compactMap { HubCatalog.tiles[$0] }.map { .tile($0, inFavorites: favorites.contains($0.id)) })
                .padding(.top, Theme.Space.inset).padding(.bottom, Theme.Space.regular)
        }
        .themeCard(padding: 0)
    }

    /// 一行 4 个（一共才二十几个格子：不用懒加载，读屏、找格子都一下子全在）；最后一行不满的空着
    private func grid(_ cells: [HubCell]) -> some View {
        Grid(horizontalSpacing: 0, verticalSpacing: Theme.Space.large) {
            ForEach(Array(stride(from: 0, to: cells.count, by: 4)), id: \.self) { start in
                GridRow {
                    ForEach(cells[start..<min(start + 4, cells.count)], id: \.self) { cell in
                        switch cell {
                        case .tile(let tile, let inFavorites): tileButton(tile, inFavorites: inFavorites)
                        case .empty: emptySlot.frame(maxWidth: .infinity)
                        }
                    }
                    ForEach(0..<(4 - min(4, cells.count - start)), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                    }
                }
            }
        }
    }

    /// 一个格子：平常点了推入那一页；管理常用时点了拿出来、放进去（常用里是 −，下面不在常用里的是 +）
    private func tileButton(_ tile: HubTile, inFavorites: Bool) -> some View {
        Button {
            if editing {
                toggle(tile.id)
            } else {
                openTile(tile)
            }
        } label: {
            HubTileView(
                tile: tile, badge: editing ? nil : badge(tile.id), mark: editing ? !inFavorites : nil)
        }
        .buttonStyle(PressScale())
        .contextMenu {
            Button(inFavorites ? "移出常用" : "加到常用", systemImage: inFavorites ? "minus.circle" : "plus.circle") {
                toggle(tile.id)
            }
            .disabled(!inFavorites && favorites.count >= HubCatalog.maxFavorites)
        }
        .accessibilityIdentifier("hub.tile.\(tile.id)")
    }

    private func badge(_ key: String) -> String? {
        hub?.badges.first { $0.tile == key }?.text
    }

    private func openTile(_ tile: HubTile) {
        if tile.id == "calendar" {
            model.pickDay()
        } else {
            model.open(tile.path(today: model.today))
        }
    }
}

extension HubPage {
    // MARK: - 最下面

    private var bottomRows: some View {
        Button {
            model.open("/settings")
        } label: {
            HStack(spacing: Theme.Space.medium) {
                Image(systemName: "gearshape.fill").font(Theme.Typeface.body)
                    .foregroundStyle(Theme.Palette.secondaryLabel).frame(width: Theme.Size.tile)
                Text("设置").font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(Theme.Typeface.glyph)
                    .foregroundStyle(Theme.Palette.tertiaryLabel)
            }
            .padding(.horizontal, Theme.Space.regular)
            .frame(minHeight: Theme.Size.touch + Theme.Space.small)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .themeCard(padding: 0)
        .accessibilityIdentifier("hub.row.settings")
    }

    // MARK: - 搜功能

    @ViewBuilder private var searchResults: some View {
        let found = HubCatalog.search(query)
        if found.isEmpty {
            Text("没有找到「\(query)」。可以搜功能的名字，比如：报销、红包、步数")
                .font(Theme.Typeface.body).foregroundStyle(Theme.Palette.secondaryLabel)
                .padding(.top, Theme.Space.xLarge)
        } else {
            grid(found.map { .tile($0, inFavorites: favorites.contains($0.id)) })
                .padding(.vertical, Theme.Space.regular)
                .themeCard(padding: 0)
                .padding(.top, Theme.Space.regular)
        }
    }

    // MARK: - 数据

    private func load() async {
        // 先用上次存的画出来（不转圈），再去拿新的
        if hub == nil, let saved: API.HubPage = model.client.cached("/api/me/hub") {
            hub = saved
            if !editing { favorites = saved.favorites.filter { HubCatalog.tiles[$0] != nil } }
        }
        do {
            let page = try await model.client.hub()
            hub = page
            problem = nil
            if !editing { favorites = page.favorites.filter { HubCatalog.tiles[$0] != nil } }
        } catch {
            problem = error.readable
        }
    }

    /// 拿出来、放进去：先改界面再存；没存上退回来、说一句
    private func toggle(_ key: String) {
        let before = favorites
        if let index = favorites.firstIndex(of: key) {
            favorites.remove(at: index)
        } else if favorites.count < HubCatalog.maxFavorites {
            favorites.append(key)
        } else {
            model.toast("常用最多 \(HubCatalog.maxFavorites) 个，先拿出来一个")
            return
        }
        // 先改界面再存（写操作队列）：没网时排在手机上，连上了自动存；服务器不收就退回去
        model.write(
            "PUT", "/api/me/hub/favorites", json: .object(["favorites": .array(favorites.map(JSONValue.string))])
        ) {
            favorites = before
        }
    }
}

/// 格子那一格：一个功能，或者管理常用时的空位
private enum HubCell: Hashable {
    case tile(HubTile, inFavorites: Bool)
    case empty
}

/// 一个格子的样子：图标（角上的字、管理时的 −、+）+ 名字（最多 4 个字，一行）
private struct HubTileView: View {
    let tile: HubTile
    let badge: String?
    /// nil：没在管理；true：点了放进去（+）；false：点了拿出来（−）
    let mark: Bool?

    var body: some View {
        VStack(spacing: Theme.Space.small) {
            HubTileIcon(symbol: tile.symbol, color: tile.color)
                .overlay(alignment: .topTrailing) {
                    if let badge { HubBadge(badge).offset(x: Theme.Space.small, y: -Theme.Space.snug) }
                }
                .overlay(alignment: .topLeading) {
                    if let mark { HubMark(adding: mark).offset(x: -Theme.Space.small, y: -Theme.Space.small) }
                }
                .hubJiggle(mark != nil)
            Text(tile.name).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.label).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(.isButton)
    }

    private var label: String {
        switch mark {
        case true?: "\(tile.name)，放进常用"
        case false?: "\(tile.name)，从常用拿出来"
        case nil: badge.map { "\(tile.name)，\($0)" } ?? tile.name
        }
    }
}
