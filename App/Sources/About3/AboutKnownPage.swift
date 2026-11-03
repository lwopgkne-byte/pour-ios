import PourAPI
import PourDesign
import SwiftUI

/// Pour 认识的（docs/3.0/06-交互细节.md 10.6，以前摊在关于我主页上）：作息、常做的事、人和关系、常去的地方、你的说法、
/// 改过的名字、我的语录。每一句点开能说「对 / 不对」（能撤销）；「/about/known#people」进来滚到那一块；
/// 对话里「记住了」的链接（「/about?item=person:小王」「?find=老地方」）进来打开那一条
struct AboutKnownPage: View {
    @Environment(AppModel.self) private var model
    let anchor: String?
    @State var ask: KnownAsk?
    @State private var known = KnownStore()
    @State private var scrolled = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.cardGap) {
                    Text("整理你的话时，Pour 用这些认出你说的是谁、哪儿、哪件事。不对就点「不对」，能撤销。")
                        .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                    if known.about != nil {
                        KnownSleep(store: known).id("sleep")
                        KnownHabits(store: known).id("habits")
                        KnownPeople(store: known).id("people")
                        KnownPlaces(store: known).id("places")
                        KnownSayings(store: known).id("sayings")
                        KnownNames().id("names")
                        KnownQuotes().id("quotes")
                    } else {
                        ProgressView().frame(maxWidth: .infinity, minHeight: Theme.Size.goalCard)
                    }
                }
                .padding(.horizontal, Theme.Space.screen)
                .padding(.bottom, Theme.Space.xLarge)
            }
            .onChange(of: known.about != nil) { _, loaded in
                guard loaded, !scrolled, let anchor else { return }
                scrolled = true
                withAnimation(Theme.Motion.standard) { proxy.scrollTo(anchor, anchor: .top) }
            }
        }
        .navigationTitle("Pour 认识的")
        .task(id: model.dataVersion) { await known.load(model.client) }
        .sheet(item: $known.opened) { KnownPeek(store: known, key: $0.id) }
        // 地址里要打开的那一条：等拿回来再打开；找不到就停在这一页
        .onChange(of: "\(ask?.item ?? "")|\(ask?.find ?? "")|\(known.about != nil)", initial: true) {
            guard let wanted = ask, known.about != nil else { return }
            ask = nil
            if let key = wanted.item ?? wanted.find.flatMap(known.find) { known.open(key) }
        }
    }
}

/// 一个人（docs/3.0/06-交互细节.md 10.6，3.0 第 8 步新的一页）：多是做什么（带次数）、那些日子的心情、关系（你哪天说的那句原话、
/// 「添加关系」）、最近的记录（点了开那条记录）、在笔记库看和他有关的原话、花在他身上的钱、「不用列出」
struct AboutPersonPage: View {
    @Environment(AppModel.self) private var model
    let name: String
    @State private var page: API.MePersonPage?
    @State private var known = KnownStore()
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
        .navigationTitle(name)
        .refreshable { await load() }
        .task(id: model.dataVersion) { await load() }
        .sheet(item: $known.opened) { KnownPeek(store: known, key: $0.id) }
    }

    @ViewBuilder private func content(_ page: API.MePersonPage) -> some View {
        Text(page.sub).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            .accessibilityIdentifier("person.sub")
        if page.empty {
            Text("这几周没说到和\(name)在一起。").font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label).themeCard()
        }
        if !page.acts.isEmpty {
            AboutSection(title: "多是做什么")
            PourFlowLayout(spacing: Theme.Space.small) {
                ForEach(page.acts, id: \.name) { act in
                    Text("\(act.name)  \(act.count)").font(Theme.Typeface.subheadline).monospacedDigit()
                        .foregroundStyle(Theme.Palette.label)
                        .padding(.horizontal, Theme.Space.medium).padding(.vertical, Theme.Space.small)
                        .background(Theme.Palette.fill, in: Capsule())
                        .accessibilityLabel(Text("\(act.name) \(act.count) 天"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .themeCard()
        }
        if let mood = page.mood {
            AboutSection(title: "那些日子的心情")
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                Text(mood.title).font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                Text(mood.sub).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .themeCard()
            .accessibilityElement(children: .combine)
        }
        relation(page)
        if !page.recent.isEmpty { recent(page) }
        if let money = page.money {
            AboutSection(title: "花在\(name)身上的")
            AboutLinkRow(title: money.text, identifier: "person.money") { model.open("/money") }
                .padding(.horizontal, Theme.Space.inset).themeCard(padding: 0)
        }
        if let person = known.about?.people.first(where: { $0.name == name }) {
            LinkButton("不用列出\(name)", identifier: "person.hide") { known.open(person.key) }
        }
    }

    /// 关系：你说过的（「儿子 · 家人」+ 你哪天说的那句原话）；没说过的「添加关系」（打开 Pour 认识的那一条）
    @ViewBuilder private func relation(_ page: API.MePersonPage) -> some View {
        let person = known.about?.people.first { $0.name == name }
        AboutSection(title: "关系")
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text([name, page.relation ?? Self.groupName(page.group)].joined(separator: " · ")).font(Theme.Typeface.body)
                .foregroundStyle(Theme.Palette.label)
            if let note = person?.relation?.note {
                Text("你 \(Show.monthDay(String(note.at.prefix(10))))说的「\(note.text)」").font(Theme.Typeface.footnote)
                    .foregroundStyle(Theme.Palette.secondaryLabel).fixedSize(horizontal: false, vertical: true)
            }
            if let person {
                Button(person.relation == nil ? "添加关系" : "改关系") { known.open(person.key) }
                    .buttonStyle(.bordered).accessibilityIdentifier("person.relation")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themeCard()
    }

    private func recent(_ page: API.MePersonPage) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            AboutSection(title: "最近的记录")
            VStack(spacing: 0) {
                ForEach(Array(page.recent.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { Divider() }
                    AboutLinkRow(title: item.text, value: Show.monthDay(item.day), identifier: "person.recent") {
                        model.openEntry(item.entryId, day: item.day)
                    }
                }
                Divider()
                AboutLinkRow(title: "在笔记库看和\(name)有关的原话", identifier: "person.library") {
                    model.open(
                        "/library?q=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name)")
                }
            }
            .padding(.horizontal, Theme.Space.inset)
            .themeCard(padding: 0)
        }
    }

    static func groupName(_ group: String) -> String {
        switch group {
        case "family": "家人"
        case "work": "工作"
        default: "朋友和其他"
        }
    }

    private func load() async {
        do {
            page = try await model.client.mePerson(name)
            problem = nil
        } catch {
            problem = error.readable
        }
        await known.load(model.client)
    }
}
