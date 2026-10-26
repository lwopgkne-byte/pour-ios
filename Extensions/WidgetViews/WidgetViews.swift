import AppIntents
import PourAPI
import PourDesign
import SwiftUI
import WidgetKit

// 小组件里画的东西（docs/模块/产品优化.md R7）：桌面「说一句」「今天」「我的语录」，锁屏「说一句」「下一件」。
// 这份代码小组件扩展和 App 都编译：App 的开发版里有一页「小组件样张」（启动参数 -widgetSamples），界面测试截图验收

/// 点了打开 Pour、直接开始听（pour://voice）
let sayURL = URL(string: "pour://voice") ?? URL(fileURLWithPath: "/")

/// 桌面小的「说一句」：一个大麦克风
struct SayWidgetView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Image(systemName: "mic.fill").font(Theme.Typeface.metric).foregroundStyle(Theme.Palette.accent)
                .accessibilityHidden(true)
            Spacer(minLength: 0)
            Text("说一句").font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
            Text("说完就记下").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// 锁屏圆的「说一句」
struct SayCircleView: View {
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "mic.fill").font(Theme.Typeface.bodySemibold)
        }
        .accessibilityLabel(Text("说一句"))
    }
}

/// 桌面中的「今天」：还没做的待办（最多 3 件，能直接勾）、做完了几件，右下角说一句
struct TodayWidgetView: View {
    let glance: API.Glance?
    let problem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            HStack(alignment: .firstTextBaseline) {
                Text("今天").font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                if let glance, glance.total > 0 {
                    Text("做完 \(glance.done)/\(glance.total)").font(Theme.Typeface.footnote)
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                }
                Spacer(minLength: 0)
                Link(destination: sayURL) {
                    Image(systemName: "mic.fill").font(Theme.Typeface.bodySemibold).foregroundStyle(
                        Theme.Palette.accent
                    )
                    .frame(width: Theme.Size.touch, height: Theme.Size.touch, alignment: .trailing)
                }
                .accessibilityLabel(Text("说一句"))
            }
            if let problem {
                Text(problem).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            } else if let glance, !glance.open.isEmpty {
                ForEach(glance.open.prefix(3)) { todo in TodoRow(todo: todo) }
            } else {
                Text(glance == nil ? "还没拿到" : "今天的待办都做完了").font(Theme.Typeface.subheadline)
                    .foregroundStyle(Theme.Palette.secondaryLabel)
            }
            Spacer(minLength: 0)
        }
    }
}

/// 一件待办：左边圆圈点一下就勾上（不用打开 App），右边几点提醒
private struct TodoRow: View {
    let todo: API.Glance.Todo

    var body: some View {
        HStack(spacing: Theme.Space.small) {
            Button(intent: TodoDoneIntent(entryId: todo.id)) {
                Image(systemName: "circle").font(Theme.Typeface.body).foregroundStyle(Theme.Palette.secondaryLabel)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("做完了：\(todo.content)"))
            Text(todo.content).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.label).lineLimit(1)
            Spacer(minLength: 0)
            if let at = todo.remindAt {
                Text(at).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel).monospacedDigit()
            } else if todo.overdue {
                Text("以前的").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            }
        }
    }
}

/// 锁屏长条的「下一件」：下一件要提醒的待办
struct NextTodoView: View {
    let glance: API.Glance?
    let problem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("下一件").font(Theme.Typeface.caption).widgetAccentable()
            if let next = glance?.next {
                Text(next.content).font(Theme.Typeface.bodySemibold).lineLimit(1)
                if let at = next.remindAt { Text("\(at) 提醒").font(Theme.Typeface.caption) }
            } else {
                Text(problem ?? "没有要提醒的").font(Theme.Typeface.subheadline).lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 「我的语录」：今天那句「你说过」（和每日回顾同一句）
struct QuoteWidgetView: View {
    let glance: API.Glance?
    let problem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text("你说过").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            if let quote = glance?.quote {
                Text("「\(quote.text)」").font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                Text(Show.dayTitle(quote.day, today: glance?.today ?? quote.day)).font(Theme.Typeface.footnote)
                    .foregroundStyle(Theme.Palette.secondaryLabel)
            } else {
                Text(problem ?? "说「记一句：……」，这里每天放一句").font(Theme.Typeface.subheadline)
                    .foregroundStyle(Theme.Palette.secondaryLabel)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
