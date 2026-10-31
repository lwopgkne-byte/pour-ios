import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 待办页（docs/3.0/01-需求文档.md 4.2、06 交互细节第 2 节）：以前没做完的（全部带到今天）、今天（日历的日程穿插在里面）、
/// 明天、这周、以后；已完成收起。右滑完成、左滑推迟或删除、按住更多；勾掉的划线留在原地，离开再回来才收进「已完成」
struct TodosPage: View {
    @Environment(AppModel.self) private var model
    @State private var mode = Mode.list
    @State private var showDone = false
    @State private var byPerson = false

    enum Mode: String, CaseIterable, Identifiable {
        case list = "清单"
        case timeline = "今天的时间线"

        var id: String { rawValue }
    }

    var body: some View {
        List {
            top
            if let page = model.todoPage {
                switch mode {
                case .list: listSections(page)
                case .timeline: TodoTimelineSection(page: page, events: events(page.today))
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
    }

    // MARK: - 顶上：一句话、清单 | 今天的时间线

    @ViewBuilder private var top: some View {
        Section {
            VStack(alignment: .leading, spacing: Theme.Space.medium) {
                if let page = model.todoPage {
                    Text(summary(page)).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.secondaryLabel)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(Theme.Motion.standard, value: summary(page))
                }
                Picker("看哪样", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("todos.mode")
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: Theme.Space.regular, bottom: 0, trailing: Theme.Space.regular))
        }
    }

    /// 「今天还有 3 件 · 已完成 2 件」
    private func summary(_ page: API.TodoPage) -> String {
        let rows = page.groups.flatMap(\.rows)
        let left = page.groups.first { $0.key == "today" }?.rows.filter { !$0.done }.count ?? 0
        let finished = rows.filter(\.done).count
        return left == 0 ? "今天的都做完了 · 已完成 \(finished) 件" : "今天还有 \(left) 件 · 已完成 \(finished) 件"
    }

    // MARK: - 清单

    @ViewBuilder
    private func listSections(_ page: API.TodoPage) -> some View {
        let sections = TodoBoard.sections(page, held: model.todoHeld)
        if byPerson {
            personSections(sections)
        } else {
            ForEach(sections.filter { $0.key != "done" }) { group in
                Section {
                    groupRows(group, page: page)
                } header: {
                    header(group)
                }
            }
        }
        if let done = sections.first(where: { $0.key == "done" }) { doneSection(done) }
        Section {
            if let text = model.reminderState?.text {
                Label(
                    text, systemImage: model.reminderState?.permission == .denied ? "bell.slash" : Theme.Symbol.remind
                )
                .font(Theme.Typeface.footnote)
                .foregroundStyle(
                    model.reminderState?.permission == .denied ? Theme.Palette.warn : Theme.Palette.secondaryLabel
                )
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("todos.reminders")
            }
            Text("右滑完成 · 左滑推迟或删除 · 按住更多 · 勾掉的留在原地，下次打开才收进「已完成」")
                .font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private func groupRows(_ group: API.TodoGroup, page: API.TodoPage) -> some View {
        if group.key == "today" {
            let items = TodayItem.merge(group.rows, events: events(page.today))
            if items.isEmpty {
                EmptyState("今天没有要做的", example: "加一件") { model.todoSheet = .add("") }
            }
            ForEach(items) { item in
                switch item {
                case .todo(let row): todoRow(row, group: group.key, today: page.today)
                case .event(let event): CalendarLine(event.title, time: TodayItem.time(event))
                }
            }
        } else {
            ForEach(group.rows) { todoRow($0, group: group.key, today: page.today) }
        }
    }

    private func todoRow(_ row: API.TodoRow, group: String, today: String) -> some View {
        TodoRowView(row: row, today: today)
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
                if !row.done {
                    if group == "overdue" {
                        Button {
                            model.carryToToday([row])
                        } label: {
                            Label("今天", systemImage: "arrow.down.to.line")
                        }
                        .tint(Theme.Palette.accentFill)
                    } else {
                        Button {
                            model.todoSheet = .snooze(row)
                        } label: {
                            Label("推迟", systemImage: Theme.Symbol.snooze)
                        }
                        .tint(Theme.Palette.warn)
                    }
                }
            }
            .contextMenu { TodoMenu(row: row) }
            .sensoryFeedback(Theme.Haptics.swipe, trigger: model.todoFlash == row.id) { _, now in now }
    }

    /// 组的标题：以前没做完的用留意色、右边「全部带到今天」；别的右边写几件
    private func header(_ group: API.TodoGroup) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(group.title).font(Theme.Typeface.bodySemibold)
                .foregroundStyle(group.key == "overdue" ? Theme.Palette.warn : Theme.Palette.label)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if group.key == "overdue" {
                ThemeTextButton("全部带到今天") { model.carryToToday(group.rows.filter { !$0.done }) }
                    .accessibilityIdentifier("todos.carryAll")
            } else {
                let left = group.rows.filter { !$0.done }.count
                if left > 0 {
                    Text("\(left) 件").font(Theme.Typeface.footnote).monospacedDigit()
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                }
            }
        }
        .textCase(nil)
        .padding(.horizontal, -Theme.Space.tight)
    }

    /// 已完成：默认收起，一行「已完成 5 件 ›」，点了展开
    private func doneSection(_ group: API.TodoGroup) -> some View {
        Section {
            Button {
                withAnimation(Theme.Motion.standard) { showDone.toggle() }
            } label: {
                HStack {
                    Text(showDone ? "收起已完成" : "已完成 \(group.rows.count) 件")
                        .font(Theme.Typeface.bodyMedium).foregroundStyle(Theme.Palette.accent)
                    Spacer()
                    Image(systemName: "chevron.right").font(Theme.Typeface.glyph)
                        .foregroundStyle(Theme.Palette.tertiaryLabel)
                        .rotationEffect(.degrees(showDone ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("todos.done")
            if showDone {
                ForEach(group.rows) { todoRow($0, group: "done", today: model.todoPage?.today ?? model.today) }
            }
        }
    }

    // MARK: - 按人（「···」里换）：没做完的按和谁分，没写和谁的放最后

    @ViewBuilder
    private func personSections(_ sections: [API.TodoGroup]) -> some View {
        let open = sections.filter { $0.key != "done" }.flatMap(\.rows)
        let names = Array(Set(open.flatMap(\.people))).sorted()
        let today = model.todoPage?.today ?? model.today
        ForEach(names, id: \.self) { name in
            Section {
                ForEach(open.filter { $0.people.contains(name) }) { todoRow($0, group: "person", today: today) }
            } header: {
                Text(name).font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label).textCase(nil)
            }
        }
        let alone = open.filter(\.people.isEmpty)
        if !alone.isEmpty {
            Section {
                ForEach(alone) { todoRow($0, group: "person", today: today) }
            } header: {
                Text("没写和谁").font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label).textCase(nil)
            }
        }
    }

    // MARK: - 右上角：加待办、更多

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Toggle("显示已完成", isOn: $showDone)
                Picker("怎么排", selection: $byPerson) {
                    Text("按时间").tag(false)
                    Text("按人").tag(true)
                }
            } label: {
                Image(systemName: "ellipsis").font(Theme.Typeface.toolbarIcon)
            }
            .accessibilityLabel(Text("更多"))
            .accessibilityIdentifier("todos.more")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                model.todoSheet = .add("")
            } label: {
                Image(systemName: Theme.Symbol.add).font(Theme.Typeface.toolbarIcon)
            }
            .accessibilityLabel(Text("加待办"))
            .accessibilityIdentifier("todos.add")
        }
    }

    private func events(_ today: String) -> [CalendarItem] { model.calendar.items[today] ?? [] }
}

/// 今天这一组里的一样：待办，或者日历里的日程（只读）
enum TodayItem: Identifiable {
    case todo(API.TodoRow)
    case event(CalendarItem)

    var id: String {
        switch self {
        case .todo(let row): "todo.\(row.id)"
        case .event(let event): "event.\(event.id)"
        }
    }

    /// 按时间排：有钟点的在前（待办按提醒、日程按开始），全天的日程最前，没时间的待办在后面（服务器给的先后不变）；
    /// 日程和你说的待办是同一件的只显示待办（和画布的待办卡一样，AgendaPlan.same）
    static func merge(_ rows: [API.TodoRow], events: [CalendarItem]) -> [TodayItem] {
        let timed = events.filter { event in
            !event.allDay
                && !rows.contains { row in
                    AgendaPlan.same(event, title: row.content, remindAt: row.remindAt.map { "\(row.day)T\($0)" })
                }
        }
        let allDay = events.filter(\.allDay).map(TodayItem.event)
        let items = (rows.map(TodayItem.todo) + timed.map(TodayItem.event)).enumerated()
            .sorted { ($0.element.clock ?? "99", $0.offset) < ($1.element.clock ?? "99", $1.offset) }
            .map(\.element)
        return allDay + items
    }

    private var clock: String? {
        switch self {
        case .todo(let row): row.remindAt
        case .event(let event): String(event.start.suffix(5))
        }
    }

    /// 「14:00–15:30」「全天 · 日历」
    static func time(_ event: CalendarItem) -> String {
        event.allDay ? "全天 · 日历" : "\(event.start.suffix(5))–\(event.end.suffix(5))"
    }
}
