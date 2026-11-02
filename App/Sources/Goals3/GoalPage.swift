import PourAPI
import PourDesign
import SwiftUI

/// 3.0 一个目标（docs/3.0/01-需求文档.md 9.3、9.4，06 交互细节 12.3、12.4）：头（大环、大数、一句状态、预测、一排数）→
/// 在等你回答 → 成习惯了 → 三句话 → 子目标 → 图 → 里程碑 → 补假 → 什么时候最容易做到 → 最近推进它的 → 每个月 →
/// 推进的日子和心情 → 设置 → 暂停 / 完成 / 删除。不同种类只给用得着的块；都不弹确认框，轻提示带撤销
struct GoalPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let id: Int
    @State private var page: API.GoalPage?
    @State private var months: [API.SubPeriod] = []
    @State private var problem: String?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.cardGap) {
                    if let page {
                        content(page)
                    } else if let problem {
                        ErrorState(problem.contains("连") ? .serverOff : .other) { Task { await load() } }
                    } else {
                        ProgressView().frame(maxWidth: .infinity, minHeight: Theme.Size.goalCard)
                    }
                }
                .padding(.horizontal, Theme.Space.screen)
                .padding(.bottom, Theme.Space.xLarge)
            }
            .onChange(of: page != nil) { _, loaded in
                guard loaded, model.goals.editing == id else { return }
                model.goals.editing = nil
                withAnimation(Theme.Motion.standard) { proxy.scrollTo("settings", anchor: .top) }
            }
        }
        .navigationTitle(page?.card.title ?? "目标")
        .refreshable { await load() }
        .task(id: model.dataVersion) { await load() }
    }

    @ViewBuilder private func content(_ page: API.GoalPage) -> some View {
        Text(page.sub).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            .fixedSize(horizontal: false, vertical: true)
        if page.card.paused { pausedBanner(page.card) }
        GoalHead(page: page)
        if let ask = page.ask { GoalAskCard(goalId: id, ask: ask) }
        if page.habit != nil { GoalHabitCard(goalId: id, page: page) }
        if page.card.kind != "parent" || page.three != nil {
            GoalThreeCard(goalId: id, three: page.three, remind: page.remind)
        }
        if let children = page.children { GoalChildren(children: children, said: page.said) }
        GoalChartBlock(page: page)
        if let steps = page.milestones, page.card.kind == "completion" {
            GoalMilestones(goalId: id, steps: steps, title: page.card.title)
        }
        if let rest = page.rest { GoalRestCard(goalId: id, rest: rest) }
        if let best = page.best { GoalBestBlock(goalId: id, best: best) }
        GoalRecentBlock(page: page)
        if !months.isEmpty { GoalMonthsBlock(goalId: id, months: months, unit: page.settings.target?.unit ?? "") }
        if let mood = page.mood { GoalMoodCard(mood: mood) }
        GoalSettingsBlock(goalId: id, page: page).id("settings")
        bottom(page.card)
    }

    private func pausedBanner(_ card: API.GoalCard) -> some View {
        HStack(spacing: Theme.Space.medium) {
            Image(systemName: "pause.circle").font(Theme.Typeface.section).foregroundStyle(Theme.Palette.tertiaryLabel)
            Text(card.line).font(Theme.Typeface.body).fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button("继续") { model.goalAct(id, "resume") }.buttonStyle(.bordered).accessibilityIdentifier("goal.resume")
        }
        .themeCard(padding: Theme.Space.inset)
    }

    /// 最下面：暂停 / 继续 · 标记完成 · 删除这个目标（都不弹确认框，回到首页给轻提示带撤销）
    private func bottom(_ card: API.GoalCard) -> some View {
        VStack(spacing: 0) {
            Button {
                model.goalAct(id, card.paused ? "resume" : "pause")
            } label: {
                VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                    Text(card.paused ? "继续" : "暂停").font(Theme.Typeface.body)
                    if !card.paused {
                        Text("暂停时不提醒、不算落后").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: Theme.Size.touch, alignment: .leading)
            }
            .accessibilityIdentifier("goal.pause")
            Divider()
            Button {
                leave { model.goalAct(id, "done") }
            } label: {
                Text("标记完成").font(Theme.Typeface.body).frame(
                    maxWidth: .infinity, minHeight: Theme.Size.touch, alignment: .leading)
            }
            .accessibilityIdentifier("goal.done")
            Divider()
            Button(role: .destructive) {
                leave { model.deleteGoal(id, title: card.title) }
            } label: {
                Text("删除这个目标").font(Theme.Typeface.body).frame(
                    maxWidth: .infinity, minHeight: Theme.Size.touch, alignment: .leading)
            }
            .accessibilityIdentifier("goal.delete")
        }
        .padding(.horizontal, Theme.Space.inset)
        .themeCard(padding: 0)
        .padding(.top, Theme.Space.small)
    }

    /// 回到首页再做（轻提示在首页出现）
    private func leave(_ work: @escaping () -> Void) {
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(320))
            work()
        }
    }

    private func load() async {
        do throws(APIError) {
            let fresh = try await model.client.goalPage(id)
            page = fresh.page
            months = fresh.months
            problem = nil
        } catch {
            if page == nil { problem = error.message }
        }
    }
}

/// 头：大环（中间百分比 / 2/4 / 26 天）、大数「92.4 / 500 公里」、一句状态（落后用黄）、一句预测；一排数；
/// 落后两周时一张「聊聊怎么调？」的卡
struct GoalHead: View {
    @Environment(AppModel.self) private var model
    let page: API.GoalPage

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            HStack(alignment: .center, spacing: Theme.Space.regular) {
                GoalRing(
                    state: page.card.ringState, progress: page.card.pct, label: page.card.ring ?? "",
                    size: Theme.Size.bigRing, spinIn: model.goals.fresh == page.card.id)
                VStack(alignment: .leading, spacing: Theme.Space.tight) {
                    (Text(page.head.big).font(Theme.Typeface.bigNumber).foregroundStyle(Theme.Palette.label)
                        + Text(page.head.bigUnit).font(Theme.Typeface.unit).foregroundStyle(
                            Theme.Palette.secondaryLabel))
                        .monospacedDigit().minimumScaleFactor(0.7).lineLimit(2)
                    Text(page.head.line).font(Theme.Typeface.bodySemibold)
                        .foregroundStyle(
                            page.card.state == "behind" ? Theme.Palette.warn : Theme.Palette.secondaryLabel
                        )
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("goal.head.line")
                    if let more = page.head.more {
                        Text(more).font(Theme.Typeface.footnote).monospacedDigit().foregroundStyle(
                            Theme.Palette.secondaryLabel
                        )
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("goal.head.more")
                    }
                }
            }
            if !page.head.nums.isEmpty { nums }
            if page.card.lagging && !page.card.paused { growCard }
        }
        .themeCard()
    }

    private var nums: some View {
        HStack(alignment: .top, spacing: Theme.Space.small) {
            ForEach(page.head.nums, id: \.label) { num in
                VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                    Text(num.label).font(Theme.Typeface.tick).foregroundStyle(Theme.Palette.secondaryLabel)
                    Text(num.value).font(Theme.Typeface.rowNumber).monospacedDigit().foregroundStyle(
                        Theme.Palette.label
                    )
                    .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.top, Theme.Space.small)
        .overlay(alignment: .top) { Divider() }
    }

    private var growCard: some View {
        Button {
            model.goals.sheet = .grow(page.card.id)
        } label: {
            HStack(spacing: Theme.Space.medium) {
                Image(systemName: "bubble.left.and.bubble.right").font(Theme.Typeface.bodyMedium)
                VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                    Text("落后两周了，聊聊怎么调？").font(Theme.Typeface.bodySemibold)
                    Text("2 分钟：还想要吗 · 卡在哪 · 有哪些办法 · 下一步").font(Theme.Typeface.footnote)
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                }
                Spacer()
                Image(systemName: "chevron.right").font(Theme.Typeface.footnoteSemibold)
            }
            .foregroundStyle(Theme.Palette.accent)
            .padding(Theme.Space.medium)
            .background(Theme.Palette.bubble, in: RoundedRectangle(cornerRadius: Theme.Corner.chip, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("goal.grow")
    }
}
