import PourAPI
import PourDesign
import SwiftUI

/// 一个目标页上的几块：在等你回答、成习惯了、三句话、子目标、里程碑、补假（docs/3.0/06-交互细节.md 12.3、12.4）

/// 块的小标题（右边可以带一行小字）
struct GoalSection: View {
    let title: String
    var meta: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(Theme.Typeface.section).foregroundStyle(Theme.Palette.label).accessibilityAddTraits(
                .isHeader)
            Spacer()
            if let meta { Text(meta).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel) }
        }
        .padding(.top, Theme.Space.small)
    }
}

/// 在等你回答：「这句没说书名，算《人类简史》吗？」+ 宋体原话；「算，加 40 页」「不算」，答了程序记住
struct GoalAskCard: View {
    @Environment(AppModel.self) private var model
    let goalId: Int
    let ask: API.GoalAsk

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Label("在等你回答 · 拿不准的只问一次", systemImage: "sparkles").font(Theme.Typeface.footnoteSemibold)
                .foregroundStyle(Theme.Palette.accent)
            Text(ask.question).font(Theme.Typeface.body).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                Text(ask.text).font(Theme.Typeface.quote)
                Text("\(ask.at) 你说的").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            }
            .padding(.leading, Theme.Space.medium)
            .overlay(alignment: .leading) { Capsule().fill(Theme.Palette.separator).frame(width: Theme.Space.hairline) }
            HStack(spacing: Theme.Space.small) {
                Button("算，加 \(Show.fmtNum(ask.add)) \(ask.unit)") { model.goalAnswer(goalId, counts: true) }
                    .buttonStyle(.borderedProminent).accessibilityIdentifier("goal.ask.yes")
                Button("不算") { model.goalAnswer(goalId, counts: false) }
                    .buttonStyle(.bordered).accessibilityIdentifier("goal.ask.no")
            }
            Text("答了以后程序记住，下次这样的话不再问。").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
        }
        .themeCard()
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Corner.card, style: .continuous).strokeBorder(
                Theme.Palette.bubble, lineWidth: 2)
        }
    }
}

/// 成习惯了（每周背单词 4 次）：放进做到的 · 少提醒一点 · 就这样
struct GoalHabitCard: View {
    @Environment(AppModel.self) private var model
    let goalId: Int
    let page: API.GoalPage
    @State private var answer: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            HStack(spacing: Theme.Space.small) {
                HabitTag()
                Text("连续 8 周每周都做到").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            }
            if let answer = answer ?? (page.habit?.quiet == true ? "以后只在周日晚上没做到时提醒一次。" : nil) {
                Text(answer).font(Theme.Typeface.body).fixedSize(horizontal: false, vertical: true)
            } else {
                Text("做稳了。要放进「做到的」，还是少提醒一点？").font(Theme.Typeface.bodySemibold)
                    .fixedSize(horizontal: false, vertical: true)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Theme.Space.small) { buttons }
                    VStack(alignment: .leading, spacing: Theme.Space.small) { buttons }
                }
            }
        }
        .themeCard()
    }

    @ViewBuilder private var buttons: some View {
        Button("放进做到的") { model.goalAct(goalId, "done") }.buttonStyle(.borderedProminent)
            .accessibilityIdentifier("goal.habit.done")
        Button("少提醒一点") {
            answer = "好，以后只在周日晚上没到 \(Int(page.settings.target?.value ?? 4)) 次时提醒一次。"
            model.goalSet(goalId, GoalChange(quiet: true))
        }
        .buttonStyle(.bordered)
        Button("就这样") { answer = "好，就这样接着算。" }.buttonStyle(.bordered)
    }
}

/// 三句话（宋体，点一句 → 花 1 分钟想清楚只改那一句）；下面一行「如果就」的提醒；没写过时是「花 1 分钟想清楚 ›」
struct GoalThreeCard: View {
    @Environment(AppModel.self) private var model
    let goalId: Int
    let three: API.GoalThree?
    let remind: API.GoalRemind?
    /// 「到家的时候」要知道家在哪（只存在手机上）
    @State private var homeKnown = HomePlace.saved != nil

    var body: some View {
        if let three {
            VStack(spacing: 0) {
                row(0, "为什么想要", three.why)
                Divider()
                row(1, "最可能拦住我的", three.obstacle)
                Divider()
                row(2, "如果……就……", three.plan)
                if let remind {
                    Divider()
                    Button {
                        model.goals.sheet = .woop(goalId, step: 2)
                    } label: {
                        Label(Self.line(remind), systemImage: Self.symbol(remind))
                            .font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
                            .frame(maxWidth: .infinity, minHeight: Theme.Size.touch, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("goal.remind")
                    if remind.kind == "place", remind.off != true, !homeKnown {
                        LinkButton("还不知道家在哪 · 我在家，用现在的位置", identifier: "goal.home") {
                            Task { homeKnown = await model.setHomeHere() }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, Theme.Space.inset)
            .themeCard(padding: 0)
        } else {
            Button {
                model.goals.sheet = .woop(goalId, step: nil)
            } label: {
                HStack(spacing: Theme.Space.medium) {
                    Image(systemName: "brain.head.profile").font(Theme.Typeface.bodyMedium).foregroundStyle(
                        Theme.Palette.accent)
                    VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                        Text("花 1 分钟想清楚").font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                        Text("为什么想要 · 最可能拦住你的 · 如果……就……").font(Theme.Typeface.footnote)
                            .foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(Theme.Typeface.footnoteSemibold).foregroundStyle(
                        Theme.Palette.tertiaryLabel)
                }
                .themeCard()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("goal.woop")
        }
    }

    /// 「每个工作日 18:30 提醒你「如果就」」；在设置里关了写「提醒关着」
    static func line(_ remind: API.GoalRemind) -> String {
        remind.off == true ? "提醒关着 · \(remind.text) · 在设置 → 提醒和通知里能开" : remind.line ?? remind.text
    }

    static func symbol(_ remind: API.GoalRemind) -> String {
        if remind.off == true { return "bell.slash" }
        return remind.kind == "place" ? "location" : "bell"
    }

    private func row(_ step: Int, _ name: String, _ text: String?) -> some View {
        Button {
            model.goals.sheet = .woop(goalId, step: step)
        } label: {
            HStack(alignment: .top, spacing: Theme.Space.medium) {
                VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                    Text(name).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    Text(text ?? "还没写").font(Theme.Typeface.quote)
                        .foregroundStyle(text == nil ? Theme.Palette.tertiaryLabel : Theme.Palette.label)
                        .lineSpacing(Theme.Leading.quote / 2).multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "pencil").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.tertiaryLabel)
            }
            .padding(.vertical, Theme.Space.medium)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("goal.three.\(step)")
    }
}

/// 大目标：子目标（同首页的一行，能点）+ 当时那句原话
struct GoalChildren: View {
    @Environment(AppModel.self) private var model
    let children: [API.GoalCard]
    let said: API.GoalQuote?

    var body: some View {
        GoalSection(title: "子目标", meta: "点开改")
        VStack(spacing: 0) {
            ForEach(Array(children.enumerated()), id: \.element.id) { index, card in
                if index > 0 { Divider() }
                GoalRow(card: card).contextMenu { GoalMenu(card: card) }
            }
        }
        .padding(.horizontal, Theme.Space.inset)
        .themeCard(padding: 0)
        if let said {
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                Text(said.text).font(Theme.Typeface.quote)
                Text("\(said.when) · AI 拆成了上面 \(children.count) 个，你点了「对」").font(Theme.Typeface.footnote)
                    .foregroundStyle(Theme.Palette.secondaryLabel)
            }
            .padding(.horizontal, Theme.Space.small)
        }
    }
}

/// 做完就算的几个里程碑：点圆圈打勾（「勾上了：第三部分 · 撤销」）；最后一步勾掉 = 做完
struct GoalMilestones: View {
    @Environment(AppModel.self) private var model
    let goalId: Int
    let steps: [API.GoalMilestone]
    let title: String
    @State private var finished = 0

    var body: some View {
        GoalSection(title: "几个里程碑", meta: "最后一步勾掉就算做完")
        VStack(spacing: 0) {
            if steps.isEmpty {
                Text("还没有分几步。说「分成四部分」，或者在设置里加。").font(Theme.Typeface.body)
                    .foregroundStyle(Theme.Palette.secondaryLabel).padding(.vertical, Theme.Space.medium)
            }
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                if index > 0 { Divider() }
                Button {
                    let last = step.doneAt == nil && steps.filter { $0.doneAt == nil }.count == 1
                    if last { finished += 1 }
                    model.goalMilestone(goalId, index: index, done: step.doneAt == nil)
                } label: {
                    HStack(spacing: Theme.Space.medium) {
                        Image(systemName: step.doneAt != nil ? "checkmark.circle.fill" : "circle").font(
                            Theme.Typeface.section
                        )
                        .foregroundStyle(step.doneAt != nil ? Theme.Palette.good : Theme.Palette.tertiaryLabel)
                        Text(step.title).font(Theme.Typeface.body)
                            .foregroundStyle(step.doneAt != nil ? Theme.Palette.secondaryLabel : Theme.Palette.label)
                        Spacer()
                        if let day = step.doneAt {
                            Text("\(Show.monthDay(day))看完").font(Theme.Typeface.footnote).foregroundStyle(
                                Theme.Palette.secondaryLabel)
                        }
                    }
                    .frame(minHeight: Theme.Size.touch)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(step.doneAt != nil ? .isSelected : [])
                .accessibilityIdentifier("goal.milestone.\(index)")
            }
        }
        .padding(.horizontal, Theme.Space.inset)
        .themeCard(padding: 0)
        .sensoryFeedback(Theme.Haptics.done, trigger: finished)
        Text("说「\(title.replacingOccurrences(of: "读完", with: ""))第三部分看完了」也会自动勾上。")
            .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// 补假（每天都要做的坚持）：没做到的那天自动用掉，不算断；一次一行；每周几次补假 0–3（改了从下周一开始）；还差几周成习惯了
struct GoalRestCard: View {
    @Environment(AppModel.self) private var model
    let goalId: Int
    let rest: API.GoalPage.Rest

    var body: some View {
        GoalSection(title: "补假")
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text("每周 \(rest.perWeek) 次补假：没做到的那天自动用掉，不算断；不用就作废，不攒到下周。")
                .font(Theme.Typeface.body).fixedSize(horizontal: false, vertical: true)
            ForEach(rest.lines, id: \.day) { line in
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.small) {
                    Text(line.day).font(Theme.Typeface.footnote).monospacedDigit().foregroundStyle(
                        Theme.Palette.secondaryLabel)
                    Text(line.text).font(Theme.Typeface.footnote).monospacedDigit().foregroundStyle(
                        Theme.Palette.secondaryLabel
                    )
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            Divider()
            HStack {
                Text("每周几次补假").font(Theme.Typeface.body)
                Spacer()
                Picker(
                    "每周几次补假",
                    selection: Binding(
                        get: { rest.perWeek },
                        set: { value in
                            model.goalSet(goalId, GoalChange(restPerWeek: value))
                        })
                ) {
                    ForEach(0...3, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: Theme.Size.goalCard)
                .accessibilityIdentifier("goal.rest")
            }
            if let left = rest.habitLeft {
                Text(left).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .themeCard()
    }
}

/// 一行字的链接按钮（「看是哪几次 ›」「改回进行中」「全部 9 条」）：字小，点的地方撑到 44 点高（无障碍审计、手指都好点）
struct LinkButton: View {
    let title: String
    var font = Theme.Typeface.footnote
    var identifier: String?
    let action: () -> Void

    init(_ title: String, font: Font = Theme.Typeface.footnote, identifier: String? = nil, action: @escaping () -> Void)
    {
        self.title = title
        self.font = font
        self.identifier = identifier
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title).font(font).foregroundStyle(Theme.Palette.accent).multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: Theme.Size.touch).contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier(identifier ?? "link")
    }
}
