import Foundation
import PourAPI
import PourCore
import Testing

@testable import Pour

/// 待办 2.0 第 8 步（docs/todo-2.0）：时间线怎么摆——撞在一起的日程并排、现在以前没安排的收起来、空档和建议、
/// 撞上日程写简称、还没排时间的托盘
@Suite("待办 2.0：时间线")
@MainActor
struct TodoTimelineTests {
    static let today = "2026-10-27"

    private func event(_ id: String, _ title: String, _ start: String, _ end: String) -> CalendarItem {
        CalendarItem(
            id: id, title: title, start: "\(Self.today)T\(start)", end: "\(Self.today)T\(end)", allDay: false,
            calendar: "工作")
    }

    private func page(_ rows: [API.TodoRow]) -> API.TodoPage {
        API.TodoPage(
            today: Self.today, groups: [API.TodoGroup(key: "today", title: "今天", rows: rows)], open: rows.count)
    }

    /// 设计稿那一天：11:35；喝水 11:12、喝三瓶水 12:30、接小孩 17:00；两场面试 15:00 起并排；回复客户电话只说了下午
    @Test func theDesignDay() {
        let water = API.TodoRow(id: 1, content: "喝水", day: Self.today, remindAt: "11:12")
        var bottles = API.TodoRow(id: 2, content: "喝三瓶水", day: Self.today, remindAt: "12:30")
        bottles.quadrant = TodoQuadrant.schedule.rawValue
        let kid = API.TodoRow(id: 3, content: "接小孩", day: Self.today, remindAt: "17:00")
        var call = API.TodoRow(id: 4, content: "回复客户电话", day: Self.today, window: .afternoon)
        call.quadrant = TodoQuadrant.doNow.rawValue
        let lunch = API.TodoRow(id: 5, content: "吃午饭", day: Self.today)
        let events = [
            event("a", "潘志文 直播带货主播-男女不限 线下面试", "15:00", "18:00"),
            event("b", "陈宏远 直播带货主播-男女不限 线下面试", "15:00", "18:30"),
        ]
        let plan = TodoTimelinePlan.make(
            page: page([water, bottles, kid, call, lunch]), held: [:], events: events, now: "2026-10-27T11:35",
            expanded: false)
        // 08:00–11:00 没安排，收起来
        #expect(plan.first == 8 && plan.collapsedUntil == 11)
        // 两场面试并排两列
        #expect(plan.events.map(\.column).sorted() == [0, 1] && plan.events.allSatisfy { $0.columns == 2 })
        // 接小孩 17:00 落在面试里
        #expect(plan.tags.first { $0.row.id == 3 }?.clash == "面试")
        #expect(plan.tags.first { $0.row.id == 1 }?.clash == nil)
        // 13:00–15:00 空着，建议排「回复客户电话」（带下午的时间段）
        #expect(plan.gaps.first?.text == "13:00–15:00")
        #expect(plan.suggestion?.row.id == 4 && plan.suggestion?.at == 14 * 60)
        // 托盘：只说了时间段的、没说时间的
        #expect(Set(plan.tray.map(\.id)) == [4, 5])
        // 展开以后不收
        let open = TodoTimelinePlan.make(
            page: page([water]), held: [:], events: [], now: "2026-10-27T11:35", expanded: true)
        #expect(open.collapsedUntil == nil)
    }

    /// 四场撞在一起：画 3 列，多的一场写「+1」
    @Test func atMostThreeColumns() {
        let events = (0..<4).map { event("e\($0)", "会议 \($0)", "10:00", "11:00") }
        let placed = TodoTimelinePlan.columns(events, day: Self.today)
        #expect(placed.events.count == 3 && placed.events.allSatisfy { $0.columns == 3 })
        #expect(placed.more.first?.count == 1)
    }

    /// 空档：现在以后、1 小时以上，开头取到下一个半点；建议先排「排时间」那格的
    /// 日历里和待办是同一件的（10:00 给客户回电话）：只画待办的小标签，不画日程、不算撞上
    @Test func twinIsOneTag() {
        let call = API.TodoRow(id: 1, content: "给客户回电话", day: Self.today, remindAt: "10:00")
        let plan = TodoTimelinePlan.make(
            page: page([call]), held: [:], events: [event("twin", "给客户回电话", "10:00", "10:15")],
            now: "\(Self.today)T09:00", expanded: false)
        #expect(plan.events.isEmpty)
        #expect(plan.tags.map(\.row.id) == [1] && plan.tags[0].clash == nil)
    }

    @Test func gapsAndSuggestion() {
        let gaps = TodoTimelinePlan.gaps(busy: [(15 * 60, 16 * 60)], from: 11 * 60 + 35, until: 22 * 60)
        #expect(gaps.map(\.text) == ["12:00–15:00", "16:00–22:00"])
        var schedule = API.TodoRow(id: 1, content: "写周报", day: Self.today)
        schedule.quadrant = TodoQuadrant.schedule.rawValue
        let evening = API.TodoRow(id: 2, content: "收衣服", day: Self.today, window: .evening)
        #expect(TodoTimelinePlan.suggest(gaps: gaps, tray: [evening, schedule])?.row.id == 1)
        // 晚上的只建议进和晚上重叠的空档：12:00–15:00 不行，16:00–22:00 排在 19:00
        #expect(TodoTimelinePlan.suggest(gaps: [gaps[0]], tray: [evening]) == nil)
        let night = TodoTimelinePlan.suggest(gaps: gaps, tray: [evening])
        #expect(night?.gap == gaps[1] && night?.at == 19 * 60)
        // 下午的放进一大段空档（10:30–17:30）：排在下午 14:00（以前只看空档开头是不是下午，排不进）
        let afternoon = API.TodoRow(id: 3, content: "整理报销单", day: Self.today, window: .afternoon)
        let long = TodoTimelinePlan.Gap(start: 10 * 60 + 30, end: 17 * 60 + 30)
        #expect(TodoTimelinePlan.suggest(gaps: [long], tray: [afternoon])?.at == 14 * 60)
    }

    /// 只空一个钟头的不标（「空着」那一条比一个钟头还高，压到下一件上；真机上 14:00 叫我起床上面压着「13:00–14:00 空着」）
    @Test func oneHourIsNotAGap() {
        // 12:23 现在；12:30 午休、14:00 叫我起床（各占半个钟头）
        let gaps = TodoTimelinePlan.gaps(busy: [(750, 780), (840, 870)], from: 743, until: 22 * 60)
        #expect(gaps.map(\.text) == ["14:30–22:00"])
    }

    @Test func shortNames() {
        #expect(TodoTimelinePlan.shortName("潘志文 直播带货主播-男女不限 线下面试") == "面试")
        #expect(TodoTimelinePlan.shortName("产品评审会") == "评审")
        #expect(TodoTimelinePlan.shortName("和小李喝咖啡").isEmpty)
    }

    // MARK: - 作息、缩放（产品主人 2026-11-06）

    private static let routine = API.Routine(
        blocks: [
            API.RoutineBlock(title: "睡觉", kind: .sleep, from: "23:30", to: "07:00", days: [0, 1, 2, 3, 4, 5, 6]),
            API.RoutineBlock(title: "上班", kind: .work, from: "09:30", to: "18:30", days: [0, 1, 2, 3, 4]),
            API.RoutineBlock(title: "午饭", kind: .busy, from: "12:00", to: "13:00", days: [0, 1, 2, 3, 4]),
        ], custom: true)

    /// 10/27 周二：跨过半夜的睡觉落在早上和今晚；从起床前半个钟头画到睡觉后半个钟头；空档不往睡觉、午饭里排
    /// （上班照样找）；落在午饭里的写「撞上午饭」
    @Test func routineShapesTheDay() {
        let lunch = API.TodoRow(id: 1, content: "约同事吃饭", day: Self.today, remindAt: "12:30")
        let plan = TodoTimelinePlan.make(
            page: page([lunch]), held: [:], events: [], now: "\(Self.today)T08:00", expanded: true,
            routine: Self.routine)
        #expect(plan.bands.map(\.title) == ["睡觉", "上班", "午饭", "睡觉"])
        #expect(plan.wake == 7 * 60 && plan.bed == 23 * 60 + 30)
        #expect(plan.first == 6 && plan.last == 24)
        #expect(plan.tags[0].clash == "午饭")
        #expect(plan.gaps.map(\.text) == ["08:00–12:00", "13:00–23:30"])
        // 周六：没有上班、午饭
        let saturday = TodoTimelinePlan.bands(Self.routine, day: "2026-10-31")
        #expect(saturday.map(\.title) == ["睡觉", "睡觉"])
    }

    /// 过了半夜才睡（00:30 到 07:30）：今天早上睡到 07:30，今晚画到 24 点；没设作息照旧 8 点到 22 点
    @Test func lateSleeperAndNoRoutine() {
        let late = API.Routine(
            blocks: [
                API.RoutineBlock(title: "睡觉", kind: .sleep, from: "00:30", to: "07:30", days: [0, 1, 2, 3, 4, 5, 6])
            ],
            custom: true)
        let plan = TodoTimelinePlan.make(
            page: page([]), held: [:], events: [], now: "\(Self.today)T09:00", expanded: true, routine: late)
        #expect(plan.wake == 7 * 60 + 30 && plan.bed == 24 * 60)
        #expect(plan.first == 7 && plan.last == 24)
        let plain = TodoTimelinePlan.make(
            page: page([]), held: [:], events: [], now: "\(Self.today)T09:00", expanded: true)
        #expect(plain.first == 8 && plain.last == 22 && plain.bands.isEmpty && plain.wake == nil)
    }

    /// 缩放：越小越简略、越大越细；手指下面那一刻留在原地（它的高度变了多少就滚多少）；不出范围
    @Test func zoomKeepsTheFingerSpot() {
        #expect(TimelineZoom.density(24) == .compact && TimelineZoom.density(46) == .regular)
        #expect(TimelineZoom.density(120) == .detailed)
        #expect(TimelineZoom.clamp(500) == TimelineZoom.range.upperBound && TimelineZoom.clamp(1) == 24)
        let pinch = TimelineZoom.Pinch(hour: 46, minute: 120, offset: 100)
        #expect(TimelineZoom.offset(pinch, hour: 92) == 192)
        #expect(TimelineZoom.offset(TimelineZoom.Pinch(hour: 92, minute: 60, offset: 10), hour: 24) == 0)
        #expect(RoutineText.days([0, 1, 2, 3, 4]) == "工作日" && RoutineText.days([0, 2, 4]) == "周一、三、五")
        #expect(
            RoutineText.summary(API.Routine(blocks: Self.routine.blocks.prefix(1).map { $0 }, custom: false))
                == "还没设，睡觉先按 23:30–07:00 算")
    }
}
