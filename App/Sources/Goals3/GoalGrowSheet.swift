import PourAPI
import PourDesign
import SwiftUI

/// 聊聊怎么调（GROW，docs/3.0/06-交互细节.md 12.7）：上面一排四段（还想要吗 · 卡在哪 · 有哪些办法 · 下一步），一问一答的气泡；
/// 程序摆事实、每个办法写程序算的新日期；选了就这样：目标马上变，底部能撤销。放下也是好结果，能再试试
struct GoalGrowSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let goalId: Int
    @State private var page: API.GrowPage?
    @State private var step = 0
    @State private var letgo = false
    @State private var why = ""
    @State private var facts = false
    @State private var picked: API.GrowOption?
    @State private var restart = true
    @State private var remind: API.GoalRemind??
    @State private var letgoWhy = ""

    private static let names = ["还想要吗", "卡在哪", "有哪些办法", "下一步"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.medium) {
                    if let page { content(page) } else { ProgressView().frame(maxWidth: .infinity) }
                }
                .padding(Theme.Space.screen)
            }
            .background(Theme.Palette.background)
            .navigationTitle("聊聊怎么调")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }.accessibilityIdentifier("grow.close")
                }
            }
        }
        .task { page = try? await model.client.goalGrow(goalId) }
    }

    @ViewBuilder private func content(_ page: API.GrowPage) -> some View {
        Text(page.sub).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
        HStack(spacing: Theme.Space.tight) {
            ForEach(0..<4, id: \.self) { index in
                let lit = letgo ? index == 0 : index <= step
                VStack(spacing: Theme.Space.tight) {
                    Capsule().fill(lit ? Theme.Palette.accent : Theme.Palette.fill).frame(height: Theme.Space.tight)
                    Text(Self.names[index]).font(Theme.Typeface.tick).foregroundStyle(
                        lit ? Theme.Palette.accent : Theme.Palette.tertiaryLabel)
                }
            }
        }
        .accessibilityHidden(true)
        if letgo {
            letgoView(page)
        } else {
            ai(page.ask, sub: page.askSub)
            if step == 0 {
                chips(["重要", "没那么重要了"]) { answer in
                    if answer == "重要" { step = 1 } else { letgo = true }
                }
            }
            if step >= 1 { stuck(page) }
            if step >= 2 { options(page) }
            if step >= 3, let picked { nextStep(page, picked) }
        }
    }

    // MARK: - 卡在哪

    @ViewBuilder private func stuck(_ page: API.GrowPage) -> some View {
        mine("重要")
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text("程序算的 · 每个数都能点回原话").font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.secondaryLabel)
            Text(page.facts.lead).font(Theme.Typeface.bodySemibold).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("grow.facts")
            if let more = page.facts.more {
                Text(more).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
            }
            if !page.facts.quotes.isEmpty {
                LinkButton(facts ? "收起" : "看是哪几次 ›") { withAnimation(Theme.Motion.standard) { facts.toggle() } }
                if facts {
                    ForEach(page.facts.quotes, id: \.self) { quote in
                        VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                            Text(quote.text).font(Theme.Typeface.quote)
                            Text(quote.when).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                        }
                    }
                }
            }
        }
        .themeCard()
        ai("你觉得是什么拦住了？", sub: nil)
        if step == 1 {
            chips(page.blockers.map(\.text)) { answer in
                why = answer
                step = 2
            }
            HStack {
                TextField("或者自己说", text: $why).font(Theme.Typeface.quote).submitLabel(.done)
                    .onSubmit { if !why.isEmpty { step = 2 } }
                Button("好了") { step = 2 }.disabled(why.isEmpty)
            }
            .padding(Theme.Space.medium)
            .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Corner.chip, style: .continuous))
            if let foot = page.blockerFoot {
                Text(foot).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel).fixedSize(
                    horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - 有哪些办法

    @ViewBuilder private func options(_ page: API.GrowPage) -> some View {
        mine(why)
        ai("有这几个办法。日期都是按你最近的速度算的：", sub: nil)
        ForEach(page.options) { option in
            Button {
                picked = option
                remind = option.remind.map { .some($0) } ?? .some(nil)
            } label: {
                VStack(alignment: .leading, spacing: Theme.Space.tight) {
                    HStack(spacing: Theme.Space.small) {
                        Image(systemName: picked == option ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(picked == option ? Theme.Palette.accent : Theme.Palette.tertiaryLabel)
                        Text(option.title).font(Theme.Typeface.bodySemibold)
                    }
                    Text(option.how).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(option.when).font(Theme.Typeface.subheadline.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(Theme.Palette.accent)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("代价：\(option.cost)").font(Theme.Typeface.footnote).foregroundStyle(
                        Theme.Palette.secondaryLabel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .themeCard(padding: Theme.Space.inset)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Corner.card, style: .continuous)
                        .strokeBorder(picked == option ? Theme.Palette.accent : Color.clear, lineWidth: 2)
                }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(picked == option ? .isSelected : [])
            .accessibilityIdentifier("grow.option.\(option.key)")
        }
        if step == 2 {
            Button {
                step = 3
            } label: {
                Text("就选这个").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).disabled(picked == nil).accessibilityIdentifier("grow.pick")
            LinkButton("都不想要，放下它", font: Theme.Typeface.subheadline) { letgo = true }.frame(maxWidth: .infinity)
        }
    }

    // MARK: - 下一步

    @ViewBuilder private func nextStep(_ page: API.GrowPage, _ option: API.GrowOption) -> some View {
        mine(option.title)
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text("选了以后马上生效").font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.secondaryLabel)
            Text(option.key == "pause" ? "先停一个月" : option.newTitle ?? page.title).font(Theme.Typeface.section)
            Text(option.how).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel).fixedSize(
                horizontal: false, vertical: true)
            Text(option.when).font(Theme.Typeface.bodySemibold).monospacedDigit().foregroundStyle(Theme.Palette.accent)
            if option.key != "pause" {
                Divider()
                Toggle(isOn: $restart) {
                    VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                        Text(page.restart.text).font(Theme.Typeface.body)
                        Text("之前落后的不再算；新的一周更容易开始").font(Theme.Typeface.footnote).foregroundStyle(
                            Theme.Palette.secondaryLabel)
                    }
                }
                .accessibilityIdentifier("grow.restart")
            }
        }
        .themeCard()
        if let ifthen = option.ifthen {
            GoalSection(title: "新的「如果就」")
            VStack(alignment: .leading, spacing: Theme.Space.small) {
                Text(ifthen).font(Theme.Typeface.quote).fixedSize(horizontal: false, vertical: true)
                Text("变成提醒，在这个时间叫你：").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                HStack {
                    if let suggested = option.remind {
                        Button(suggested.text, systemImage: "bell") { remind = .some(suggested) }
                            .buttonStyle(.bordered).tint(
                                remind == .some(suggested) ? Theme.Palette.accent : Theme.Palette.secondaryLabel)
                    }
                    Button("不用提醒") { remind = .some(nil) }.buttonStyle(.bordered)
                        .tint(remind == .some(nil) ? Theme.Palette.accent : Theme.Palette.secondaryLabel)
                }
            }
            .themeCard()
        }
        Button {
            model.applyGrow(goalId, key: option.key, restart: restart, remind: remind ?? nil, ifthen: option.ifthen)
            dismiss()
        } label: {
            Text("就这样").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent).accessibilityIdentifier("grow.apply")
        LinkButton("换一个办法", font: Theme.Typeface.subheadline) { step = 2 }.frame(maxWidth: .infinity)
    }

    // MARK: - 放下

    @ViewBuilder private func letgoView(_ page: API.GrowPage) -> some View {
        ai(page.ask, sub: page.askSub)
        mine("没那么重要了")
        ai("放下也是好结果，不算失败。它会放进「放下的」，以后想再试也行。", sub: "写一句为什么？可以不写")
        chips(page.letgoWhys) { letgoWhy = $0 }
        TextField("为什么放下（可以不写）", text: $letgoWhy).font(Theme.Typeface.quote)
            .padding(Theme.Space.medium)
            .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Corner.chip, style: .continuous))
            .accessibilityIdentifier("grow.letgo.why")
        HStack {
            Button {
                model.goalAct(goalId, "letgo", why: letgoWhy.isEmpty ? nil : letgoWhy)
                dismiss()
            } label: {
                Text("放下").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).accessibilityIdentifier("grow.letgo")
            Button {
                letgo = false
                step = 0
            } label: {
                Text("再想想").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - 气泡

    private func ai(_ text: String, sub: String?) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            Text(text).font(Theme.Typeface.body).fixedSize(horizontal: false, vertical: true)
            if let sub { Text(sub).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel) }
        }
        .padding(Theme.Space.medium)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Corner.bubble, style: .continuous))
        .padding(.trailing, Theme.Size.touch)
    }

    private func mine(_ text: String) -> some View {
        HStack {
            Spacer(minLength: Theme.Size.touch)
            Text(text).font(Theme.Typeface.quote).padding(Theme.Space.medium)
                .background(
                    Theme.Palette.bubble, in: RoundedRectangle(cornerRadius: Theme.Corner.bubble, style: .continuous))
        }
    }

    private func chips(_ items: [String], pick: @escaping (String) -> Void) -> some View {
        PourFlowLayout(spacing: Theme.Space.small) {
            ForEach(items, id: \.self) { item in
                Button(item) { withAnimation(Theme.Motion.standard) { pick(item) } }.buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("grow.chip.\(item)")
            }
        }
    }
}
