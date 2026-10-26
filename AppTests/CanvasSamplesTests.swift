import Foundation
import Testing

@testable import Pour

/// 画布样张（产品主人 2026-10-26）：打开时这一周每天一种人的一天，六天前空着，明天只有待办；关掉时什么都没有
@Suite("画布样张", .serialized)
@MainActor
struct CanvasSamplesTests {
    @Test func weekOfSamples() {
        let before = CanvasSamples.isOn
        CanvasSamples.set(true)
        defer { CanvasSamples.set(before) }
        let plan = StubServer.State.samplePlan(today: "2026-10-26")
        #expect(plan.count == 7)
        #expect(plan["2026-10-26"]?.summary == CanvasSample.office.summary)
        #expect(plan["2026-10-25"]?.summary == CanvasSample.mom.summary)
        #expect(plan["2026-10-21"]?.summary == CanvasSample.quiet.summary)
        #expect(plan["2026-10-20"] == nil)
        #expect(plan["2026-10-27"]?.entries == CanvasSample.tomorrow.entries)
        // 每条记录的编号不重复（几天的样张放在一起）
        let ids = StubServer.State.sampleEntries(today: "2026-10-26").compactMap { $0["id"] as? Int }
        #expect(Set(ids).count == ids.count)
        #expect(ids.count > 40)
    }

    @Test func offMeansNothing() {
        let before = CanvasSamples.isOn
        CanvasSamples.set(false)
        defer { CanvasSamples.set(before) }
        #expect(StubServer.State.samplePlan(today: "2026-10-26").isEmpty)
        #expect(StubServer.State.sampleCategories.isEmpty)
    }
}
