import PourCore
import Testing

/// 画布和对话里的写法：和服务器 shared/src/format.ts、tidy.ts、receipt.ts 一字不差
@Suite("画布和对话里的写法")
struct WebTextTests {
    let run = RecordData.Event(
        category: "run", label: "跑步", start: "2026-10-19T07:00", durationMin: 40,
        metrics: [.init(name: "距离", value: 5, unit: "公里")])
    let lunch = RecordData.Event(
        category: "diet", label: "吃面", start: "2026-10-19T12:00",
        metrics: [.init(name: "花费", value: 32, unit: "元", item: "面")], people: ["小王"])

    @Test func clocksMinutesAndDays() {
        #expect(WebText.clock("2026-09-24T07:30") == "7:30")
        #expect(WebText.clock("2026-09-24T23:05") == "23:05")
        #expect(WebText.minutes(60) == "60 分钟")
        #expect(WebText.minutes(150) == "2 小时 30 分")
        #expect(WebText.minutes(120) == "2 小时")
        #expect(WebText.dayTitle("2026-10-19", today: "2026-10-19") == "10月19日 周一")
        #expect(WebText.dayTitle("2025-12-31", today: "2026-10-19") == "2025年12月31日 周三")
        #expect(WebText.relative("2026-10-18", today: "2026-10-19") == "昨天")
        #expect(WebText.yuan(8600) == "¥8,600")
        #expect(WebText.yuan(12.5) == "¥12.5")
    }

    @Test func eventLines() {
        #expect(WebText.eventMeta(run) == "7:00 开始 · 40 分钟 · 5 公里")
        #expect(WebText.eventMeta(lunch) == "12:00 开始 · 面 ¥32 · 和小王")
        #expect(WebText.headline([lunch], measure: "duration") == "花了 ¥32")
        #expect(WebText.headline([run, run], measure: "count") == "2 次")
        #expect(WebText.headline([run], measure: "公里") == "5 公里")
        #expect(WebText.dayMood([5, 2]) == "有起有落")
        #expect(WebText.dayMood([4, 4]) == "挺好")
    }

    @Test func receipts() {
        let categories = [
            LifeCategory(key: "run", name: "跑步", emoji: "🏃", color: "green", measure: "duration", order: 20),
            LifeCategory(key: "diet", name: "饮食", emoji: "🍽", color: "orange", measure: "duration", order: 60),
        ]
        let entry = { (data: RecordData) in
            Entry(id: "x", noteId: "n", day: "2026-10-19", data: data, span: "", confidence: 1, createdAt: .now)
        }
        let items = [
            WebReceipt.item(.created, entry: entry(.event(run)), categories: categories),
            WebReceipt.item(.created, entry: entry(.event(lunch)), categories: categories),
        ]
        #expect(WebReceipt.line(items) == "已记录：🏃 跑步 40 分钟 5 公里 · 🍽 吃面 面 ¥32 · 和小王")
        let deleted = WebReceipt.item(.deleted, entry: entry(.event(lunch)), categories: categories)
        #expect(WebReceipt.line([items[0], deleted]) == "已记录：🏃 跑步 40 分钟 5 公里；已删除：🍽 吃面 面 ¥32 · 和小王")
        let todo = entry(.todo(.init(content: "开会", remindAt: "2026-10-19T15:00")))
        #expect(WebReceipt.describe(todo.data, day: todo.day, categories: []) == "📝 待办：开会（⏰ 15:00 提醒）")
    }
}
