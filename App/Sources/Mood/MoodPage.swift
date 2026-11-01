import PourAPI
import PourDesign
import SwiftUI

/// 「心情」（3.0 第 4 步，docs/3.0/01-需求文档.md 第 6 章）：心情页（我的 → 心情、画布心情卡的标题）、
/// 心情分析（心情页卡片右上角「›」进，以前「关于我 → 心情」的全部）、好时刻（全部）
struct MoodPage: View {
    @Environment(AppModel.self) private var model
    let route: MoodRoute

    var body: some View {
        switch route {
        case .home(let month): MoodHomePage(month: month ?? String(model.today.prefix(7)))
        case .analysis: MoodAnalysisPage()
        case .moments: MoodMomentsPage()
        }
    }
}

/// 心情里的一页
enum MoodRoute: Hashable {
    /// 心情页：nil 是这个月
    case home(String?)
    /// 心情分析
    case analysis
    /// 好时刻（全部）
    case moments

    /// 「/mood」「/mood/2026-10」「/mood/analysis」「/mood/moments」；以前的「/about/mood」是心情分析
    init?(_ path: String) {
        let head = path.split(separator: "?", maxSplits: 1).first.map(String.init) ?? path
        if head == "/about/mood" {
            self = .analysis
            return
        }
        let parts = head.split(separator: "/").map(String.init)
        guard parts.first == "mood" else { return nil }
        switch (parts.count, parts.dropFirst().first) {
        case (1, _): self = .home(nil)
        case (2, "analysis"): self = .analysis
        case (2, "moments"): self = .moments
        case (2, let month?) where month.wholeMatch(of: /\d{4}-(0[1-9]|1[0-2])/) != nil: self = .home(month)
        default: return nil
        }
    }

    var title: String {
        switch self {
        case .home: "心情"
        case .analysis: "心情分析"
        case .moments: "好时刻"
        }
    }

    /// 哪一种页（换月只换同一种）
    var kind: String {
        switch self {
        case .home: "home"
        case .analysis: "analysis"
        case .moments: "moments"
        }
    }
}
