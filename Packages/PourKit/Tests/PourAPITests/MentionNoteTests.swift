import Foundation
import Testing

@testable import PourAPI

/// 「说到的」小胶囊旁边写什么：第一次、这周第几次；只说过一次又不是第一次的不写
@Suite("说到的：以前说到过多少")
struct MentionNoteTests {
    typealias History = API.MentionHistory

    @Test func firstTime() {
        #expect(CanvasPlan.mentionNote(History(kind: "thing", name: "牛奶", weekDays: 1, firstTime: true)) == "第一次")
    }

    @Test func severalDaysThisWeek() {
        #expect(CanvasPlan.mentionNote(History(kind: "person", name: "小李", weekDays: 3, firstTime: false)) == "这周 3 天")
    }

    @Test func onceAndNotNewSaysNothing() {
        #expect(CanvasPlan.mentionNote(History(kind: "person", name: "老婆", weekDays: 1, firstTime: false)) == nil)
        #expect(CanvasPlan.mentionNote(nil) == nil)
    }

    /// 服务器 2.1.0 的样子（curl 演示服务器 /api/day 拿的一段）；以前的服务器没有这个字段，也能解
    @Test func decodesFromServer() throws {
        let json = #"""
            {"day":"2026-10-15","entries":[],"summary":null,"goals":[],
            "mentions":[{"kind":"thing","name":"降噪耳机","weekDays":2,"firstTime":false},
            {"kind":"thing","name":"牛奶","weekDays":1,"firstTime":true}]}
            """#
        let day = try JSONDecoder().decode(API.DayView.self, from: Data(json.utf8))
        #expect(day.mentions?.map(\.name) == ["降噪耳机", "牛奶"])
        #expect(CanvasPlan.mentionNote(day.mentions?.last) == "第一次")
        let old = try JSONDecoder().decode(
            API.DayView.self, from: Data(#"{"day":"2026-10-15","entries":[],"summary":null,"goals":[]}"#.utf8))
        #expect(old.mentions == nil)
    }

    @Test func findsByKindAndName() {
        let all = [
            History(kind: "person", name: "学校", weekDays: 2, firstTime: false),
            History(kind: "place", name: "学校", weekDays: 4, firstTime: false),
        ]
        #expect(CanvasPlan.history(all, kind: "place", name: "学校")?.weekDays == 4)
        #expect(CanvasPlan.history(all, kind: "thing", name: "学校") == nil)
        #expect(CanvasPlan.history(nil, kind: "place", name: "学校") == nil)
    }
}
