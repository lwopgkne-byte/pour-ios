import Foundation
import PourAPI
import Testing

/// 我的卡片和语录（docs/模块/产品优化.md R3、R4）：服务器写好的数拆成大数字和单位；字段照服务器的解码
@Suite("我的卡片和语录")
struct CardsTests {
    @Test func figure() {
        let cups = CanvasPlan.figure("12 杯")
        #expect(cups.prefix == nil)
        #expect(cups.parts == [CanvasPlan.Part(number: "12", unit: "杯")])
        #expect(
            CanvasPlan.figure("1 小时 20 分").parts == [.init(number: "1", unit: "小时"), .init(number: "20", unit: "分")])
        let money = CanvasPlan.figure("¥1,980")
        #expect(money.prefix == "¥")
        #expect(money.parts == [.init(number: "1,980", unit: "")])
        #expect(CanvasPlan.figure("23:40").parts == [.init(number: "23:40", unit: "")])
    }

    @Test func decodes() throws {
        let day = try JSONDecoder().decode(
            API.DayView.self,
            from: Data(
                #"""
                {"day":"2026-10-26","summary":null,"goals":[],"entries":[],"mentions":[],"cards":[
                {"id":2,"title":"今年读的书","show":"list","basis":"今年 · 带「《」的 · 说到的东西",
                 "items":[{"text":"《三体》","day":"2026-10-12","entryId":9}],"more":3,"empty":false},
                {"id":3,"title":"咖啡","show":"number","basis":"本月 · 多少杯","empty":true,"hint":"说到「咖啡」就会记在这里"}]}
                """#.utf8))
        #expect(day.cards?.map(\.title) == ["今年读的书", "咖啡"])
        #expect(day.cards?.first?.items?.first?.entryId == 9)
        #expect(day.cards?.last?.empty == true)
        let quotes = try JSONDecoder().decode(
            API.MyQuotes.self,
            from: Data(
                #"""
                {"quotes":[{"entryId":5,"text":"付出不亚于任何人的努力","day":"2026-10-20","noteId":7,"asked":true}]}
                """#.utf8))
        #expect(quotes.quotes.first?.asked == true)
    }
}
