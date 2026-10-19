import PourDesign
import SwiftUI

/// 左上角菜单里的页面（网页版 Layout 的 PAGES，顺序一样；「设置」是另开的一层）
enum Page: String, CaseIterable, Identifiable {
    case canvas, review, money, about, goals, library

    var id: String { rawValue }

    var label: String {
        switch self {
        case .canvas: "生活画布"
        case .review: "回顾"
        case .money: "钱"
        case .about: "关于我"
        case .goals: "目标"
        case .library: "笔记库"
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
        }
    }
}

/// 每一页显示什么。照网页版搬好一页，就把这一页的 LaterPage 换成它（docs/复刻网页版-交接.md）
struct PageView: View {
    let page: Page

    var body: some View {
        switch page {
        case .canvas: CanvasView()
        case .review: LaterPage(page: page)
        case .money: LaterPage(page: page)
        case .about: LaterPage(page: page)
        case .goals: LaterPage(page: page)
        case .library: LaterPage(page: page)
        }
    }
}

/// 还没照网页版搬过来的页面：标题和一句说明
struct LaterPage: View {
    let page: Page

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Web.space4) {
                Text(page.label).font(Web.title).foregroundStyle(Web.fg)
                Text("这一页正在照网页版搬过来。").font(Web.body).foregroundStyle(Web.fgTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Web.space4)
        }
    }
}
