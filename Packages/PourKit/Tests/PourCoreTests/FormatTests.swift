import Foundation
import PourCore
import Testing

/// 界面上的写法（规范 10 第 3 节）
@Suite("写法")
struct FormatTests {
    @Test func durationsMoneyAndClock() {
        #expect(PourFormat.duration(minutes: 45) == "45 分钟")
        #expect(PourFormat.duration(minutes: 80) == "1 小时 20 分")
        #expect(PourFormat.duration(minutes: 120) == "2 小时")
        #expect(PourFormat.money(28) == "¥28")
        #expect(PourFormat.money(28.5) == "¥28.50")
        #expect(PourFormat.money(12800) == "¥12,800")
        #expect(PourFormat.amount(5) == "5")
        #expect(PourFormat.amount(6.4) == "6.4")
        #expect(PourFormat.clock("2026-10-18T07:05") == "07:05")
    }

    @Test func dayTitles() {
        #expect(PourFormat.dayTitle("2026-10-18", today: "2026-10-18") == "今天")
        #expect(PourFormat.dayTitle("2026-10-17", today: "2026-10-18") == "昨天")
        #expect(PourFormat.dayTitle("2026-10-14", today: "2026-10-18") == "10月14日")
        #expect(PourFormat.dayTitle("2025-10-14", today: "2026-10-18") == "2025年10月14日")
        #expect(PourFormat.weekday("2026-10-18") == "周日")
    }

    @Test func logicalDayFollowsTheBoundary() throws {
        let shanghai = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let lateNight = Date(timeIntervalSince1970: 1_792_262_000)  // 上海 2026-10-18 02:33
        #expect(PourDate.localDateTime(lateNight, in: shanghai) == "2026-10-18T02:33")
        #expect(PourDate.logicalDay(lateNight, in: shanghai) == "2026-10-17")
        #expect(PourDate.logicalDay(of: "2026-10-18T04:00") == "2026-10-18")
    }

    @Test func moneyIsRecognizedLikeTheWebVersion() {
        #expect(Metric(name: "花费", value: 32, unit: "元").isMoney)
        #expect(Metric(name: "花了", value: 20, unit: "块").isMoney)
        // 「块」也是量词：名字不是钱就不算
        #expect(!Metric(name: "鸡胸肉", value: 2, unit: "块").isMoney)
        #expect(Metric(name: "花费", value: 860, unit: "元", item: "菜").display == "菜 ¥860")
        #expect(Metric(name: "距离", value: 5, unit: "公里").display == "5 公里")
    }

    @Test func recordLinesReadLikeTheReceiptSpec() {
        let categories = [
            LifeCategory(key: "exercise", name: "运动", color: "moss"),
            LifeCategory(key: "run", name: "跑步", color: "moss", parent: "exercise"),
            LifeCategory(key: "diet", name: "饮食", color: "apricot"),
        ]
        let run = RecordLine(
            .event(
                .init(
                    category: "run", label: "跑步", start: "2026-10-18T07:10", durationMin: 32,
                    metrics: [.init(name: "距离", value: 5, unit: "公里")])),
            categories: categories, said: "2026-10-18T12:40", today: "2026-10-18")
        #expect(run.title == "跑步 5 公里")
        #expect(run.value == "32 分钟")
        #expect(run.time == "07:10")
        #expect(run.color == "moss")
        let lunch = RecordLine(
            .event(
                .init(category: "diet", label: "吃面", metrics: [.init(name: "花费", value: 32, unit: "元")], people: ["小王"])
            ),
            categories: categories, said: "2026-10-18T12:40", today: "2026-10-18")
        #expect(lunch.title == "吃面")
        #expect(lunch.value == "¥32")
        #expect(lunch.person == "小王")
        #expect(lunch.time == nil)
        #expect(lunch.sortKey == "2026-10-18T12:40")
        let mood = RecordLine(
            .mood(.init(level: 4, energy: 2, emotions: ["开心"])), categories: categories, said: "2026-10-18T12:40",
            today: "2026-10-18")
        #expect(mood.title == "挺好")
        #expect(mood.detail == "开心 · 有点累")
    }
}
