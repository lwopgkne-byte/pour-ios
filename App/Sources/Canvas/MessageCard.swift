import PourAPI
import PourDesign
import SwiftUI

/// 对话里的一条系统消息（规格 12.1：所有提醒同时也出现在对话里）：Pour 说的，左边白气泡（原型 .bub.pour）——
/// 图标、标题、一句话、几点；每日回顾、周报月报只留一行，点了去「回顾」看完整的
struct MessageCard: View {
    @Environment(AppModel.self) private var model
    let message: API.SystemMessage

    var body: some View {
        if let link {
            Button {
                // 3.0：每日回顾、周报月报打开全屏的故事
                model.openStory(path: link.path)
            } label: {
                HStack(spacing: Theme.Space.small) {
                    Image(systemName: Show.messageSymbol(message.kind)).foregroundStyle(Theme.Palette.accent)
                        .accessibilityHidden(true)
                    Text(link.text).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                    time
                    Image(systemName: "chevron.right").font(Theme.Typeface.caption)
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                }
                .frame(minHeight: Theme.Size.touch - Theme.Space.small * 2 - Theme.Space.hairline)
                .contentShape(Rectangle())
                .pourBubble()
            }
            .buttonStyle(PressScale())
        } else {
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                HStack(spacing: Theme.Space.small) {
                    Image(systemName: Show.messageSymbol(message.kind)).foregroundStyle(Theme.Palette.accent)
                        .accessibilityHidden(true)
                    Text(Show.spaced(message.title)).font(Theme.Typeface.cardTitle).foregroundStyle(
                        Theme.Palette.label)
                    Spacer(minLength: 0)
                    time
                }
                Text(Show.spaced(message.body)).font(Theme.Typeface.message)
                    .foregroundStyle(Theme.Palette.label).lineSpacing(Theme.Leading.body)
                    .fixedSize(horizontal: false, vertical: true)
                if !failed.isEmpty {
                    Text("推送没有发出去：\(failed.joined(separator: "；"))").font(Theme.Typeface.footnote)
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .pourBubble()
            .accessibilityElement(children: .combine)
        }
    }

    private var time: some View {
        Text(Show.formatClock(message.createdAt)).font(Theme.Typeface.footnote)
            .foregroundStyle(Theme.Palette.secondaryLabel).monospacedDigit().fixedSize()
    }

    private var failed: [String] {
        (message.push ?? []).filter { !$0.ok }.map { $0.message ?? Show.channelName($0.channel) }
    }

    /// 每日回顾、周报月报：一行字和点了去哪
    private var link: (text: AttributedString, path: String)? {
        if message.kind == "daily", let daily = message.daily {
            return (line("昨天的回顾好了", daily.overview), "/review/\(daily.day)")
        }
        if message.kind == "weekly" || message.kind == "monthly", let report = message.report {
            let title = report.kind == "weekly" ? "上周的周报好了" : "上个月的月报好了"
            return (line(title, message.body), Show.reportPath(report.kind, from: report.period.from))
        }
        return nil
    }

    private func line(_ title: String, _ detail: String) -> AttributedString {
        var head = AttributedString(title)
        head.font = Theme.Typeface.cardTitle
        head.foregroundColor = Theme.Palette.label
        var tail = AttributedString(Show.spaced(" · \(detail)"))
        tail.font = Theme.Typeface.footnote
        tail.foregroundColor = Theme.Palette.secondaryLabel
        return head + tail
    }
}
