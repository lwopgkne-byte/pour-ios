import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 今天的时间线（待办 2.0 第 8 步，docs/todo-2.0 design/after-04-timeline）：上面「还没排时间 · N」托盘（按住拖到下面的时间上
/// 就定下钟点）；现在以前没安排的钟点收成一条；一小时 46 高，定了钟点的待办是 28 高的小标签，日程是浅蓝块（撞在一起的并排）；
/// 「现在」线在标签和块下面一层；1 小时以上的空档画虚线框，建议排一件进去；撞上日程的标签后面写「撞上面试」
struct TodoTimelineView: View {
    @Environment(AppModel.self) private var model
    let page: API.TodoPage
    let events: [CalendarItem]
    let now: String
    @State private var expanded = false
    /// 放下一次轻震一下
    @State private var dropped = 0

    /// 一小时多高
    static let hour: CGFloat = 46
    /// 左边写钟点的那一列
    static let gutter: CGFloat = 54
    /// 第一条钟点线离顶上多远（钟点的字不被切）
    private static let top: CGFloat = 10

    var body: some View {
        let plan = TodoTimelinePlan.make(
            page: page, held: model.todoHeld, events: events, now: now, expanded: expanded)
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            if !plan.tray.isEmpty { tray(plan.tray) }
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
        .onDisappear { model.todoGaps = false }
    }

    // MARK: - 托盘

    /// 「还没排时间 · 2」：只说了时间段的、没说时间的；点了打开编辑，按住拖到下面的时间上
    private func tray(_ rows: [API.TodoRow]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            HStack {
                Text("还没排时间 · \(rows.count)").font(Theme.Typeface.footnoteSemibold)
                    .foregroundStyle(Theme.Palette.secondaryLabel)
                Spacer()
                Text("按住拖到时间上").font(Theme.Typeface.footnote)
                    .foregroundStyle(Theme.Palette.tertiaryLabel)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Space.small) {
                    ForEach(rows) { row in
                        Button {
                            model.todoSheet = .detail(row)
                        } label: {
                            TrayChip(Show.spaced(row.content), quadrant: row.lane.rawValue, note: row.timeWindow?.title)
                        }
                        .buttonStyle(.plain)
                        .draggable(TodoMatrixPlan.dragText(row)) {
                            TrayChip(Show.spaced(row.content), quadrant: row.lane.rawValue)
                        }
                        .accessibilityIdentifier("timeline.tray.chip")
                    }
                }
                .padding(.vertical, Theme.Space.hairline)
            }
        }
        .padding(.horizontal, Theme.Space.regular)
        .padding(.vertical, Theme.Space.medium)
        .background(Theme.Palette.card, in: Theme.rounded(Theme.Corner.smallCard))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("timeline.tray")
    }

    // MARK: - 钟点、标签、日程

    private func canvas(_ plan: TodoTimelinePlan) -> some View {
        let from = plan.shownFrom
        let height = CGFloat(plan.last - from) * Self.hour + Self.top * 2
        let rows = plan.tagRows
        let tops = Self.stack(rows.map { y($0.minute, from: from) - TimelineTag.height / 2 })
        return GeometryReader { proxy in
            let width = proxy.size.width - Self.gutter
            ZStack(alignment: .topLeading) {
                hourLines(from: from, last: plan.last, now: plan.now)
                if let minute = plan.now, minute >= from * 60, minute <= plan.last * 60 {
                    NowMarker(clock: TodoTimelinePlan.Gap.clock(minute), gutter: Self.gutter)
                        .offset(y: y(minute, from: from) - NowMarker.height / 2)
                        .accessibilityIdentifier("timeline.now")
                }
                ForEach(plan.events) { event in
                    eventView(event, width: width, from: from)
                }
                ForEach(plan.more, id: \.minute) { more in
                    Text("+\(more.count)").font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Agenda.ink)
                        .padding(.horizontal, Theme.Space.small).frame(height: Theme.Size.badge + Theme.Space.tight)
                        .background(Theme.Palette.card, in: Capsule())
                        .offset(x: proxy.size.width - Theme.Size.touch, y: y(more.minute, from: from) + 4)
                        .accessibilityLabel(Text("还有 \(more.count) 个日程"))
                }
                // 空档放在它开头的地方；前面的小标签往下错开了的话，跟在小标签后面（不叠在一起）
                ForEach(plan.gaps.prefix(Self.gapsShown)) { gap in
                    let before = zip(rows, tops).filter { $0.0.minute < gap.start }.map { $0.1 + TimelineTag.height }
                    let top = max(y(gap.start, from: from) + Theme.Space.tight, (before.max() ?? 0) + Theme.Space.small)
                    gapView(gap, plan: plan)
                        .frame(width: width - Theme.Space.small)
                        .offset(x: Self.gutter + Theme.Space.tight, y: top)
                }
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    tagRow(row, width: width).offset(x: Self.gutter + Theme.Space.tight, y: tops[index])
                }
            }
            .frame(width: proxy.size.width, height: height, alignment: .topLeading)
        }
        .frame(height: height)
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { items, point in
            drop(items, at: point, from: from, last: plan.last)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("timeline.canvas")
    }

    /// 最多标几个空档（多了也只是一样的虚线条）
    private static let gapsShown = 3

    /// 每个整点一条线，左边写钟点（离「现在」的胶囊太近的钟点不写，不叠在一起；字用次文字色，小字也看得清）。
    /// 画在 Canvas 里：只是刻度，读屏不念；无障碍审计会去量藏起来的字和线（2026-11-05）
    private func hourLines(from: Int, last: Int, now: Int?) -> some View {
        Canvas { context, size in
            for hour in from...last {
                let lineY = y(hour * 60, from: from)
                var line = Path()
                line.move(to: CGPoint(x: Self.gutter, y: lineY))
                line.addLine(to: CGPoint(x: size.width, y: lineY))
                context.stroke(line, with: .color(Theme.Palette.separator), lineWidth: 1)
                let covered = now.map { abs(y($0, from: from) - lineY) < Theme.Size.badge } ?? false
                if !covered {
                    let label = Text("\(Self.hh(hour)):00").font(Theme.Typeface.tick).monospacedDigit()
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                    context.draw(context.resolve(label), at: CGPoint(x: 0, y: lineY), anchor: .leading)
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// 空档：一条细虚线框，第一个排得进的空档带一个建议
    private func gapView(_ gap: TodoTimelinePlan.Gap, plan: TodoTimelinePlan) -> some View {
        let suggestion = plan.suggestion?.gap == gap ? plan.suggestion : nil
        return GapBox(
            text: "\(gap.text) 空着", suggestion: suggestion.map { "把「\(Show.spaced($0.row.content))」排进来" },
            lit: model.todoGaps, oneLine: gap.end - gap.start < 90
        ) {
            if let suggestion { model.schedule(suggestion.row, at: suggestion.at) }
        }
        .accessibilityIdentifier("timeline.gap")
    }

    /// 日程块：撞在一起的分列并排
    private func eventView(_ event: TodoTimelinePlan.Event, width: CGFloat, from: Int) -> some View {
        let column = (width - CGFloat(event.columns - 1) * Theme.Space.tight) / CGFloat(event.columns)
        return EventBlock(
            time: "\(TodoTimelinePlan.Gap.clock(event.start))–\(TodoTimelinePlan.Gap.clock(event.end))",
            title: Show.spaced(event.item.title)
        )
        .frame(
            width: column, height: max(TimelineTag.height, y(event.end, from: from) - y(event.start, from: from) - 2)
        )
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
        .frame(height: TimelineTag.height)
    }

    private func tagView(_ tag: TodoTimelinePlan.Tag) -> some View {
        let row = tag.row
        let when = TodoBoard.trailing(row, today: page.today, now: now)
        let clash = tag.clash.map { $0.isEmpty ? "时间撞了" : "撞上\($0)" }
        return TimelineTag(
            quadrant: row.lane.rawValue, title: Show.spaced(row.content), done: row.done, when: when, clash: clash,
            spoken: [row.content, row.done ? "已完成" : when?.text, clash].compactMap { $0 }.joined(separator: "，")
        ) {
            model.todoSheet = .detail(row)
        }
        .accessibilityIdentifier("timeline.tag")
    }

    /// 一行一行的小标签挨得太近就往下错开一点（一个标签高），不叠在一起
    static func stack(_ ideal: [CGFloat]) -> [CGFloat] {
        var out: [CGFloat] = []
        for value in ideal { out.append(max(value, (out.last ?? -.infinity) + TimelineTag.height + Theme.Space.tight)) }
        return out
    }

    /// 一天里的第几分钟 → 离顶上多远
    private func y(_ minute: Int, from: Int) -> CGFloat {
        Self.top + CGFloat(minute - from * 60) / 60 * Self.hour
    }

    /// 放到时间线上：放在哪一刻（取到 15 分钟）就定在那一刻，时间段去掉
    private func drop(_ items: [String], at point: CGPoint, from: Int, last: Int) -> Bool {
        let ids = Set(items.compactMap(TodoMatrixPlan.dragId))
        guard let row = page.groups.flatMap(\.rows).first(where: { ids.contains($0.id) }) else { return false }
        let raw = from * 60 + Int(((point.y - Self.top) / Self.hour * 60).rounded())
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
