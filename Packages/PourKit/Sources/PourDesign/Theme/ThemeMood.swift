public import SwiftUI

// 3.0 心情（docs/3.0/06-交互细节.md 第 4 节）：五档同一种粉从浅到深，表情本身说明好坏（不只靠颜色）——
// 带颜色的表情、五个小点、「现在心情怎么样」那一排、每格一个表情的月历、一周七根竖条

extension Theme {
    /// 五档心情的颜色（1 很差 … 5 很好）：底色从浅到深；浅的两三档脸用深粉色画，深的用白色（对比度 ThemeColorTests 量）
    public enum Mood {
        static let fills: [UInt32] = [0xE9D1DC, 0xDDB0C5, 0xCF8DAD, 0xB45584, 0x96305F]
        static let inks: [UInt32] = [0x7E2A52, 0x6E2147, 0x4F1631, 0xFFFFFF, 0xFFFFFF]

        static func index(_ level: Int) -> Int { min(5, max(1, level)) - 1 }
        public static func fillToken(_ level: Int) -> ColorToken { Tokens.one(fills[index(level)]) }
        public static func inkToken(_ level: Int) -> ColorToken { Tokens.one(inks[index(level)]) }
        /// 这一档的底色
        public static func fill(_ level: Int) -> Color { fillToken(level).color }
        /// 画在这一档底色上的脸
        public static func ink(_ level: Int) -> Color { inkToken(level).color }
        /// 五个小点里没点亮的
        public static let empty = Tokens.one(0xEADFE4).color
        /// 五档的说法
        public static let names = ["很差", "不太好", "一般", "挺好", "很好"]
    }
}

/// 带颜色的表情：这一档的粉色圆，上面画脸（很差皱眉、嘴往下弯；很好嘴往上弯）。选中的放大一点、外面一圈
public struct MoodBadge: View {
    let level: Int
    let size: CGFloat
    let selected: Bool

    public init(level: Int, size: CGFloat = Theme.Size.touch, selected: Bool = false) {
        self.level = min(5, max(1, level))
        self.size = size
        self.selected = selected
    }

    public var body: some View {
        Canvas { context, canvas in
            let side = min(canvas.width, canvas.height)
            let face = CGRect(x: 0, y: 0, width: side, height: side).insetBy(dx: side * 0.2, dy: side * 0.2)
            MoodFace.draw(
                level: level, in: face, ink: Theme.Mood.ink(level), line: max(1.5, side / 16), context: context,
                brows: false)
        }
        .frame(width: size, height: size)
        .background(Theme.Mood.fill(level), in: Circle())
        .padding(selected ? Theme.Space.hairline : 0)
        .overlay {
            if selected { Circle().stroke(Theme.Mood.fill(5), lineWidth: Theme.Space.hairline) }
        }
        .scaleEffect(selected ? 1.12 : 1)
        .animation(Theme.Motion.quick, value: selected)
        .accessibilityElement()
        .accessibilityLabel(Text(Theme.Mood.names[level - 1]))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 五个小点：点亮到这一档（一刻心情的一行、好时刻）
public struct MoodDots: View {
    let level: Int

    public init(level: Int) {
        self.level = min(5, max(1, level))
    }

    public var body: some View {
        HStack(spacing: Theme.Space.hairline + 1) {
            ForEach(1...5, id: \.self) { dot in
                Circle().fill(dot <= level ? Theme.Mood.fill(5) : Theme.Mood.empty)
                    .frame(width: Theme.Size.dot - 1, height: Theme.Size.dot - 1)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("心情：\(Theme.Mood.names[level - 1])，五级里的第 \(level) 级"))
    }
}

/// 现在心情怎么样：五个表情，下面写说法；点一个就记（选中的放大）
public struct MoodCheckinRow: View {
    let selected: Int?
    /// 界面测试认的编号前缀（心情页「mood.level」、弹层里各自一个）
    let id: String
    let pick: (Int) -> Void

    public init(selected: Int? = nil, id: String = "mood.level", pick: @escaping (Int) -> Void) {
        self.selected = selected
        self.id = id
        self.pick = pick
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(1...5, id: \.self) { level in
                Button {
                    pick(level)
                } label: {
                    VStack(spacing: Theme.Space.snug) {
                        MoodBadge(level: level, size: Theme.Size.touch + Theme.Space.tight, selected: selected == level)
                        Text(Theme.Mood.names[level - 1]).font(Theme.Typeface.footnote)
                            .foregroundStyle(selected == level ? Theme.Palette.label : Theme.Palette.secondaryLabel)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressScale())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(Theme.Mood.names[level - 1]))
                .accessibilityAddTraits(selected == level ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier("\(id).\(level)")
            }
        }
        .themeSelectionFeedback(trigger: selected)
    }
}

/// 心情月历：一格一天，上面几号、下面那天的表情（一天几条取平均）；没说心情写「—」。今天蓝框、选中蓝底
public struct MoodMonthGrid: View {
    public struct Day: Hashable, Sendable {
        public let day: String
        public let number: Int
        /// 1–5；没说心情是 nil
        public let level: Int?
        /// 读屏念的（「10月24日，挺好」）
        public let spoken: String

        public init(day: String, number: Int, level: Int?, spoken: String) {
            self.day = day
            self.number = number
            self.level = level
            self.spoken = spoken
        }
    }

    let blanks: Int
    let days: [Day]
    let today: String?
    let selected: String?
    let pick: (String) -> Void

    public init(blanks: Int, days: [Day], today: String?, selected: String?, pick: @escaping (String) -> Void) {
        self.blanks = blanks
        self.days = days
        self.today = today
        self.selected = selected
        self.pick = pick
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Theme.Space.tight), count: 7)

    public var body: some View {
        LazyVGrid(columns: columns, spacing: Theme.Space.tight) {
            ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { name in
                Text(name).font(Theme.Typeface.caption).foregroundStyle(Theme.Palette.secondaryLabel)
                    .accessibilityHidden(true)
            }
            ForEach(0..<blanks, id: \.self) { _ in Color.clear.frame(height: 1).accessibilityHidden(true) }
            ForEach(days, id: \.day) { day in cell(day) }
        }
    }

    private func cell(_ day: Day) -> some View {
        let isSelected = selected == day.day
        let isToday = today == day.day
        return Button {
            pick(day.day)
        } label: {
            VStack(spacing: Theme.Space.hairline) {
                Text("\(day.number)").font(Theme.Typeface.caption).monospacedDigit()
                    .foregroundStyle(isSelected ? Theme.Palette.onAccent : Theme.Palette.secondaryLabel)
                if let level = day.level {
                    MoodBadge(level: level, size: Theme.Size.badge + Theme.Space.tight)
                } else {
                    Text("—").font(Theme.Typeface.footnote)
                        .foregroundStyle(isSelected ? Theme.Palette.onAccent : Theme.Palette.tertiaryLabel)
                        .frame(height: Theme.Size.badge + Theme.Space.tight)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Theme.Size.touch + Theme.Space.medium)
            .background(isSelected ? Theme.Palette.accentFill : .clear, in: Theme.rounded(Theme.Corner.tile))
            .overlay {
                if isToday && !isSelected {
                    Theme.rounded(Theme.Corner.tile)
                        .stroke(Theme.Palette.accent, lineWidth: Theme.Space.hairline / 2 + 0.5)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(day.spoken))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("mood.day.\(day.day)")
    }
}

/// 一周七根竖条：高度是那个星期几的平均心情，顶上是表情；够数的才画（不够的是一截灰）
public struct MoodWeekBars: View {
    /// 周一到周日：平均心情（1–5），不够数是 nil
    let values: [Double?]
    /// 最低的那天（0 是周一），没说是 nil
    let low: Int?

    public init(values: [Double?], low: Int?) {
        self.values = values
        self.low = low
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: Theme.Space.small) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                VStack(spacing: Theme.Space.tight) {
                    if let value {
                        MoodBadge(level: Int(value.rounded()), size: Theme.Size.badge)
                        Theme.rounded(Theme.Corner.tile)
                            .fill(index == low ? Theme.Mood.fill(5) : Theme.Mood.fill(3))
                            .frame(height: Theme.Size.curve * CGFloat(max(0.15, (value - 1) / 4)))
                    } else {
                        Theme.rounded(Theme.Corner.tile).fill(Theme.Palette.fill).frame(height: Theme.Space.small)
                    }
                    Text(["一", "二", "三", "四", "五", "六", "日"][index]).font(Theme.Typeface.caption)
                        .foregroundStyle(index == low ? Theme.Palette.label : Theme.Palette.secondaryLabel)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: Theme.Size.curve + Theme.Size.badge + Theme.Space.xLarge, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(spoken))
    }

    private var spoken: String {
        let names = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        return values.enumerated().compactMap { index, value in
            value.map { "\(names[index]) \(Theme.Mood.names[min(5, max(1, Int($0.rounded()))) - 1])" }
        }.joined(separator: "，")
    }
}

#Preview("心情：表情、五个小点、现在心情怎么样、月历、一周") {
    @Previewable @State var picked: Int?
    let days = (1...31).map { number in
        MoodMonthGrid.Day(
            day: String(format: "2026-10-%02d", number), number: number, level: number % 6 == 0 ? nil : number % 5 + 1,
            spoken: "10月\(number)日")
    }
    ScrollView {
        VStack(spacing: Theme.Space.regular) {
            HStack { ForEach(1...5, id: \.self) { MoodBadge(level: $0, selected: $0 == 4) } }
            HStack { ForEach(1...5, id: \.self) { MoodDots(level: $0) } }
            MoodCheckinRow(selected: picked) { picked = $0 }.themeCard()
            MoodMonthGrid(blanks: 3, days: days, today: "2026-10-12", selected: "2026-10-04") { _ in }.themeCard()
            MoodWeekBars(values: [2.6, 3.9, 2.4, 4, nil, 3.7, 3.8], low: 2).themeCard()
        }
        .padding()
    }
    .background(Theme.Palette.background)
}
