public import SwiftUI

// 作息（待办的时间线，产品主人 2026-11-06）：每天差不多的几段时间画成淡淡的底色，睡觉的那段收成上下两条。
// 别家的日历都是这样标上班以外的时间：比日程淡得多，只是看的，不挡你排事情（不接手指）

extension Theme {
    /// 作息的底色：比日程（Agenda）淡，叠在它下面
    public enum Routine {
        /// 睡觉：夜里的一点靛蓝
        public static let night = Tokens.one(0x2E3B66, opacity: 0.07).color
        /// 上班、上学：最淡的一层浅墨
        public static let work = Tokens.one(0x1D1C1A, opacity: 0.04).color
        /// 忙着（通勤、吃饭、健身）：深一点，看得出这段排不进事
        public static let busy = Tokens.one(0x1D1C1A, opacity: 0.075).color
    }
}

/// 作息落在时间线上的一段：圆角的底色，小字「上班 09:30–18:30」写在右上角（被压住时写在右下角，都被压住就不写）；只是看的
public struct RoutineBand: View {
    public enum Kind: Sendable {
        case sleep, work, busy
    }

    let title: String
    let time: String
    let kind: Kind
    /// 字写在上边还是下边；nil 是不写
    let label: VerticalEdge?

    public init(title: String, time: String, kind: Kind, label: VerticalEdge?) {
        self.title = title
        self.time = time
        self.kind = kind
        self.label = label
    }

    /// 那行字占多高（时间线上找地方用）
    public static let labelHeight: CGFloat = 22

    public var body: some View {
        Theme.rounded(Theme.Corner.tile)
            .fill(fill)
            .overlay(alignment: label == .bottom ? .bottomTrailing : .topTrailing) {
                if label != nil {
                    HStack(spacing: Theme.Space.tight) {
                        Image(systemName: RoutineBand.symbol(title: title, kind: kind))
                        Text("\(title) \(time)").monospacedDigit()
                    }
                    .font(Theme.Typeface.caption).foregroundStyle(Theme.Palette.secondaryLabel)
                    .lineLimit(1)
                    .padding(.horizontal, Theme.Space.small)
                    .padding(label == .bottom ? .bottom : .top, Theme.Space.tight)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var fill: Color {
        switch kind {
        case .sleep: Theme.Routine.night
        case .work: Theme.Routine.work
        case .busy: Theme.Routine.busy
        }
    }

    /// 一段作息的小图标：按名字认（上班、吃饭、通勤……），认不出按种类
    public static func symbol(title: String, kind: Kind) -> String {
        let known: [(String, String)] = [
            ("睡", "moon.zzz"), ("班", "briefcase"), ("学", "graduationcap"), ("课", "graduationcap"),
            ("饭", "fork.knife"), ("餐", "fork.knife"), ("通勤", "tram"), ("地铁", "tram"), ("开车", "car"),
            ("健身", "figure.run"), ("跑", "figure.run"), ("运动", "figure.run"), ("午休", "cup.and.saucer"),
            ("孩子", "figure.and.child.holdinghands"), ("儿子", "figure.and.child.holdinghands"),
        ]
        if let hit = known.first(where: { title.contains($0.0) }) { return hit.1 }
        switch kind {
        case .sleep: return "moon.zzz"
        case .work: return "briefcase"
        case .busy: return "clock"
        }
    }
}

/// 时间线上下收起来的睡觉：「睡到 07:00」「23:30 睡觉」，点了改作息
public struct SleepEdge: View {
    let text: String
    let action: () -> Void

    public init(_ text: String, action: @escaping () -> Void) {
        self.text = text
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.tight) {
                Image(systemName: "moon.zzz").font(Theme.Typeface.caption)
                Text(text).monospacedDigit()
            }
            .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            .padding(.horizontal, Theme.Space.medium)
            .frame(minHeight: Theme.Size.badge + Theme.Space.small)
            .background(Theme.Routine.night, in: Capsule())
            .frame(minHeight: Theme.Size.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("改作息"))
    }
}
