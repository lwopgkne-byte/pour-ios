public import SwiftUI

// 3.0 待办行（docs/3.0/01-需求文档.md 3.2、06 交互细节 2.1）：大圆圈、标题、时间胶囊、第二行（和谁、东西、地方、重复）。
// 只管样子；点了做什么、左右滑、按住的菜单由用它的地方接（待办页、画布的待办卡）

/// 待办的圆圈：点的范围 44×44；勾上时填满、对勾弹出来、成功的触感（01 3.3）。
/// 「减少动态效果」时只渐变（themeTransition）
public struct TodoCircle: View {
    let done: Bool
    let label: String
    let toggle: () -> Void

    public init(done: Bool, label: String, toggle: @escaping () -> Void) {
        self.done = done
        self.label = label
        self.toggle = toggle
    }

    public var body: some View {
        Button(action: toggle) {
            ZStack {
                Circle().strokeBorder(done ? Theme.Palette.accentFill : Theme.Palette.tertiaryLabel, lineWidth: 1.6)
                if done {
                    Circle().fill(Theme.Palette.accentFill)
                    Image(systemName: Theme.Symbol.done).font(Theme.Typeface.glyph)
                        .foregroundStyle(Theme.Palette.onAccent)
                        .themeTransition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: Theme.Size.check, height: Theme.Size.check)
            .frame(width: Theme.Size.touch, height: Theme.Size.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(Theme.Motion.spring, value: done)
        .todoDoneFeedback(done)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(done ? "已完成" : "未完成"))
        .accessibilityHint(Text(done ? "改成没完成" : "完成"))
        .accessibilityIdentifier("todo.check")
    }
}

/// 时间胶囊：蓝 = 到点提醒（🔔 17:30）；黄 = 过了没做（「10:00 过了」）、以前没做完的写本来的日子（「10月25日」）
public struct TimeCapsule: View {
    public enum Tone: Sendable {
        /// 到点提醒（蓝）
        case remind
        /// 过了时间、以前没做完的（留意色）
        case late
        /// 只写日子（明天、这周、以后里的「10月30日」）
        case plain
    }

    let text: String
    let tone: Tone

    public init(_ text: String, tone: Tone) {
        self.text = text
        self.tone = tone
    }

    public var body: some View {
        HStack(spacing: Theme.Space.hairline) {
            if let symbol {
                Image(systemName: symbol).font(Theme.Typeface.glyph).accessibilityHidden(true)
            }
            Text(text).font(Theme.Typeface.footnoteMedium).monospacedDigit()
        }
        .foregroundStyle(color)
        .padding(.horizontal, Theme.Space.small)
        .padding(.vertical, Theme.Space.hairline)
        .background(fill, in: Capsule())
        .fixedSize()
    }

    private var symbol: String? {
        switch tone {
        case .remind: Theme.Symbol.remind
        case .late: "clock"
        case .plain: nil
        }
    }

    private var color: Color {
        switch tone {
        case .remind: Theme.Palette.accent
        case .late: Theme.Palette.warnInk
        case .plain: Theme.Palette.secondaryLabel
        }
    }

    private var fill: Color {
        switch tone {
        case .remind: Theme.Palette.remindFill
        case .late: Theme.Palette.warnFill
        case .plain: Theme.Palette.fill
        }
    }
}

/// 一行待办的字：标题（最多两行）、右边时间胶囊、第二行辅助色（和谁 · 东西 · 地方、↻ 重复）。
/// 做完的划线、变次要色，留在原地（产品主人 2026-10-21）；新加的、刚挪过来的亮一下再变回去（06 第 0 节第 4 条）
public struct TodoLabel: View {
    let title: String
    let done: Bool
    let capsule: (text: String, tone: TimeCapsule.Tone)?
    let detail: String?
    let repeatText: String?

    public init(
        _ title: String, done: Bool, capsule: (text: String, tone: TimeCapsule.Tone)? = nil, detail: String? = nil,
        repeatText: String? = nil
    ) {
        self.title = title
        self.done = done
        self.capsule = capsule
        self.detail = detail
        self.repeatText = repeatText
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.small) {
            VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                Text(title).font(Theme.Typeface.body).lineLimit(2)
                    .foregroundStyle(done ? Theme.Palette.secondaryLabel : Theme.Palette.label)
                    .strikethrough(done, color: Theme.Palette.secondaryLabel)
                if !done, detail != nil || repeatText != nil {
                    HStack(spacing: Theme.Space.small) {
                        if let repeatText {
                            Label(repeatText, systemImage: Theme.Symbol.repeats).labelStyle(TightLabel())
                        }
                        if let detail { Text(detail).lineLimit(1) }
                    }
                    .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                }
            }
            Spacer(minLength: 0)
            if !done, let capsule { TimeCapsule(capsule.text, tone: capsule.tone) }
        }
        .padding(.vertical, Theme.Space.small)
        .animation(Theme.Motion.spring, value: done)
    }
}

/// 日历里的日程，穿插在今天里（只读）：左边一条日历颜色的竖条，右边「14:00–15:30」或「全天 · 日历」
public struct CalendarLine: View {
    let title: String
    let time: String
    let color: Color

    public init(_ title: String, time: String, color: Color = Theme.Tile.blue) {
        self.title = title
        self.time = time
        self.color = color
    }

    public var body: some View {
        HStack(spacing: Theme.Space.medium) {
            Capsule().fill(color).frame(width: Theme.Space.tight, height: Theme.Size.capsule - Theme.Space.small)
                .accessibilityHidden(true)
            Text(title).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label).lineLimit(2)
            Spacer(minLength: Theme.Space.small)
            Text(time).font(Theme.Typeface.footnote).monospacedDigit().foregroundStyle(Theme.Palette.secondaryLabel)
                .fixedSize()
        }
        .padding(.vertical, Theme.Space.small)
        .frame(minHeight: Theme.Size.touch)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("日历：\(title)，\(time)"))
    }
}

/// 图标和字挨得紧一点的标签（「↻ 每周一」）
private struct TightLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Theme.Space.hairline) {
            configuration.icon.font(Theme.Typeface.glyph)
            configuration.title
        }
    }
}

extension View {
    /// 勾上时成功的触感（取消打勾不震）
    fileprivate func todoDoneFeedback(_ done: Bool) -> some View {
        #if os(iOS)
            sensoryFeedback(Theme.Haptics.done, trigger: done) { _, now in now }
        #else
            self
        #endif
    }
}

#Preview("待办行：全部状态") {
    @Previewable @State var done = false
    VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 0) {
            TodoCircle(done: done, label: "把会员改版的 PRD 发给研发") { done.toggle() }
            TodoLabel(
                "把会员改版的 PRD 发给研发", done: done, capsule: ("17:30", .remind), detail: "研发 · PRD")
        }
        Divider()
        HStack(spacing: 0) {
            TodoCircle(done: false, label: "交水费") {}
            TodoLabel("交水费", done: false, capsule: ("10月25日", .late))
        }
        Divider()
        HStack(spacing: 0) {
            TodoCircle(done: false, label: "给客户回电话") {}
            TodoLabel("给客户回电话", done: false, capsule: ("10:00 过了", .late))
        }
        Divider()
        HStack(spacing: 0) {
            TodoCircle(done: false, label: "交周报") {}
            TodoLabel("交周报", done: false, capsule: ("09:00", .remind), repeatText: "每周一")
        }
        Divider()
        HStack(spacing: 0) {
            TodoCircle(done: true, label: "买牛奶") {}
            TodoLabel("买牛奶", done: true, capsule: ("18:00", .remind))
        }
        Divider()
        CalendarLine("产品评审会", time: "14:00–15:30").padding(.leading, Theme.Space.regular)
        CalendarLine("结婚纪念日", time: "全天 · 日历", color: Theme.Tile.pink).padding(.leading, Theme.Space.regular)
    }
    .padding(.trailing, Theme.Space.regular)
    .background(Theme.Palette.card)
    .padding()
    .background(Theme.Palette.background)
}
