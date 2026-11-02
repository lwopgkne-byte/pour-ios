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

/// 3.0 目标首页（docs/3.0/01-需求文档.md 9.2、06 交互细节 12.1）：这周一句话、每周回顾那一行、我在乎的、
/// 按我在乎的分组的目标（一行一个：系统的左滑只认一整行）、坚持、做到的 · 放下的。按住出菜单、左滑暂停，都能撤销
struct GoalsHomePage: View {
    @Environment(AppModel.self) private var model
    @State private var home: API.GoalsHome?
    @State private var problem: String?
    @State private var closedOpen = false

    var body: some View {
        List {
            if let home {
                if let empty = home.empty {
                    GoalsEmptyView(empty: empty, care: home.care)
                } else {
                    top(home)
                    ForEach(home.groups, id: \.name) { group in groupSection(group) }
                    if !home.streaks.isEmpty { streaks(home.streaks) }
                }
                closed(home)
            } else if let problem {
                ErrorState(problem.contains("连") ? .serverOff : .other) { Task { await load() } }
                    .listRowBackground(Color.clear)
            } else {
                ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        // 组和组之间、组名上下留得少：iPhone 15 第一屏要看得到 5 个目标（01 需求文档 9.14 第 6 条）
        .listSectionSpacing(Theme.Space.small)
        .environment(\.defaultMinListHeaderHeight, 0)
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

    /// 一行上下留得少一点：第一屏要放得下 5 个目标（01 需求文档 9.14 第 6 条）
    static let rowInsets = EdgeInsets(
        top: Theme.Space.small, leading: Theme.Space.regular, bottom: Theme.Space.small, trailing: Theme.Space.regular)
    /// 组名：上面留一点、下面紧挨着卡片
    static let headerInsets = EdgeInsets(
        top: Theme.Space.small, leading: Theme.Space.regular, bottom: Theme.Space.tight, trailing: Theme.Space.regular)

    // MARK: - 这周一句话、每周回顾、我在乎的

    @ViewBuilder private func top(_ home: API.GoalsHome) -> some View {
        Section {
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
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: Theme.Space.tight, bottom: 0, trailing: Theme.Space.tight))
        }
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

    private func groupSection(_ group: API.GoalGroup) -> some View {
        Section {
            ForEach(group.cards) { card in
                GoalRow(card: card).goalActions(card, model: model).listRowInsets(Self.rowInsets)
            }
        } header: {
            Label(group.name, systemImage: CareIcon.symbol(group.icon)).font(Theme.Typeface.footnoteSemibold)
                .foregroundStyle(Theme.Palette.secondaryLabel)
                .listRowInsets(Self.headerInsets)
        }
    }

    private func streaks(_ cards: [API.GoalCard]) -> some View {
        Section {
            ForEach(cards) { card in
                StreakRowView(card: card).goalActions(card, model: model).listRowInsets(Self.rowInsets)
            }
        } header: {
            HStack {
                Text("坚持").font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.secondaryLabel)
                Spacer()
                DayCellLegend()
            }
            .listRowInsets(Self.headerInsets)
        }
    }

    // MARK: - 做到的 · 放下的

    @ViewBuilder private func closed(_ home: API.GoalsHome) -> some View {
        if !home.done.isEmpty || !home.letgo.isEmpty {
            Section {
                Button {
                    withAnimation(Theme.Motion.standard) { closedOpen.toggle() }
                } label: {
                    HStack {
                        // 能折行（canWrap）：「·」排版时被挤窄，审计按没挤的宽度量、以为字被截了
                        Text("做到的 \(home.done.count) · 放下的 \(home.letgo.count)").font(Theme.Typeface.body)
                            .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("canWrap")
                        Spacer()
                        Image(systemName: closedOpen ? "chevron.down" : "chevron.right").font(
                            Theme.Typeface.footnoteSemibold)
                    }
                    .foregroundStyle(Theme.Palette.accent)
                }
                .accessibilityIdentifier("goals.closed")
                if closedOpen {
                    ForEach(home.done) { card in closedRow(card, done: true) }
                    ForEach(home.letgo) { card in closedRow(card, done: false) }
                }
            } footer: {
                Text("按住一个目标：改 · 暂停 · 标记完成 · 删除；左滑暂停。删了、暂停、放下都能撤销。")
                    .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            }
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
                        Text("\(card.closed ?? "") · 放下的 · ") + Text("「\(why)」").font(Theme.Typeface.quote)
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
                                Image(systemName: CareIcon.symbol(chip.icon)).font(Theme.Typeface.tick)
                                    .foregroundStyle(Theme.Palette.secondaryLabel)
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
