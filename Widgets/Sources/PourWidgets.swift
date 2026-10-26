import AppIntents
import PourAPI
import PourDesign
import SwiftUI
import WidgetKit

/// Pour 的桌面小组件、锁屏组件、控制中心按钮（docs/模块/产品优化.md R7）
@main
struct PourWidgets: WidgetBundle {
    var body: some Widget {
        SayWidget()
        TodayWidget()
        NextTodoWidget()
        QuoteWidget()
        SayControl()
    }
}

/// 一次取到的「一眼」：连不上时 glance 是 nil、problem 写原因（不把上次的当这次的显示）
struct GlanceEntry: TimelineEntry {
    let date: Date
    let glance: API.Glance?
    let problem: String?
}

/// 每半小时找服务器要一次「一眼」；App 里改了东西会让小组件马上重新要
struct GlanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> GlanceEntry { GlanceEntry(date: .now, glance: nil, problem: nil) }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (GlanceEntry) -> Void) {
        if context.isPreview {
            completion(GlanceEntry(date: .now, glance: WidgetSamples.glance, problem: nil))
            return
        }
        Task { completion(await Self.load()) }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<GlanceEntry>) -> Void) {
        Task {
            let entry = await Self.load()
            completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60))))
        }
    }

    static func load() async -> GlanceEntry {
        do {
            return GlanceEntry(date: .now, glance: try await SharedClient.make().glance(), problem: nil)
        } catch .needPin {
            return GlanceEntry(date: .now, glance: nil, problem: "打开 Pour 输一次 PIN")
        } catch {
            return GlanceEntry(date: .now, glance: nil, problem: "连不上电脑上的 Pour")
        }
    }
}

/// 桌面小的、锁屏圆的「说一句」：点了打开 Pour 直接开始听
struct SayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "pour.say", provider: GlanceProvider()) { entry in
            SayEntryView(entry: entry).widgetURL(sayURL)
        }
        .configurationDisplayName("说一句")
        .description("点一下就开始说，说完就记下。")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

private struct SayEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GlanceEntry

    var body: some View {
        if family == .accessoryCircular {
            SayCircleView().containerBackground(.clear, for: .widget)
        } else {
            SayWidgetView().containerBackground(Theme.Palette.card, for: .widget)
        }
    }
}

/// 桌面中的「今天」：还没做的待办，点圆圈就勾上
struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "pour.today", provider: GlanceProvider()) { entry in
            TodayWidgetView(glance: entry.glance, problem: entry.problem)
                .containerBackground(Theme.Palette.card, for: .widget)
        }
        .configurationDisplayName("今天")
        .description("今天还没做的待办，点圆圈就勾上。")
        .supportedFamilies([.systemMedium])
    }
}

/// 锁屏长条的「下一件」
struct NextTodoWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "pour.next", provider: GlanceProvider()) { entry in
            NextTodoView(glance: entry.glance, problem: entry.problem)
                .containerBackground(.clear, for: .widget)
                .widgetURL(URL(string: "pour://open?path=/"))
        }
        .configurationDisplayName("下一件")
        .description("下一件要提醒的待办。")
        .supportedFamilies([.accessoryRectangular])
    }
}

/// 「我的语录」：每天一句自己说过的话
struct QuoteWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "pour.quote", provider: GlanceProvider()) { entry in
            QuoteWidgetView(glance: entry.glance, problem: entry.problem)
                .containerBackground(Theme.Palette.card, for: .widget)
        }
        .configurationDisplayName("我的语录")
        .description("每天一句你自己说过的话。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// 控制中心（还有锁屏底下、操作按钮）的「说一句」：点了打开 Pour 直接开始听
struct SayControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "pour.say.control") {
            ControlWidgetButton(action: OpenURLIntent(sayURL)) {
                Label("说一句", systemImage: "mic.fill")
            }
        }
        .displayName("说一句")
        .description("打开 Pour 直接开始说。")
    }
}
