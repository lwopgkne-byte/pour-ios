import PourDesign
import SwiftUI

/// 关于 Pour → 小组件和捷径（docs/3.0/07-开发任务清单.md 10.5a）：不打开 App 也能用 Pour 的几个地方，一样一句
struct WidgetsGuide: View {
    private static let groups: [(title: String, rows: [String])] = [
        (
            "桌面小组件",
            [
                "说一句：点了直接开始说", "今天：今天的几件事和下一件待办", "下一件待办：点圆圈就完成", "语录：今天重温的那一句",
                "记心情：点一个表情就记下", "记一笔：点了打开数字键盘；中号写这个月花了多少",
            ]
        ),
        ("控制中心和锁屏", ["说一句", "记一笔"]),
        ("按住 App 图标", ["加待办 · 记一笔 · 记心情 · 说一句"]),
        ("Siri 和快捷指令", ["「用 Pour 说一句」", "「用 Pour 记一笔」", "「用 Pour 记心情」", "「Pour 今天还有什么待办」"]),
        ("通知上的按钮", ["待办到点：完成 · 10 分钟后 · 1 小时后 · 明天早上", "晚上问心情：按住通知直接选一档，或者说两句"]),
        ("从别的 App 分享", ["分享一段文字进来：记一句，或者记成感悟"]),
        ("打开的时候", ["电脑上的 Pour 要 PIN 时，先输 PIN", "连不上电脑：先看存下的，连上了自动刷新", "App 太旧：提醒装新的"]),
    ]

    var body: some View {
        ForEach(Self.groups, id: \.title) { group in
            VStack(alignment: .leading, spacing: Theme.Space.small) {
                Text(group.title).font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.secondaryLabel)
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: Theme.Space.small) {
                    ForEach(group.rows, id: \.self) { row in
                        Text(row).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .themeCard()
            }
        }
    }
}
