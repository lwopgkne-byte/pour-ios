import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 今天的时间线（待办 2.0 第 8 步，docs/todo-2.0 design/after-04-timeline）：上面「还没排时间 · N」托盘（按住拖到下面的时间上
/// 就定下钟点）；现在以前没安排的钟点收成一条；定了钟点的待办是小标签，日程是浅蓝块（撞在一起的并排）；
/// 「现在」线在标签和块下面一层；一个半钟头以上的空档画虚线框，建议排一件进去；撞上日程的标签后面写「撞上面试」。
/// 2026-11-06 产品主人：作息（睡觉、上班、忙着）画成淡淡的底色，一天夹在两段夜里；双指缩放（TimelineZoom）
struct TodoTimelineView: View {
    @Environment(AppModel.self) var model
    let page: API.TodoPage
    let events: [CalendarItem]
    let now: String
    /// 待办页的滚动：缩放时把手指下面那一刻留在原地
    @Binding var scroll: ScrollPosition
    let offset: ScrollOffset
    @State private var expanded = false
    /// 放下一次轻震一下
    @State private var dropped = 0
    /// 一小时多高（双指缩放，记住上次的）
    @AppStorage(TimelineZoom.key) var hour = TimelineZoom.standard
    /// 正在缩放：开始时的样子
    @State private var pinch: TimelineZoom.Pinch?

    /// 左边写钟点的那一列
    static let gutter: CGFloat = 54
    /// 第一条钟点线离顶上多远（钟点的字不被切）
    static let top: CGFloat = 10

    var body: some View {
        let plan = TodoTimelinePlan.make(
            page: page, held: model.todoHeld, events: events, now: now, expanded: expanded,
            routine: model.timeline.routine)
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            if !plan.tray.isEmpty { tray(plan.tray) }
            if let routine = model.timeline.routine { routineLine(routine) }
            if let until = plan.collapsedUntil {
                CollapsedHours("\(Self.hh(plan.first)):00–\(Self.hh(until)):00 没安排，已收起") {
                    withAnimation(Theme.Motion.standard) { expanded = true }
                }
                .padding(.leading, Self.gutter - Theme.Space.medium)
                .accessibilityIdentifier("timeline.collapsed")
            }
            canvas(plan)
        }
        .sensoryFeedback(Theme.Haptics.drop, trigger: dropped)
        .sensoryFeedback(.selection, trigger: TimelineZoom.density(hour))
        .onDisappear { model.todoGaps = false }
    }

    var density: TimelineZoom.Density { TimelineZoom.density(hour) }
    var compact: Bool { density == .compact }
    var tagHeight: CGFloat { TimelineTag.height(compact: compact) }

    // MARK: - 钟点、底色、标签、日程

    private func canvas(_ plan: TodoTimelinePlan) -> some View {
        let from = plan.shownFrom
        let height = CGFloat(plan.last - from) * CGFloat(hour) + Self.top * 2
        let rows = plan.tagRows
        let tops = Self.stack(rows.map { y($0.minute, from: from) - tagHeight / 2 }, height: tagHeight)
        return GeometryReader { proxy in
            let width = proxy.size.width - Self.gutter
            ZStack(alignment: .topLeading) {
                hourLines(from: from, last: plan.last, now: plan.now)
                ForEach(plan.bands) { band in
                    bandView(band, plan: plan, width: width, from: from, taken: taken(plan, tops: tops, from: from))
                }
                if let minute = plan.now, minute >= from * 60, minute <= plan.last * 60 {
                    NowMarker(clock: TodoTimelinePlan.Gap.clock(minute), gutter: Self.gutter)
                        .offset(y: y(minute, from: from) - NowMarker.height / 2)
                        .accessibilityIdentifier("timeline.now")
                }
                ForEach(plan.events) { event in eventView(event, width: width, from: from) }
                ForEach(plan.more, id: \.minute) { more in
                    Text("+\(more.count)").font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Agenda.ink)
                        .padding(.horizontal, Theme.Space.small).frame(height: Theme.Size.badge + Theme.Space.tight)
                        .background(Theme.Palette.card, in: Capsule())
                        .offset(x: proxy.size.width - Theme.Size.touch, y: y(more.minute, from: from) + 4)
                        .accessibilityLabel(Text("还有 \(more.count) 个日程"))
                }
                gapViews(plan, rows: rows, tops: tops, width: width, from: from)
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    tagRow(row, width: width).offset(x: Self.gutter + Theme.Space.tight, y: tops[index])
                }
            }
            .frame(width: proxy.size.width, height: height, alignment: .topLeading)
        }
        .frame(height: height)
        .contentShape(Rectangle())
        .simultaneousGesture(
            MagnifyGesture(minimumScaleDelta: 0.01)
                .onChanged { value in zoom(value) }
                .onEnded { _ in pinch = nil }
        )
        .dropDestination(for: String.self) { items, point in
            drop(items, at: point, from: from, last: plan.last)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("timeline.canvas")
    }

    /// 时间线上已经有东西的高度（小标签、日程、空档框、「现在」线）：作息那行字躲开它们
    private func taken(_ plan: TodoTimelinePlan, tops: [CGFloat], from: Int) -> [ClosedRange<CGFloat>] {
        let tags = tops.map { $0...($0 + tagHeight) }
        let events = plan.events.map { y($0.start, from: from)...y($0.end, from: from) }
        let gaps = plan.gaps.prefix(Self.gapsShown).map {
            y($0.start, from: from)...(y($0.start, from: from) + Self.twoLines)
        }
        let now = plan.now.map { y($0, from: from) }.map { [($0 - Theme.Space.small)...($0 + Theme.Space.small)] } ?? []
        return tags + events + gaps + now
    }

    /// 双指缩放：一小时多高跟着手指变，手指下面那一刻留在屏幕上原来的地方（待办页跟着滚）
    private func zoom(_ value: MagnifyGesture.Value) {
        let base =
            pinch
            ?? TimelineZoom.Pinch(
                hour: hour, minute: max(0, Double(value.startLocation.y - Self.top) / hour * 60), offset: offset.y)
        pinch = base
        var quiet = Transaction()
        quiet.disablesAnimations = true
        withTransaction(quiet) {
            hour = TimelineZoom.clamp(base.hour * value.magnification)
            scroll.scrollTo(y: TimelineZoom.offset(base, hour: hour))
        }
    }

    /// 日程块：撞在一起的分列并排；缩得很小只写名字，放大了名字多写几行
    private func eventView(_ event: TodoTimelinePlan.Event, width: CGFloat, from: Int) -> some View {
        let column = (width - CGFloat(event.columns - 1) * Theme.Space.tight) / CGFloat(event.columns)
        let height = y(event.end, from: from) - y(event.start, from: from) - 2
        return EventBlock(
            time: "\(TodoTimelinePlan.Gap.clock(event.start))–\(TodoTimelinePlan.Gap.clock(event.end))",
            title: Show.spaced(event.item.title), compact: compact || height < TimelineTag.height + Theme.Space.small,
            lines: density == .detailed ? 4 : 2
        )
        .frame(width: column, height: max(compact ? tagHeight - Theme.Space.tight : TimelineTag.height, height))
        .offset(
            x: Self.gutter + CGFloat(event.column) * (column + Theme.Space.tight), y: y(event.start, from: from) + 1)
    }

    /// 一行小标签：放得下就照原来的长短一个挨一个；放不下才一起缩（名字省略）
    private func tagRow(_ row: TodoTimelinePlan.TagRow, width: CGFloat) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Space.small - 2) {
                ForEach(row.tags) { tagView($0).fixedSize() }
            }
            HStack(spacing: Theme.Space.small - 2) {
                ForEach(row.tags) { tagView($0) }
            }
        }
        .frame(maxWidth: width - Theme.Space.small, alignment: .leading)
        .frame(height: tagHeight)
    }

    private func tagView(_ tag: TodoTimelinePlan.Tag) -> some View {
        let row = tag.row
        let when = TodoBoard.trailing(row, today: page.today, now: now)
        let clash = tag.clash.map { $0.isEmpty ? "时间撞了" : "撞上\($0)" }
        return TimelineTag(
            quadrant: row.lane.rawValue, title: Show.spaced(row.content), done: row.done, when: when, clash: clash,
            spoken: [row.content, row.done ? "已完成" : when?.text, clash].compactMap { $0 }.joined(separator: "，"),
            compact: compact
        ) {
            model.todoSheet = .detail(row)
        }
        .accessibilityIdentifier("timeline.tag")
    }

    /// 一行一行的小标签挨得太近就往下错开一点（一个标签高），不叠在一起
    static func stack(_ ideal: [CGFloat], height: CGFloat = TimelineTag.height) -> [CGFloat] {
        var out: [CGFloat] = []
        for value in ideal { out.append(max(value, (out.last ?? -.infinity) + height + Theme.Space.tight)) }
        return out
    }

    /// 一天里的第几分钟 → 离顶上多远
    func y(_ minute: Int, from: Int) -> CGFloat {
        Self.top + CGFloat(minute - from * 60) / 60 * CGFloat(hour)
    }

    /// 放到时间线上：放在哪一刻（取到 15 分钟）就定在那一刻，时间段去掉
    private func drop(_ items: [String], at point: CGPoint, from: Int, last: Int) -> Bool {
        let ids = Set(items.compactMap(TodoMatrixPlan.dragId))
        guard let row = page.groups.flatMap(\.rows).first(where: { ids.contains($0.id) }) else { return false }
        let raw = from * 60 + Int((Double(point.y - Self.top) / hour * 60).rounded())
        let minute = min(max(Int((Double(raw) / 15).rounded()) * 15, from * 60), last * 60 - 15)
        model.schedule(row, at: minute)
        dropped += 1
        return true
    }

    static func hh(_ hour: Int) -> String { String(format: "%02d", hour) }
}

extension AppModel {
    /// 排到今天的一个钟点（时间线上拖过去、空档的建议）：时间段去掉；先改界面再发，轻提示能撤销
    func schedule(_ row: API.TodoRow, at minute: Int) {
        let clock = TodoTimelinePlan.Gap.clock(minute)
        editTodo(row.id, day: today, time: .some(clock), window: .some(nil))
        toast("「\(row.content)」排到 \(clock)", action: "撤销") { [weak self] in
            self?.editTodo(row.id, day: row.day, time: .some(row.remindAt), window: .some(row.timeWindow))
        }
    }
}
