import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 今天的时间线（06 交互细节 2.5）：8:00 到 22:00 每小时一格；日程（浅蓝块）、带钟点的待办（蓝 / 过了黄 / 做完划线）
/// 摆在对应的钟点上；红线是现在。回答「今天下午还有空吗」
struct TodoTimelineSection: View {
    let page: API.TodoPage
    let events: [CalendarItem]

    private static let start = 8
    private static let end = 22
    /// 一小时多高
    private nonisolated static let hour: CGFloat = 44
    /// 左边写钟点的那一列
    private static let gutter: CGFloat = 48

    var body: some View {
        Section {
            let allDay = events.filter(\.allDay)
            if !allDay.isEmpty {
                ForEach(allDay) { CalendarLine($0.title, time: "全天 · 日历", color: Theme.Tile.pink) }
            }
            TimelineView(.everyMinute) { context in
                grid(now: PourDate.localDateTime(context.date, in: .current))
            }
            .listRowInsets(EdgeInsets(top: Theme.Space.medium, leading: 0, bottom: Theme.Space.medium, trailing: 0))
        } footer: {
            if blocks.isEmpty {
                Text("今天没有定了钟点的事，也没有日程。").font(Theme.Typeface.footnote)
                    .foregroundStyle(Theme.Palette.secondaryLabel)
            }
        }
    }

    private func grid(now: String) -> some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(Self.start...Self.end, id: \.self) { hour in
                    HStack(alignment: .top, spacing: Theme.Space.small) {
                        Text(String(format: "%02d:00", hour)).font(Theme.Typeface.tick).monospacedDigit()
                            .foregroundStyle(Theme.Palette.tertiaryLabel)
                            .frame(width: Self.gutter - Theme.Space.small, alignment: .trailing)
                        Rectangle().fill(Theme.Palette.separator).frame(height: 1).padding(.top, Theme.Space.snug)
                    }
                    .frame(height: Self.hour, alignment: .top)
                }
            }
            .accessibilityHidden(true)
            ForEach(blocks) { block in
                block.view
                    .padding(.leading, Self.gutter + Theme.Space.tight)
                    .padding(.trailing, Theme.Space.medium)
                    .offset(y: offset(block.start) + Theme.Space.snug)
            }
            if now.hasPrefix(page.today), let minutes = PourDate.minutesOfDay(now) {
                let clock = String(format: "%02d:%02d", minutes / 60, minutes % 60)
                if clock >= String(format: "%02d:00", Self.start), clock <= String(format: "%02d:00", Self.end) {
                    Rectangle().fill(Theme.Palette.bad).frame(height: 2)
                        .padding(.leading, Self.gutter)
                        .offset(y: offset(clock) + Theme.Space.snug)
                        .accessibilityLabel(Text("现在 \(clock)"))
                }
            }
        }
        .frame(height: CGFloat(Self.end - Self.start + 1) * Self.hour)
    }

    /// 钟点 → 离顶上多远
    private func offset(_ clock: String) -> CGFloat {
        let parts = clock.split(separator: ":").compactMap { Double($0) }
        guard parts.count == 2 else { return 0 }
        let hours = min(max(parts[0] + parts[1] / 60, Double(Self.start)), Double(Self.end))
        return CGFloat(hours - Double(Self.start)) * Self.hour
    }

    /// 摆上去的：日程、今天带钟点的待办
    private var blocks: [Block] {
        let todos = (page.groups.first { $0.key == "today" }?.rows ?? []).compactMap { row -> Block? in
            guard let clock = row.remindAt else { return nil }
            return Block(id: "todo.\(row.id)", start: clock, minutes: 30, title: row.content, kind: .todo(row))
        }
        let timed = events.filter { !$0.allDay }.map { event in
            let start = String(event.start.suffix(5))
            let minutes = max(30, PourDate.minutesBetween(event.start, event.end))
            return Block(id: "event.\(event.id)", start: start, minutes: minutes, title: event.title, kind: .event)
        }
        return (timed + todos).sorted { $0.start < $1.start }
    }

    struct Block: Identifiable {
        enum Kind {
            case todo(API.TodoRow)
            case event
        }

        let id: String
        let start: String
        let minutes: Int
        let title: String
        let kind: Kind

        var view: some View {
            HStack(spacing: Theme.Space.small) {
                Text(start).font(Theme.Typeface.footnoteSemibold).monospacedDigit()
                Text(title).font(Theme.Typeface.footnote).lineLimit(1).strikethrough(done)
                Spacer(minLength: 0)
            }
            .foregroundStyle(ink)
            .padding(.horizontal, Theme.Space.small)
            .frame(height: max(28, CGFloat(minutes) / 60 * TodoTimelineSection.hour - 2), alignment: .topLeading)
            .padding(.top, Theme.Space.tight)
            .background(fill, in: Theme.rounded(Theme.Corner.tile))
            .accessibilityElement(children: .combine)
        }

        private var done: Bool {
            if case .todo(let row) = kind { return row.done }
            return false
        }

        private var late: Bool {
            guard case .todo(let row) = kind, !row.done else { return false }
            return "\(row.day)T\(start)" < PourDate.localDateTime(Date(), in: .current)
        }

        private var ink: Color {
            switch kind {
            case .event: Theme.Palette.accent
            case .todo: done ? Theme.Palette.secondaryLabel : late ? Theme.Palette.warnInk : Theme.Palette.accent
            }
        }

        private var fill: Color {
            switch kind {
            case .event: Theme.Palette.bubble
            case .todo: done ? Theme.Palette.fill : late ? Theme.Palette.warnFill : Theme.Palette.remindFill
            }
        }
    }
}
