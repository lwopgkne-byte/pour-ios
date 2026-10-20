import PourAPI
import PourDesign
import SwiftUI

/// 目标页（规格 8.5）：回答「我离目标还有多远」。
/// 按周期分组，模糊目标自成一组，完成的收在最后；每个目标一行：状态色小圆点、名称、细进度条、关键数字；
/// 年目标能展开到月、再到周。点一行打开详情
struct GoalsPage: View {
    @Environment(AppModel.self) private var model
    @State private var goals: [API.Goal]?
    @State private var problem: String?
    @State private var adding = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: Web.space3) {
                    Text("目标").font(Web.title).foregroundStyle(Web.fg).accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 0)
                    WebTextButton("添加目标") { adding = true }
                }
                if let goals {
                    if goals.isEmpty {
                        Text("还没有目标。在输入框里说一句「我今年想跑 1000 公里」就能创建。")
                            .font(Web.body).foregroundStyle(Web.fgTertiary).padding(.top, Web.space6)
                    } else {
                        GoalGroups(goals: goals).padding(.top, Web.space6)
                    }
                } else if let problem {
                    WebErrorState(problem) { Task { await load() } }.padding(.top, Web.space6)
                } else {
                    VStack(alignment: .leading, spacing: Web.space4) {
                        WebSkeleton(width: Web.space16 * 1.5)
                        WebSkeleton(height: Web.space12)
                        WebSkeleton(height: Web.space12)
                    }
                    .padding(.top, Web.space6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Web.space4)
            .padding(.top, Web.space4)
            .padding(.bottom, Web.space12)
        }
        .refreshable { await load() }
        .task(id: model.dataVersion) { await load() }
        .sheet(isPresented: $adding, onDismiss: { Task { await load() } }, content: { GoalForm() })
    }

    private func load() async {
        do {
            goals = try await model.client.goals()
            problem = nil
        } catch {
            problem = error.readable
        }
    }
}

/// 分组：模糊目标各自一组，然后按周期，完成的放最后
private struct GoalGroups: View {
    let goals: [API.Goal]
    @State private var showDone = false

    /// 一组：标题和哪些目标算这一组
    private struct Spec {
        let key: String
        let title: String
        let test: (API.Goal) -> Bool
    }

    private static let groups = [
        Spec(key: "year", title: "今年") { $0.kind == "quantity" && $0.calc != "streak" && $0.period == "year" },
        Spec(key: "month", title: "每月") { $0.kind == "quantity" && $0.calc != "streak" && $0.period == "month" },
        Spec(key: "week", title: "每周") { $0.kind == "quantity" && $0.calc != "streak" && $0.period == "week" },
        Spec(key: "streak", title: "连续天数") { $0.kind == "quantity" && $0.calc == "streak" },
        Spec(key: "completion", title: "做完就算") { $0.kind == "completion" },
    ]

    var body: some View {
        let active = goals.filter { $0.status != "done" }
        let done = goals.filter { $0.status == "done" }
        // 有的行右边有展开按钮：其他行留出同样的位置，右边的数字才能对齐
        let gutter = goals.contains { ($0.monthRows ?? $0.weekRows ?? []).count > 1 }
        VStack(alignment: .leading, spacing: Web.space8) {
            ForEach(active.filter { $0.kind == "parent" }) { ParentGroup(goal: $0, gutter: gutter) }
            ForEach(Self.groups, id: \.key) { group in
                let list = active.filter { $0.kind != "parent" && group.test($0) }
                if !list.isEmpty { section(group.title, list, gutter: gutter) }
            }
            if !done.isEmpty {
                VStack(alignment: .leading, spacing: Web.space2) {
                    Button(showDone ? "已完成 \(done.count) 个 · 收起" : "已完成 \(done.count) 个") {
                        withAnimation(Web.panel) { showDone.toggle() }
                    }
                    .font(Web.body).foregroundStyle(Web.fgSecondary).buttonStyle(.plain)
                    .frame(minHeight: Web.touch)
                    if showDone {
                        VStack(spacing: 0) { ForEach(done) { GoalRow(goal: $0, gutter: gutter) } }
                            .padding(.horizontal, -Web.space2)
                    }
                }
            }
        }
    }

    /// 一组：标题（这一组的时间范围都一样时写在标题后面，每一行就不再重复）和一行一个目标
    private func section(_ title: String, _ list: [API.Goal], gutter: Bool) -> some View {
        let ranges = Set(list.map(\.rangeLabel).filter { !$0.isEmpty })
        let shared = ranges.count == 1 && list.allSatisfy { !$0.rangeLabel.isEmpty } ? ranges.first : nil
        return VStack(alignment: .leading, spacing: Web.space2) {
            HStack(spacing: Web.space2) {
                Text(title).font(Web.captionMedium).foregroundStyle(Web.fgSecondary)
                if let shared { Text(Show.spaced(shared)).font(Web.caption).foregroundStyle(Web.fgTertiary) }
            }
            .padding(.horizontal, Web.space2)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(list) { GoalRow(goal: $0, hideRange: shared != nil, gutter: gutter) }
            }
        }
        // 每行为了按下去的底色留了内边距：整组向两边伸出同样的距离，文字和「目标」两个字左边对齐
        .padding(.horizontal, -Web.space2)
    }
}

/// 模糊目标：自成一组，标题旁边是综合进度；AI 建议的拆解等确认（虚线框）
private struct ParentGroup: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    let goal: API.Goal
    let gutter: Bool

    var body: some View {
        let proposed = goal.status == "proposed"
        VStack(alignment: .leading, spacing: Web.space2) {
            Button {
                model.goalDetail = .init(id: goal.id)
            } label: {
                HStack(spacing: Web.space2) {
                    ToneDot(tone: proposed ? "idle" : goal.progress.tone)
                    Text(Show.spaced(goal.title)).font(Web.bodySemibold).foregroundStyle(Web.fg)
                    Text(Show.spaced(proposed ? "AI 建议的拆解，确认后生效" : goal.progress.headline))
                        .font(Web.body).foregroundStyle(Web.fgTertiary).lineLimit(typeSize > .large ? nil : 1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Web.space2)
                .frame(minHeight: Web.touch)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            VStack(spacing: 0) { ForEach(goal.children ?? []) { GoalRow(goal: $0, gutter: gutter) } }
            if proposed {
                HStack(spacing: Web.space3) {
                    WebButton("确认", variant: .primary) { model.confirmGoal(goal.id) }
                    WebTextButton("不要了") { model.removeGoal(goal.id) }
                    Text("想改哪个子目标，点开它直接改，或者在对话里说").font(Web.caption).foregroundStyle(Web.fgTertiary)
                }
                .padding(.horizontal, Web.space2)
            }
        }
        .padding(.vertical, proposed ? Web.space3 : 0)
        .padding(.horizontal, proposed ? 0 : -Web.space2)
        .overlay {
            if proposed {
                RoundedRectangle(cornerRadius: Web.radiusCard)
                    .strokeBorder(Web.lineStrong, style: StrokeStyle(lineWidth: 1, dash: [Web.space1, Web.space1 / 2]))
            }
        }
    }
}

/// 一个目标一行；年目标可以展开到月、月再展开到周
private struct GoalRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    let goal: API.Goal
    var hideRange = false
    var gutter = false
    @State private var open = false

    var body: some View {
        let rows = goal.monthRows ?? goal.weekRows
        let progress = goal.progress
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Web.space1) {
                Button {
                    model.goalDetail = .init(id: goal.id)
                } label: {
                    VStack(alignment: .leading, spacing: Web.space1) {
                        HStack(spacing: Web.space2) {
                            ToneDot(tone: goal.status == "proposed" ? "idle" : progress.tone)
                            // 平时一行、放不下用省略号；系统字号调大了就换行，不藏字
                            Text(Show.spaced(goal.title)).foregroundStyle(Web.fg)
                                .lineLimit(typeSize > .large ? nil : 1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            // 数字不换行，放不下时名称用省略号
                            Text(Show.spaced(Show.keyNumber(goal, progress))).foregroundStyle(Web.fgSecondary)
                                .monospacedDigit().fixedSize()
                        }
                        .font(Web.body)
                        if goal.kind != "completion" { GoalBar(pct: progress.pct, tone: progress.tone) }
                        if !sub.isEmpty { Text(Show.spaced(sub)).font(Web.caption).foregroundStyle(Web.fgTertiary) }
                    }
                    .padding(Web.space2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(WebPressStyle(radius: Web.radiusControl))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(spoken))
                if let rows, rows.count > 1 {
                    GoalExpand(open: $open, label: goal.monthRows != nil ? "展开每个月" : "展开每周")
                } else if gutter {
                    Color.clear.frame(width: Web.touch, height: Web.touch).accessibilityHidden(true)
                }
            }
            if open, let rows {
                GoalSubs { ForEach(rows) { GoalSubRow(row: $0, unit: goal.unit ?? "") } }
            }
        }
    }

    /// 下面那一行：时间范围、在等你回答的问题或者超前落后多少
    private var sub: String {
        let range =
            hideRange || goal.kind == "completion"
            ? "" : goal.repeats == true ? "现在是 \(goal.rangeLabel)" : goal.rangeLabel
        let pace = goal.question.map { "在等你回答：\($0)" } ?? Show.paceText(goal, goal.progress)
        return [range, pace].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private var spoken: String {
        let tone = Show.toneName(goal.status == "proposed" ? "idle" : goal.progress.tone)
        return [goal.title, tone, Show.keyNumber(goal, goal.progress), sub].filter { !$0.isEmpty }
            .joined(separator: "，")
    }
}
