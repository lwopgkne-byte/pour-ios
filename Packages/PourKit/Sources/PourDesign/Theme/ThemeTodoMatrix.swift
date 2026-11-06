public import SwiftUI

// 待办 2.0 四象限（docs/todo-2.0 第 7 步，design/after-03-matrix）：一格（象限底色、圆角 20，格头图标 + 名字 + 数量，
// 下一行副标题）、格里的小卡片（白底圆角 14：圈 + 名字一行 + 时间一行）、格子下面的「还没分」托盘里的一件。只管样子

/// 四象限的一格：象限底色、圆角 20；格头（线条图标 + 名字 + 右边数量，下面副标题）点了进这一格的全部；
/// 拖着卡片到上面时描一圈象限色
public struct MatrixCell<Content: View>: View {
    let quadrant: Int
    let title: String
    let subtitle: String
    let count: Int
    /// 马上做多了：数字后面写「· 有点多」
    let crowded: Bool
    let targeted: Bool
    let open: () -> Void
    let content: Content

    public init(
        quadrant: Int, title: String, subtitle: String, count: Int, crowded: Bool = false, targeted: Bool,
        open: @escaping () -> Void, @ViewBuilder content: () -> Content
    ) {
        self.quadrant = quadrant
        self.title = title
        self.subtitle = subtitle
        self.count = count
        self.crowded = crowded
        self.targeted = targeted
        self.open = open
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Button(action: open) {
                VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Space.tight + Theme.Space.hairline) {
                        if let symbol = Theme.Quadrant.symbol(quadrant) {
                            Image(systemName: symbol.replacingOccurrences(of: ".fill", with: ""))
                                .font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Quadrant.ring(quadrant))
                        }
                        Text(title).font(Theme.Typeface.pageSection).foregroundStyle(Theme.Quadrant.text(quadrant))
                            .lineLimit(1)
                        Spacer(minLength: Theme.Space.tight)
                        Text("\(count)").font(Theme.Typeface.subheadline.weight(.semibold)).monospacedDigit()
                            .foregroundStyle(Theme.Quadrant.text(quadrant))
                            .fixedSize()
                    }
                    // 多了：「有点多」写在副标题后面（格子窄，和名字、数字挤一行会把名字挤成「马…」，2026-11-06）
                    (Text(subtitle).foregroundStyle(Theme.Palette.secondaryLabel)
                        + Text(crowded ? " · 有点多" : "").foregroundStyle(Theme.Quadrant.text(quadrant)).bold())
                        .font(Theme.Typeface.footnote)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("\(title)，\(subtitle)，\(count) 件\(crowded ? "，有点多" : "")"))
            .accessibilityHint(Text("打开这一格的全部"))
            content
        }
        .padding(Theme.Space.small + Theme.Space.hairline)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.Quadrant.tint(quadrant), in: Theme.rounded(Theme.Corner.smallCard))
        .overlay {
            Theme.rounded(Theme.Corner.smallCard)
                .strokeBorder(Theme.Quadrant.ring(quadrant), lineWidth: targeted ? 2 : 0)
        }
        .animation(Theme.Motion.standard, value: targeted)
    }
}

/// 格里的一件：白底圆角 14；左边圈（点了勾掉），右边名字一行、下面时间一行（「下午」「🔔 17:00」「⏱ 11:12 过了」）；
/// 排时间的事到了日子没定时间的写「今天到期」。圈以外点了打开编辑
public struct MatrixCard<Ring: View>: View {
    let title: String
    let done: Bool
    let when: TodoTrailing.Kind?
    let note: String?
    let spoken: String
    /// 到点响铃（像闹钟一样）：时间前面是闹钟
    let alarm: Bool
    let open: () -> Void
    let ring: Ring

    public init(
        _ title: String, done: Bool, when: TodoTrailing.Kind?, note: String? = nil, spoken: String, alarm: Bool = false,
        open: @escaping () -> Void, @ViewBuilder ring: () -> Ring
    ) {
        self.title = title
        self.done = done
        self.when = when
        self.note = note
        self.spoken = spoken
        self.alarm = alarm
        self.open = open
        self.ring = ring()
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ring
            Button(action: open) {
                VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                    Text(title).font(Theme.Typeface.cardItem).lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(done ? Theme.Palette.tertiaryLabel : Theme.Palette.label)
                        .strikethrough(done, color: Theme.Palette.tertiaryLabel)
                    if let note, !done {
                        // 和「⏱ 昨天 11:12」一样只是沙色的字，不再套一个胶囊
                        Label(note, systemImage: "calendar").font(Theme.Typeface.footnoteSemibold)
                            .foregroundStyle(Theme.Palette.warnInk).labelStyle(TightIcon())
                    } else if let when, !done {
                        TodoTrailing(when, plain: true, compact: true, alarm: alarm)
                    }
                }
                .padding(.top, Theme.Space.small + Theme.Space.hairline)
                .padding(.bottom, Theme.Space.small)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.touch, alignment: .topLeading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(spoken))
            .accessibilityHint(Text("打开编辑；按住拖到别的格子"))
            .accessibilityIdentifier("matrix.card")
        }
        .padding(.trailing, Theme.Space.small)
        .background(Theme.Palette.card, in: Theme.rounded(Theme.Corner.choice))
    }
}

/// 图标和字挨得紧一点（「📅 今天到期」）
private struct TightIcon: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Theme.Space.hairline + 1) {
            configuration.icon.font(Theme.Typeface.caption)
            configuration.title
        }
    }
}

/// 托盘里的一件（四象限的「还没分」、时间线的「还没排时间」）：浅灰胶囊，象限的小圈 + 名字（+「 · 下午」）；
/// 点了选一格或打开编辑，按住拖走
public struct TrayChip: View {
    let title: String
    let quadrant: Int
    let note: String?

    public init(_ title: String, quadrant: Int = 0, note: String? = nil) {
        self.title = title
        self.quadrant = quadrant
        self.note = note
    }

    public var body: some View {
        HStack(spacing: Theme.Space.small) {
            QuadrantBadge(quadrant: quadrant, size: Theme.Size.check - Theme.Space.tight)
            Text(title).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label).lineLimit(1)
            if let note {
                Text("· \(note)").font(Theme.Typeface.body).foregroundStyle(Theme.Palette.secondaryLabel).fixedSize()
            }
        }
        .padding(.leading, Theme.Space.small + Theme.Space.hairline).padding(.trailing, Theme.Space.medium)
        .frame(minHeight: Theme.Size.touch)
        // 浅灰底、不描边：托盘本身是白卡片，里面再白底描边就是框套框（2026-11-06 打磨）
        .background(Theme.Palette.fill, in: Capsule())
        .contentShape(Capsule())
    }
}
