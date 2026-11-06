import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 时间线的另几块（TodoTimelineView）：托盘、作息那一行、钟点的刻度、作息的底色、空档
extension TodoTimelineView {
    // MARK: - 托盘、作息

    /// 「还没排时间 · 2」：只说了时间段的、没说时间的；点了打开编辑，按住拖到下面的时间上
    func tray(_ rows: [API.TodoRow]) -> some View {
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

    /// 「作息  睡觉 23:30–07:00 · 上班 09:30–18:30  ›」：底色是什么、点了改；没设过写「还没设，睡觉先按 23:30–07:00 算」
    func routineLine(_ routine: API.Routine) -> some View {
        Button {
            model.timeline.editing = true
        } label: {
            HStack(spacing: Theme.Space.small) {
                Label("作息", systemImage: "moon.zzz").font(Theme.Typeface.footnoteSemibold)
                    .foregroundStyle(Theme.Palette.label)
                // 最多两行（三四段放得下）；再多才省略：读屏念整句，点开弹框看全（webOneLine：省略是故意的）
                Text(RoutineText.summary(routine)).font(Theme.Typeface.footnote).monospacedDigit()
                    .foregroundStyle(Theme.Palette.secondaryLabel).lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("webOneLine")
                Spacer(minLength: Theme.Space.small)
                Image(systemName: "chevron.right").font(Theme.Typeface.caption)
                    .foregroundStyle(Theme.Palette.tertiaryLabel)
            }
            .frame(minHeight: Theme.Size.touch).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("作息：\(RoutineText.summary(routine))"))
        .accessibilityHint(Text("改作息"))
        .accessibilityIdentifier("timeline.routine")
        // 读屏没法双指捏合：在这一行上给「放大」「缩小」（挂在整块时间线上会传给里面每一段字）
        .accessibilityAction(named: Text("放大时间线")) { hour = TimelineZoom.clamp(hour * 1.4) }
        .accessibilityAction(named: Text("缩小时间线")) { hour = TimelineZoom.clamp(hour / 1.4) }
    }

    /// 最多标几个空档（多了也只是一样的虚线条）
    static let gapsShown = 3
    /// 两行的空档（一行字、一行建议）要多高
    static let twoLines: CGFloat = 72

    /// 空档放在它开头的地方；前面的小标签往下错开了的话，跟在小标签后面（不叠在一起）；
    /// 到下一件（它的小标签上沿）为止放不下就不标，绝不压到下一件上
    @ViewBuilder func gapViews(
        _ plan: TodoTimelinePlan, rows: [TodoTimelinePlan.TagRow], tops: [CGFloat], width: CGFloat, from: Int
    ) -> some View {
        ForEach(plan.gaps.prefix(Self.gapsShown)) { gap in
            let before = zip(rows, tops).filter { $0.0.minute < gap.start }.map { $0.1 + tagHeight }
            let top = max(y(gap.start, from: from) + Theme.Space.tight, (before.max() ?? 0) + Theme.Space.small)
            let room = y(gap.end, from: from) - tagHeight / 2 - Theme.Space.tight - top
            if room >= Theme.Size.touch {
                gapView(gap, plan: plan, oneLine: room < Self.twoLines)
                    .frame(width: width - Theme.Space.small)
                    .offset(x: Self.gutter + Theme.Space.tight, y: top)
            }
        }
    }

    /// 每个整点一条线，左边写钟点（离「现在」太近的不写）；缩得很小时隔两个钟头写一个，放大了半点也画一条浅线、写钟点。
    /// 画在 Canvas 里：只是刻度，读屏不念；无障碍审计会去量藏起来的字和线（2026-11-05）
    func hourLines(from: Int, last: Int, now: Int?) -> some View {
        Canvas { context, size in
            func covered(_ lineY: CGFloat) -> Bool {
                now.map { abs(y($0, from: from) - lineY) < Theme.Size.badge } ?? false
            }
            for hour in from...last {
                let lineY = y(hour * 60, from: from)
                var line = Path()
                line.move(to: CGPoint(x: Self.gutter, y: lineY))
                line.addLine(to: CGPoint(x: size.width, y: lineY))
                context.stroke(line, with: .color(Theme.Palette.separator), lineWidth: 1)
                if !covered(lineY), !compact || (hour - from) % 2 == 0 {
                    let label = Text("\(Self.hh(hour)):00").font(Theme.Typeface.tick).monospacedDigit()
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                    context.draw(context.resolve(label), at: CGPoint(x: 0, y: lineY), anchor: .leading)
                }
                guard density == .detailed, hour < last else { continue }
                let halfY = y(hour * 60 + 30, from: from)
                var half = Path()
                half.move(to: CGPoint(x: Self.gutter, y: halfY))
                half.addLine(to: CGPoint(x: size.width, y: halfY))
                context.stroke(
                    half, with: .color(Theme.Palette.separator), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                if !covered(halfY) {
                    let label = Text("\(Self.hh(hour)):30").font(Theme.Typeface.tick).monospacedDigit()
                        .foregroundStyle(Theme.Palette.tertiaryLabel)
                    context.draw(context.resolve(label), at: CGPoint(x: 0, y: halfY), anchor: .leading)
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// 作息的底色：睡觉写「睡到 07:00」「23:30 睡觉」，别的写名字和几点到几点；太矮不写字
    func bandView(
        _ band: TodoTimelinePlan.Band, plan: TodoTimelinePlan, width: CGFloat, from: Int, taken: [ClosedRange<CGFloat>]
    ) -> some View {
        let start = max(band.start, from * 60)
        let end = min(band.end, plan.last * 60)
        let top = y(start, from: from)
        let height = max(0, y(end, from: from) - top)
        let label: (title: String, time: String) =
            band.kind != .sleep
            ? (band.title, band.text)
            : band.start == 0
                ? ("睡到", TodoTimelinePlan.Gap.clock(band.end)) : (TodoTimelinePlan.Gap.clock(band.start), band.title)
        // 那行字放在右上角；被小标签、日程、「现在」线占了就放右下角；都占了不写（上面「作息」那一行写着）
        let free = { (range: ClosedRange<CGFloat>) in !taken.contains { $0.overlaps(range) } }
        let line = RoutineBand.labelHeight
        let edge: VerticalEdge? =
            height < line
            ? nil
            : free(top...(top + line)) ? .top : free((top + height - line)...(top + height)) ? .bottom : nil
        return RoutineBand(title: label.title, time: label.time, kind: RoutineText.kind(band.kind), label: edge)
            .frame(width: width, height: height)
            .offset(x: Self.gutter, y: top)
    }

    /// 空档：一条细虚线框，第一个排得进的空档带一个建议（放得下两行才分两行）
    func gapView(_ gap: TodoTimelinePlan.Gap, plan: TodoTimelinePlan, oneLine: Bool) -> some View {
        let suggestion = plan.suggestion?.gap == gap ? plan.suggestion : nil
        return GapBox(
            text: "\(gap.text) 空着", suggestion: suggestion.map { "把「\(Show.spaced($0.row.content))」排进来" },
            lit: model.todoGaps, oneLine: oneLine
        ) {
            if let suggestion { model.schedule(suggestion.row, at: suggestion.at) }
        }
        .accessibilityIdentifier("timeline.gap")
    }
}
