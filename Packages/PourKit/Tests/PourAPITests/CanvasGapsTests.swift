import PourAPI
import Testing

/// 时间轴上点空当补记（docs/模块/产品优化.md R1.2）
@Suite("一天的时间上的空当")
struct CanvasGapsTests {
    let day = "2026-10-24"

    @Test func betweenEvents() {
        let spans = [
            ("\(day)T08:20", "\(day)T08:55"), ("\(day)T09:00", "\(day)T12:00"), ("\(day)T14:00", "\(day)T18:00"),
        ]
        let gaps = CanvasPlan.ribbonGaps(spans.map { (start: $0.0, end: $0.1) }, day: day, today: "2026-10-26", now: "")
        // 6:00–8:20、12:00–14:00、18:00–23:00；8:55–9:00 只有 5 分钟，不算
        #expect(gaps.map(\.prompt) == ["6:00 到 8:20，", "12:00 到 14:00，", "18:00 到 23:00，"])
        #expect(gaps[1].spoken == "补记 12:00 到 14:00")
    }

    @Test func overlappingAndToday() {
        // 重叠的合在一起：9–12 和 10–13 之间没有空当；今天只到现在
        let spans = [(start: "\(day)T09:00", end: "\(day)T12:00"), (start: "\(day)T10:00", end: "\(day)T13:00")]
        let gaps = CanvasPlan.ribbonGaps(spans, day: day, today: day, now: "\(day)T15:10")
        #expect(
            gaps == [
                CanvasPlan.Gap(start: "\(day)T06:00", end: "\(day)T09:00"),
                CanvasPlan.Gap(start: "\(day)T13:00", end: "\(day)T15:10"),
            ])
    }

    @Test func nothingToFill() {
        // 以后的日子不能补记；现在离上一件事不到半小时，不算
        #expect(CanvasPlan.ribbonGaps([], day: "2026-10-27", today: "2026-10-26", now: "2026-10-26T10:00").isEmpty)
        let spans = [(start: "\(day)T05:30", end: "\(day)T09:50")]
        #expect(CanvasPlan.ribbonGaps(spans, day: day, today: day, now: "\(day)T10:10").isEmpty)
        // 早上 6 点以前的不算：从 6 点（或者前一件事结束）算起
        #expect(CanvasPlan.ribbonGaps([], day: day, today: day, now: "\(day)T06:20").isEmpty)
    }
}
