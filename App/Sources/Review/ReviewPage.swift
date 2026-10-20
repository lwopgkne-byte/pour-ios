import PourAPI
import PourDesign
import SwiftUI

/// 「回顾」（docs/prd-review.md）：Pour 写给你的东西——每天的回顾、周报月报、预警。
/// 列表点一项打开那一篇；对话里的链接（/review/2026-10-18、/review/week/…、/review/month/…）直接打开那一篇
struct ReviewPage: View {
    @Environment(AppModel.self) private var model
    @State private var route: ReviewRoute?

    var body: some View {
        Group {
            switch route {
            case .daily(let day): DailyReviewView(day: day, navigate: navigate)
            case .period(let kind, let day): PeriodReviewView(kind: kind, day: day, navigate: navigate)
            case nil: ReviewList(navigate: navigate)
            }
        }
        .onAppear { follow(model.pagePath) }
        .onChange(of: model.pagePath) { _, path in follow(path) }
    }

    /// 换到一个页面地址（回顾里互相跳）
    private func navigate(_ path: String) {
        withAnimation(Web.panel) { route = ReviewRoute(path) }
    }

    private func follow(_ path: String?) {
        guard let path, path.hasPrefix("/review") else { return }
        model.pagePath = nil
        route = ReviewRoute(path)
    }
}

/// 回顾里的一篇：每日回顾，或者周报 / 月报（kind、那一期的第一天）
enum ReviewRoute: Equatable {
    case daily(String)
    case period(String, String)

    /// 「/review」是列表（nil）；「/review/2026-10-18」「/review/week/2026-10-12」「/review/month/2026-09」
    init?(_ path: String) {
        let parts = path.split(separator: "/").map(String.init)
        guard parts.first == "review", parts.count > 1 else { return nil }
        if parts.count == 3, parts[1] == "week" {
            self = .period("weekly", parts[2])
        } else if parts.count == 3, parts[1] == "month" {
            self = .period("monthly", "\(parts[2])-01")
        } else if parts.count == 2 {
            self = .daily(parts[1])
        } else {
            return nil
        }
    }
}

/// 回顾列表：一行一项，新的在上面；看过的变成次要文字色。不显示数量、没有红点（原则 5）
private struct ReviewList: View {
    @Environment(AppModel.self) private var model
    let navigate: (String) -> Void
    @State private var items: [API.ReviewItem]?
    @State private var problem: String?
    @State private var openWarning: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("回顾").font(Web.title).foregroundStyle(Web.fg).accessibilityAddTraits(.isHeader)
                Text("每天早上，Pour 把昨天说过的话整理成一页放在这里。").font(Web.body).foregroundStyle(Web.fgTertiary)
                    .padding(.top, Web.space2)
                if let items {
                    if items.isEmpty {
                        Text("还没有回顾。今天说过的话，明天早上会整理成一页放在这里。").font(Web.body)
                            .foregroundStyle(Web.fgTertiary).padding(.top, Web.space8)
                    } else {
                        list(items).padding(.top, Web.space8)
                    }
                } else if let problem {
                    WebErrorState(problem) { Task { await load() } }.padding(.top, Web.space8)
                } else {
                    VStack(alignment: .leading, spacing: Web.space4) {
                        WebSkeleton(height: Web.space6).containerRelativeFrame(.horizontal) { width, _ in width * 2 / 3
                        }
                        WebSkeleton(height: Web.space6).containerRelativeFrame(.horizontal) { width, _ in width / 2 }
                        WebSkeleton(height: Web.space6).containerRelativeFrame(.horizontal) { width, _ in width * 3 / 5
                        }
                    }
                    .padding(.top, Web.space8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Web.space4)
            .padding(.top, Web.space4)
            .padding(.bottom, Web.space12)
        }
        .refreshable { await load() }
        .task(id: model.dataVersion) { await load() }
    }

    private func list(_ items: [API.ReviewItem]) -> some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        open(item)
                    } label: {
                        row(item)
                    }
                    .buttonStyle(WebPressStyle(radius: 0))
                    if openWarning == item.id {
                        Text(Show.spaced(item.summary)).font(Web.body).foregroundStyle(Web.fgSecondary)
                            .padding(.horizontal, Web.space2).padding(.bottom, Web.space4)
                    }
                }
                .overlay(alignment: .bottom) { Rectangle().fill(Web.line).frame(height: 1) }
            }
        }
        .overlay(alignment: .top) { Rectangle().fill(Web.line).frame(height: 1) }
    }

    /// 手机上：第一行标题和时间，第二行一句话（最多两行）
    private func row(_ item: API.ReviewItem) -> some View {
        VStack(alignment: .leading, spacing: Web.space1) {
            HStack(alignment: .firstTextBaseline, spacing: Web.space4) {
                Text(Show.spaced(item.title))
                    .font(item.read ? Web.body : Web.bodyMedium)
                    .foregroundStyle(item.read ? Web.fgSecondary : Web.fg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(Show.spaced(Show.reviewWhen(item.createdAt, today: model.today))).font(Web.caption)
                    .foregroundStyle(Web.fgTertiary).monospacedDigit()
            }
            Text(Show.spaced(item.summary)).font(Web.body).foregroundStyle(Web.fgSecondary).lineLimit(2)
        }
        .padding(.vertical, Web.space4).padding(.horizontal, Web.space2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text(item.read ? "看过了" : ""))
    }

    /// 打开就算看过；每日回顾、周报月报打开那一篇，预警就地展开
    private func open(_ item: API.ReviewItem) {
        if !item.read {
            Task {
                try? await model.client.markRead(message: item.id)
                await load()
            }
        }
        if item.kind == "daily", let day = item.day {
            navigate("/review/\(day)")
        } else if item.kind == "weekly" || item.kind == "monthly", let from = item.from {
            navigate(Show.reportPath(item.kind, from: from))
        } else {
            withAnimation(Web.panel) { openWarning = openWarning == item.id ? nil : item.id }
        }
    }

    private func load() async {
        do {
            items = try await model.client.reviewList()
            problem = nil
        } catch {
            problem = error.readable
        }
    }
}
