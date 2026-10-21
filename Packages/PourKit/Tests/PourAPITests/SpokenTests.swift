import Testing

@testable import PourAPI

/// 给读屏念的（Show.spoken）：时间段念「到」，小圆点换成停顿
@Suite("给读屏念的")
struct SpokenTests {
    @Test func timeRanges() {
        #expect(Show.spoken("20:00–20:45 · 45 分钟") == "20:00 到 20:45，45 分钟")
        #expect(Show.spoken("0:10 → 7:10") == "0:10 到 7:10")
        #expect(Show.spoken("进食窗口 8:00–18:30 · ¥58") == "进食窗口 8:00 到 18:30，¥58")
    }

    @Test func plainTextStaysTheSame() {
        #expect(Show.spoken("送车去保养") == "送车去保养")
    }
}
