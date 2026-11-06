import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 待办页（待办 2.0，docs/todo-2.0 第 4 步）：大标题「待办」，下面一行「今天还有 5 件 · 完成 1 件 · 🔔 3 个提醒已排好」，
/// 清单 | 四象限 | 时间线。清单：过点了（沙色；行下面「挪到下午 · 明天再说 · 不做了」，多于 3 件改成标题旁「全部挪到…」）、
/// 今天（全天的日程最前、不定时的在上、别的按时间、日程穿插；放一放折成一行放最后）、明天、这周、以后；已完成收起。
/// 右滑完成、左滑推迟或删除、按住出菜单（TodoPressMenu）；勾掉的划线留在原地，离开再回来才收进「已完成」
struct TodosPage: View {
    @Environment(AppModel.self) var model
    @State private var mode = Mode.list
    @State var showDone = false
    @State private var showLater = false
    @State var byPerson = false
    /// 现在几点（到分钟）
    @State var now = TodosPage.clock()
    /// 四象限里点开的那一格（看这一格的全部）
    @State var focus: TodoQuadrant?
    /// 一次性引导看过了（存在这台手机上）
    @AppStorage("todos.guideSeen") private var guideSeen = false

    enum Mode: Hashable {
        case list, matrix, timeline
    }

    var body: some View {
        Group {
            if mode != .list, focus == nil, let page = model.todoPage {
                // 四象限、时间线不放在 List 里：List 自己接拖放，格子、时间线收不到放下来的卡片（2026-11-05 测出来的）
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: Theme.Space.medium) {
                            heading(now: now)
                            if mode == .matrix {
                                TodoMatrixSection(page: page, now: now, mode: $mode, focus: $focus)
                            } else {
                                TodoTimelineView(page: page, events: events(page.today), now: now).id("timeline")
                            }
                        }
                        .padding(.horizontal, Theme.Space.regular)
                        .padding(.bottom, Theme.Space.large)
                    }
                    .refreshable { await model.loadTodos() }
                    // 四象限「排进空档 ›」过来：滚到时间线（空档在上面标出来了）
                    .task(id: mode) {
                        guard mode == .timeline, model.todoGaps else { return }
                        try? await Task.sleep(for: .milliseconds(300))
                        withAnimation(Theme.Motion.standard) { proxy.scrollTo("timeline", anchor: .top) }
                    }
                }
            } else {
                list
            }
        }
        .toolbar { toolbar }
        .task(id: model.dataVersion) { await model.loadTodos() }
        .task { model.loadTodayEvents() }
        .task(id: model.todoFlash) {
            // 新加的、刚挪过来的那一行亮一下（1.5 秒）再变回去
            guard model.todoFlash != nil else { return }
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(Theme.Motion.standard) { model.todoFlash = nil }
        }
        .onDisappear { model.settleTodos() }
        .onChange(of: mode) { focus = nil }
        .onAppear {
            // 结果卡片上点了「看时间线」：打开就是时间线
            if let open = model.todoOpenMode {
                mode = open
                model.todoOpenMode = nil
            }
        }
        .task {
            // 跟着钟走（过点了、快到了）：每到整分钟换一次。不用 TimelineView 包整个列表：和大标题的导航栏
            // 互相触发布局，一直转（2026-11-05 界面测试里 CPU 跑满）
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60 - Calendar.current.component(.second, from: Date())))
                now = Self.clock()
            }
        }
    }

    static func clock() -> String { PourDate.localDateTime(Date(), in: .current) }

    private var list: some View {
        List {
            top(now: now)
            if let page = model.todoPage {
                switch mode {
                case .list: listSections(page, now: now)
                case .matrix: if let focus { focusSections(page, focus) }
                case .timeline: EmptyView()
                }
            } else if let problem = model.todoProblem {
                ErrorState(problem.contains("连不上") || problem.contains("没连上") ? .serverOff : .other) {
                    Task { await model.loadTodos() }
                }
                .listRowBackground(Color.clear)
            } else {
                ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(Theme.Space.medium)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, Theme.Size.touch)
        .refreshable { await model.loadTodos() }
    }

    // MARK: - 顶上：一句话、清单 | 四象限 | 时间线

    private func top(now: String) -> some View {
        Section {
            heading(now: now)
                .listRowBackground(Color.clear)
                .listRowInsets(
                    EdgeInsets(top: 0, leading: Theme.Space.regular, bottom: 0, trailing: Theme.Space.regular))
        }
    }

    private func heading(now: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            if let page = model.todoPage { summary(page, now: now) }
            PillSegments(selection: $mode, items: [(.list, "清单"), (.matrix, "四象限"), (.timeline, "时间线")])
                .accessibilityIdentifier("todos.mode")
            if !guideSeen { guide }
        }
    }

    // MARK: - 清单

    @ViewBuilder
    private func listSections(_ page: API.TodoPage, now: String) -> some View {
        let sections = TodoBoard.sections(page, held: model.todoHeld)
        if byPerson {
            personSections(sections)
        } else {
            let plan = TodoListPlan.make(page: page, held: model.todoHeld, events: events(page.today), now: now)
            if !plan.late.isEmpty { lateSection(plan.late, now: now, today: page.today) }
            todaySection(plan, page: page)
            ForEach(plan.ahead) { group in
                Section {
                    ForEach(group.rows) { todoRow($0, group: group.key, today: page.today) }
                } header: {
                    header(group.title, count: group.rows.filter { !$0.done }.count)
                }
            }
        }
        if let done = sections.first(where: { $0.key == "done" }) { doneSection(done) }
        // 底下不再常驻说明和「手机上排好了 N 个提醒」（提醒数在标题下面；说明是第一次来的一次性引导）
        if model.reminderState?.permission == .denied {
            Section {
                Label("通知关着：定了时间的待办到点不会响。在 iPhone 的「设置 → 通知 → Pour」里打开", systemImage: "bell.slash")
                    .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.warn)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("todos.reminders")
            }
        }
    }

    /// 过点了（沙色，不用红）：每件下面三个小按钮「挪到下午 · 明天再说 · 不做了」；多于 3 件改成标题旁一个「全部挪到…」
    private func lateSection(_ rows: [API.TodoRow], now: String, today: String) -> some View {
        let open = rows.filter { !$0.done }
        let move = TodoListPlan.laterToday(now: now)
        let many = open.count > 3
        return Section {
            ForEach(rows) { row in
                todoRow(row, group: "late", today: today, chips: !many && !row.done, move: move)
            }
        } header: {
            HStack(alignment: .firstTextBaseline) {
                Text("过点了 · \(open.count) 件").font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.warn)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if many {
                    Menu {
                        if let move { Button(move.title) { model.move(open, to: move) } }
                        Button(TodoMove.tomorrow.title) { model.move(open, to: .tomorrow) }
                    } label: {
                        // 点的地方 44 高（组标题那一行字小，按钮跟着字高只有 18，2026-11-06 审计）
                        Text("全部挪到…").font(Theme.Typeface.subheadline.weight(.semibold))
                            .frame(minHeight: Theme.Size.touch).contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("todos.moveAll")
                }
            }
            .textCase(nil)
            .padding(.horizontal, -Theme.Space.tight)
        }
    }

    /// 今天：全天的日程最前、不定时的在上、别的按时间（日程穿插）；放一放折成一行「放一放 · 3 件 ›」放最后
    private func todaySection(_ plan: TodoListPlan, page: API.TodoPage) -> some View {
        // 全天的事（节气、生日）写在标题后面，不占一行：「今天 · 11月6日 周五 · 立冬」
        let title = CanvasTopBar.withAllDay(
            page.groups.first { $0.key == "today" }?.title ?? "今天", events: events(page.today))
        let open = plan.today.filter(\.isOpenTodo).count + plan.later.filter { !$0.done }.count
        return Section {
            if plan.today.isEmpty && plan.later.isEmpty { emptyToday }
            ForEach(plan.today) { item in
                switch item {
                case .todo(let row): todoRow(row, group: "today", today: page.today)
                case .event(let event): CalendarLine(event: event).listRowInsets(EdgeInsets())
                }
            }
            if !plan.later.isEmpty {
                laterRow(plan.later.filter { !$0.done }.count)
                if showLater {
                    ForEach(plan.later) { todoRow($0, group: "today", today: page.today) }
                }
            }
        } header: {
            header(title, count: open)
        }
    }

    /// 「放一放 · 3 件 ›」：点了展开、再点收起
    private func laterRow(_ count: Int) -> some View {
        Button {
            withAnimation(Theme.Motion.standard) { showLater.toggle() }
        } label: {
            TodoLine(showLater ? "收起放一放的" : "放一放 · \(count) 件", done: false, dim: true) {
                QuadrantBadge(quadrant: TodoQuadrant.later.rawValue)
                    .frame(width: Theme.Size.touch, height: Theme.Size.touch)
            } trailing: {
                Image(systemName: "chevron.right").font(Theme.Typeface.footnoteSemibold)
                    .foregroundStyle(Theme.Palette.tertiaryLabel)
                    .rotationEffect(.degrees(showLater ? 90 : 0))
            }
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets())
        .accessibilityIdentifier("todos.later")
    }

    /// 一行（加上列表的边、左右滑、按住的菜单）；chips：过点了的那一行下面带小按钮（move 是今天往后挪到哪，
    /// 没有就只给「明天再说 · 不做了」）
    func todoRow(
        _ row: API.TodoRow, group: String, today: String, chips: Bool = false, move: TodoMove? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            TodoRowView(row: row, today: today, now: now).todoPress(row)
            if chips {
                HStack(spacing: Theme.Space.small) {
                    if let move { MiniChip(move.title) { model.move([row], to: move) } }
                    MiniChip(TodoMove.tomorrow.title) { model.move([row], to: .tomorrow) }
                    MiniChip("不做了") { model.deleteTodo(row) }
                }
                .padding(.leading, Theme.Space.regular + Theme.Size.check + Theme.Space.medium + Theme.Space.hairline)
                .padding(.top, -Theme.Space.medium).padding(.bottom, Theme.Space.tight)
            }
        }
        // 待办 2.0：一行自己留边（圈看得见的左边距 16、行高 52），列表不再多留
        .listRowInsets(EdgeInsets())
        .listRowBackground(model.todoFlash == row.id ? Theme.Palette.bubble : Theme.Palette.card)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if !row.done {
                Button {
                    model.setDone(row.id, true)
                } label: {
                    Label("完成", systemImage: Theme.Symbol.done)
                }
                .tint(Theme.Palette.good)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                model.deleteTodo(row)
            } label: {
                Label("删除", systemImage: Theme.Symbol.delete)
            }
            // 删除是红的：不写的话跟着整页的强调色变蓝（2026-11-05 走一遍时看到的）
            .tint(Theme.Palette.bad)
            if !row.done {
                Button {
                    model.todoSheet = .snooze(row)
                } label: {
                    Label("推迟", systemImage: Theme.Symbol.snooze)
                }
                .tint(Theme.Palette.warn)
            }
        }
        .sensoryFeedback(Theme.Haptics.swipe, trigger: model.todoFlash == row.id) { _, now in now }
    }

    private func events(_ today: String) -> [CalendarItem] { model.calendar.items[today] ?? [] }
}

extension TodosPage {
    /// 「今天还有 5 件 · 完成 1 件 · 🔔 3 个提醒已排好」（铃铛是图标）
    private func summary(_ page: API.TodoPage, now: String) -> some View {
        let plan = TodoListPlan.make(page: page, held: model.todoHeld, events: events(page.today), now: now)
        let counts = plan.counts(page: page)
        let head =
            counts.left == 0 ? "今天的都做完了 · 完成 \(counts.done) 件" : "今天还有 \(counts.left) 件 · 完成 \(counts.done) 件"
        // 排好了几个提醒：这台手机上真排上的系统通知（断网也准）；演示数据不排通知，数还没到的
        let reminders = model.demo ? TodoListPlan.reminders(page, now: now) : model.reminderState?.scheduled ?? 0
        return Group {
            if reminders > 0 {
                Text("\(head) · \(Image(systemName: "bell")) \(reminders) 个提醒已排好")
            } else {
                Text(head)
            }
        }
        .font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel).monospacedDigit()
        .contentTransition(.numericText())
        .animation(Theme.Motion.standard, value: "\(head)\(reminders)")
        .accessibilityIdentifier("todos.summary")
    }

    /// 第一次来时的一次性引导（以前常驻在最下面）：看过点「知道了」就不再出
    private var guide: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.small) {
            Image(systemName: "hand.draw").foregroundStyle(Theme.Palette.accent).accessibilityHidden(true)
            Text("右滑完成 · 左滑推迟或删除 · 按住更多。勾掉的留在原地，下次打开才收进「已完成」")
                .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.label)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            ThemeTextButton("知道了") { withAnimation(Theme.Motion.standard) { guideSeen = true } }
                .accessibilityIdentifier("todos.guide.ok")
        }
        .padding(.leading, Theme.Space.medium).padding(.trailing, Theme.Space.tight)
        .padding(.vertical, Theme.Space.tight)
        .background(Theme.Palette.remindFill, in: Theme.rounded(Theme.Corner.stat))
        .accessibilityElement(children: .contain)
    }

    /// 今天没有待办：说一句就能加
    private var emptyToday: some View {
        Button {
            model.startSaying("")
        } label: {
            HStack(spacing: Theme.Space.medium) {
                Image(systemName: Theme.Symbol.mic).font(Theme.Typeface.bodySemibold).foregroundStyle(
                    Theme.Palette.accent
                )
                .frame(width: Theme.Size.micButton, height: Theme.Size.micButton)
                .background(Theme.Palette.bubble, in: Circle())
                VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                    Text("今天没有待办").font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                    Text("说一句就能加，比如「明天三点取快递」").font(Theme.Typeface.footnote)
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, Theme.Space.small)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("todos.empty")
    }

    /// 组的标题：名字、右边还有几件
    private func header(_ title: String, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if count > 0 {
                Text("\(count) 件").font(Theme.Typeface.footnote).monospacedDigit()
                    .foregroundStyle(Theme.Palette.secondaryLabel)
            }
        }
        .textCase(nil)
        .padding(.horizontal, -Theme.Space.tight)
    }
}
