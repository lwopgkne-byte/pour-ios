import Foundation
import PourAPI
import Testing

/// 一眼（docs/模块/产品优化.md R7）：小组件、锁屏的那一小份，字段照服务器的解码
@Suite("一眼")
struct GlanceTests {
    @Test func decodes() throws {
        let glance = try JSONDecoder().decode(
            API.Glance.self,
            from: Data(
                #"""
                {"today":"2026-10-26","open":[{"id":1,"content":"喝水","remindAt":"14:00","overdue":false},
                {"id":5,"content":"修晾衣架","remindAt":null,"overdue":true}],"done":1,"total":3,
                "next":{"id":1,"content":"喝水","remindAt":"14:00","overdue":false},
                "quote":{"text":"付出不亚于任何人的努力","day":"2026-10-20","asked":true}}
                """#.utf8))
        #expect(glance.open.map(\.content) == ["喝水", "修晾衣架"])
        #expect(glance.open.last?.overdue == true)
        #expect(glance.next?.remindAt == "14:00")
        #expect(glance.quote?.asked == true)
        let empty = try JSONDecoder().decode(
            API.Glance.self,
            from: Data(#"{"today":"2026-10-26","open":[],"done":0,"total":0,"next":null,"quote":null}"#.utf8))
        #expect(empty.next == nil)
    }
}
