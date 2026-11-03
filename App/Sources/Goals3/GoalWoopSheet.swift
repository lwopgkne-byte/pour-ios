import PourAPI
import PourDesign
import SwiftUI

/// 花 1 分钟想清楚（WOOP，docs/3.0/06-交互细节.md 12.6）：一屏一问，三屏；每屏 2–3 个现成的回答（宋体，能看从哪句原话来）、
/// 或者自己说一句；第三屏选提醒（时间、地点、不用提醒），选了才能「好了」。随时「跳过」；从目标页点一句进来只有那一屏
struct GoalWoopSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let goalId: Int
    /// 只改那一句（0 为什么 · 1 拦住我的 · 2 如果就）；nil 是三屏都走
    let only: Int?
    @State private var page: API.WoopPage?
    @State private var step = 0
    @State private var picks: [Int: String] = [:]
    @State private var own = ""
    @State private var remind: API.GoalRemind??

    private static let names = ["为什么想要", "最可能拦住你的", "如果……就……"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.medium) {
                    if let page, page.steps.indices.contains(step) {
                        content(page, page.steps[step])
                    } else {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                }
                .padding(Theme.Space.screen)
            }
            .background(Theme.Palette.background)
            .navigationTitle(only == nil ? "花 1 分钟想清楚 \(step + 1) / 3" : "花 1 分钟想清楚")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(only == nil ? "跳过" : "取消") { dismiss() }.accessibilityIdentifier("woop.skip")
                }
            }
        }
        .task {
            step = only ?? 0
            page = try? await model.client.goalWoop(goalId)
            if let three = page?.three {
                picks = [0: three.why, 1: three.obstacle, 2: three.plan].compactMapValues { $0 }
            }
        }
    }

    @ViewBuilder private func content(_ page: API.WoopPage, _ current: API.WoopStep) -> some View {
        if only == nil {
            HStack(spacing: Theme.Space.tight) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule().fill(index <= step ? Theme.Palette.accent : Theme.Palette.fill).frame(
                        height: Theme.Space.tight)
                }
            }
            .accessibilityHidden(true)
        }
        Text("\(page.title) · \(Self.names[step])").font(Theme.Typeface.footnote).foregroundStyle(
            Theme.Palette.secondaryLabel)
        Text(current.question).font(Theme.Typeface.section).fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("woop.question")
        if let sub = current.sub {
            Text(sub).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
        }
        ForEach(Array(current.options.enumerated()), id: \.offset) { index, option in
            ChoiceCard(
                text: option.text, selected: picks[step] == option.text,
                source: option.source.map { ($0.text, $0.when) },
                how: option.how, identifier: "woop.option.\(index)"
            ) {
                picks[step] = option.text
                own = ""
            }
        }
        HStack(spacing: Theme.Space.small) {
            TextField("或者自己说一句", text: $own, axis: .vertical).font(Theme.Typeface.quote).lineLimit(1...3)
                .onChange(of: own) { _, now in if !now.isEmpty { picks[step] = now } }
                .accessibilityIdentifier("woop.own")
            Image(systemName: "mic").foregroundStyle(Theme.Palette.tertiaryLabel).accessibilityHidden(true)
        }
        .padding(Theme.Space.medium)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Corner.chip, style: .continuous))
        if step == 2 { reminds(page) }
        Button {
            next(page)
        } label: {
            Text(buttonTitle).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(picks[step] == nil || (step == 2 && only == nil && remind == nil))
        .accessibilityIdentifier("woop.next")
    }

    private var buttonTitle: String {
        if only != nil { return "改好了" }
        return step < 2 ? "下一步" : "好了"
    }

    /// 第三屏：要在什么时候提醒你（选一个才能「好了」）
    private func reminds(_ page: API.WoopPage) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text(page.remindQ).font(Theme.Typeface.bodySemibold)
            PourFlowLayout(spacing: Theme.Space.small) {
                ForEach(page.reminds, id: \.text) { item in
                    pick(item.kind == "place" ? "📍 \(item.text)" : "🔔 \(item.text)", selected: remind == .some(item)) {
                        remind = .some(item)
                    }
                }
                pick("不用提醒", selected: remind == .some(nil)) { remind = .some(nil) }
            }
        }
        .themeCard()
    }

    private func pick(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text).font(Theme.Typeface.subheadline)
                .foregroundStyle(selected ? Theme.Palette.onAccent : Theme.Palette.label)
                .padding(.horizontal, Theme.Space.medium).padding(.vertical, Theme.Space.small)
                .background(selected ? Theme.Palette.accentFill : Theme.Palette.fill, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("woop.remind.\(text)")
    }

    private func next(_ page: API.WoopPage) {
        own = ""
        if only == nil && step < 2 {
            withAnimation(Theme.Motion.standard) { step += 1 }
            return
        }
        let three = API.GoalThree(why: picks[0], obstacle: picks[1], plan: picks[2])
        // 只改一句：只发那一句；三屏都走完：三句话和提醒一起
        let change: GoalChange
        if let only {
            change = GoalChange(
                remind: only == 2 ? remind : nil,
                three: API.GoalThree(
                    why: only == 0 ? picks[0] : nil, obstacle: only == 1 ? picks[1] : nil,
                    plan: only == 2 ? picks[2] : nil))
        } else {
            change = GoalChange(remind: remind, three: three)
        }
        model.goalSet(goalId, change)
        dismiss()
    }
}
