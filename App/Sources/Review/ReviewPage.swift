import PourAPI
import PourDesign
import SwiftUI

/// 「回顾」（docs/prd-review.md）：Pour 写给你的东西——每天的回顾、周报月报、预警。
/// 3.0（第 6 步）：列表是 ReviewListPage（点一张打开全屏的故事 ReviewStory）；一篇的长页面（故事最后「看整页」、
/// 页面地址 /review/2026-10-18、/review/week/…、/review/month/…）推进导航栈；翻上一天、上一周换掉这一页（AppModel.open）
struct ReviewPage: View {
    @Environment(AppModel.self) private var model
    /// nil 是列表
    let route: ReviewRoute?

    var body: some View {
        switch route {
        case .daily(let day): DailyReviewView(day: day, navigate: navigate)
        case .period(let kind, let day): PeriodReviewView(kind: kind, day: day, navigate: navigate)
        case nil: ReviewListPage()
        }
    }

    /// 换到一个页面地址（回顾里互相跳、去别处）
    private func navigate(_ path: String) {
        model.open(path)
    }
}

/// 回顾里的一篇：每日回顾，或者周报 / 月报（kind、那一期的第一天）
enum ReviewRoute: Hashable {
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
        } else if parts.count == 2, parts[1].wholeMatch(of: /\d{4}-\d{2}-\d{2}/) != nil {
            self = .daily(parts[1])
        } else {
            return nil
        }
    }
}
