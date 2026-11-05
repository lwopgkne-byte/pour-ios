import PourAPI
import PourDesign
import SwiftUI

/// 目标的几页：首页、一个目标、坚持、预算、我在乎的一块
struct GoalsRoutePage: View {
    let route: GoalRoute

    var body: some View {
        switch route {
        case .home: GoalsHomePage()
        case .goal(let id): GoalPage(id: id)
        case .streaks: GoalListPage(kind: .streaks)
        case .budgets: GoalListPage(kind: .budgets)
        case .care(let key): CareDomainPage(key: key)
        }
    }
}

/// 3.0 目标首页（docs/3.0/01-需求文档.md 9.2、06 交互细节 12.1；3.0.1 照可交互原型）：这周一句话、每周回顾那一行、我在乎的、
/// 按我在乎的分组的目标——一个目标一张小卡、两列排（GoalBlock：落后要调的占一整行，只有一个目标的两块左右并排）、坚持、
/// 做到的 · 放下的。按住出菜单、左滑暂停（GoalSwipe），都能撤销
struct GoalsHomePage: View {
    @Environment(AppModel.self) private var model
    @State private var home: API.GoalsHome?
    @State private var problem: String?
    @State private var closedOpen = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let home {
                    if let empty = home.empty {
                        GoalsEmptyView(empty: empty, care: home.care)
                    } else {
                        top(home)
                        ForEach(GoalBlock.blocks(home.groups)) { block in blockView(block) }
                        if !home.streaks.isEmpty { streaks(home.streaks) }
                    }
                    closed(home)
                } else if let problem {
                    ErrorState(problem.contains("连") ? .serverOff : .other) { Task { await load() } }
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, Theme.Space.section)
                }
            }
            .padding(.horizontal, Theme.Space.screen)
            .padding(.bottom, Theme.Space.section)
        }
        .background(Theme.Palette.background)
        .environment(
            \.openURL,
            OpenURLAction { url in
                // 一句话里「聊聊怎么调？」：pour://grow/4
                if url.host() == "grow", let id = Int(url.lastPathComponent) { model.goals.sheet = .grow(id) }
                return .handled
            }
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.goals.sheet = .define(nil)
                } label: {
                    Image(systemName: Theme.Symbol.add).font(Theme.Typeface.toolbarIcon)
                }
                .accessibilityLabel(Text("定目标"))
                .accessibilityIdentifier("goals.add")
            }
        }
        .refreshable { await load() }
        .task(id: model.dataVersion) { await load() }
    }

    /// 卡片之间（原型 10）
    private static let gap = Theme.Space.small + Theme.Space.hairline

    // MARK: - 这周一句话、每周回顾、我在乎的

    @ViewBuilder private func top(_ home: API.GoalsHome) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text(summary(home.summary)).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                .lineSpacing(Theme.Leading.body).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("goals.summary")
            if let weekly = home.weekly {
                Button {
                    model.goals.sheet = .weekly
                } label: {
                    Label {
                        Text("\(weekly.text) ›")
                    } icon: {
                        Image(systemName: "calendar")
                    }
                    .font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.accent)
                    .frame(minHeight: Theme.Size.touch, alignment: .leading)
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("goals.weekly")
            }
            Text("我在乎的").font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.secondaryLabel)
                .padding(.top, Theme.Space.tight)
            CareChips(chips: home.care)
        }
        .padding(.horizontal, Theme.Space.tight)
    }

    /// 「这周 7 个目标里 4 个在正轨上；「今年跑 500 公里」落后两周了，聊聊怎么调？」后半句点了进 GROW
    private func summary(_ summary: API.GoalsHome.Summary) -> AttributedString {
        var out = AttributedString(summary.lead)
        guard let id = summary.lagId, let title = summary.lagTitle else {
            out += AttributedString("。")
            return out
        }
        out += AttributedString("；「\(title)」落后两周了，")
        var link = AttributedString("聊聊怎么调？")
        link.link = URL(string: "pour://grow/\(id)")
        link.foregroundColor = Theme.Palette.accent
        out += link
        return out
    }

    // MARK: - 进行中、坚持

    /// 一块：单个、两个单个并排、好几个（两列，占一整行的单独一行）
    @ViewBuilder private func blockView(_ block: GoalBlock) -> some View {
        switch block {
        case .single(let group, let card):
            VStack(alignment: .leading, spacing: Theme.Space.snug) {
                GoalGroupLabel(group: group)
                GoalCardView(card: card, wide: true)
            }
            .padding(.top, Theme.Space.inset)
        case .pair(let left, let leftCard, let right, let rightCard):
            Grid(alignment: .topLeading, horizontalSpacing: Self.gap, verticalSpacing: Theme.Space.snug) {
                GridRow {
                    GoalGroupLabel(group: left)
                    GoalGroupLabel(group: right)
                }
                GridRow {
                    GoalCardView(card: leftCard)
                    GoalCardView(card: rightCard)
                }
            }
            .padding(.top, Theme.Space.inset)
        case .group(let group):
            VStack(alignment: .leading, spacing: Theme.Space.snug) {
                GoalGroupLabel(group: group)
                Grid(alignment: .topLeading, horizontalSpacing: Self.gap, verticalSpacing: Self.gap) {
                    ForEach(Array(GoalBlock.rows(group.cards).enumerated()), id: \.offset) { _, row in
                        GridRow {
                            if row.count == 1, let card = row.first {
                                GoalCardView(card: card, wide: true).gridCellColumns(2)
                            } else {
                                ForEach(row) { card in GoalCardView(card: card) }
                            }
                        }
                    }
                }
            }
            .padding(.top, Theme.Space.inset)
        }
    }

    /// 坚持：小标题和图例，下面一张卡一行一个（按住出菜单、左滑暂停）
    private func streaks(_ cards: [API.GoalCard]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            HStack {
                Text("坚持").font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.secondaryLabel)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                DayCellLegend()
            }
            .padding(.horizontal, Theme.Space.tight)
            VStack(spacing: 0) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    if index > 0 { Divider().padding(.leading, Theme.Space.regular) }
                    StreakRowView(card: card)
                        .padding(.horizontal, Theme.Space.regular).padding(.vertical, Theme.Space.medium)
                        .background(Theme.Palette.card)
                        .contextMenu { GoalMenu(card: card) }
                        .modifier(GoalSwipe(card: card))
                }
            }
            .clipShape(Theme.rounded(Theme.Corner.smallCard))
            .themeEdge(radius: Theme.Corner.smallCard)
        }
        .padding(.top, Theme.Space.inset)
    }

    // MARK: - 做到的 · 放下的

    @ViewBuilder private func closed(_ home: API.GoalsHome) -> some View {
        if !home.done.isEmpty || !home.letgo.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.small) {
                Button {
                    withAnimation(Theme.Motion.standard) { closedOpen.toggle() }
                } label: {
                    HStack(spacing: Theme.Space.tight) {
                        // 能折行（canWrap）：「·」排版时被挤窄，审计按没挤的宽度量、以为字被截了
                        Text("做到的 \(home.done.count) · 放下的 \(home.letgo.count)").font(Theme.Typeface.body)
                            .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("canWrap")
                        Image(systemName: closedOpen ? "chevron.down" : "chevron.right").font(
                            Theme.Typeface.footnoteSemibold)
                    }
                    .foregroundStyle(Theme.Palette.accent)
                    .frame(minHeight: Theme.Size.touch)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("goals.closed")
                if closedOpen {
                    VStack(spacing: Theme.Space.medium) {
                        ForEach(home.done) { card in closedRow(card, done: true) }
                        ForEach(home.letgo) { card in closedRow(card, done: false) }
                    }
                    .themeCard(radius: Theme.Corner.smallCard)
                }
                Text("按住一个目标：改 · 暂停 · 标记完成 · 删除；左滑暂停。删了、暂停、放下都能撤销。")
                    .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Theme.Space.tight)
            .padding(.top, Theme.Space.medium)
        }
    }

    private func closedRow(_ card: API.GoalCard, done: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.medium) {
            Image(systemName: done ? "checkmark" : "flag").font(Theme.Typeface.bodyMedium)
                .foregroundStyle(done ? Theme.Palette.good : Theme.Palette.tertiaryLabel)
            VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                Text(card.title).font(Theme.Typeface.body)
                    .foregroundStyle(done ? Theme.Palette.label : Theme.Palette.secondaryLabel)
                Group {
                    if let why = card.why {
                        let quote = Text("「\(why)」").font(Theme.Typeface.quote)
                        Text("\(card.closed ?? "") · 放下的 · \(quote)")
                    } else {
                        Text(card.closed ?? "")
                    }
                }
                .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            }
            Spacer()
            LinkButton(
                done ? "改回进行中" : "再试试", font: Theme.Typeface.footnoteMedium, identifier: "goal.reopen.\(card.id)"
            ) {
                model.goalAct(card.id, done ? "reopen" : "retry")
            }
        }
    }

    private func load() async {
        if home == nil, let saved: API.GoalsHome = model.client.cached(APIClient.goalsHomePath) { home = saved }
        do throws(APIError) {
            home = try await model.client.goalsHome()
            problem = nil
        } catch {
            if home == nil { problem = error.message }
        }
    }
}

/// 我在乎的：一排小胶囊（4 个一排放得下，多了横着滑），每个一个小环（这块目标的总体）、名字、几个；点进领域页
struct CareChips: View {
    @Environment(AppModel.self) private var model
    let chips: [API.CareChip]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.snug) {
                ForEach(chips) { chip in
                    Button {
                        model.open("/goals/care/\(chip.key)")
                    } label: {
                        HStack(spacing: Theme.Space.snug) {
                            ZStack {
                                GoalRing(
                                    state: chip.ringState, progress: chip.pct, label: "", size: Theme.Size.smallRing - 8
                                )
                                Image(systemName: CareIcon.symbol(chip.icon)).font(Theme.Typeface.glyph)
                                    .foregroundStyle(Theme.careColor(chip.icon))
                            }
                            VStack(alignment: .leading, spacing: 0) {
                                Text(chip.name).font(Theme.Typeface.footnoteSemibold).foregroundStyle(
                                    Theme.Palette.label)
                                Text(chip.count >= 1 ? "\(chip.count) 个" : "还没有").font(Theme.Typeface.tick)
                                    .foregroundStyle(Theme.Palette.secondaryLabel)
                            }
                        }
                        .padding(.vertical, Theme.Space.snug).padding(.leading, Theme.Space.snug)
                        .padding(.trailing, Theme.Space.small)
                        .background(Theme.Palette.card, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("\(chip.name)：\(chip.count >= 1 ? "\(chip.count) 个目标" : "还没有目标")"))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("care.chip.\(chip.key)")
                }
            }
        }
    }
}

extension API.CareChip {
    var ringState: GoalRing.State {
        switch state {
        case "track": .onTrack
        case "behind": .behind
        case "paused": .paused
        default: .notYet
        }
    }
}
