import Foundation
import PourAPI
import Testing

/// 补记和名字表（docs/模块/产品优化.md R1.1、R2）：字段照服务器的解码；「说到的」照服务器给的名单
@Suite("补记和名字表")
struct NamesTests {
    @Test func decodes() throws {
        let note = try JSONDecoder().decode(
            API.Note.self,
            from: Data(
                #"""
                {"id":3,"text":"晚上吃了火锅","createdAt":"2026-10-26T07:00:00.000Z","day":"2026-10-24",
                "backfill":true,"status":"done"}
                """#.utf8))
        #expect(note.backfill == true)
        let rules = try JSONDecoder().decode(
            API.NameRules.self,
            from: Data(
                #"""
                {"rules":[
                {"kind":"person","name":"小丽","canonical":"小李","hidden":false,"updatedAt":"2026-10-26T07:00:00.000Z"},
                {"kind":"place","name":"医院","canonical":null,"hidden":true,"updatedAt":"2026-10-26T07:00:00.000Z"}]}
                """#.utf8))
        #expect(rules.rules.map(\.id) == ["person|小丽", "place|医院"])
        #expect(rules.rules[1].canonical == nil)
    }

    /// 记录里写的是「小丽」「医院」，服务器说改成了小李、医院不再显示：照服务器的；服务器没给（旧版）才从记录里收
    @Test func mentionsFollowTheServer() throws {
        let day = try JSONDecoder().decode(
            API.DayView.self,
            from: Data(
                #"""
                {"day":"2026-10-21","summary":null,"goals":[],"entries":[
                {"id":1,"day":"2026-10-21","kind":"event","category":"social","confidence":1,"status":"ok",
                 "data":{"label":"吃饭","people":["小丽","老婆"],"places":["医院"]},"sources":[]}]}
                """#.utf8))
        let history = [
            API.MentionHistory(kind: "person", name: "小李", weekDays: 3, firstTime: false),
            API.MentionHistory(kind: "person", name: "老婆", weekDays: 1, firstTime: false),
        ]
        let shown = CanvasPlan.mentions(day.entries, history: history)
        #expect(shown.people == ["小李", "老婆"])
        #expect(shown.places.isEmpty)
        #expect(CanvasPlan.mentions(day.entries, history: nil).places == ["医院"])
        // 名单只剩一个时「说到的」不长出来（两样以上才有）
        let one = [API.MentionHistory(kind: "person", name: "老婆", weekDays: 1, firstTime: false)]
        #expect(!CanvasPlan.cards(day.entries, [], mentions: one).contains { $0.id == CanvasPlan.mentionsKey })
        #expect(CanvasPlan.cards(day.entries, [], mentions: history).contains { $0.id == CanvasPlan.mentionsKey })
    }
}
