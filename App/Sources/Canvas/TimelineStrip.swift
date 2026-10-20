import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 时间轴（网页版 Timeline 1 比 1）：一天从早到晚的一条细线，事件按时间排成类别色的色块，点一下看详情；
/// 说不出具体时间的事件放在下面的「未定时间」里
struct TimelineStrip: View {
    @Environment(AppModel.self) private var model
    let day: String
    let entries: [API.Entry]
    let categories: [API.Category]

    private struct Item: Identifiable {
        let id: Int
        let event: API.EventData
        let category: String
        let pending: Bool
    }

    var body: some View {
        let events = entries.compactMap { entry -> Item? in
            guard case .event(let event) = entry.data else { return nil }
            return Item(id: entry.id, event: event, category: entry.category, pending: entry.pending)
        }
        let timed = events.filter { $0.event.start != nil || $0.event.end != nil }
        let untimed = events.filter { $0.event.start == nil && $0.event.end == nil }
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                if !timed.isEmpty { track(timed) }
                if !untimed.isEmpty {
                    PourFlowLayout(spacing: Web.space2, lineSpacing: Web.space3) {
                        Text("未定时间").font(Web.caption).foregroundStyle(Web.fgTertiary)
                        ForEach(untimed) { item in chip(item) }
                    }
                    .padding(.top, Web.space3)
                }
            }
            .padding(.top, Web.space6)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("时间轴"))
        }
    }

    private func color(_ item: Item) -> Color { Web.tag(Show.meta(item.category, categories).color).solid }

    /// 时间轴的范围：至少早上 6 点到晚上 11 点，有更早更晚的事件就往外扩（最多前一天 18 点到第二天 12 点），按整点取整
    private func range(_ items: [Item]) -> (start: String, minutes: Int) {
        var start = "\(day)T06:00"
        var end = "\(day)T23:00"
        for item in items {
            let from = item.event.start ?? item.event.end ?? start
            let until = item.event.end ?? item.event.start ?? end
            if from < start { start = from }
            if until > end { end = until }
        }
        start = max(start, "\(PourDate.addDays(day, -1))T18:00")
        end = min(end, "\(PourDate.addDays(day, 1))T12:00")
        let floor = String(start.prefix(13)) + ":00"
        let endFloor = String(end.prefix(13)) + ":00"
        let ceil = end.hasSuffix(":00") ? end : PourDate.addMinutes(endFloor, 60)
        return (floor, max(60, PourDate.minutesBetween(floor, ceil)))
    }

    private func track(_ items: [Item]) -> some View {
        let range = range(items)
        let step = range.minutes > 16 * 60 ? 6 : 3
        let ticks = stride(from: 0, through: range.minutes, by: 60).compactMap { minute -> (Double, String)? in
            let hour = Int(PourDate.addMinutes(range.start, minute).dropFirst(11).prefix(2)) ?? 0
            return hour % step == 0 ? (Double(minute) / Double(range.minutes), "\(hour):00") : nil
        }
        func position(_ time: String) -> Double {
            min(1, max(0, Double(PourDate.minutesBetween(range.start, time)) / Double(range.minutes)))
        }
        return GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Web.line).frame(height: 1).offset(y: Web.space6 / 2)
                ForEach(items) { item in
                    let from = item.event.start ?? item.event.end ?? range.start
                    let left = position(from) * width
                    let span: CGFloat =
                        if let start = item.event.start, let end = item.event.end {
                            max((position(end) - position(start)) * width, width * 0.008)
                        } else { 0 }
                    block(item, left: left, span: span)
                }
                // 按位置认：跨过半夜时开头和结尾都叫「0:00」，按名字认会丢掉一个
                ForEach(ticks, id: \.0) { place, label in
                    Text(label).font(Web.caption).foregroundStyle(Web.fgTertiary).fixedSize().accessibilityHidden(true)
                        .alignmentGuide(.leading) { size in
                            place < 0.05
                                ? -place * width
                                : place > 0.95 ? size.width - place * width : size.width / 2 - place * width
                        }
                        .offset(y: Web.space6)
                }
                .accessibilityHidden(true)
            }
        }
        .frame(height: Web.space6 + Web.space4)
        .padding(.top, Web.space3)
    }

    /// 时间轴上的一块：看得见的是细细的色块；能点的范围撑到 44×44（手机上色块太细不好点，网页版同样撑高）
    private func block(_ item: Item, left: CGFloat, span: CGFloat) -> some View {
        let shown = span > 0 ? span : Web.space2
        let tap = max(shown, Web.touch)
        let label =
            "\(Show.meta(item.category, categories).emoji) \(item.event.label) \(Show.eventMeta(item.event, day: day))"
        return Button {
            model.openEntry(item.id, day: day)
        } label: {
            Capsule().fill(color(item))
                .frame(width: shown, height: Web.space2)
                .opacity(item.pending ? 0.45 : 0.85)
                .frame(width: tap, height: Web.touch)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(x: (span > 0 ? left : left - Web.space1) + shown / 2 - tap / 2, y: Web.space6 / 2 - Web.touch / 2)
        .accessibilityLabel(Text(label))
    }

    private func chip(_ item: Item) -> some View {
        Button {
            model.openEntry(item.id, day: day)
        } label: {
            HStack(spacing: Web.space1) {
                Circle().fill(color(item)).frame(width: Web.space2, height: Web.space2)
                Text(Show.spaced(item.event.label)).foregroundStyle(Web.fg)
                if item.event.durationMin != nil {
                    Text(Show.spaced(Show.eventMeta(item.event, day: day))).foregroundStyle(Web.fgTertiary)
                }
            }
            .font(Web.caption)
            .padding(.horizontal, Web.space2)
            .frame(minHeight: Web.control)
            .background(Capsule().fill(Web.bg))
            .overlay(
                Capsule().strokeBorder(
                    item.pending ? Web.lineStrong : Web.line,
                    style: StrokeStyle(lineWidth: 1, dash: item.pending ? [Web.space1, Web.space1 / 2] : [])))
        }
        .buttonStyle(.plain)
        // 读屏、审计都当成一个按钮（里面的名字和时长不再各算一个）
        .accessibilityElement(children: .combine)
    }
}
