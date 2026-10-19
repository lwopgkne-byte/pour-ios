import PourAPI
import PourDesign
import SwiftUI

/// 目标详情（网页版 goals/GoalPeek.tsx，规格 8.5）：手机上从底部滑出。
/// 应达 vs 实际曲线、预测、贡献这个目标的所有记录；名称、目标值、类别、每个月的目标都能原地改
struct GoalPeek: View {
    @Environment(AppModel.self) private var model
    let goalId: Int
    @State private var detail: API.GoalDetail?
    @State private var problem: String?

    var body: some View {
        WebPeek(title: detail?.goal.title ?? "") {
            if let detail {
                GoalDetailView(detail: detail)
            } else if let problem {
                WebErrorState(problem) { Task { await load() } }
            } else {
                VStack(alignment: .leading, spacing: Web.space4) {
                    WebSkeleton().containerRelativeFrame(.horizontal) { width, _ in width * 2 / 3 }
                    WebSkeleton(height: Web.space16)
                    WebSkeleton().containerRelativeFrame(.horizontal) { width, _ in width / 2 }
                }
            }
        }
        .task(id: model.dataVersion) { await load() }
    }

    private func load() async {
        do {
            detail = try await model.client.goal(goalId)
            problem = nil
        } catch {
            problem = error.readable
        }
    }
}

private struct GoalDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let detail: API.GoalDetail

    private var goal: API.Goal { detail.goal }

    var body: some View {
        let progress = goal.progress
        VStack(alignment: .leading, spacing: Web.space6) {
            notices
            VStack(alignment: .leading, spacing: Web.space2) {
                HStack(spacing: Web.space2) {
                    ToneDot(tone: progress.tone)
                    // 右边已经有「195.8 / 500 公里」，这里只说超前落后
                    let pace = Show.paceText(goal, progress)
                    Text(Show.spaced(pace.isEmpty ? progress.headline : pace)).font(Web.bodyMedium).foregroundStyle(
                        Web.fg)
                    Spacer(minLength: Web.space2)
                    Text(Show.spaced(Show.keyNumber(goal, progress))).foregroundStyle(Web.fgSecondary).monospacedDigit()
                }
                .font(Web.body)
                if goal.kind != "completion" { GoalBar(pct: progress.pct, tone: progress.tone) }
                if goal.kind == "quantity", goal.invalid == nil { GoalNumbers(goal: goal) }
                if !detail.prediction.isEmpty {
                    Text(Show.spaced(detail.prediction)).font(Web.caption).foregroundStyle(Web.fgSecondary)
                }
            }
            if detail.series.count > 1 {
                GoalChart(
                    series: detail.series, unit: goal.unit ?? "", tone: progress.tone, avg: goal.calc == "avg",
                    lte: goal.direction == "lte")
            }
            if let days = detail.streakDays, !days.isEmpty {
                PeekSection(title: "最近每一天") { StreakStrip(days: days) }
            }
            if goal.kind == "completion" {
                let done = goal.status == "done"
                WebButton(done ? "改回进行中" : "标记完成", variant: done ? .secondary : .primary) {
                    model.setGoalDone(goal.id, !done)
                }
            }
            if let children = goal.children, !children.isEmpty { childrenSection(children) }
            GoalSettings(goal: goal)
            if let months = goal.monthRows { GoalMonths(goal: goal, months: months) }
            if let weeks = goal.weekRows {
                PeekSection(title: "每周") {
                    VStack(spacing: 0) { ForEach(weeks) { GoalSubRow(row: $0, unit: goal.unit ?? "") } }
                }
            }
            contributions
            WebTextButton("删除这个目标", color: Web.danger) {
                dismiss()
                model.removeGoal(goal.id)
            }
        }
    }

    /// 上面的提示：AI 建议的拆解等确认、在等你回答、绑定的类别没了
    @ViewBuilder private var notices: some View {
        if goal.status == "proposed" {
            SetupBox {
                Text("这是 AI 建议的拆解，确认后才开始算进度。不合适的话直接改下面的内容，或者在对话里说。")
                    .font(Web.body).foregroundStyle(Web.fg)
                WebButton("确认", variant: .primary) { model.confirmGoal(goal.parentId ?? goal.id) }
            }
        }
        if let question = goal.question, goal.status != "proposed" {
            SetupBox {
                Text(Show.spaced(question)).font(Web.body).foregroundStyle(Web.fg)
                HStack(spacing: Web.space3) {
                    if goal.maybeDone == true {
                        WebButton("标记完成", variant: .primary) { model.setGoalDone(goal.id, true) }
                    } else {
                        WebButton("就这样", variant: .primary) { model.confirmGoal(goal.id) }
                    }
                    WebTextButton("在对话里回答") {
                        dismiss()
                        model.chatOpen = true
                    }
                }
            }
        }
        if let invalid = goal.invalid {
            SetupBox {
                Text(Show.spaced(invalid.message)).font(Web.body).foregroundStyle(Web.fg)
                HStack(spacing: Web.space3) {
                    if let suggest = invalid.suggest {
                        WebButton("改绑到「\(suggest.name)」", variant: .primary) {
                            save(["category": .string(suggest.key)])
                        }
                    }
                    Text("也可以在下面「类别」里重新选").font(Web.caption).foregroundStyle(Web.fgTertiary)
                }
            }
        }
    }

    private func childrenSection(_ children: [API.Goal]) -> some View {
        PeekSection(title: "子目标") {
            VStack(alignment: .leading, spacing: Web.space3) {
                ForEach(children) { child in
                    VStack(alignment: .leading, spacing: Web.space1) {
                        HStack(spacing: Web.space2) {
                            ToneDot(tone: child.progress.tone)
                            Text(Show.spaced(child.title)).foregroundStyle(Web.fg)
                            Spacer(minLength: 0)
                            Text(Show.spaced(Show.keyNumber(child, child.progress))).font(Web.caption)
                                .foregroundStyle(Web.fgSecondary).monospacedDigit()
                        }
                        .font(Web.body)
                        GoalBar(pct: child.progress.pct, tone: child.progress.tone)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    /// 贡献的记录：点一条去那一天的画布
    @ViewBuilder private var contributions: some View {
        if !detail.contributions.isEmpty {
            PeekSection(title: "贡献的记录（\(detail.contributions.count)）") {
                VStack(spacing: 0) {
                    ForEach(detail.contributions.prefix(50)) { item in
                        Button {
                            dismiss()
                            model.page = .canvas
                            model.show(item.day)
                        } label: {
                            HStack(spacing: Web.space3) {
                                Text(Show.dayTitle(item.day, today: model.today)).foregroundStyle(Web.fgTertiary)
                                    .monospacedDigit()
                                // 网页版一行、放不下用省略号；手机上长的换行，字号调大了也看得全
                                Text(Show.spaced(item.text)).foregroundStyle(Web.fg)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if goal.calc == "sum", item.value > 0 {
                                    Text("+\(Show.fmtNum(item.value))").foregroundStyle(Web.fgSecondary)
                                        .monospacedDigit()
                                }
                            }
                            .font(Web.body)
                            .padding(.horizontal, Web.space2)
                            .frame(minHeight: Web.touch)
                        }
                        .buttonStyle(WebPressStyle(radius: Web.radiusControl))
                    }
                }
                .padding(.horizontal, -Web.space2)
            }
        } else if goal.kind == "quantity", goal.invalid == nil {
            let name = Show.meta(goal.binding?.category ?? "other", model.categories).name
            Text("还没有算进这个目标的记录。说一句「今天\(name)了…」就会自动算进来。").font(Web.caption)
                .foregroundStyle(Web.fgTertiary)
        }
    }

    private func save(_ fields: [String: JSONValue]) {
        let id = goal.id
        Task {
            do {
                try await model.updateGoal(id, fields)
            } catch {
                model.toast(error.readable)
            }
        }
    }
}

/// 应达、实际、差值；平均型是剩下的天里每天要多少；连续型是最长连续（网页版 Numbers）
private struct GoalNumbers: View {
    let goal: API.Goal

    var body: some View {
        let items = Self.items(goal)
        if !items.isEmpty {
            // 一排放得下就一排，放不下换行（网页版 flex-wrap）
            PourFlowLayout(spacing: Web.space6, lineSpacing: Web.space2) { cells(items) }
        }
    }

    private func cells(_ items: [(String, String)]) -> some View {
        ForEach(items, id: \.0) { name, value in
            VStack(alignment: .leading, spacing: 0) {
                Text(name).font(Web.caption).foregroundStyle(Web.fgTertiary)
                Text(Show.spaced(value)).font(Web.body).foregroundStyle(Web.fg).monospacedDigit()
            }
            .accessibilityElement(children: .combine)
        }
    }

    static func items(_ goal: API.Goal) -> [(String, String)] {
        let progress = goal.progress
        let unit = goal.unit ?? ""
        var items: [(String, String)] = []
        if goal.calc == "avg" {
            if let days = progress.days, days > 0 { items.append(("记了", "\(days) 天")) }
            if let needed = progress.neededPerDay, !progress.ended {
                items.append(("剩下每天平均", "\(goal.direction == "lte" ? "不超过" : "")\(Show.fmtNum(needed)) \(unit)"))
            }
        } else if goal.calc == "streak" {
            items.append(("最长连续", "\(progress.best ?? 0) 天"))
        } else if goal.direction == "lte" {
            items.append(("到今天允许", "\(Show.fmtNum(progress.expected ?? 0)) \(unit)"))
        } else if let expected = progress.expected, !progress.reached {
            items.append(("应达", "\(Show.fmtNum(expected)) \(unit)"))
            if let diff = progress.diff, expected > 0 {
                items.append((diff >= 0 ? "超前" : "落后", "\(Show.fmtNum(abs(diff))) \(unit)"))
            }
        }
        if !progress.ended, progress.daysLeft > 0, goal.repeats != true, goal.calc != "streak" {
            items.append(("还剩", "\(progress.daysLeft) 天"))
        }
        return items
    }
}
