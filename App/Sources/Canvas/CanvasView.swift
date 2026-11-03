import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 生活画布 2.0（docs/模块/生活画布2.0.md 第 4 节）：回答「我今天过得怎么样」。画布由内容决定——
/// 固定的只有顶部、一周条、输入框；今天的样子、推进的目标、一天的带子、卡片，当天有才出现。左右滑换日子
struct CanvasView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var picking = false
    /// 一周条展开着（默认收起：设计评审 2026-10-23，日期不长期占着首页；点顶上的日子展开）
    @State private var weekOpen = false
    /// 刚才看的是哪天：换一天时新的一天从哪边进来（往后的日子从右边，往前的从左边）
    @State private var lastDay = ""

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if weekOpen {
                        VStack(alignment: .trailing, spacing: 0) {
                            CanvasWeek()
                            // 跳到更早的哪一天（3.0 的日历页第 10 步做；这里先用系统的月历选）
                            // 能点的范围撑在按钮里面（外面加的尺寸不算，2026-10-31 审计查出来的）
                            ThemeTextButton("跳到某一天") { picking = true }
                                .accessibilityIdentifier("today.pickDay")
                        }
                        .padding(.bottom, Theme.Space.small)
                        .themeTransition(.move(edge: .top).combined(with: .opacity))
                    }
                    CanvasDayHints()
                    SetupCard()
                    // 换一天：新的一天从那一边推进来，刚才那天原地淡出（淡出的不再占位置，两天叠在一起换）。
                    // 不包 ZStack：包了以后审计说卡片里的字「字号大了可能被截」（对照实验，2026-10-21）
                    CanvasBody { target in
                        withAnimation(Theme.Motion.pick(Theme.Motion.standard, reduceMotion: reduceMotion)) {
                            reader.scrollTo(target, anchor: .top)
                        }
                    }
                    .padding(.top, Theme.Space.medium)
                    .id(model.shownDay)
                    .themeTransition(
                        .asymmetric(
                            insertion: .move(edge: model.shownDay > lastDay ? .trailing : .leading)
                                .combined(with: .opacity),
                            removal: .opacity.animation(Theme.Motion.quick))
                    )
                    .onChange(of: model.shownDay, initial: true) { _, day in lastDay = day }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Space.screen)
                .padding(.bottom, Theme.Space.section)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
            .sayBarFollowsScroll()
            .refreshable { await model.refreshAll() }
            // 日历的日程只在手机上（R6）：换一天、回到前台时读一次
            .task(id: model.shownDay) { model.loadCalendar() }
            .onChange(of: scenePhase) { _, phase in if phase == .active { model.loadCalendar() } }
            // 往下翻看内容时一周条自动收起（只收不展，免得来回闪）
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top > Theme.Size.touch + Theme.Space.regular
            } action: { _, scrolled in
                guard scrolled, weekOpen else { return }
                withAnimation(Theme.Motion.pick(Theme.Motion.standard, reduceMotion: reduceMotion)) { weekOpen = false }
            }
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        // 左右滑动切换日期（横着滑 60 点以上、比竖着多一倍才算）
        .simultaneousGesture(
            DragGesture(minimumDistance: Theme.Space.xLarge).onEnded { drag in
                let across = drag.translation.width
                guard abs(across) > Theme.Size.touch + Theme.Space.regular,
                    abs(across) > abs(drag.translation.height) * 2
                else { return }
                withAnimation(Theme.Motion.pick(Theme.Motion.standard, reduceMotion: reduceMotion)) {
                    model.show(PourDate.addDays(model.shownDay, across > 0 ? -1 : 1))
                }
            }
        )
        .sheet(isPresented: $picking) { DayPicker() }
        .onChange(of: model.dayPickerRequest) { picking = true }
        // 顶上那一行（「我」、日子、搜索）在系统的导航栏里；推进来的页返回按钮写「今天」（看别的日子时写那天）
        .toolbar {
            CanvasTopBar(
                weekOpen: $weekOpen, title: CanvasTopBar.short(model.shownDay, today: model.today),
                reduceMotion: reduceMotion, openMe: { model.open("/me") }, search: { model.search = "" })
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(model.shownDay == model.today ? "今天" : Show.monthDay(model.shownDay))
    }
}

/// 一天的内容，从上到下：几行安静的字（空的一天、还在整理、要你确认）、待办和提醒（永远最前）、推进的目标、
/// 一天的时间、别的卡片；连不上时说原因、能重试；还没拿到时是骨架
private struct CanvasBody: View {
    @Environment(AppModel.self) private var model
    let scrollTo: (String) -> Void

    var body: some View {
        if let day = model.day {
            let rows = CanvasPlan.rows(
                day.entries, model.categories, steps: day.health?.steps, agenda: !model.shownEvents.isEmpty)
            let todos = rows.first.flatMap { row -> CanvasPlan.Row? in
                if case .full(let card) = row, card.template == .todo { row } else { nil }
            }
            VStack(alignment: .leading, spacing: Theme.Space.xLarge) {
                CanvasNotes(day: day, scrollTo: scrollTo)
                if let todos { CanvasCards(day: day, rows: [todos]) }
                let goals = day.goals.filter { $0.delta != nil }
                if !goals.isEmpty { GoalRings(goals: goals) }
                // 我的卡片：说一句建的（docs/模块/产品优化.md R3），在推进的目标后面
                if let cards = day.cards, !cards.isEmpty { MyCards(day: day.day, cards: cards) }
                DayRibbon(day: day.day, entries: day.entries)
                let rest = todos == nil ? rows : Array(rows.dropFirst())
                if !rest.isEmpty { CanvasCards(day: day, rows: rest) }
                // 接上健康、日历的安静的小卡（docs/模块/产品优化.md R5、R6）：只在今天、还没接、没点掉时
                HealthHint()
                CalendarHint()
            }
        } else if let offline = model.offline {
            VStack(alignment: .leading, spacing: Theme.Space.small) {
                Text(Show.spaced(offline)).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.secondaryLabel)
                ThemeTextButton("重试", font: Theme.Typeface.bodySemibold) { Task { await model.refreshAll() } }
            }
            .themeCard()
        } else {
            VStack(spacing: Theme.Space.cardGap) {
                SkeletonBlock(height: Theme.Size.goalCard * 0.7)
                SkeletonBlock(height: Theme.Size.goalCard)
            }
        }
    }
}

/// 点日历：选一天看（不能选还没到的日子）
private struct DayPicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            DatePicker("哪一天", selection: $date, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .padding(.horizontal, Theme.Space.regular)
                .navigationTitle("跳到某一天")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("好") {
                            model.show(PourDate.logicalDay(date, in: .current))
                            dismiss()
                        }
                    }
                }
        }
        .presentationDetents([.medium])
        .tint(Theme.Palette.accent)
    }
}
