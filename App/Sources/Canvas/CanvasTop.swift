import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 画布顶上浮着的玻璃按钮：左边菜单，右边日历、搜索；往上滑以后中间出现「今天 · 10月21日」的玻璃胶囊
struct CanvasTopBar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    let collapsed: Bool
    let openMenu: () -> Void
    let pickDay: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: Theme.Space.small) {
            HStack(spacing: Theme.Space.small) {
                GlassCircleButton("line.3.horizontal", label: "菜单", action: openMenu)
                    .accessibilityIdentifier("today.menu")
                Spacer(minLength: 0)
                if collapsed {
                    Button(action: pickDay) {
                        Text(Self.short(model.shownDay, today: model.today, brief: typeSize.isAccessibilitySize))
                            .font(Theme.Typeface.cardTitle).foregroundStyle(Theme.Palette.label).lineLimit(1)
                            .padding(.horizontal, Theme.Space.regular).frame(minHeight: Theme.Size.touch)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .themeGlassCapsule()
                    .accessibilityHint(Text("跳到某一天"))
                    .themeTransition(.opacity.combined(with: .scale(scale: 0.92)))
                }
                Spacer(minLength: 0)
                GlassCircleButton("calendar", label: "跳到某一天", action: pickDay)
                GlassCircleButton("magnifyingglass", label: "搜索") { model.search = "" }
            }
        }
        .padding(.horizontal, Theme.Space.screen)
        .padding(.vertical, Theme.Space.tight)
        .animation(Theme.Motion.standard, value: collapsed)
    }

    /// 胶囊里的字：「今天 · 10月21日」；别的日子「10月18日 周六」。字号很大时（brief）只写「今天」「10月18日」
    static func short(_ day: String, today: String, brief: Bool = false) -> String {
        let relative = Show.relative(day, today: today)
        if brief { return relative ?? Show.monthDay(day) }
        if let relative { return "\(relative) · \(Show.monthDay(day))" }
        return "\(Show.monthDay(day)) \(Show.weekday(day))"
    }
}

/// 日子：大标题「今天 / 昨天」或日期（几号、星期几下面的一周条上有，不再另写一行）；看别的日子时右边「回到今天」；
/// 下面一排小胶囊：演示数据、昨天的回顾好了
struct CanvasTitle: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let relative = Show.relative(model.shownDay, today: model.today)
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.medium) {
                Text(relative ?? Show.monthDay(model.shownDay))
                    .font(Theme.Typeface.largeTitle).foregroundStyle(Theme.Palette.label)
                    .contentTransition(.opacity)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("today.header")
                if relative == nil {
                    Spacer(minLength: 0)
                    Button("回到今天") {
                        withAnimation(Theme.Motion.pick(Theme.Motion.standard, reduceMotion: reduceMotion)) {
                            model.show(model.today)
                        }
                    }
                    .font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.accent)
                    .buttonStyle(.plain).frame(minHeight: Theme.Size.touch)
                }
            }
            CanvasCapsules()
        }
    }
}

/// 标题下的小胶囊：演示数据（回到真实数据）、早上「昨天的回顾好了」
private struct CanvasCapsules: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let review = ReviewHint.path(model)
        if model.mode == "demo" || review != nil {
            HStack(spacing: Theme.Space.small) {
                if model.mode == "demo" {
                    capsule("演示数据 · 回到真实数据", symbol: "sparkles") { model.open("/settings#data") }
                        .accessibilityHint(Text("现在看的是演示数据，你的真实数据没有变化"))
                }
                if let review {
                    capsule("昨天的回顾好了", symbol: "doc.text") { model.open(review) }
                }
            }
        }
    }

    /// 32 点高的玻璃胶囊；能点的范围撑到 44
    private func capsule(_ text: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(text, systemImage: symbol).font(Theme.Typeface.footnoteSemibold)
                .foregroundStyle(Theme.Palette.secondaryLabel)
                .padding(.horizontal, Theme.Space.medium).frame(minHeight: Theme.Size.capsule)
                .themeGlassCapsule()
                .frame(minHeight: Theme.Size.touch)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 一周条：七天一排（周一到周日），今天蓝色实心圆，选中的别的日子浅灰圆，还没到的日子淡一点；点一下换那天。
/// 字是画出来的：一个字一个元素时审计量对比度不准（笔画太细），读屏读的是整个按钮「10月21日 周二」
struct CanvasWeek: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var circle

    var body: some View {
        let week = Self.week(of: model.shownDay)
        HStack(spacing: 0) {
            ForEach(week, id: \.self) { day in
                Button {
                    withAnimation(Theme.Motion.pick(Theme.Motion.standard, reduceMotion: reduceMotion)) {
                        model.show(day)
                    }
                } label: {
                    // 同一周里换一天：选中的圆滑过去。换了一周不滑（不然往前一天时圆往右跑过整条）；减弱动态效果时也不滑
                    let slide = reduceMotion ? day : week[0]
                    WeekDay(day: day, today: model.today, selected: day == model.shownDay, circle: circle, slide: slide)
                }
                .buttonStyle(PressScale())
                .accessibilityLabel(Text(spoken(day)))
                .accessibilityAddTraits(day == model.shownDay ? .isSelected : [])
            }
        }
        .sensoryFeedback(Theme.Haptics.select, trigger: model.shownDay)
    }

    /// 读屏念的：今天前面加「今天」
    private func spoken(_ day: String) -> String {
        let title = Show.dayTitle(day, today: model.today)
        return day == model.today ? "今天，\(title)" : title
    }

    /// 这一天所在的那一周（周一到周日）
    static func week(of day: String) -> [String] {
        let monday = PourDate.addDays(day, -PourDate.weekdayMon0(day))
        return (0..<7).map { PourDate.addDays(monday, $0) }
    }
}

/// 一周条里的一天：上面「一」，下面日子的数字在一个圆里
private struct WeekDay: View {
    let day: String
    let today: String
    let selected: Bool
    let circle: Namespace.ID
    /// 选中的圆跟着谁滑：同一个值的圆之间滑过去
    let slide: String

    var body: some View {
        let isToday = day == today
        VStack(spacing: Theme.Space.tight) {
            Painted(
                text: String(Show.weekday(day).suffix(1)), font: Theme.Typeface.caption,
                color: isToday ? Theme.Palette.accent : Theme.Palette.tertiaryLabel
            )
            .frame(height: Theme.Size.tickRow)
            Painted(text: "\(Int(day.suffix(2)) ?? 0)", font: Theme.Typeface.dayNumber, color: numberColor(isToday))
                .frame(width: Theme.Size.dayCircle, height: Theme.Size.dayCircle)
                .background {
                    if selected {
                        Circle().fill(isToday ? Theme.Palette.accentFill : Theme.Palette.fill)
                            .matchedGeometryEffect(id: "selected-\(slide)", in: circle)
                    } else if isToday {
                        Circle().strokeBorder(Theme.Palette.accent, lineWidth: 1.5)
                    }
                }
        }
        .padding(.vertical, Theme.Space.tight)
        .frame(maxWidth: .infinity, minHeight: Theme.Size.touch)
        .contentShape(Rectangle())
    }

    private func numberColor(_ isToday: Bool) -> Color {
        if selected && isToday { return Theme.Palette.onAccent }
        return day > today ? Theme.Palette.tertiaryLabel : Theme.Palette.label
    }
}

/// 画出来的一小段字（不算一个元素）；字号最大到「特大」，再大圆里放不下
private struct Painted: View {
    let text: String
    let font: Font
    let color: Color

    var body: some View {
        Canvas { context, size in
            context.draw(
                Text(verbatim: text).font(font).foregroundStyle(color),
                at: CGPoint(x: size.width / 2, y: size.height / 2))
        }
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}
