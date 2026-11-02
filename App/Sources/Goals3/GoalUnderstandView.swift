import PourAPI
import PourDesign
import SwiftUI

/// 理解卡的几种样子（06 交互细节 12.5）：问一句（3 个现成的回答）、模糊的先问、拆开的几个（能勾掉不要的）、
/// 已经有了（数不一样问要不要改）、理解卡（种类和周期、怎么算、已经算进去和是哪几句原话、我在乎的）+「不要」的另给一个「去做」的
struct GoalUnderstandView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let result: API.GoalUnderstand
    @Binding var care: String?
    let areas: [API.CareArea]
    let say: (String) -> Void
    let accept: ([API.GoalPlanView], String?) -> Void
    let again: () -> Void
    @State private var quotes = false
    @State private var dropped: Set<Int> = []
    @State private var positive: Bool?

    var body: some View {
        switch result.kind {
        case "ask", "vague": ask
        case "split": split
        case "dup": dup
        default: if let plan = result.plan { planCard(plan, main: true) }
        }
    }

    // MARK: - 问一句

    private var ask: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                Text(result.question ?? "").font(Theme.Typeface.body)
                if let sub = result.sub {
                    Text(sub).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                }
            }
            .padding(Theme.Space.medium)
            .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Corner.bubble, style: .continuous))
            PourFlowLayout(spacing: Theme.Space.small) {
                ForEach(result.options ?? [], id: \.text) { option in
                    Button(option.text) { say(option.say) }.buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("define.option.\(option.text)")
                }
            }
        }
    }

    // MARK: - 理解卡

    private func planCard(_ plan: API.GoalPlanView, main: Bool) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            Label("听懂的 · 你点「对」才开始算", systemImage: "sparkles").font(Theme.Typeface.footnoteSemibold)
                .foregroundStyle(Theme.Palette.accent)
            Text(plan.title).font(Theme.Typeface.section).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("define.plan.title")
            row("种类", "\(plan.type) · \(plan.period)")
            row("怎么算", plan.from)
            row("已经算进去", plan.counted)
            if !plan.quotes.isEmpty {
                LinkButton(quotes ? "收起原话" : "看是哪 \(plan.quotes.count) 句原话 ›", identifier: "define.quotes") {
                    withAnimation(Theme.Motion.standard) { quotes.toggle() }
                }
                if quotes {
                    ForEach(plan.quotes, id: \.self) { quote in
                        VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                            Text(quote.text).font(Theme.Typeface.quote)
                            Text(quote.when).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                        }
                    }
                }
            }
            if main { carePicker }
            if let note = result.note {
                Text(note).font(Theme.Typeface.footnote).padding(Theme.Space.medium)
                    .background(
                        Theme.Palette.fill, in: RoundedRectangle(cornerRadius: Theme.Corner.chip, style: .continuous))
            }
            if main {
                HStack(spacing: Theme.Space.small) {
                    Button {
                        accept([plan], nil)
                        if positive == true, let extra = result.positive?.plan { accept([extra], nil) }
                    } label: {
                        Text("对").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).accessibilityIdentifier("define.yes")
                    Button {
                        again()
                    } label: {
                        Text("改一下").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                if let extra = result.positive { positiveCard(extra) }
            }
        }
        .themeCard()
    }

    private func row(_ name: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.medium) {
            Text(name).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.tertiaryLabel).frame(
                width: Theme.Size.touch * 1.6, alignment: .leading)
            Text(value).font(Theme.Typeface.body).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 我在乎的：一排胶囊，猜好的那个是选中的；能点着改
    private var carePicker: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.medium) {
            Text("我在乎的").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.tertiaryLabel).frame(
                width: Theme.Size.touch * 1.6, alignment: .leading)
            PourFlowLayout(spacing: Theme.Space.snug) {
                ForEach(areas) { area in chip(area.name, selected: care == area.key) { care = area.key } }
                chip("其他", selected: care == nil) { care = nil }
            }
        }
    }

    private func chip(_ name: String, selected: Bool, pick: @escaping () -> Void) -> some View {
        Button(action: pick) {
            Text(name).font(Theme.Typeface.footnoteSemibold)
                .foregroundStyle(selected ? Theme.Palette.onAccent : Theme.Palette.label)
                .padding(.horizontal, Theme.Space.medium).padding(.vertical, Theme.Space.snug)
                .background(selected ? Theme.Palette.label : Theme.Palette.fill, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("define.care.\(name)")
    }

    /// 「不要」的：换成「去做」的会更容易坚持，要一起加上吗？（点不点都行）
    private func positiveCard(_ extra: API.GoalPositive) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text(extra.why).font(Theme.Typeface.subheadline).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(positive == true ? "✓ 一起加上" : "加上") { positive = true }.buttonStyle(.bordered)
                    .accessibilityIdentifier("define.positive.yes")
                Button("不用了") { positive = false }.buttonStyle(.bordered)
            }
        }
        .padding(Theme.Space.medium)
        .background(Theme.Palette.bubble, in: RoundedRectangle(cornerRadius: Theme.Corner.chip, style: .continuous))
    }

    // MARK: - 模糊的拆开

    private var split: some View {
        let children = result.children ?? []
        let kept = children.enumerated().filter { !dropped.contains($0.offset) }.map(\.element)
        return VStack(alignment: .leading, spacing: Theme.Space.medium) {
            Text(result.lead ?? "").font(Theme.Typeface.body)
            Text(result.title ?? "").font(Theme.Typeface.section)
            ForEach(Array(children.enumerated()), id: \.offset) { index, child in
                Button {
                    if dropped.contains(index) { dropped.remove(index) } else { dropped.insert(index) }
                } label: {
                    HStack(alignment: .top, spacing: Theme.Space.medium) {
                        Image(systemName: dropped.contains(index) ? "circle" : "checkmark.circle.fill").font(
                            Theme.Typeface.section
                        )
                        .foregroundStyle(dropped.contains(index) ? Theme.Palette.tertiaryLabel : Theme.Palette.accent)
                        VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                            Text(child.title).font(Theme.Typeface.bodySemibold)
                            Text("\(child.type) · \(child.from) · \(child.counted)").font(Theme.Typeface.footnote)
                                .foregroundStyle(Theme.Palette.secondaryLabel).fixedSize(
                                    horizontal: false, vertical: true)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            ForEach(result.skipped ?? [], id: \.self) { line in
                Text(line).font(Theme.Typeface.footnote).padding(Theme.Space.small)
                    .background(
                        Theme.Palette.fill, in: RoundedRectangle(cornerRadius: Theme.Corner.chip, style: .continuous))
            }
            HStack {
                Button("都定下（\(kept.count) 个）") { accept(kept, result.title) }.buttonStyle(.borderedProminent)
                    .disabled(kept.isEmpty).accessibilityIdentifier("define.split.yes")
                Button("换一个方向") { say("我想变健康") }.buttonStyle(.bordered)
            }
        }
        .themeCard()
    }

    // MARK: - 已经有了

    private var dup: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            Text("已经有了，不重复建").font(Theme.Typeface.bodySemibold)
            if let goal = result.goal {
                HStack(spacing: Theme.Space.medium) {
                    GoalRing(state: goal.ringState, progress: goal.pct, label: goal.ring ?? "")
                    VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                        Text(goal.title).font(Theme.Typeface.bodySemibold)
                        Text(goal.line).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                }
                if let note = result.note {
                    Text(note).font(Theme.Typeface.subheadline).fixedSize(horizontal: false, vertical: true)
                }
                if let offer = result.offer {
                    Text(offer.text).font(Theme.Typeface.subheadline).fixedSize(horizontal: false, vertical: true)
                    Button(offer.text.hasPrefix("改成") ? offer.text : "改成 \(Show.fmtNum(offer.value)) \(offer.unit)") {
                        model.goalSet(goal.id, GoalChange(target: offer.value))
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent).accessibilityIdentifier("define.offer")
                }
                HStack {
                    Button("去看看") {
                        dismiss()
                        model.openGoal(goal.id)
                    }
                    .buttonStyle(.bordered).accessibilityIdentifier("define.dup.open")
                    Button(result.offer != nil ? "不改，就这样" : "换个说法") { again() }.buttonStyle(.bordered)
                }
            }
            if let extra = result.positive {
                positiveCard(extra)
                if positive == true {
                    Button("加上「\(extra.plan.title)」") { accept([extra.plan], nil) }.buttonStyle(.borderedProminent)
                }
            }
        }
        .themeCard()
    }
}
