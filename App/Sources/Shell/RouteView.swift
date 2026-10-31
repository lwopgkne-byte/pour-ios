import PourDesign
import SwiftUI

/// 推进来的一页（docs/3.0/01-需求文档.md 2.5：一个功能的页面推入导航栈，左上角返回、从左边缘右滑返回）。
/// 还没重做的页（第 2–10 步一块一块重做）原样放进来：它们自己画大标题，导航栏只放返回按钮；
/// 导航栏的名字照样设好，下一页的返回按钮写的就是它
struct RouteView: View {
    @Environment(AppModel.self) private var model
    let route: Route

    var body: some View {
        page
            .sayBarFollowsScroll()
            .navigationTitle(route.title)
            .navigationBarTitleDisplayMode(route.legacy ? .inline : .large)
            .toolbar {
                // 旧页面自己有大标题：导航栏中间不再写一遍
                if route.legacy { ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1) } }
            }
            .background(background.ignoresSafeArea())
    }

    @ViewBuilder private var page: some View {
        switch route {
        case .hub: HubPage()
        case .review(let review): ReviewPage(route: review)
        case .money(let money): MoneyPage(route: money)
        case .about(let about, let ask): AboutPage(route: about, ask: ask)
        case .goals: GoalsPage()
        case .library(let ask): LibraryPage(ask: ask)
        case .settings(let anchor): SettingsPage(anchor: anchor)
        }
    }

    /// 重做过的页是画布的暖灰底；还没重做的照旧白底（和它们原来的底一样白）
    private var background: Color {
        route.legacy ? Theme.Palette.card : Theme.Palette.background
    }
}

extension Route {
    /// 还没按 3.0 重做的页（自己画标题、用 Web 的样子）
    var legacy: Bool {
        if case .hub = self { return false }
        return true
    }
}
