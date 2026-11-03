import PourAPI
import PourDesign
import SwiftUI

/// 3.0 定目标（docs/3.0/01-需求文档.md 9.5、06 交互细节 12.5）：说一句 → 在听懂 → 问一句 → 理解卡 → 定好了（环转一下 +「花 1 分钟想清楚」）。
/// 模糊的先问再拆、「不要」的给一个「去做」的、已经有的不重复建（数不一样问要不要改）；常用的只列还没有的；或者一项一项填
struct GoalDefineSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let preset: String?
    @State private var text = ""
    @State private var said: String?
    @State private var thinking = false
    @State private var result: API.GoalUnderstand?
    @State private var made: API.GoalMade?
    @State private var madeTitle = ""
    @State private var care: String?
    @State private var areas: [API.CareArea] = []
    @State private var existing: Set<String> = []
    @State private var form = false
    @State private var done = 0

    private static let common = [
        "每天走 8000 步", "平均睡 7.5 小时", "每月外卖不超过 300 元", "读完一本书", "每天 11 点前睡", "每周陪儿子出去玩 2 次", "每周运动 3 次",
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.medium) {
                    if let made {
                        GoalMadeView(made: made, title: madeTitle, close: finish)
                    } else {
                        if result == nil && !thinking { input }
                        if let said { bubble(said, mine: true) }
                        if thinking { bubble("✦ 在听懂…", mine: false) }
                        if let result {
                            GoalUnderstandView(
                                result: result, care: $care, areas: areas, say: understand, accept: accept, again: reset
                            )
                        }
                    }
                }
                .padding(Theme.Space.screen)
            }
            .background(Theme.Palette.background)
            .navigationTitle("定目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }.accessibilityIdentifier("define.close")
                }
            }
            .sheet(isPresented: $form) { GoalForm() }
        }
        .sensoryFeedback(Theme.Haptics.done, trigger: done)
        .task {
            areas = (try? await model.client.care())?.areas ?? []
            let home: API.GoalsHome? = model.client.cached(APIClient.goalsHomePath)
            existing = Set((home?.groups.flatMap(\.cards) ?? []).map(\.title) + (home?.streaks ?? []).map(\.title))
            if let preset { understand(preset) }
        }
    }

    // MARK: - 说一句

    private var input: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            HStack(spacing: Theme.Space.small) {
                TextField("说一句你想做到的", text: $text, axis: .vertical).font(Theme.Typeface.quote).lineLimit(1...4)
                    .submitLabel(.send).onSubmit { understand(text) }
                    // 能折行的输入框按「发送」是换行（不走 onSubmit）：换行就当发出去
                    .onChange(of: text) { _, now in
                        guard now.contains("\n") else { return }
                        text = now.replacingOccurrences(of: "\n", with: "")
                        understand(text)
                    }
                    .accessibilityIdentifier("define.field")
                Button {
                    understand(text)
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(Theme.Typeface.section)
                }
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel(Text("发送"))
                .accessibilityIdentifier("define.send")
            }
            .padding(Theme.Space.medium)
            .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Corner.chip, style: .continuous))
            let common = Self.common.filter { !existing.contains($0) }
            if !common.isEmpty {
                Text("常用的").font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.secondaryLabel)
                PourFlowLayout(spacing: Theme.Space.small) {
                    ForEach(common, id: \.self) { item in
                        Button(item) { understand(item) }.buttonStyle(.bordered).font(Theme.Typeface.subheadline)
                    }
                }
            }
            LinkButton("或者一项一项填 ›", font: Theme.Typeface.subheadline, identifier: "define.form") { form = true }
        }
    }

    private func bubble(_ text: String, mine: Bool) -> some View {
        HStack {
            if mine { Spacer(minLength: Theme.Size.touch) }
            Text(text).font(mine ? Theme.Typeface.quote : Theme.Typeface.body)
                .foregroundStyle(mine ? Theme.Palette.label : Theme.Palette.secondaryLabel)
                .padding(.horizontal, Theme.Space.medium).padding(.vertical, Theme.Space.small)
                .background(
                    mine ? Theme.Palette.bubble : Theme.Palette.card,
                    in: RoundedRectangle(cornerRadius: Theme.Corner.bubble, style: .continuous))
            if !mine { Spacer(minLength: Theme.Size.touch) }
        }
    }

    // MARK: - 听懂、定好

    private func understand(_ sentence: String) {
        let sentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sentence.isEmpty else { return }
        said = sentence
        result = nil
        thinking = true
        Task {
            do throws(APIError) {
                let out = try await model.client.understandGoal(sentence)
                care = out.plan?.care ?? out.children?.first?.care
                withAnimation(Theme.Motion.standard) {
                    result = out
                    thinking = false
                }
            } catch {
                thinking = false
                model.toast(error.message)
            }
        }
    }

    /// 点「对」：建（模糊的连同子目标一起），环转一下、轻触感
    private func accept(_ plans: [API.GoalPlanView], _ parent: String?) {
        guard let first = plans.first else { return }
        Task {
            do throws(APIError) {
                let out = try await model.client.planGoal(
                    first.operation, care: care, children: parent != nil ? plans.map(\.operation) : nil, title: parent)
                madeTitle = parent ?? first.title
                model.goals.fresh = out.id
                model.dataChanged()
                done += 1
                withAnimation(Theme.Motion.spring) { made = out }
            } catch {
                model.toast(error.message)
            }
        }
    }

    private func reset() {
        result = nil
        said = nil
        text = ""
    }

    private func finish(_ woop: Bool) {
        dismiss()
        guard woop, let made else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            model.goals.sheet = .woop(made.id, step: nil)
        }
    }
}

/// 定好了：大环转一下（中间写名字）、「定好了 · 在『坚持』里 · 我在乎的：关系」；大目标问一次「花 1 分钟想清楚？」
struct GoalMadeView: View {
    let made: API.GoalMade
    let title: String
    let close: (Bool) -> Void

    var body: some View {
        VStack(spacing: Theme.Space.medium) {
            GoalRing(state: .onTrack, progress: 1, label: "", size: Theme.Size.bigRing, spinIn: true)
            Text(title).font(Theme.Typeface.section).multilineTextAlignment(.center)
            Text(made.line).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("define.made")
            if made.big {
                VStack(alignment: .leading, spacing: Theme.Space.small) {
                    Text("大目标，花 1 分钟想清楚？").font(Theme.Typeface.bodySemibold)
                    Text("为什么想要 · 最可能拦住你的 · 如果……就……；当面一问一答，比自己填表更容易做到")
                        .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel).fixedSize(
                            horizontal: false, vertical: true)
                    HStack {
                        Button("好，现在想") { close(true) }.buttonStyle(.borderedProminent).accessibilityIdentifier(
                            "define.woop")
                        Button("以后再说") { close(false) }.buttonStyle(.bordered)
                    }
                }
                .themeCard()
            } else {
                LinkButton("花 1 分钟想清楚，更容易做到 ›", font: Theme.Typeface.subheadline) { close(true) }
                Button("好") { close(false) }.buttonStyle(.borderedProminent).accessibilityIdentifier("define.ok")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Space.xLarge)
    }
}
