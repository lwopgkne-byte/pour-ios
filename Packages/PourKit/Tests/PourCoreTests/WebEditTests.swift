import PourCore
import Testing

/// 详情里改时间、最近 7 天（照网页版 applyUpdate、trend.ts）
@Suite("详情里改")
struct WebEditTests {
    let run = RecordData.Event(
        category: "run", label: "跑步", start: "2026-10-19T07:00", end: "2026-10-19T07:40", durationMin: 40)

    @Test func clocks() {
        #expect(WebEdit.clock("8:30") == 510)
        #expect(WebEdit.clock("08:30") == 510)
        #expect(WebEdit.clock("8:3") == nil)
        #expect(WebEdit.clock("25:00") == nil)
        #expect(WebEdit.words("儿子、老公 朋友，儿子") == ["儿子", "老公", "朋友"])
    }

    @Test func movingTheStartKeepsTheDuration() {
        let next = WebEdit.setStart(run, day: "2026-10-19", minutes: 7 * 60 + 30)
        #expect(next.start == "2026-10-19T07:30")
        #expect(next.end == "2026-10-19T08:10")
        #expect(next.durationMin == 40)
    }

    @Test func changingTheEndRecountsTheDuration() {
        #expect(WebEdit.setEnd(run, day: "2026-10-19", minutes: 8 * 60).durationMin == 60)
        // 睡觉跨过零点：23:30 → 7:00
        let sleep = RecordData.Event(category: "sleep", label: "睡觉", start: "2026-10-18T23:30")
        let woke = WebEdit.setEnd(sleep, day: "2026-10-18", minutes: 7 * 60)
        #expect(woke.end == "2026-10-19T07:00")
        #expect(woke.durationMin == 450)
    }

    @Test func changingTheDurationMovesTheEnd() {
        #expect(WebEdit.setDuration(run, minutes: 60).end == "2026-10-19T08:00")
    }

    @Test func sevenDays() {
        let entry = { (day: DayString, minutes: Int) in
            Entry(
                id: day, noteId: "n", day: day,
                data: .event(.init(category: "run", label: "跑步", durationMin: minutes)), span: "", confidence: 1,
                createdAt: .now)
        }
        let today = entry("2026-10-19", 40)
        let trend = WebTrend.of(today, among: [entry("2026-10-17", 30), today, entry("2026-10-19", 20)])
        #expect(trend?.unit == "分钟")
        #expect(trend?.points.map(\.value) == [nil, nil, nil, nil, 30, nil, 60])
    }
}
