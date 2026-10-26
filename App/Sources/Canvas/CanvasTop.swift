import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 画布顶上浮着的一行玻璃（设计评审 2026-10-23：日期默认收起，需要时再展开）：左边菜单；中间是现在看的那天
/// 「今天 · 10月21日」，点一下展开、收起一周；右边日历（跳到哪天都行）、搜索
struct CanvasTopBar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var weekOpen: Bool
    let openMenu: () -> Void
    let pickDay: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: Theme.Space.small) {
            HStack(spacing: Theme.Space.small) {
                GlassCircleButton("line.3.horizontal", label: "菜单", action: openMenu)
                    .accessibilityIdentifier("today.menu")
                Spacer(minLength: 0)
                dayButton
                Spacer(minLength: 0)
                GlassCircleButton("calendar", label: "跳到某一天", action: pickDay)
                GlassCircleButton("magnifyingglass", label: "搜索") { model.search = "" }
            }
        }
        .padding(.horizontal, Theme.Space.screen)
        .padding(.vertical, Theme.Space.tight)
    }

    /// 现在看的那天（看别的日子时写那天，不一直写「今天」）；点一下展开、收起一周
    private var dayButton: some View {
        let title = Self.short(model.shownDay, today: model.today)
        return Button {
            withAnimation(Theme.Motion.pick(Theme.Motion.standard, reduceMotion: reduceMotion)) { weekOpen.toggle() }
        } label: {
            HStack(spacing: Theme.Space.snug) {
                Text(title).font(Theme.Typeface.cardTitle).foregroundStyle(Theme.Palette.label).lineLimit(1)
                    .contentTransition(.opacity)
                Image(systemName: "chevron.down").font(Theme.Typeface.caption)
                    .foregroundStyle(Theme.Palette.secondaryLabel)
                    .rotationEffect(.degrees(weekOpen ? 180 : 0))
            }
            .padding(.horizontal, Theme.Space.regular).frame(minHeight: Theme.Size.touch)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .themeGlassCapsule()
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text(weekOpen ? "收起这一周" : "展开这一周，点哪天看哪天"))
        .accessibilityIdentifier("today.header")
    }

    /// 胶囊里的字：「今天 · 10月21日」；别的日子「10月18日 周六」
    static func short(_ day: String, today: String) -> String {
        let relative = Show.relative(day, today: today)
        if let relative { return "\(relative) · \(Show.monthDay(day))" }
        return "\(Show.monthDay(day)) \(Show.weekday(day))"
    }
}

/// 画布最上面一行（日子写在顶上的玻璃胶囊里，这里不再写大标题）：小胶囊（画布样张、演示数据、昨天的回顾好了），
/// 看别的日子时「回到今天」；放不下就折到下一行；都没有时这一行不占地方
struct CanvasDayHints: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let other = model.shownDay != model.today
        if other || CanvasCapsules.any(model) {
            PourFlowLayout(spacing: Theme.Space.small, lineSpacing: 0) {
                CanvasCapsules()
                if other {
                    Button("回到今天") {
                        withAnimation(Theme.Motion.pick(Theme.Motion.standard, reduceMotion: reduceMotion)) {
                            model.show(model.today)
                        }
                    }
                    .font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.accent)
                    .buttonStyle(.plain).frame(minHeight: Theme.Size.touch)
                }
            }
        }
    }
}

/// 标题下的小胶囊：演示数据（回到真实数据）、早上「昨天的回顾好了」
private struct CanvasCapsules: View {
    @Environment(AppModel.self) private var model

    /// 有没有要出的小胶囊
    static func any(_ model: AppModel) -> Bool {
        CanvasSamples.isOn || model.mode == "demo" || ReviewHint.path(model) != nil
    }

    /// 一个个胶囊（外面的 PourFlowLayout 放不下就折行）
    var body: some View {
        if CanvasSamples.isOn {
            capsule("画布样张 · 回到服务器的数据", symbol: "square.grid.2x2") { model.showSamples(false) }
                .accessibilityHint(Text("现在看的是 App 里的样张，一周每天一种人的一天，不连服务器"))
                .accessibilityIdentifier("canvas.samples")
        } else if model.mode == "demo" {
            capsule("演示数据 · 回到真实数据", symbol: "sparkles") { model.open("/settings#data") }
                .accessibilityHint(Text("现在看的是演示数据，你的真实数据没有变化"))
        }
        if let review = ReviewHint.path(model) {
            capsule("昨天的回顾好了", symbol: "doc.text") { model.open(review) }
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
