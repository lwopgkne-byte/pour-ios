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
                if let when, !done { TodoTrailing(when) }
                if let clash, !done { SandPill(clash, symbol: "exclamationmark.triangle") }
            }
            .padding(.leading, Theme.Space.tight)
            .padding(.trailing, Theme.Space.small + Theme.Space.hairline)
            .frame(minHeight: Self.height)
            .background(Theme.Palette.card, in: Capsule())
            .overlay { Capsule().strokeBorder(Theme.Palette.separator, lineWidth: 0.5) }
            .shadow(color: Theme.Palette.shadowFar, radius: 4, y: 1)
            .frame(minHeight: Theme.Size.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .accessibilityLabel(Text(spoken))
        .accessibilityHint(Text("打开编辑"))
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

/// 「现在」：左边蓝色时间胶囊 + 横过去一条 2pt 品牌蓝的线（画在标签、日程下面一层）
public struct NowMarker: View {
    let clock: String
    let gutter: CGFloat

    public init(clock: String, gutter: CGFloat) {
        self.clock = clock
        self.gutter = gutter
    }

    public var body: some View {
        HStack(spacing: 0) {
            Text(clock).font(Theme.Typeface.footnoteBold).monospacedDigit()
                .foregroundStyle(Theme.Palette.onAccent)
                .padding(.horizontal, Theme.Space.small - Theme.Space.hairline)
                .frame(minHeight: Theme.Size.badge + Theme.Space.tight)
                .background(Theme.Palette.accentFill, in: Capsule())
                .frame(width: gutter, alignment: .leading)
            Rectangle().fill(Theme.Palette.accentFill).frame(height: 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("现在 \(clock)"))
    }
}

/// 1 小时以上的空档：虚线框「13:00–15:00 空着」，下面可以有一个建议按钮「＋ 把「回复客户电话」排进来」；
/// 从四象限「排进空档」过来时框描成品牌蓝
public struct GapBox: View {
    let text: String
    let suggestion: String?
    let lit: Bool
    let action: () -> Void

    public init(text: String, suggestion: String?, lit: Bool, action: @escaping () -> Void) {
        self.text = text
        self.suggestion = suggestion
        self.lit = lit
        self.action = action
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text(text).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
            if let suggestion {
                Button(action: action) {
                    Label(suggestion, systemImage: "plus").font(Theme.Typeface.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .foregroundStyle(Theme.Palette.accent)
                        .padding(.horizontal, Theme.Space.medium)
                        .frame(minHeight: Theme.Size.touch - Theme.Space.tight)
                        .background(Theme.Palette.bubble, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(PressScale())
            }
        }
        .padding(Theme.Space.medium)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay {
            Theme.rounded(Theme.Corner.choice)
                .strokeBorder(
                    lit ? Theme.Palette.accentFill : Theme.Palette.tertiaryLabel,
                    style: StrokeStyle(lineWidth: lit ? 1.5 : 1, dash: [5, 4]))
        }
        .accessibilityElement(children: .contain)
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
