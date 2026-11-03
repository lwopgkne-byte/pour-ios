import Foundation
import PourAPI
import PourCore

/// 待办上的弹层（3.0 第 2 步）：加待办、一件待办的详情、推迟到哪。挂在外壳上，哪儿都能打开
/// （待办页、画布的待办卡、「我的」的快捷、按住图标的「加待办」、通知）
enum TodoSheet: Identifiable, Hashable {
    /// 加待办：输入框里先填好的（「明天下午三点取快递」）
    case add(String)
    case detail(API.TodoRow)
    case snooze(API.TodoRow)

    var id: String {
        switch self {
        case .add: "add"
        case .detail(let row): "detail.\(row.id)"
        case .snooze(let row): "snooze.\(row.id)"
        }
    }
}

// MARK: - 待办（docs/3.0/01-需求文档.md 第 4 章、06 交互细节第 2 节）：界面先变、再发；能撤销就不问

extension AppModel {
    /// 拿待办页的单子：先用存下的画出来（不转圈），再拿新的
    func loadTodos() async {
        if todoPage == nil, let saved: API.TodoPage = client.cached("/api/todos") { todoPage = saved }
        do throws(APIError) {
            todoPage = try await client.todos()
            todoProblem = nil
        } catch {
            if todoPage == nil { todoProblem = error.message }
        }
    }

    /// 离开待办页：这一次勾掉的收进「已完成」，下次打开就在那里
    func settleTodos() {
        todoHeld = [:]
        todoPage?.settle()
    }

    /// 勾、取消勾（待办页、画布、通知上的「完成」都走这里）：圆圈马上变、划线留在原地；
    /// 没网时排在手机上，连上了自动发；服务器不收就退回去。勾上了说一句、能撤销
    func setDone(_ id: Int, _ done: Bool) {
        let title = todoTitle(id)
        if let key = todoPage?.key(of: id), todoHeld[id] == nil { todoHeld[id] = key }
        let apply = { [weak self] (value: Bool) in
            guard let self else { return }
            patchEntry(id) { entry in
                if case .todo(var todo) = entry.data {
                    todo.done = value
                    entry.data = .todo(todo)
                }
            }
            todoPage?.setDone(id, value, at: ISO8601DateFormatter().string(from: Date()))
            // 详情开着：里面的圆圈也跟着变
            if case .detail(var row) = todoSheet, row.id == id {
                row.done = value
                todoSheet = .detail(row)
            }
        }
        apply(done)
        write("PATCH", "/api/entries/\(id)", json: .object(["done": .bool(done)])) { apply(!done) }
        refreshWidgets()
        guard done else { return }
        toast(title.map { "完成了：\($0)" } ?? "完成了", action: "撤销") { [weak self] in self?.setDone(id, false) }
    }

    /// 推迟（左滑「推迟」、按住的菜单、详情、通知上的按钮）：几个说好的选项，服务器算具体时刻；界面先挪过去
    func snooze(_ id: Int, to preset: SnoozePreset) {
        let target = preset.target(now: Date(), today: today)
        move(
            id, day: target.day, time: target.time, json: .object(["preset": .string(preset.rawValue)]),
            saying: "推迟到\(preset.title) \(target.time)")
    }

    /// 推迟到自己挑的那天那个钟点（「选别的时间」、通知上的「10 分钟后」）
    func snooze(_ id: Int, day: String, time: String?) {
        move(
            id, day: day, time: time,
            json: .object(["day": .string(day), "time": time.map(JSONValue.string) ?? .null]),
            saying: "推迟到\(TodoBoard.when(day: day, time: time, today: today))")
    }

    /// 以前没做完的带到今天（左滑「今天」、标题旁「全部带到今天」）：提醒的钟点照旧，挪到今天
    func carryToToday(_ rows: [API.TodoRow]) {
        guard !rows.isEmpty else { return }
        let before = rows.map { ($0.id, $0.day, $0.remindAt) }
        for row in rows { todoPage?.move(row.id, day: today, time: row.remindAt) }
        todoFlash = rows.first?.id
        let back: @MainActor @Sendable () -> Void = { [weak self] in
            for (id, day, time) in before { self?.todoPage?.move(id, day: day, time: time) }
        }
        write(
            "POST", "/api/todos/carry", json: .object(["ids": .array(rows.map { .number(Double($0.id)) })]),
            revert: back)
        toast(rows.count == 1 ? "带到今天了" : "\(rows.count) 件带到今天了", action: "撤销") { [weak self] in
            back()
            for (id, day, time) in before {
                self?.write("PATCH", "/api/todos/\(id)", json: Self.dayAndTime(day, time)) {}
            }
        }
    }

    /// 详情里改：事、哪天、几点提醒（.some(nil) 是不提醒）、重复（.some(nil) 是不重复）。改了马上生效，不用存
    func editTodo(
        _ id: Int, content: String? = nil, day: String? = nil, time: String?? = nil, repeat rule: API.Repeat?? = nil
    ) {
        guard let old = todoPage?.row(id) ?? detailRow(id) else { return }
        var row = old
        if let content { row.content = content }
        if let day { row.day = day }
        if let time { row.remindAt = time }
        if let rule {
            row.repeat = rule
            row.repeatText = rule?.text
        }
        row.overdue = !row.done && row.day < today
        todoPage?.put(row)
        if case .detail = todoSheet { todoSheet = .detail(row) }
        var body: [String: JSONValue] = [:]
        if let content { body["content"] = .string(content) }
        if let day { body["day"] = .string(day) }
        if let time { body["time"] = time.map(JSONValue.string) ?? .null }
        if let rule { body["repeat"] = rule?.json ?? .null }
        write("PATCH", "/api/todos/\(id)", json: .object(body)) { [weak self] in self?.todoPage?.put(old) }
    }

    /// 详情里改和谁、东西、地方（和原来的记录详情一样发 PATCH /api/entries 的 fields）：先改界面再发
    func editTodoRelated(_ id: Int, field: String, words: [String]) {
        guard let old = todoPage?.row(id) ?? detailRow(id) else { return }
        var row = old
        switch field {
        case "people": row.people = words
        case "things": row.things = words
        default: row.places = words
        }
        todoPage?.change(id) { $0 = row }
        if case .detail = todoSheet { todoSheet = .detail(row) }
        write(
            "PATCH", "/api/entries/\(id)",
            json: .object(["fields": .object([field: .array(words.map(JSONValue.string))])])
        ) { [weak self] in
            self?.todoPage?.change(id) { $0 = old }
            if case .detail = self?.todoSheet { self?.todoSheet = .detail(old) }
        }
    }

    /// 删一件（左滑「删除」、菜单、详情）。重复的先问「只删这一次 / 以后都不要了」（todoDeleting）
    func deleteTodo(_ row: API.TodoRow, onlyThisTime: Bool? = nil) {
        if row.repeat != nil, onlyThisTime == nil {
            todoDeleting = row
            return
        }
        todoSheet = nil
        todoPage?.take(row.id)
        removeEntry(row.id)
        if onlyThisTime == true {
            skipOnce(row)
            return
        }
        write("DELETE", "/api/entries/\(row.id)") { [weak self] in self?.todoPage?.put(row) }
        toast("删了：\(row.content)", action: "撤销") { [weak self] in
            self?.todoPage?.put(row)
            self?.write("POST", "/api/entries/\(row.id)/restore") {}
        }
    }

    /// 重复的「只删这一次」：这一次删掉、接着出现下一次（服务器回下一次是哪条，撤销时一起撤掉）
    private func skipOnce(_ row: API.TodoRow) {
        let client = self.client
        Task { [weak self] in
            guard let self else { return }
            do throws(APIError) {
                let next = try await client.skipTodo(row.id)
                if let next { todoPage?.put(next) }
                dataChanged()
                toast("删了这一次：\(row.content)", action: "撤销") { [weak self] in
                    self?.todoPage?.put(row)
                    if let next { self?.todoPage?.take(next.id) }
                    self?.write("POST", "/api/entries/\(row.id)/restore") {}
                    if let next { self?.write("DELETE", "/api/entries/\(next.id)") {} }
                }
            } catch {
                todoPage?.put(row)
                toast(error.message)
            }
        }
    }

    /// 加待办（快加）：程序认好时间马上建好，回认出的结果；新的一行放到对的组、亮一下；能撤销。
    /// 没网：排在手机上（带编号，连上了发不会建两条），说一句
    func addTodo(_ text: String) {
        let clientId = UUID().uuidString
        let client = self.client
        Task { [weak self] in
            guard let self else { return }
            do throws(APIError) {
                guard let row = try await client.addTodo(text, clientId: clientId) else { return }
                todoPage?.put(row)
                todoFlash = row.id
                dataChanged()
                let when = TodoBoard.when(day: row.day, time: row.remindAt, today: today)
                toast("加上了：\(when) \(row.content)", action: "撤销") { [weak self] in
                    self?.todoPage?.take(row.id)
                    self?.write("DELETE", "/api/entries/\(row.id)") {}
                }
            } catch .unreachable {
                write(
                    "POST", "/api/todos",
                    json: .object(["text": .string(text), "clientId": .string(clientId)])
                ) {}
            } catch {
                toast(error.message)
            }
        }
    }

    /// 通知上点了（App 开着、或者刚被叫醒）：完成、10 分钟后、1 小时后、明天早上；点了通知本身打开待办
    func perform(_ action: TodoAction, todo id: Int) {
        switch action {
        case .open: openLink("/todos")
        case .done: setDone(id, true)
        case .tenMinutes:
            let local = PourDate.localDateTime(Date().addingTimeInterval(600), in: .current)
            snooze(id, day: String(local.prefix(10)), time: String(local.suffix(5)))
        case .hour: snooze(id, to: .hour)
        case .tomorrow: snooze(id, to: .tomorrow)
        }
    }

    // MARK: - 帮手

    /// 推迟到那天那个钟点：界面先挪、亮一下；发出去；能撤销（挪回原来的日子和钟点）
    private func move(_ id: Int, day: String, time: String?, json: JSONValue, saying: String) {
        let old = todoPage?.row(id)
        todoPage?.move(id, day: day, time: time)
        todoFlash = id
        todoSheet = nil
        let back: @MainActor @Sendable () -> Void = { [weak self] in
            if let old { self?.todoPage?.put(old) }
        }
        write("POST", "/api/todos/\(id)/snooze", json: json, revert: back)
        guard let old else {
            toast(saying)
            return
        }
        toast(saying, action: "撤销") { [weak self] in
            back()
            self?.write("PATCH", "/api/todos/\(id)", json: Self.dayAndTime(old.day, old.remindAt)) {}
        }
    }

    nonisolated static func dayAndTime(_ day: String, _ time: String?) -> JSONValue {
        .object(["day": .string(day), "time": time.map(JSONValue.string) ?? .null])
    }

    /// 这件待办叫什么（轻提示上写）：待办页的单子里找，画布正在看的那天里找
    private func todoTitle(_ id: Int) -> String? {
        if let row = todoPage?.row(id) { return row.content }
        guard let entry = day?.entries.first(where: { $0.id == id }), case .todo(let todo) = entry.data else {
            return nil
        }
        return todo.content
    }

    /// 详情开着的那一行（从画布打开的，待办页的单子里可能没有）
    private func detailRow(_ id: Int) -> API.TodoRow? {
        if case .detail(let row) = todoSheet, row.id == id { return row }
        return nil
    }

}

/// 通知上点了什么（PourPlatform 的 Reminders.Action；App 里只认这几样）
enum TodoAction {
    case done, tenMinutes, hour, tomorrow, open
}
