import PourAPI
import PourDesign
import SwiftUI

/// 关于我（docs/prd-about-me-2.md）：主页和点进去的几页（心情、人、你说的话、你的一年、一块生活）。
/// 3.0 外壳（第 1 步）：一个地址一页，点进去的推进导航栈（AppModel.open）
struct AboutPage: View {
    @Environment(AppModel.self) private var model
    let route: AboutRoute
    /// 地址里带着的「Pour 认识的」那一条（?item=person:小王），或者只知道一个词（?find=老地方：对话里「记住了」的链接）
    @State private var ask: KnownAsk?

    init(route: AboutRoute, ask: KnownAsk?) {
        self.route = route
        _ask = State(initialValue: ask)
    }

    var body: some View {
        switch route {
        // 「/about?item=person:小王」（对话里「记住了」的链接）：Pour 认识的那一页打开那一条
        case .home where ask != nil: AboutKnownPage(anchor: nil, ask: ask)
        case .home: AboutHomePage()
        case .known(let anchor): AboutKnownPage(anchor: anchor, ask: ask)
        case .person(let name): AboutPersonPage(name: name)
        case .people: AboutPeoplePage()
        case .talk: AboutTalkView(navigate: navigate)
        case .year(let year): AboutYearView(year: year ?? Int(model.today.prefix(4)) ?? 2026, navigate: navigate)
        case .domain(let key): AboutDomainView(key: key, navigate: navigate)
        }
    }

    /// 换到一个页面地址（关于我里互相跳、去钱、去笔记库）
    private func navigate(_ path: String) {
        model.open(path)
    }
}

/// 关于我里的一页
enum AboutRoute: Hashable {
    case home, people, talk
    /// nil 是今年
    case year(Int?)
    case domain(String)
    /// 一个人（3.0 第 8 步）
    case person(String)
    /// Pour 认识的（3.0 第 8 步，以前摊在主页上）；带着要滚到的那一块（「/about/known#people」）
    case known(String?)

    /// 「/about」「/about/people」「/about/talk」「/about/year」「/about/domain/diet」
    /// （「/about/mood」3.0 第 4 步起是心情分析，Route 里先认了）
    init?(_ path: String, anchor: String? = nil) {
        let clean = path.split(separator: "?").first.map(String.init) ?? path
        let parts = clean.split(separator: "/").map { String($0).removingPercentEncoding ?? String($0) }
        guard parts.first == "about" else { return nil }
        switch (parts.count, parts.dropFirst().first) {
        case (1, _): self = .home
        case (2, "people"): self = .people
        case (2, "talk"): self = .talk
        case (2, "year"): self = .year(nil)
        case (3, "year"): self = .year(Int(parts[2]))
        case (3, "domain"): self = .domain(parts[2])
        case (3, "person"): self = .person(parts[2])
        case (2, "known"): self = .known(anchor)
        default: return nil
        }
    }
}

/// 地址里要打开的「Pour 认识的」那一条
struct KnownAsk: Hashable {
    var item: String?
    var find: String?
}
