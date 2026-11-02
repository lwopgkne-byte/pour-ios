import PourAPI
import PourDesign
import SwiftUI

/// 关于我（docs/3.0/01-需求文档.md 第 10 章、06 交互细节 10.6）：头一句；你的生活由什么组成；时间去向；这周的新发现；
/// 换个角度看你；好日子的配方；你没注意到的变化；说的和做的；Pour 认识的（六行，点进那一页）；还在攒的；你的 2026。
/// 一块一张卡片，方法说明收在标题旁的 ⓘ；数字、句子都是服务器算好的
struct AboutHomePage: View {
    @Environment(AppModel.self) private var model
    @State private var page: API.MeHomePage?
    @State private var care: API.MeCare?
    @State private var known: API.Known?
    @State private var problem: String?

    var body: some View {
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
        .navigationTitle("关于我")
        .refreshable { await load() }
        .task(id: model.dataVersion) { await load() }
    }

    @ViewBuilder private func content(_ page: API.MeHomePage) -> some View {
        if !page.caption.isEmpty {
            Text(Show.spaced(page.caption)).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                .accessibilityIdentifier("about.caption")
        }
        if page.composition.total == 0 {
            Text("Pour 还在认识你。多说几天，这里会慢慢长出来：你的生活由什么组成、你和谁在一起、什么样的日子心情好。")
                .font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label).fixedSize(
                    horizontal: false, vertical: true
                )
                .themeCard()
        } else {
            CompositionCard(composition: page.composition)
            TimeGoneCard()
        }
        if !page.findings.isEmpty { FindingsStrip(findings: page.findings) { vote($0, $1) } }
        if !page.angles.isEmpty { AngleGrid(angles: page.angles) }
        if let recipe = page.recipe { RecipeCard(recipe: recipe) }
        if !page.changes.isEmpty { ChangeCards(changes: page.changes) }
        if let care { CareCard(care: care) { await load() } }
        if let known { KnownSummaryCard(known: known) }
        if !page.waiting.isEmpty { WaitingCard(items: page.waiting) }
        YearCard(year: String(model.today.prefix(4)))
        AboutFoot()
    }

    private func vote(_ key: String, _ vote: String?) {
        let client = model.client
        Task {
            do {
                try await client.vote(about: key, vote)
                await load()
            } catch {
                model.toast(error.readable)
            }
        }
    }

    private func load() async {
        do {
            page = try await model.client.meHome()
            problem = nil
            care = try? await model.client.meCare()
            known = try? await model.client.known()
        } catch {
            problem = error.readable
        }
    }
}

/// Pour 认识的：一行一类（作息、常做的事、人和关系、常去的地方、你的说法、改过的名字），点进「Pour 认识的」那一页
struct KnownSummaryCard: View {
    @Environment(AppModel.self) private var model
    let known: API.Known

    var body: some View {
        AboutSection(title: "Pour 认识的", meta: "你说过的为准，不对就点「不对」")
        VStack(spacing: 0) {
            let rows = Self.rows(known)
            ForEach(Array(rows.enumerated()), id: \.element.key) { index, row in
                if index > 0 { Divider() }
                AboutLinkRow(title: row.title, sub: row.sub, identifier: "about.known.\(row.key)") {
                    model.open("/about/known#\(row.key)")
                }
            }
        }
        .padding(.horizontal, Theme.Space.inset)
        .themeCard(padding: 0)
    }

    /// 一类一行
    struct Row: Hashable {
        let key: String
        let title: String
        let sub: String

        init(_ key: String, _ title: String, _ sub: String) {
            self.key = key
            self.title = title
            self.sub = sub
        }
    }

    /// 每一类一句：有的才列
    static func rows(_ known: API.Known) -> [Row] {
        var out: [Row] = []
        if let sleep = known.sleep { out.append(Row("sleep", "作息", "多在 \(sleep.bed) 前后睡、\(sleep.wake) 前后起")) }
        if !known.habits.isEmpty {
            out.append(Row("habits", "常做的事", known.habits.prefix(4).map(\.name).joined(separator: "、")))
        }
        let people = known.people.filter { !$0.titled || $0.relation != nil }
        if !people.isEmpty {
            let first = people.first { $0.relation != nil }
            let lead = first.map { "\($0.name) · \($0.relation?.meaning ?? "") 等 " } ?? ""
            out.append(Row("people", "人和关系", "\(lead)\(known.people.count) 个人"))
        }
        if !known.places.isEmpty {
            out.append(Row("places", "常去的地方", known.places.prefix(5).map(\.name).joined(separator: "、")))
        }
        if !known.sayings.isEmpty {
            out.append(
                Row(
                    "sayings", "你的说法",
                    known.sayings.prefix(3).map { "\($0.phrase) = \($0.meaning)" }.joined(separator: " · ")
                ))
        }
        if !known.hidden.isEmpty { out.append(Row("names", "改过的名字", "\(known.hidden.count) 个")) }
        return out
    }
}

/// 还在攒的：一样一行，写还差多少
struct WaitingCard: View {
    let items: [API.MeWaiting]

    var body: some View {
        AboutSection(title: "还在攒的")
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.key) { index, item in
                if index > 0 { Divider() }
                VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                    Text(item.name).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                    Text(Show.spaced(item.text)).font(Theme.Typeface.footnote).foregroundStyle(
                        Theme.Palette.secondaryLabel
                    )
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, Theme.Space.small)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, Theme.Space.inset)
        .themeCard(padding: 0)
    }
}

/// 你的 2026：一年每天一格、说得最多的、和谁在一起最多（入口一直在，记得够不够由那一页自己说）
struct YearCard: View {
    @Environment(AppModel.self) private var model
    let year: String

    var body: some View {
        Button {
            model.open("/about/year")
        } label: {
            HStack(spacing: Theme.Space.medium) {
                Image(systemName: "flag.fill").font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.onAccent)
                    .frame(width: Theme.Size.hubIcon, height: Theme.Size.hubIcon)
                    .background(
                        Theme.Palette.good, in: RoundedRectangle(cornerRadius: Theme.Corner.chip, style: .continuous))
                VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                    Text("你的 \(year)").font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                    Text("一年每天一格、说得最多的、和谁在一起最多").font(Theme.Typeface.footnote)
                        .foregroundStyle(Theme.Palette.secondaryLabel).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(Theme.Typeface.footnoteSemibold)
                    .foregroundStyle(Theme.Palette.tertiaryLabel)
            }
            .themeCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("about.year")
        .padding(.top, Theme.Space.small)
    }
}
