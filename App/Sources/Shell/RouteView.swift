import PourDesign
import SwiftUI

/// 推进来的一页（docs/3.0/01-需求文档.md 2.5：一个功能的页面推入导航栈，左上角返回、从左边缘右滑返回）。
/// 第 2–10 步一块一块重做完了，每一页都是 3.0 的样子：导航栏的大标题、画布的暖灰底；
/// 导航栏的名字照样设好，下一页的返回按钮写的就是它
struct RouteView: View {
    @Environment(AppModel.self) private var model
    let route: Route

    var body: some View {
        page
            .sayBarFollowsScroll()
            .modifier(RouteTitle(route: route))
            .navigationBarTitleDisplayMode(.large)
            .background(Theme.Palette.background.ignoresSafeArea())
    }

    @ViewBuilder private var page: some View {
        switch route {
        case .hub: HubPage()
        case .todos: TodosPage()
        case .review(let review): ReviewPage(route: review)
        case .money(let money): MoneyPage(route: money)
        case .mood(let mood): MoodPage(route: mood)
        case .about(let about, let ask): AboutPage(route: about, ask: ask)
        case .insights: InsightsPage()
        case .goals(let goal): GoalsRoutePage(route: goal)
        case .library(let ask): LibraryPage3(ask: ask)
        case .settings(let anchor): SettingsPage(anchor: anchor)
        }
    }
}

/// 导航栏上的名字：一个目标、我在乎的一块由页面自己写（拿到名字才知道）
private struct RouteTitle: ViewModifier {
    let route: Route

    func body(content: Content) -> some View {
        switch route {
        case .goals(.goal), .goals(.care), .about(.domain, _), .about(.person, _), .about(.year, _): content
        default: content.navigationTitle(route.title)
        }
    }
}
