import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 说一句的结果卡片里的一件待办（待办 2.0 第 10 步，docs/todo-2.0 design/after-07-voice）：名字下面三个小标签——
/// 哪一格（AI 猜的虚线边、写「· 猜的」）· 哪天 · 几点，点哪个改哪个（菜单）；钟点撞上今天的日程写一行
/// 「和 15:00 的面试撞了 · 看时间线」。改了以后标签跟着变（待办页的单子在手上就看它，不在就记在这张卡里）
struct TodoReceiptTags: View {
    @Environment(AppModel.self) private var model
    let entryId: Int
    let snapshot: API.ReceiptTodo

    /// 现在的样子：单子上的、这次改过的，都没有就是收据上的
    private var todo: API.ReceiptTodo {
        (model.todoPage?.row(entryId) ?? model.todoLatest[entryId]).map(Self.receipt) ?? snapshot
    }

    var body: some View {
        let todo = self.todo
        VStack(alignment: .leading, spacing: 0) {
            // 三个标签放不下一行就换行（标签自己不折）
            PourFlowLayout(spacing: Theme.Space.small - Theme.Space.hairline, lineSpacing: 0) {
                quadrantMenu(todo)
                dayMenu(todo)
                timeMenu(todo)
            }
            if let clash = Self.clash(todo, events: model.calendar.items[todo.day ?? ""] ?? []) {
                HStack(spacing: Theme.Space.tight) {
                    Label(clash, systemImage: "exclamationmark.triangle").font(Theme.Typeface.footnote)
                        .foregroundStyle(Theme.Palette.warnInk)
                    ThemeTextButton("看时间线", font: Theme.Typeface.footnoteSemibold) {
                        model.todoOpenMode = .timeline
                        model.chatOpen = false
                        model.openLink("/todos")
                    }
                }
                .accessibilityElement(children: .contain)
            }
        }
    }

    // MARK: - 三个标签

    private func quadrantMenu(_ todo: API.ReceiptTodo) -> some View {
        Menu {
            ForEach(TodoQuadrant.sorted, id: \.self) { lane in
                Button("放进\(lane.title)", systemImage: lane.symbol ?? "circle") { edit(todo, quadrant: lane) }
            }
        } label: {
            ReceiptTag(
                todo.lane.title, symbol: todo.lane.symbol ?? "circle.dashed",
                kind: .quadrant(todo.quadrant, guessed: todo.guessed))
        }
        .accessibilityLabel(Text("哪一格：\(todo.lane.title)\(todo.guessed ? "，猜的" : "")"))
        .accessibilityIdentifier("receipt.quadrant")
    }

    private func dayMenu(_ todo: API.ReceiptTodo) -> some View {
        let today = model.today
        return Menu {
            ForEach(TodoEditCards.dayChoices(today: today), id: \.day) { choice in
                Button(choice.title) { edit(todo, day: choice.day) }
            }
            Button("以后再说", systemImage: "tray") { edit(todo, someday: true) }
        } label: {
            ReceiptTag(todo.day.map { TodoBoard.when(day: $0, time: nil, today: today) } ?? "以后再说")
        }
        .accessibilityLabel(Text("哪天：\(todo.day.map { TodoBoard.when(day: $0, time: nil, today: today) } ?? "以后再说")"))
        .accessibilityIdentifier("receipt.day")
    }

    private func timeMenu(_ todo: API.ReceiptTodo) -> some View {
        Menu {
            Button("不定时") { edit(todo, time: .some(nil), window: .some(nil)) }
            ForEach(TimeWindow.allCases, id: \.self) { window in
                Button(window.title) { edit(todo, time: .some(nil), window: .some(window)) }
            }
            Button("几点…", systemImage: "bell") { model.todoSheet = .detail(Self.row(entryId, todo)) }
            // 定了钟点：到点像闹钟一样响，还是一条通知（「7点叫我起床」程序认成响铃，认错了在这改）
            if todo.time != nil {
                Toggle("响铃", systemImage: "alarm", isOn: Binding(get: { todo.rings }, set: { edit(todo, alarm: $0) }))
            }
        } label: {
            if let time = todo.time {
                // 响铃的写出来（只换个图标太不显眼：说完要一眼看到「明早会像闹钟一样叫我」）
                ReceiptTag(todo.rings ? "\(time) · 响铃" : time, symbol: todo.rings ? "alarm" : "bell")
            } else {
                ReceiptTag(todo.timeWindow?.title ?? "不定时")
            }
        }
        .accessibilityLabel(Text("几点：\(todo.time ?? todo.timeWindow?.title ?? "不定时")\(todo.rings ? "，响铃" : "")"))
        .accessibilityIdentifier("receipt.time")
    }

    // MARK: - 改

    private func edit(
        _ todo: API.ReceiptTodo, quadrant: TodoQuadrant? = nil, day: String? = nil, time: String?? = nil,
        window: TimeWindow?? = nil, someday: Bool? = nil, alarm: Bool? = nil
    ) {
        model.editTodo(
            entryId, day: day, time: time, quadrant: quadrant, window: window, someday: someday, alarm: alarm,
            base: Self.row(entryId, todo))
    }

    /// 收据 → 待办页的一行（编辑弹框、改的时候用）
    static func row(_ id: Int, _ todo: API.ReceiptTodo) -> API.TodoRow {
        API.TodoRow(
            id: id, content: todo.content, day: todo.day ?? "", remindAt: todo.time, quadrant: todo.lane,
            guessed: todo.guessed, window: todo.timeWindow, someday: todo.day == nil, alarm: todo.alarm == true)
    }

    /// 待办页的一行 → 收据的样子
    static func receipt(_ row: API.TodoRow) -> API.ReceiptTodo {
        API.ReceiptTodo(
            content: row.content, day: row.isSomeday ? nil : row.day, time: row.remindAt, window: row.window,
            quadrant: row.lane.rawValue, guessed: row.guessed, alarm: row.alarm == true)
    }

    /// 钟点落在那天的哪个日程里：「和 15:00 的面试撞了」（日程的简称取不到写「和 15:00 的日程撞了」）
    static func clash(_ todo: API.ReceiptTodo, events: [CalendarItem]) -> String? {
        guard let time = todo.time, let day = todo.day, let minute = TodoTimelinePlan.minute(time) else { return nil }
        let hit = TodoTimelinePlan.columns(events.filter { !$0.allDay }, day: day).events.first {
            minute >= $0.start && minute < $0.end
        }
        guard let hit else { return nil }
        let short = TodoTimelinePlan.shortName(hit.item.title)
        return "和 \(TodoTimelinePlan.Gap.clock(hit.start)) 的\(short.isEmpty ? "日程" : short)撞了"
    }
}

/// 只说了上午、下午、晚上：在这段话的结果下面问一句几点（对话里最新的那段才问，答过就不再问）
struct TodoWindowAsk: View {
    @Environment(AppModel.self) private var model
    let entryId: Int
    let todo: API.ReceiptTodo

    var body: some View {
        if let window = todo.timeWindow, todo.time == nil, !model.todoAsked.contains(entryId) {
            WindowAsk("\(window.title)几点提醒你？", choices: Self.choices(window), keep: "\(window.title)就行") { clock in
                model.todoAsked.insert(entryId)
                guard let clock else { return }
                let now = (model.todoPage?.row(entryId) ?? model.todoLatest[entryId]).map(TodoReceiptTags.receipt)
                model.editTodo(
                    entryId, time: .some(clock), window: .some(nil), base: TodoReceiptTags.row(entryId, now ?? todo))
                model.toast("「\(todo.content)」\(clock) 提醒你")
            }
            .pourBubble(trailing: Theme.Space.section)
            .accessibilityIdentifier("receipt.ask")
        }
    }

    /// 每个时段给三个常用的钟点
    static func choices(_ window: TimeWindow) -> [String] {
        switch window {
        case .morning: ["09:00", "10:00", "11:00"]
        case .afternoon: ["13:00", "15:00", "16:00"]
        case .evening: ["19:00", "20:00", "21:00"]
        }
    }
}

extension EnvironmentValues {
    /// 对话里最新的那段话（只在它的结果下面问「下午几点提醒你？」）
    @Entry var latestNote: Int?
}
