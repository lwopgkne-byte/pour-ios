import PourDesign
import SwiftUI

/// 左上角菜单里的页面（顺序一样）
enum Page: String, CaseIterable, Identifiable {
    case canvas, review, money, about, goals, library, settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .canvas: "生活画布"
        case .review: "回顾"
        case .money: "钱"
        case .about: "关于我"
        case .goals: "目标"
        case .library: "笔记库"
        case .settings: "设置"
        }
    }

    var icon: String {
        switch self {
        case .canvas: "square.grid.2x2"
        case .review: "book"
        case .money: "yensign.circle"
        case .about: "person"
        case .goals: "target"
        case .library: "books.vertical"
        case .settings: "gearshape"
        }
    }
}

/// 每一页显示什么
struct PageView: View {
    let page: Page

    var body: some View {
        switch page {
        case .canvas: CanvasView()
        case .review: ReviewPage()
        case .money: MoneyPage()
        case .about: AboutPage()
        case .goals: GoalsPage()
        case .library: LibraryPage()
        case .settings: SettingsPage()
        }
    }
}
