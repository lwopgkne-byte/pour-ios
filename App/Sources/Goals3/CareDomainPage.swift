import PourAPI
import PourDesign
import SwiftUI

/// 我在乎的一块（docs/3.0/01-需求文档.md 9.9、06 交互细节 12.9）：上面四块——我想成为（点头才算）、这一块的目标、
/// 在乎和投入（打的分和最近 30 天花的时间，只是放在一起看）、这个季度打几分；下面是「关于我」里原来就有的那一块（第 8 步重做）。
/// 钱这一块只有四块 +「钱的明细在『钱』里」
struct CareDomainPage: View {
    @Environment(AppModel.self) private var model
    let key: String
    @State private var page: API.CareDomain?
    @State private var problem: String?
    @State private var sources = false
    @State private var writing = false
    @State private var draft = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.cardGap) {
                if let page {
                    wish(page)
                    goals(page)
                    invest(page)
                    score(page)
                    below(page)
                } else if let problem {
                    ErrorState(problem.contains("连") ? .serverOff : .other) { Task { await load() } }
                } else {
                    ProgressView().frame(maxWidth: .infinity, minHeight: Theme.Size.goalCard)
                }
            }
            .padding(.horizontal, Theme.Space.screen)
            .padding(.bottom, Theme.Space.xLarge)
        }
        .navigationTitle(page?.area.name ?? "我在乎的")
        .refreshable { await load() }
        .task(id: model.dataVersion) { await load() }
    }

    // MARK: - 我想成为

    @ViewBuilder private func wish(_ page: API.CareDomain) -> some View {
        GoalSection(title: "我想成为……")
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            if writing {
                writer
            } else if let wish = page.wish {
                Text(wish.text).font(Theme.Typeface.quoteLarge).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("care.wish")
                if wish.agreed {
                    LinkButton("你点过头的 · 改", identifier: "care.wish.edit") { startWriting(wish.text) }
                } else {
                    nod(wish)
                }
            } else {
                Text("还没有。说说你想成为什么样的人，或者自己写一句。").font(Theme.Typeface.body)
                    .foregroundStyle(Theme.Palette.secondaryLabel)
                Button("我自己写") { startWriting("") }.buttonStyle(.bordered)
            }
        }
        .themeCard()
    }

    /// 自己写一句：原地变输入框 +「好」
    @ViewBuilder private var writer: some View {
        TextField("我想成为……", text: $draft, axis: .vertical).font(Theme.Typeface.quoteLarge).lineLimit(1...3)
            .submitLabel(.done)
            // 一句话：按「完成」（换行）就是写好了
            .onChange(of: draft) { _, now in
                guard now.contains("\n") else { return }
                draft = now.replacingOccurrences(of: "\n", with: "")
                saveWish()
            }
            .accessibilityIdentifier("care.wish.field")
        Button("好") { saveWish() }
            .buttonStyle(.borderedProminent)
    }

    private func saveWish() {
        writing = false
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        Task {
            try? await model.client.careWish(key, text: text, agreed: true)
            await load()
        }
    }

    /// 还没点头：看原话、「对，就这句」「我自己写」
    @ViewBuilder private func nod(_ wish: API.CareWish) -> some View {
        LinkButton(sources ? "收起原话" : "AI 从你说过的话里提的一句，你点头才算 · 看原话", identifier: "care.wish.sources") {
            withAnimation(Theme.Motion.standard) { sources.toggle() }
        }
        if sources {
            ForEach(wish.sources, id: \.self) { source in
                VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                    Text(source.text).font(Theme.Typeface.quote)
                    Text("\(Show.monthDay(source.day)) 你说的").font(Theme.Typeface.footnote)
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                }
            }
        }
        HStack {
            Button("对，就这句") {
                Task {
                    try? await model.client.careWish(key, text: nil, agreed: true)
                    await load()
                }
            }
            .buttonStyle(.borderedProminent).accessibilityIdentifier("care.wish.yes")
            Button("我自己写") { startWriting(wish.text) }.buttonStyle(.bordered)
        }
    }

    private func startWriting(_ text: String) {
        draft = text
        writing = true
    }

    // MARK: - 这一块的目标

    @ViewBuilder private func goals(_ page: API.CareDomain) -> some View {
        GoalSection(title: page.goals.isEmpty ? "\(page.area.name)的目标" : "\(page.area.name)的目标 · \(page.goals.count) 个")
        VStack(alignment: .leading, spacing: 0) {
            if page.goals.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Space.small) {
                    if let empty = page.empty {
                        Text("还没有目标。\(empty.from)，要定成「\(empty.title)」吗？").font(Theme.Typeface.body)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("定这个") { model.goals.sheet = .define(empty.title) }.buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("care.suggest")
                    } else {
                        Text("还没有目标。").font(Theme.Typeface.body)
                        Button("定一个") { model.goals.sheet = .define(nil) }.buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, Theme.Space.medium)
            }
            ForEach(Array(page.goals.enumerated()), id: \.element.id) { index, card in
                if index > 0 { Divider() }
                GoalRow(card: card).contextMenu { GoalMenu(card: card) }
            }
        }
        .padding(.horizontal, Theme.Space.inset)
        .themeCard(padding: 0)
    }

    // MARK: - 在乎和投入

    @ViewBuilder private func invest(_ page: API.CareDomain) -> some View {
        GoalSection(title: "在乎和投入")
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            Text(page.invest.line).font(Theme.Typeface.body).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("care.invest")
            HStack(spacing: Theme.Space.medium) {
                legend(Theme.Palette.accent, "在乎（打的分）")
                legend(Theme.Palette.tertiaryLabel, "投入（最近 30 天）")
            }
            let most = Double(page.invest.rows.map(\.minutes).max() ?? 1)
            ForEach(page.invest.rows) { row in
                InvestRow(
                    name: row.name, score: row.score, value: row.value, time: most > 0 ? Double(row.minutes) / most : 0,
                    mine: row.mine)
            }
            Text(page.invest.foot).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
        .themeCard()
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: Theme.Space.tight) {
            Capsule().fill(color).frame(width: Theme.Space.regular, height: Theme.Size.bar)
            Text(text).font(Theme.Typeface.tick).foregroundStyle(Theme.Palette.secondaryLabel)
        }
    }

    // MARK: - 这个季度打几分

    @ViewBuilder private func score(_ page: API.CareDomain) -> some View {
        GoalSection(title: "这个季度打几分", meta: page.score.prev.map { "上个季度 \($0) 分" })
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            HStack(spacing: Theme.Space.tight) {
                ForEach(1...10, id: \.self) { value in
                    Button {
                        model.careScore(key, value)
                    } label: {
                        Text("\(value)").font(Theme.Typeface.footnoteSemibold).monospacedDigit()
                            .foregroundStyle(page.score.value == value ? Theme.Palette.onAccent : Theme.Palette.label)
                            .frame(maxWidth: .infinity, minHeight: Theme.Size.touch)
                            .background(
                                page.score.value == value ? Theme.Palette.accentFill : Theme.Palette.fill,
                                in: RoundedRectangle(cornerRadius: Theme.Corner.chip, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("\(value) 分"))
                    .accessibilityAddTraits(page.score.value == value ? .isSelected : [])
                    .accessibilityIdentifier("care.score.\(value)")
                }
            }
            Text(page.score.foot).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
        .themeCard()
    }

    // MARK: - 下面

    @ViewBuilder private func below(_ page: API.CareDomain) -> some View {
        Button {
            if page.money {
                model.open("/money")
            } else if let first = page.area.categories?.first {
                model.open("/about/domain/\(first)")
            } else {
                model.open("/about")
            }
        } label: {
            HStack {
                Text(page.money ? "钱的明细、预算、留意的 · 都在「钱」里" : "「关于我」里原来就有的\(page.area.name)：每一天、什么时候、心情……")
                    .font(Theme.Typeface.body).multilineTextAlignment(.leading).fixedSize(
                        horizontal: false, vertical: true)
                Spacer()
                Image(systemName: "chevron.right").font(Theme.Typeface.footnote)
            }
            .foregroundStyle(Theme.Palette.accent)
            .themeCard()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("care.below")
    }

    private func load() async {
        do throws(APIError) {
            page = try await model.client.careDomain(key)
            problem = nil
        } catch {
            if page == nil { problem = error.message }
        }
    }
}
