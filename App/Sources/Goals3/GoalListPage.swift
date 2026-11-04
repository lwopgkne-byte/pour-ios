import PourAPI
import PourDesign
import SwiftUI

/// 我的 → 坚持、我的 → 预算（docs/3.0/06-交互细节.md 12.10）：坚持的那几行（同首页，能点、能按住、能左滑）+ 图例；
/// 说过的「不超过」一行一个（子目标下面小字说是哪个大目标的）+「钱的明细在『钱』里 ›」
struct GoalListPage: View {
    enum Kind {
        case streaks, budgets
    }

    @Environment(AppModel.self) private var model
    let kind: Kind
    @State private var home: API.GoalsHome?
    @State private var problem: String?

    var body: some View {
        List {
            if let home {
                Section {
                    if cards(home).isEmpty {
                        Text(kind == .streaks ? "还没有坚持的目标。说一句「每天走 8000 步」就有了。" : "还没有说过「不超过」的目标。")
                            .font(Theme.Typeface.body).foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                    ForEach(cards(home)) { card in
                        Group {
                            if kind == .streaks {
                                StreakRowView(card: card)
                            } else {
                                VStack(alignment: .leading, spacing: Theme.Space.tight) {
                                    GoalRow(card: card)
                                    if let parent = card.parent {
                                        Text("「\(parent)」的子目标").font(Theme.Typeface.footnote)
                                            .foregroundStyle(Theme.Palette.secondaryLabel)
                                    }
                                }
                            }
                        }
                        .goalActions(card, model: model)
                    }
                } header: {
                    Text(kind == .streaks ? "不看连续天数，看最近 30 天做到几天；每天都要做的，每周有 2 次补假" : "你说过的「不超过」：还能花多少、还能几次")
                        .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel).textCase(nil)
                } footer: {
                    if kind == .streaks { DayCellLegend().padding(.top, Theme.Space.small) }
                }
                Section {
                    Button(kind == .streaks ? "全部目标 ›" : "钱的明细在「钱」里 ›") {
                        model.open(kind == .streaks ? "/goals" : "/money")
                    }
                    .accessibilityIdentifier("goals.list.more")
                }
            } else if let problem {
                ErrorState(problem.contains("连") ? .serverOff : .other) { Task { await load() } }
                    .listRowBackground(Color.clear)
            } else {
                ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .task(id: model.dataVersion) { await load() }
    }

    private func cards(_ home: API.GoalsHome) -> [API.GoalCard] {
        kind == .streaks ? home.streaks : (home.budgets ?? [])
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

/// 还没有目标（06 交互细节 12.1 最后）：「说一句你想做到的」大卡 → 从你说过的话里找到的三条（点了直接到理解卡）→
/// 我在乎的点头（对 / 改一下）
struct GoalsEmptyView: View {
    @Environment(AppModel.self) private var model
    let empty: API.GoalsHome.Empty
    let care: [API.CareChip]
    @State private var agreed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Theme.Space.medium) {
                Text("说一句你想做到的").font(Theme.Typeface.section)
                Button {
                    model.goals.sheet = .define(nil)
                } label: {
                    Label("比如：今年想跑 500 公里", systemImage: "mic.fill").font(Theme.Typeface.body)
                        .foregroundStyle(Theme.Palette.tertiaryLabel).frame(
                            maxWidth: .infinity, minHeight: Theme.Size.touch, alignment: .leading
                        )
                        .padding(.horizontal, Theme.Space.medium)
                        .background(
                            Theme.Palette.fill,
                            in: RoundedRectangle(cornerRadius: Theme.Corner.chip, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("goals.empty.say")
            }
            .themeCard(radius: Theme.Corner.smallCard)
            .padding(.top, Theme.Space.small)
            if !empty.suggestions.isEmpty {
                PageSection(title: "从你说过的话里找到的") {
                    VStack(alignment: .leading, spacing: Theme.Space.medium) {
                        ForEach(empty.suggestions, id: \.title) { item in suggestion(item) }
                    }
                }
            }
            PageSection(title: "我在乎的") { careRows }
        }
    }

    private func suggestion(_ item: API.GoalsHome.Suggestion) -> some View {
        HStack(spacing: Theme.Space.medium) {
            VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                Text(item.from).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                Text("要定成「\(item.title)」吗？").font(Theme.Typeface.body).fixedSize(
                    horizontal: false, vertical: true)
            }
            Spacer()
            Button("定这个") { model.goals.sheet = .define(item.title) }
                .font(Theme.Typeface.footnoteSemibold).buttonStyle(.borderless)
        }
    }

    @ViewBuilder private var careRows: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            if agreed || empty.careAgreed {
                Text("好，就这 \(care.count) 个。以后能改名、能删，最多 6 个；没归到哪个的目标放在最后的「其他」。")
                    .font(Theme.Typeface.body).fixedSize(horizontal: false, vertical: true)
            } else {
                Text("你说得最多的是这 \(care.count) 块，就从它们开始？").font(Theme.Typeface.body)
                CareChips(chips: care)
                HStack(spacing: Theme.Space.small) {
                    Button("对") {
                        agreed = true
                        Task { _ = try? await model.client.saveCare(areas: nil, agreed: true) }
                    }
                    .buttonStyle(.borderedProminent)
                    Button("改一下") { model.open("/goals/care/\(care.first?.key ?? "health")") }
                        .buttonStyle(.bordered)
                }
            }
        }
    }
}
