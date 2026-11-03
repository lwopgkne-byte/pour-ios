import Foundation
import PourAPI
import PourCore
import PourDesign

/// 待办页的单子怎么摆（docs/3.0/01-需求文档.md 4.2；服务器 server/src/services/todo-page.ts 的分组原样）：
/// 以前没做完的、今天、明天、这周（后天到周日）、以后、已完成。界面先改（勾、推迟、带到今天、改日子），
/// 这里照服务器的规矩把那一行挪到对的组；服务器回来的单子随后对上
enum TodoBoard {
    static let order = ["overdue", "today", "tomorrow", "week", "later", "done"]

    /// 这一天的待办在哪一组（做完的在「已完成」）
    static func key(day: String, done: Bool, today: String) -> String {
        if done { return "done" }
        let tomorrow = PourDate.addDays(today, 1)
        let sunday = PourDate.addDays(today, 6 - PourDate.weekdayMon0(today))
        if day < today { return "overdue" }
        if day == today { return "today" }
        if day == tomorrow { return "tomorrow" }
        return day <= sunday ? "week" : "later"
    }

    /// 组的名字（服务器给了的用服务器的；界面先挪过去、服务器还没回来时用这个）
    static func title(_ key: String, today: String) -> String {
        switch key {
        case "overdue": "以前没做完的"
        case "today": "今天 · \(Show.dayTitle(today, today: today))"
        case "tomorrow": "明天"
        case "week": "这周"
        case "later": "以后"
        default: "已完成"
        }
    }

    /// 同一组里的先后：同一天有提醒的按钟点在前，没提醒的按说的先后；以前没做完的最近的在前；已完成的最近做完的在前
    static func before(_ lhs: API.TodoRow, _ rhs: API.TodoRow, in key: String) -> Bool {
        if key == "done" { return (lhs.doneAt ?? "") > (rhs.doneAt ?? "") }
        let left = (lhs.day, lhs.remindAt ?? "99", lhs.id)
        let right = (rhs.day, rhs.remindAt ?? "99", rhs.id)
        return key == "overdue" ? left > right : left < right
    }

    /// 页面上显示的组：这一次看着勾掉的（held：编号 → 原来在哪一组）留在原地，离开再回来才收进「已完成」
    static func sections(_ page: API.TodoPage, held: [Int: String]) -> [API.TodoGroup] {
        var groups = page.groups
        var moved: [(String, API.TodoRow)] = []
        for index in groups.indices {
            let key = groups[index].key
            groups[index].rows.removeAll { row in
                guard let home = held[row.id], home != key else { return false }
                moved.append((home, row))
                return true
            }
        }
        for (home, row) in moved { insert(row, into: home, groups: &groups, today: page.today) }
        return groups.filter { !$0.rows.isEmpty || $0.key == "today" }
    }

    /// 放进某一组（没有这一组就按顺序加上）
    static func insert(_ row: API.TodoRow, into key: String, groups: inout [API.TodoGroup], today: String) {
        if let index = groups.firstIndex(where: { $0.key == key }) {
            let at = groups[index].rows.firstIndex { before(row, $0, in: key) } ?? groups[index].rows.endIndex
            groups[index].rows.insert(row, at: at)
            return
        }
        let rank = order.firstIndex(of: key) ?? order.count
        let at = groups.firstIndex { (order.firstIndex(of: $0.key) ?? order.count) > rank } ?? groups.endIndex
        groups.insert(API.TodoGroup(key: key, title: title(key, today: today), rows: [row]), at: at)
    }

    /// 页面上一行的时间胶囊（06 交互细节 2.1）：蓝 = 到点提醒；过了时间没做、以前没做完的用留意色写本来的日子；
    /// 明天以后的写哪天；做完的不写
    static func capsule(_ row: API.TodoRow, today: String, now: String) -> (text: String, tone: TimeCapsule.Tone)? {
        guard !row.done else { return nil }
        let clock = row.remindAt
        if row.day < today {
            let name = row.day == PourDate.addDays(today, -1) ? "昨天" : Show.monthDay(row.day)
            return ([name, clock].compactMap { $0 }.joined(separator: " "), .late)
        }
        if row.day == today {
            guard let clock else { return nil }
            // 按完整的时刻比（凌晨一点还算昨天：昨天 17:30 的照样算过了）
            return "\(row.day)T\(clock)" < now ? ("\(clock) 过了", .late) : (clock, .remind)
        }
        let name = row.day == PourDate.addDays(today, 1) ? nil : dayName(row.day, today: today)
        let text = [name, clock].compactMap { $0 }.joined(separator: " ")
        guard !text.isEmpty else { return nil }
        return (text, clock == nil ? .plain : .remind)
    }

    /// 这周的写「周五」，再往后写「11月2日」
    static func dayName(_ day: String, today: String) -> String {
        let sunday = PourDate.addDays(today, 6 - PourDate.weekdayMon0(today))
        return day <= sunday ? Show.weekday(day) : Show.monthDay(day)
    }

    /// 第二行：和谁 · 东西 · 地方
    static func detail(_ row: API.TodoRow) -> String? {
        let words = row.people + row.things + row.places
        return words.isEmpty ? nil : words.joined(separator: " · ")
    }

    /// 原话什么时候说的：ISO 时刻 →「10月26日 21:40」（详情里原话下面那一行）
    static func saidAt(_ iso: String) -> String? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { return nil }
        let local = PourDate.localDateTime(date, in: .current)
        return "\(Show.monthDay(String(local.prefix(10)))) \(local.suffix(5))"
    }

    /// 「今天 15:00」「明天」「11月2日 周一 09:00」（轻提示、加待办时认出来的那一句；和服务器的 labelOf 一样）
    static func when(day: String, time: String?, today: String) -> String {
        let name =
            switch PourDate.diffDays(day, today) {
            case 0: "今天"
            case 1: "明天"
            case 2: "后天"
            default: Show.dayTitle(day, today: today)
            }
        return [name, time].compactMap { $0 }.joined(separator: " ")
    }
}

extension API.TodoPage {
    /// 某一行在哪一组
    func key(of id: Int) -> String? {
        groups.first { $0.rows.contains { $0.id == id } }?.key
    }

    func row(_ id: Int) -> API.TodoRow? {
        groups.lazy.flatMap(\.rows).first { $0.id == id }
    }

    /// 勾、取消勾：只改这一行，不挪（划线留在原地）
    mutating func setDone(_ id: Int, _ done: Bool, at moment: String) {
        let today = self.today
        change(id) { row in
            row.done = done
            row.doneAt = done ? moment : nil
            row.overdue = !done && row.day < today
        }
    }

    /// 改了哪天、几点（推迟、带到今天、详情里改）：挪到对的组
    mutating func move(_ id: Int, day: String, time: String?) {
        guard var row = take(id) else { return }
        row.day = day
        row.remindAt = time
        row.overdue = !row.done && day < today
        put(row)
    }

    /// 服务器回来的这一行（改过的、新加的）：换上、放到对的组
    mutating func put(_ row: API.TodoRow) {
        _ = take(row.id)
        TodoBoard.insert(
            row, into: TodoBoard.key(day: row.day, done: row.done, today: today), groups: &groups, today: today)
        recount()
    }

    /// 拿走这一行（删了、要挪走）
    @discardableResult
    mutating func take(_ id: Int) -> API.TodoRow? {
        for index in groups.indices {
            if let at = groups[index].rows.firstIndex(where: { $0.id == id }) {
                let row = groups[index].rows.remove(at: at)
                if groups[index].rows.isEmpty && groups[index].key != "today" { groups.remove(at: index) }
                recount()
                return row
            }
        }
        return nil
    }

    /// 离开待办页：做完的收进「已完成」（最近做完的在最上面），下次打开不跳一下
    mutating func settle() {
        let finished = groups.filter { $0.key != "done" }.flatMap(\.rows).filter(\.done)
        for row in finished { put(row) }
    }

    mutating func change(_ id: Int, _ edit: (inout API.TodoRow) -> Void) {
        for index in groups.indices {
            if let at = groups[index].rows.firstIndex(where: { $0.id == id }) { edit(&groups[index].rows[at]) }
        }
        recount()
    }

    /// 还没做完的一共几件（今天和以前的；服务器的 open 一样算）
    private mutating func recount() {
        open = groups.filter { ["overdue", "today"].contains($0.key) }.flatMap(\.rows).filter { !$0.done }.count
    }
}

extension API.Repeat {
    /// 「每天」「工作日」「每周一、三」「每月 15 号」（服务器 shared/src/when.ts repeatText 一字不差）
    var text: String {
        switch self {
        case .daily: "每天"
        case .weekdays: "工作日"
        case .weekly(let days): "每周" + days.map { ["一", "二", "三", "四", "五", "六", "日"][$0 % 7] }.joined(separator: "、")
        case .monthly(let day): "每月 \(day) 号"
        }
    }
}

extension SnoozePreset {
    /// 推迟弹层上的名字（06 交互细节 2.2）
    var title: String {
        switch self {
        case .hour: "1 小时后"
        case .tonight: "今晚"
        case .tomorrow: "明天早上"
        case .saturday: "这个周六"
        case .monday: "下周一"
        }
    }

    var symbol: String {
        switch self {
        case .hour: "clock.arrow.circlepath"
        case .tonight: "moon.fill"
        case .tomorrow: "sun.max.fill"
        case .saturday: "calendar"
        case .monday: "calendar.badge.clock"
        }
    }

    /// 推迟到哪天几点（服务器 snoozeTarget 原样：1 小时后取到 5 分钟的整数、今晚 8 点、明天早上 9 点、
    /// 这个周六上午 10 点（周六周日说的是下周六）、下周一早上 9 点）。弹层上先写出来，界面先挪；服务器算的为准
    func target(now: Date, today: String, calendar: Calendar = .current) -> (day: String, time: String) {
        switch self {
        case .hour:
            let later = now.addingTimeInterval(3600)
            let parts = calendar.dateComponents([.hour, .minute], from: later)
            let minutes = Int((Double((parts.hour ?? 0) * 60 + (parts.minute ?? 0)) / 5).rounded(.up)) * 5
            let local = PourDate.localDateTime(later, in: calendar.timeZone)
            let day = minutes >= 1440 ? PourDate.addDays(String(local.prefix(10)), 1) : String(local.prefix(10))
            return (day, String(format: "%02d:%02d", minutes / 60 % 24, minutes % 60))
        case .tonight: return (today, "20:00")
        case .tomorrow: return (PourDate.addDays(today, 1), "09:00")
        case .saturday:
            let weekday = PourDate.weekdayMon0(today)
            return (PourDate.addDays(today, weekday < 5 ? 5 - weekday : 12 - weekday), "10:00")
        case .monday: return (PourDate.addDays(today, 7 - PourDate.weekdayMon0(today)), "09:00")
        }
    }
}
