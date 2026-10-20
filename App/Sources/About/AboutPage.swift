import PourAPI
import PourDesign
import SwiftUI

/// 关于我（网页版 about/*.tsx，docs/prd-about-me-2.md）：主页和点进去的几页（心情、人、你说的话、你的一年、一块生活）
struct AboutPage: View {
    @Environment(AppModel.self) private var model
    @State private var route = AboutRoute.home

    var body: some View {
        Group {
            switch route {
            case .home: AboutHome(navigate: navigate)
            case .mood: AboutMoodView(navigate: navigate)
            case .people: AboutPeopleView(navigate: navigate)
            case .talk: AboutTalkView(navigate: navigate)
            case .year(let year): AboutYearView(year: year ?? Int(model.today.prefix(4)) ?? 2026, navigate: navigate)
            case .domain(let key): AboutDomainView(key: key, navigate: navigate)
            }
        }
        .id(route)
        .onAppear { follow(model.pagePath) }
        .onChange(of: model.pagePath) { _, path in follow(path) }
    }

    /// 换到网页版的一个地址：关于我里的留在这儿，别的（钱、笔记库）交给外面
    private func navigate(_ path: String) {
        guard let next = AboutRoute(path) else {
            model.open(path)
            return
        }
        withAnimation(Web.panel) { route = next }
    }

    private func follow(_ path: String?) {
        guard let path, path.hasPrefix("/about"), let next = AboutRoute(path) else { return }
        model.pagePath = nil
        route = next
    }
}

/// 关于我里的一页
enum AboutRoute: Hashable {
    case home, mood, people, talk
    /// nil 是今年
    case year(Int?)
    case domain(String)

    /// 「/about」「/about/mood」「/about/people」「/about/talk」「/about/year」「/about/domain/diet」
    init?(_ path: String) {
        let clean = path.split(separator: "?").first.map(String.init) ?? path
        let parts = clean.split(separator: "/").map { String($0).removingPercentEncoding ?? String($0) }
        guard parts.first == "about" else { return nil }
        switch (parts.count, parts.dropFirst().first) {
        case (1, _): self = .home
        case (2, "mood"): self = .mood
        case (2, "people"): self = .people
        case (2, "talk"): self = .talk
        case (2, "year"): self = .year(nil)
        case (3, "year"): self = .year(Int(parts[2]))
        case (3, "domain"): self = .domain(parts[2])
        default: return nil
        }
    }
}

/// 「关于我」主页（网页版 AboutPage.tsx）：你的生活由什么组成、时间去向、这周的新发现、换个角度看你、好日子的配方、
/// 你没注意到的变化、说的和做的、还在攒的、你的一年。数字、句子都是服务器算好的
private struct AboutHome: View {
    @Environment(AppModel.self) private var model
    let navigate: (String) -> Void
    @State private var page: API.MeHomePage?
    @State private var care: API.MeCare?
    @State private var known = KnownStore()
    @State private var problem: String?

    var body: some View {
        Group {
            if let page {
                content(page)
            } else if let problem {
                WebErrorState(problem) { Task { await load() } }
            } else {
                ReviewSkeleton()
            }
        }
        .moneyPage()
        .task(id: model.dataVersion) { await load() }
        .task(id: model.dataVersion) { await known.load(model.client) }
        .sheet(item: $known.opened) { KnownPeek(store: known, key: $0.id) }
    }

    @ViewBuilder private func content(_ page: API.MeHomePage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Web.space1) {
                Text("关于我").font(Web.title).foregroundStyle(Web.fg).accessibilityAddTraits(.isHeader)
                if !page.caption.isEmpty { MeNote(page.caption) }
            }
            if page.composition.total == 0 {
                Text("Pour 还在认识你。多说几天，这里会慢慢长出来：你的生活由什么组成、你和谁在一起、什么样的日子心情好。")
                    .font(Web.body).foregroundStyle(Web.fg).padding(.top, Web.space8)
            } else {
                MeComposition(composition: page.composition, navigate: navigate)
                TimeGone()
            }
            if !page.findings.isEmpty {
                ReviewSection(title: "这周的新发现") {
                    VStack(spacing: Web.space3) {
                        ForEach(page.findings, id: \.key) { finding in
                            FindingCard(
                                finding: finding,
                                openDay: { day in
                                    model.page = .canvas
                                    model.show(day)
                                }, vote: { vote(finding.key, $0) })
                        }
                    }
                }
            }
            if !page.angles.isEmpty {
                ReviewSection(title: "换个角度看你") { MeAngles(angles: page.angles, navigate: navigate) }
            }
            if let recipe = page.recipe { ReviewSection(title: "好日子的配方") { MeRecipeView(recipe: recipe) } }
            if !page.changes.isEmpty {
                ReviewSection(title: "你没注意到的变化") { MeChanges(changes: page.changes, navigate: navigate) }
            }
            if let care { MeCareView(care: care) { await load() } }
            if let about = known.about,
                !about.sayings.isEmpty || !about.places.isEmpty
                    || about.people.contains(where: { $0.relation != nil && !$0.titled })
            {
                ReviewSection(title: "Pour 认识的") {
                    VStack(alignment: .leading, spacing: Web.space6) {
                        KnownPeople(store: known, onlyRelations: true)
                        KnownPlaces(store: known)
                        KnownSayings(store: known)
                    }
                }
            }
            if !page.waiting.isEmpty { waiting(page.waiting) }
            yearLink
            MeFoot()
        }
    }

    /// 还在攒的：每样什么时候能看
    private func waiting(_ items: [API.MeWaiting]) -> some View {
        ReviewSection(title: "还在攒的") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.key) { index, item in
                    VStack(alignment: .leading, spacing: Web.space1) {
                        Text(item.name).font(Web.body).foregroundStyle(Web.fg)
                        MeNote(item.text)
                    }
                    .padding(.vertical, Web.space2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .bottom) {
                        if index < items.count - 1 { Rectangle().fill(Web.line).frame(height: 1) }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    /// 你的一年：入口一直在，记得够不够由那一页自己说
    private var yearLink: some View {
        Button {
            navigate("/about/year")
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: Web.space3) {
                Text("你的 \(model.today.prefix(4))").font(Web.bodySemibold).foregroundStyle(Web.fg)
                Spacer(minLength: 0)
                Text("一年每天一格、说得最多的、和谁在一起最多").font(Web.caption).foregroundStyle(Web.fgTertiary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, Web.space3).padding(.vertical, Web.space2)
            .frame(minHeight: Web.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(WebPressStyle(radius: Web.radiusCard))
        .overlay(RoundedRectangle(cornerRadius: Web.radiusCard).strokeBorder(Web.line, lineWidth: 1))
        .padding(.top, Web.space6)
        .accessibilityElement(children: .combine)
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
        } catch {
            problem = error.readable
        }
    }
}
