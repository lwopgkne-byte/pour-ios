import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 3.0 回顾页（01 需求文档第 8 章、06 交互细节第 6 节）：分段「每天 · 每周 · 每月」；「每天」最上面是「需要留意」
/// （浅黄底，有才出现，「知道了」收起）；一篇一张卡：日期、一句话、几个数的小胶囊；没看过的粗体带「新」（不打红点），
/// 重写过的「已更新」。点一张打开全屏的故事（最后「看整页」才是长页面）
struct ReviewListPage: View {
    @Environment(AppModel.self) private var model
    @AppStorage("pour.review.tab") private var tab = "day"
    @State private var pages: [String: API.ReviewListPage] = [:]
    @State private var problem: String?
    /// 这次点开过的（马上变成看过的样子）、「知道了」收起的预警
    @State private var opened: Set<Int> = []
    @State private var dismissed: Set<Int> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.cardGap) {
                Picker("看哪一种", selection: $tab) {
                    Text("每天").tag("day")
                    Text("每周").tag("week")
                    Text("每月").tag("month")
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("review.tabs")
                if let page = pages[tab] {
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
        .refreshable { await load() }
        .task(id: "\(tab)-\(model.dataVersion)") { await load() }
    }

    @ViewBuilder private func content(_ page: API.ReviewListPage) -> some View {
        if let attention = page.attention, !Set(attention.ids).isSubset(of: dismissed) {
            AttentionCard(lines: attention.lines) { dismiss(attention) }
        }
        if page.items.isEmpty {
            Text(empty).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.secondaryLabel)
                .padding(.top, Theme.Space.large)
        }
        ForEach(page.items) { card in
            ReviewListCard(
                title: title(card), summary: Show.spaced(card.summary), chips: card.chips,
                read: card.read || opened.contains(card.id), updated: card.updated
            ) {
                open(card)
            }
            .accessibilityIdentifier("review.card.\(card.day ?? card.from ?? "\(card.id)")")
        }
    }

    private var empty: String {
        switch tab {
        case "week": "还没有周报。每周一早上，Pour 把上一周整理成一篇放在这里。"
        case "month": "还没有月报。每个月 1 号早上，Pour 把上个月整理成一篇放在这里。"
        default: "还没有回顾。今天说过的话，明天早上会整理成一篇放在这里。"
        }
    }

    /// 「昨天 · 11月1日 周日」；周报月报用服务器写的（「10月26日–11月1日 周报」）
    private func title(_ card: API.ReviewCard) -> String {
        guard let day = card.day else { return Show.spaced(card.title) }
        let title = Show.dayTitle(day, today: model.today)
        return Show.relative(day, today: model.today).map { "\($0) · \(title)" } ?? title
    }

    /// 点一张：算看过，打开故事
    private func open(_ card: API.ReviewCard) {
        opened.insert(card.id)
        if !card.read {
            let client = model.client
            Task { try? await client.markRead(message: card.id) }
        }
        if card.kind == "daily", let day = card.day {
            model.review.story = ReviewStoryRef(kind: "daily", day: day)
        } else if let from = card.from {
            model.review.story = ReviewStoryRef(kind: card.kind, day: from)
        }
    }

    /// 需要留意的「知道了」：这几条预警都算看过，卡片收起
    private func dismiss(_ attention: API.ReviewAttention) {
        withAnimation(Theme.Motion.standard) { dismissed.formUnion(attention.ids) }
        let client = model.client
        Task {
            for id in attention.ids { try? await client.markRead(message: id) }
        }
    }

    private func load() async {
        let tab = self.tab
        if pages[tab] == nil, let saved: API.ReviewListPage = model.client.cached(APIClient.reviewListPath(tab)) {
            pages[tab] = saved
        }
        do throws(APIError) {
            pages[tab] = try await model.client.reviewList(tab)
            problem = nil
        } catch {
            if pages[tab] == nil { problem = error.message }
        }
    }
}
