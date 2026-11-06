public import SwiftUI

// 待办 2.0 时间线（docs/todo-2.0 第 8 步，design/after-04-timeline）：定了钟点的待办画成 28 高的小标签（不再画成 45 分钟的块），
// 日程块、「现在」线（品牌蓝 2pt，画在卡片下面一层，左边时间胶囊）、空档虚线框、收起来的钟点。只管样子

/// 时间线上的一件待办：白底胶囊、轻阴影；小圈 + 名字 + 右边时间或状态，撞上日程再加沙色「撞上面试」。
/// 看得见的高 28，点的地方 44
public struct TimelineTag: View {
    let quadrant: Int
    let title: String
    let done: Bool
    let when: TodoTrailing.Kind?
    let clash: String?
    let spoken: String
    let action: () -> Void

    public init(
        quadrant: Int, title: String, done: Bool, when: TodoTrailing.Kind?, clash: String?, spoken: String,
        action: @escaping () -> Void
    ) {
        self.quadrant = quadrant
        self.title = title
        self.done = done
        self.when = when
        self.clash = clash
        self.spoken = spoken
        self.action = action
    }

    public static let height: CGFloat = 28

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.tight + Theme.Space.hairline) {
                QuadrantBadge(quadrant: quadrant, size: Theme.Size.check - Theme.Space.tight)
                Text(title).font(Theme.Typeface.subheadline).lineLimit(1)
                    .foregroundStyle(done ? Theme.Palette.tertiaryLabel : Theme.Palette.label)
                    .strikethrough(done, color: Theme.Palette.tertiaryLabel)
                if let when, !done { time(when) }
                if let clash, !done { SandPill(clash, symbol: "exclamationmark.triangle") }
            }
            .padding(.leading, Theme.Space.tight)
            .padding(.trailing, Theme.Space.small + Theme.Space.hairline)
            .frame(minHeight: Self.height)
            .background(Theme.Palette.card, in: Capsule())
            // 只留一层淡淡的影子（细边 + 影子画的是同一条边，多余）
            .shadow(color: Theme.Palette.shadowFar, radius: 3, y: 1)
            .frame(minHeight: Theme.Size.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .accessibilityLabel(Text(spoken))
        .accessibilityHint(Text("打开编辑"))
    }

    /// 标签上的钟点只写小字（它摆在哪就是几点，不再加铃铛；快到了蓝、过了沙色）：并排两件也放得下一行
    @ViewBuilder private func time(_ kind: TodoTrailing.Kind) -> some View {
        switch kind {
        case .soon(let text):
            Text(String(text.split(separator: " · ").first ?? Substring(text)))
                .font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.accent)
        case .late(let text):
            Text(text).font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.warnInk)
        case .clock(let text), .window(let text), .day(let text), .clash(let text):
            Text(text).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
        }
    }
}

/// 时间线上的一个日程：浅蓝块，几点到几点（粗）+ 名字（两行）；只看
public struct EventBlock: View {
    let time: String
    let title: String

    public init(time: String, title: String) {
        self.time = time
        self.title = title
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.hairline) {
            Text(time).font(Theme.Typeface.footnoteSemibold).monospacedDigit()
            Text(title).font(Theme.Typeface.footnote).lineLimit(2)
        }
        .foregroundStyle(Theme.Agenda.ink)
        .padding(.horizontal, Theme.Space.small + Theme.Space.hairline)
        .padding(.vertical, Theme.Space.small - Theme.Space.hairline)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.Agenda.fill, in: Theme.rounded(Theme.Corner.tile + Theme.Space.tight))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("日程 \(time)，\(title)"))
    }
}

/// 「现在」：左边那一列写现在几点（蓝字），线头一个小圆点，横过去一条细的品牌蓝线（画在标签、日程下面一层）。
/// 和系统日历一样，不用实心胶囊
public struct NowMarker: View {
    let clock: String
    let gutter: CGFloat

    public init(clock: String, gutter: CGFloat) {
        self.clock = clock
        self.gutter = gutter
    }

    public static let height: CGFloat = 16

    public var body: some View {
        HStack(spacing: 0) {
            Text(clock).font(Theme.Typeface.tick.weight(.bold)).monospacedDigit()
                .foregroundStyle(Theme.Palette.accent)
                .frame(width: gutter - Theme.Space.tight, alignment: .leading)
            Circle().fill(Theme.Palette.accentFill)
                .frame(width: Theme.Space.small - 1, height: Theme.Space.small - 1)
            Rectangle().fill(Theme.Palette.accentFill).frame(height: 1.5)
        }
        // 只是一条线：不接手指（下面的拖放、小标签照样点得到），读屏不单独念（状态栏上就有现在几点）
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 1 小时以上的空档：在空档开头放一条细虚线框「10:30–22:00 空着」，右边一个建议「＋ 把「喝茶」排进来」；
/// 不再画一个从开头到结尾的大框（几个钟头的空档一大块虚线，乱，2026-11-06）。从四象限「排进空档」过来时描成品牌蓝
public struct GapBox: View {
    let text: String
    let suggestion: String?
    let lit: Bool
    /// 空档不到一个半钟头：写成一行（两行的话比空档还高，压到下一件）
    let oneLine: Bool
    let action: () -> Void

    public init(
        text: String, suggestion: String?, lit: Bool, oneLine: Bool = false, action: @escaping () -> Void
    ) {
        self.text = text
        self.suggestion = suggestion
        self.lit = lit
        self.oneLine = oneLine
        self.action = action
    }

    public var body: some View {
        Group {
            if oneLine || suggestion == nil {
                HStack(spacing: Theme.Space.small) {
                    words.layoutPriority(1)
                    Spacer(minLength: 0)
                    if let suggestion { button(suggestion) }
                }
                .frame(minHeight: Theme.Size.touch)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    words.frame(minHeight: Theme.Size.badge + Theme.Space.small)
                    button(suggestion ?? "")
                }
                .padding(.vertical, Theme.Space.tight)
            }
        }
        .padding(.horizontal, Theme.Space.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            Theme.rounded(Theme.Corner.choice - 2)
                .strokeBorder(
                    lit ? Theme.Palette.accentFill : Theme.Palette.separator,
                    style: StrokeStyle(lineWidth: lit ? 1.5 : 1, dash: [4, 3]))
        }
        .accessibilityElement(children: .contain)
    }

    private var words: some View {
        Text(text).font(Theme.Typeface.footnote).monospacedDigit().foregroundStyle(Theme.Palette.secondaryLabel)
            .lineLimit(1)
    }

    private func button(_ title: String) -> some View {
        Button(action: action) {
            Label(title, systemImage: "plus").font(Theme.Typeface.footnoteSemibold).lineLimit(1)
                .foregroundStyle(Theme.Palette.accent)
                .frame(minHeight: Theme.Size.touch - Theme.Space.small, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 现在以前没安排、收起来的钟点：「08:00–11:00 没安排，已收起 ⌄」，点了展开
public struct CollapsedHours: View {
    let text: String
    let action: () -> Void

    public init(_ text: String, action: @escaping () -> Void) {
        self.text = text
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.tight) {
                Text(text).monospacedDigit()
                Image(systemName: "chevron.down").font(Theme.Typeface.caption)
            }
            .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            .padding(.horizontal, Theme.Space.medium)
            .frame(minHeight: Theme.Size.badge + Theme.Space.small)
            .background(Theme.Palette.fill, in: Capsule())
            .frame(minHeight: Theme.Size.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("展开"))
    }
}
