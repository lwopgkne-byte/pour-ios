import Foundation
import PourAPI
import Testing

/// 画布由内容决定（docs/模块/生活画布2.0.md 第 4、5 节）：不同人的一天，长出不一样的亮点和卡片
@Suite("画布由内容决定")
struct CanvasPlanTests {
    /// 演示里那个人的一天（Fixtures/day.json，上班族）
    @Test func officeDay() throws {
        let day = try fixture()
        let cards = CanvasPlan.cards(day.entries, Self.categories)
        // 有没做完的待办：待办最前，钱的汇总卡（几笔）跟在后面；感悟、心情放最后
        #expect(cards.map(\.id).prefix(3) == ["todo", "money", "mentions"])
        #expect(cards.map(\.id).suffix(2) == ["insight", "mood"])
        let templates = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0.template) })
        #expect(templates["sleep"] == .sleep)
        #expect(templates["work"] == .duration)
        #expect(templates["study"] == .duration)
        #expect(templates["c-84f6a689"] == .count)
        #expect(templates["mood"] == .mood)
        // 心情说了那一刻：整行
        #expect(cards.first { $0.id == "mood" }?.size == .full)
        let highlights = CanvasPlan.highlights(day.entries, Self.categories)
        #expect(highlights.map(\.label) == ["上班", "花了", "看书"])
        #expect(highlights[0].parts == [CanvasPlan.Part(number: "9", unit: "小时")])
        #expect(highlights[1].parts.first?.number == "6,895")
        #expect(highlights[2].parts == [CanvasPlan.Part(number: "33", unit: "页")])
    }

    /// 待办和提醒永远最前：都做完了也不往后挪（产品主人 2026-10-21：做完的待办跑到下面去是毛病）
    @Test func todosStayFirst() throws {
        let entries = [
            try event(1, "work", "上班", minutes: 480),
            try todo(2, "交电费", done: true),
            try event(3, "diet", "午饭"),
        ]
        #expect(CanvasPlan.cards(entries, Self.categories).first?.id == "todo")
    }

    /// 待办的先后：有提醒的按时间在前，其余按说的先后；勾掉不改变位置
    @Test func todoOrderIsStable() throws {
        let first = try todo(1, "买牛奶")
        let reminded = try todo(2, "交作业", remind: "2026-10-21T23:00")
        let early = try todo(3, "取快递", remind: "2026-10-21T09:00")
        let last = try todo(4, "交电费")
        let open = CanvasPlan.todoOrder([first, reminded, early, last]).map(\.id)
        let done = CanvasPlan.todoOrder([try todo(1, "买牛奶", done: true), reminded, early, last]).map(\.id)
        #expect(open == [3, 2, 1, 4])
        #expect(done == open)
    }

    /// 说到的人、东西、地方、话题：按说的先后、不重复；两样以上才长出「说到的」那张卡，跟在待办、钱后面
    @Test func mentionsGrowFromWhatWasSaid() throws {
        let lunch = try event(
            1, "diet", "和小李吃午饭", extra: ["people": ["小李"], "places": ["公司楼下"], "tags": ["同事"]])
        let book = try event(2, "study", "看书", extra: ["things": ["《人类简史》"], "people": ["小李"]])
        let mentions = CanvasPlan.mentions([lunch, book])
        #expect(mentions.people == ["小李"])
        #expect(mentions.things == ["《人类简史》"])
        #expect(mentions.places == ["公司楼下"])
        #expect(mentions.topics == ["同事"])
        #expect(CanvasPlan.cards([lunch, book], Self.categories).first?.id == "mentions")
        let alone = try event(3, "work", "上班", extra: ["people": ["老板"]])
        #expect(!CanvasPlan.cards([alone], Self.categories).contains { $0.id == "mentions" })
    }

    /// 宝妈：喂奶是次数，睡眠断成三段，奶粉记在购物
    @Test func momDay() throws {
        let feeds = try (0..<7).map { try event(100 + $0, "c-baby", "喂奶", start: "2026-10-21T0\($0):30") }
        let diapers = try (0..<6).map { try event(200 + $0, "c-baby", "换尿布", start: "2026-10-21T1\($0):10") }
        let sleeps = [
            try event(300, "sleep", "睡觉", start: "2026-10-20T23:40", end: "2026-10-21T01:30"),
            try event(301, "sleep", "睡觉", start: "2026-10-21T02:20", end: "2026-10-21T04:10"),
            try event(302, "sleep", "睡觉", start: "2026-10-21T05:30", end: "2026-10-21T07:10"),
        ]
        let milk = try event(400, "c-shop", "奶粉", metrics: [Metric(name: "花费", value: 298, unit: "元")])
        let entries = feeds + diapers + sleeps + [milk]
        let highlights = CanvasPlan.highlights(entries, Self.categories)
        #expect(highlights.map(\.label) == ["睡了", "喂奶", "花了"])
        #expect(highlights[0].parts == CanvasPlan.durationParts(320))
        #expect(highlights[1].parts == [CanvasPlan.Part(number: "7", unit: "次")])
        // 只有一笔钱：没有钱的汇总卡，点「花了」滚到购物那张
        #expect(highlights[2].target == "c-shop")
        let baby = CanvasPlan.cards(entries, Self.categories).first { $0.id == "c-baby" }
        #expect(baby?.template == .count)
        #expect(baby?.size == .full)
    }

    /// 退休老人：健康卡上面是血压，下面是吃药三次；运动是两件不一样的事，写类别名
    @Test func elderDay() throws {
        let pressure = try event(
            1, "c-health", "量血压", start: "2026-10-21T07:30",
            metrics: [Metric(name: "收缩压", value: 135, unit: "mmHg"), Metric(name: "舒张压", value: 85, unit: "mmHg")])
        let pills = try (0..<3).map { try event(10 + $0, "c-health", "吃药") }
        let walks = [
            try event(20, "exercise", "散步", minutes: 40), try event(21, "exercise", "太极", minutes: 30),
        ]
        let entries = [pressure] + pills + walks
        let highlights = CanvasPlan.highlights(entries, Self.categories)
        #expect(highlights.map(\.label) == ["运动", "吃药", "血压"])
        #expect(highlights[0].parts == CanvasPlan.durationParts(70))
        #expect(highlights[2].parts == [CanvasPlan.Part(number: "135/85", unit: "")])
        let health = CanvasPlan.cards(entries, Self.categories).first { $0.id == "c-health" }
        #expect(health?.template == .count)
        #expect(health?.withBody == true)
        #expect(health?.size == .full)
    }

    /// 开店：收入比花费多，收入在前；钱的汇总卡因为有收入单独出来
    @Test func shopDay() throws {
        let entries = [
            try event(
                1, "work", "进货", start: "2026-10-21T06:30", end: "2026-10-21T08:00",
                metrics: [Metric(name: "花费", value: 1800, unit: "元")]),
            try event(
                2, "work", "开店", start: "2026-10-21T09:00", end: "2026-10-21T19:00",
                metrics: [Metric(name: "收入", value: 3200, unit: "元")]),
            try event(3, "diet", "午饭", metrics: [Metric(name: "花费", value: 60, unit: "元")]),
        ]
        let highlights = CanvasPlan.highlights(entries, Self.categories)
        #expect(highlights.map(\.label) == ["工作", "收入", "花了"])
        #expect(highlights[1].parts.first?.number == "3,200")
        #expect(highlights[2].parts.first?.number == "1,860")
        #expect(CanvasPlan.cards(entries, Self.categories).first?.id == "money")
    }

    /// 界面测试里说的那一句：跑步 32 分钟 5 公里、吃面 ¥32。跑步只放一次；只有一笔钱，「花了」滚到饮食那张；
    /// 两张都是半宽，配成一行
    @Test func oneSentence() throws {
        let entries = [
            try event(
                1, "run", "跑步", start: "2026-10-21T07:10", end: "2026-10-21T07:42", minutes: 32,
                metrics: [Metric(name: "距离", value: 5, unit: "公里")]),
            try event(2, "diet", "吃面", metrics: [Metric(name: "花费", value: 32, unit: "元")]),
        ]
        let highlights = CanvasPlan.highlights(entries, Self.categories)
        #expect(highlights.map(\.label) == ["跑步", "花了"])
        #expect(highlights[1].target == "diet")
        #expect(CanvasPlan.rows(entries, Self.categories).map(\.id) == ["pair-exercise-diet"])
    }

    /// 只写了一句感悟的一天：没有亮点，一张整行的感悟卡
    @Test func quietDay() throws {
        let insight = try entry([
            "id": 1, "day": "2026-10-21", "kind": "insight", "category": "insight",
            "data": ["title": "先做完再改", "quote": "其实不用把每件事都做完美", "tags": ["工作"]],
        ])
        #expect(CanvasPlan.highlights([insight], Self.categories).isEmpty)
        #expect(CanvasPlan.rows([insight], Self.categories).map(\.id) == ["full-insight"])
    }

    /// 每月固定扣的房贷不算今天花的：「花了」和钱的汇总卡一样是 ¥95
    @Test func monthlyIsNotToday() throws {
        let entries = [
            try event(1, "diet", "午饭", metrics: [Metric(name: "花费", value: 26, unit: "元")]),
            try event(2, "c-shop", "网购牛奶", metrics: [Metric(name: "花费", value: 69, unit: "元")]),
            try event(3, "c-shop", "房贷", metrics: [Metric(name: "花费", value: 6800, unit: "元", monthly: true)]),
        ]
        let spend = CanvasPlan.highlights(entries, Self.categories).first { $0.label == "花了" }
        #expect(spend?.parts.first?.number == "95")
    }

    /// 只有一笔钱：不单独出钱的汇总卡（它的类别卡上已经写了）
    @Test func oneSpendNoMoneyCard() throws {
        let entries = [
            try event(1, "diet", "午饭", metrics: [Metric(name: "花费", value: 35, unit: "元")]),
            try event(2, "work", "上班", minutes: 480),
        ]
        #expect(!CanvasPlan.cards(entries, Self.categories).contains { $0.id == "money" })
    }

    /// 配对：半宽两两成对；隔一张整行的半宽往前挪一位；单出一张拉满
    @Test func pairing() {
        let half = { (id: String) in
            CanvasPlan.Card(id: id, template: .general, size: .half, entries: [], withBody: false)
        }
        let full = { (id: String) in
            CanvasPlan.Card(id: id, template: .todo, size: .full, entries: [], withBody: false)
        }
        #expect(CanvasPlan.pair([half("a"), half("b")]).map(\.id) == ["pair-a-b"])
        #expect(CanvasPlan.pair([half("a"), full("b"), half("c")]).map(\.id) == ["pair-a-c", "full-b"])
        #expect(CanvasPlan.pair([half("a"), full("b")]).map(\.id) == ["full-a", "full-b"])
        #expect(CanvasPlan.pair([half("a"), half("b"), half("c")]).map(\.id) == ["pair-a-b", "full-c"])
    }

    /// 心情的底色：有好有坏是有起有落；没记心情不猜
    @Test func moodTone() throws {
        let mood = { (id: Int, level: Int) in
            try entry([
                "id": id, "day": "2026-10-21", "kind": "mood", "category": "mood",
                "data": ["mood": level, "emotions": [String]()],
            ])
        }
        #expect(CanvasPlan.mood([try mood(1, 2), try mood(2, 4)]) == .mixed)
        #expect(CanvasPlan.mood([try mood(1, 4)]) == .good)
        #expect(CanvasPlan.mood([try mood(1, 2)]) == .low)
        #expect(CanvasPlan.mood([try event(1, "work", "上班")]) == .none)
    }

    // MARK: - 造数据

    static let categories: [API.Category] = {
        let list: [[String: Any]] = [
            ["key": "sleep", "name": "睡眠", "emoji": "😴", "color": "purple", "measure": "duration"],
            ["key": "exercise", "name": "运动", "emoji": "🏃", "color": "green", "measure": "duration"],
            [
                "key": "strength", "name": "力量", "emoji": "🏋️", "color": "green", "parent": "exercise",
                "measure": "duration",
            ],
            [
                "key": "run", "name": "跑步", "emoji": "🏃", "color": "green", "parent": "exercise",
                "measure": "duration",
            ],
            ["key": "diet", "name": "饮食", "emoji": "🍽", "color": "orange", "measure": "duration"],
            ["key": "study", "name": "学习", "emoji": "📚", "color": "blue", "measure": "duration"],
            ["key": "work", "name": "工作", "emoji": "💼", "color": "brown", "measure": "duration"],
            ["key": "c-94fb6da3", "name": "出行", "emoji": "🚗", "color": "blue", "measure": "duration"],
            ["key": "c-84f6a689", "name": "购物", "emoji": "🛒", "color": "orange", "measure": "count"],
            ["key": "c-8dc516e6", "name": "育儿", "emoji": "🍼", "color": "pink", "measure": "count"],
            ["key": "c-c916946f", "name": "娱乐", "emoji": "🎬", "color": "purple", "measure": "duration"],
            ["key": "c-b27062be", "name": "办事", "emoji": "📋", "color": "gray", "measure": "count"],
            ["key": "c-baby", "name": "育儿", "emoji": "🍼", "color": "pink", "measure": "count"],
            ["key": "c-shop", "name": "购物", "emoji": "🛒", "color": "orange", "measure": "count"],
            ["key": "c-health", "name": "健康", "emoji": "🩺", "color": "red", "measure": "count"],
        ]
        let data = (try? JSONSerialization.data(withJSONObject: list)) ?? Data()
        return (try? JSONDecoder().decode([API.Category].self, from: data)) ?? []
    }()

    private func fixture() throws -> API.DayView {
        let url = try #require(Bundle.module.url(forResource: "day", withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(API.DayView.self, from: Data(contentsOf: url))
    }

    /// 造数据用的一个数
    struct Metric {
        let name: String
        let value: Double
        let unit: String
        var monthly = false
    }

    private func entry(_ object: [String: Any]) throws -> API.Entry {
        try JSONDecoder().decode(API.Entry.self, from: JSONSerialization.data(withJSONObject: object))
    }

    private func todo(_ id: Int, _ content: String, done: Bool = false, remind: String? = nil) throws -> API.Entry {
        var data: [String: Any] = ["content": content, "done": done]
        if let remind { data["remindAt"] = remind }
        return try entry(["id": id, "day": "2026-10-21", "kind": "todo", "category": "todo", "data": data])
    }

    private func event(
        _ id: Int, _ category: String, _ label: String, start: String? = nil, end: String? = nil,
        minutes: Int? = nil, metrics: [Metric] = [], extra: [String: Any] = [:]
    ) throws -> API.Entry {
        var data: [String: Any] = ["label": label]
        data.merge(extra) { _, new in new }
        if let start { data["start"] = start }
        if let end { data["end"] = end }
        if let minutes { data["durationMin"] = minutes }
        if !metrics.isEmpty {
            data["metrics"] = metrics.map { metric in
                ["name": metric.name, "value": metric.value, "unit": metric.unit, "monthly": metric.monthly]
            }
        }
        return try entry(["id": id, "day": "2026-10-21", "kind": "event", "category": category, "data": data])
    }
}
