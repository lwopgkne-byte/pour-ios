import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 生活画布（网页版 CanvasPage 1 比 1）：回答「我今天过得怎么样」。
/// 从上到下：日期、一句话总结、今天推进的目标、还在整理的那一行、时间轴、类别卡片；左右滑换日子
struct CanvasView: View {
    @Environment(AppModel.self) private var model
    @State private var picking = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DayHeader(picking: $picking)
                SetupCard()
                if model.shownDay == model.today { ReviewHint() }
                CanvasBody()
                    .padding(.top, Web.space4)
                    .id(model.shownDay)
                    .transition(.opacity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Web.space4)
            .padding(.top, Web.space4)
            .padding(.bottom, Web.space12)
        }
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await model.refreshAll() }
        // 手机：左右滑动切换日期（横着滑 60 点以上、比竖着多一倍才算）
        .simultaneousGesture(
            DragGesture(minimumDistance: Web.space6).onEnded { drag in
                let across = drag.translation.width
                guard abs(across) > Web.space12 + Web.space3, abs(across) > abs(drag.translation.height) * 2 else {
                    return
                }
                withAnimation(Web.panel) { model.show(PourDate.addDays(model.shownDay, across > 0 ? -1 : 1)) }
            }
        )
        .sheet(isPresented: $picking) { DayPicker() }
    }
}

/// 日期标题：「10 月 19 日 周一」加上「今天」；不是今天、昨天就是「回到今天」。点日期选哪一天
private struct DayHeader: View {
    @Environment(AppModel.self) private var model
    @Binding var picking: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Web.space3) {
            Button {
                picking = true
            } label: {
                Text(Show.spaced(Show.dayTitle(model.shownDay, today: model.today)))
                    .font(Web.title).foregroundStyle(Web.fg).lineLimit(1).fixedSize()
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("跳到某一天"))
            .accessibilityIdentifier("today.header")
            if let relative = Show.relative(model.shownDay, today: model.today) {
                Text(relative).font(Web.section).foregroundStyle(Web.fgTertiary)
            } else {
                WebTextButton("回到今天") { withAnimation(Web.panel) { model.show(model.today) } }
            }
        }
    }
}

/// 一天的内容：总结、目标胶囊、还在整理的、时间轴、卡片；什么都没有时一句话说明
private struct CanvasBody: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let day = model.day {
            content(day)
        } else if let offline = model.offline {
            VStack(alignment: .leading, spacing: Web.space2) {
                Text(offline).font(Web.body).foregroundStyle(Web.fgSecondary)
                WebTextButton("重试") { Task { await model.refreshAll() } }
            }
        }
    }

    @ViewBuilder private func content(_ day: API.DayView) -> some View {
        let progress = progressLine(model.dayNotes)
        VStack(alignment: .leading, spacing: 0) {
            if day.entries.isEmpty && model.dayNotes.isEmpty {
                Text(Show.spaced(emptyText)).font(Web.body).foregroundStyle(Web.fgTertiary)
                    .lineSpacing(Web.bodyLineSpacing)
            } else {
                if let summary = day.summary {
                    Text(Show.spaced(summary)).font(Web.body).foregroundStyle(Web.fgSecondary)
                        .lineSpacing(Web.bodyLineSpacing)
                        .accessibilityIdentifier("today.summary")
                }
                GoalPills(goals: day.goals.filter { $0.delta != nil })
                if let progress {
                    Button {
                        withAnimation(Web.panel) { model.chatOpen = true }
                    } label: {
                        Label(progress, systemImage: "circle").labelStyle(QuietLabel())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, Web.space1)
                }
                if day.entries.isEmpty && progress == nil {
                    Text("说过的话里没有整理出记录。").font(Web.body).foregroundStyle(Web.fgTertiary)
                }
                TimelineStrip(day: day.day, entries: day.entries, categories: model.categories)
                DayCards(entries: day.entries, categories: model.categories, goals: day.goals)
            }
        }
    }

    private var emptyText: String {
        let offset = PourDate.diffDays(model.shownDay, model.today)
        if offset == 0 { return "今天还是空白。说说你做了什么，这里会自己长出来。" }
        return offset > 0 ? "这一天还没到。" : "这一天没有留下记录。"
    }

    /// 还在整理、等着、没整理成的话：一行安静的字，点一下打开对话
    private func progressLine(_ notes: [API.Note]) -> String? {
        let count = { (status: String) in notes.filter { $0.status == status }.count }
        let parts = [
            count("processing") > 0 ? "正在整理…" : nil,
            count("pending") > 0 ? "\(count("pending")) 段等待整理" : nil,
            count("failed") > 0 ? "\(count("failed")) 段处理失败" : nil,
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// 这一天推进的目标（网页版 goal-pills）：状态色小圆点、目标、推进了多少
private struct GoalPills: View {
    let goals: [API.DayGoal]

    var body: some View {
        if !goals.isEmpty {
            PourFlowLayout(spacing: Web.space2, lineSpacing: Web.space2) {
                ForEach(goals) { goal in
                    HStack(spacing: Web.space2) {
                        ToneDot(tone: goal.tone)
                        Text(Show.spaced(goal.title)).foregroundStyle(Web.fgSecondary)
                        if let delta = goal.delta {
                            Text(Show.spaced(delta)).font(Web.bodyMedium).foregroundStyle(Web.fg).monospacedDigit()
                        }
                    }
                    .font(Web.body)
                    .padding(.horizontal, Web.space3)
                    .frame(minHeight: Web.touch)
                    .background(Capsule().fill(Web.bg))
                    .overlay(Capsule().strokeBorder(Web.line, lineWidth: 1))
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.top, Web.space3)
        }
    }
}

/// 目标的状态色小圆点；还谈不上状态的是空心圈
struct ToneDot: View {
    let tone: String

    var body: some View {
        Group {
            if tone == "idle" {
                Circle().strokeBorder(Web.fgTertiary, lineWidth: 1)
            } else {
                Circle().fill(Web.status(tone))
            }
        }
        .frame(width: Web.space2, height: Web.space2)
        .accessibilityHidden(true)
    }
}

/// 网页版的 quiet-link：小图标 + 次要文字，至少 44 点高
struct QuietLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Web.space1) {
            configuration.icon.font(Web.caption)
            configuration.title.font(Web.body)
        }
        .foregroundStyle(Web.fgSecondary)
        .frame(minHeight: Web.touch)
    }
}

/// 点日期：选一天看（不能选还没到的日子）
private struct DayPicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            DatePicker("哪一天", selection: $date, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .padding(.horizontal, Web.space4)
                .navigationTitle("跳到某一天")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("好") {
                            model.show(PourDate.logicalDay(date, in: .current))
                            dismiss()
                        }
                    }
                }
        }
        .presentationDetents([.medium])
        .tint(Web.accent)
    }
}
