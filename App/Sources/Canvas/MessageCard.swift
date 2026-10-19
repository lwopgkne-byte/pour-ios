import PourAPI
import PourDesign
import SwiftUI

/// 对话里的一条系统消息（网页版 MessageCard 1 比 1；规格 12.1：所有提醒同时也出现在对话里）：
/// 左边对齐，和 AI 的回复一样安静；每日回顾、周报月报只留一行链接，完整的在「回顾」里
struct MessageCard: View {
    @Environment(AppModel.self) private var model
    let message: API.SystemMessage

    var body: some View {
        if let link {
            Button {
                model.open(link.path)
            } label: {
                HStack(spacing: Web.space2) {
                    Text(Show.messageEmoji(message.kind)).accessibilityHidden(true)
                    Text(link.text).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                    time
                }
                .padding(Web.space3)
                .frame(minHeight: Web.touch)
            }
            .buttonStyle(WebPressStyle())
            .card()
        } else {
            VStack(alignment: .leading, spacing: Web.space1) {
                HStack(spacing: Web.space2) {
                    Text(Show.messageEmoji(message.kind)).accessibilityHidden(true)
                    Text(Show.spaced(message.title)).font(Web.bodyMedium).foregroundStyle(Web.fg)
                    Spacer(minLength: 0)
                    time
                }
                Text(Show.spaced(message.body)).font(Web.body).foregroundStyle(Web.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !failed.isEmpty {
                    Text("推送没有发出去：\(failed.joined(separator: "；"))").font(Web.caption).foregroundStyle(Web.fgTertiary)
                }
            }
            .padding(Web.space3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
            .accessibilityElement(children: .combine)
        }
    }

    private var time: some View {
        Text(Show.formatClock(message.createdAt)).font(Web.caption).foregroundStyle(Web.fgTertiary).fixedSize()
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
        head.font = Web.bodyMedium
        head.foregroundColor = Web.fg
        var tail = AttributedString(Show.spaced(" · \(detail)"))
        tail.font = Web.body
        tail.foregroundColor = Web.fgSecondary
        return head + tail
    }
}

extension View {
    /// 网页版 .chat-system：白底、细边、卡片圆角，上下各空一点
    fileprivate func card() -> some View {
        background(RoundedRectangle(cornerRadius: Web.radiusCard).fill(Web.bg))
            .overlay(RoundedRectangle(cornerRadius: Web.radiusCard).strokeBorder(Web.line, lineWidth: 1))
            .padding(.vertical, Web.space2)
    }
}
