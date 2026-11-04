import Foundation
import PourAPI
import PourDesign
import Testing

@testable import Pour

/// 说一句里的收据一条一张（照原型）：服务器写好的一行字（describeEntry）拆成粗体的那件事和下面的灰字，
/// 再按种类挑小方块的颜色
@Suite("说一句：收据拆成粗体和灰字")
@MainActor
struct ChatReceiptTests {
    private let categories: [API.Category] = Self.decode(
        """
        [{"key": "food", "name": "饮食", "emoji": "🍽", "color": "#C27E12", "measure": "money"},
         {"key": "sport", "name": "运动", "emoji": "🏃", "color": "#2F6FD6", "measure": "duration"}]
        """)

    @Test func eventWithPlaceAndPeople() {
        let item = Self.item("created", "event", "🍽 食堂午饭 ¥15 · 在公司食堂 · 和小王")
        let parts = ReceiptRow.parts(item, categories: categories)
        #expect(parts.title == "食堂午饭 ¥15")
        #expect(parts.sub == "饮食 · 在公司食堂 · 和小王")
        #expect(ReceiptRow.color(item) == Theme.Palette.kindMoney)
    }

    @Test func kindNameAndBrackets() {
        let mood = ReceiptRow.parts(Self.item("created", "mood", "💭 心情：挺好 · 开心（AI 推测）"), categories: categories)
        #expect(mood.title == "挺好")
        #expect(mood.sub == "心情 · 开心（AI 推测）")
        let todo = ReceiptRow.parts(
            Self.item("created", "todo", "📋 待办：给客户回电话（⏰ 10:00 提醒）"), categories: categories)
        #expect(todo.title == "给客户回电话")
        #expect(todo.sub == "待办 · ⏰ 10:00 提醒")
    }

    @Test func actionsAndPending() {
        let deleted = ReceiptRow.parts(Self.item("deleted", "event", "删除 🏃 跑步 30 分钟"), categories: categories)
        #expect(deleted.title == "跑步 30 分钟")
        #expect(deleted.sub == "已删除 · 运动")
        let done = ReceiptRow.parts(Self.item("completed", "todo", "✅ 完成：看电影"), categories: categories)
        #expect(done.title == "看电影")
        #expect(done.sub == "已完成")
        let pending = ReceiptRow.parts(Self.item("created", "event", "🍽 吃面 ¥32", pending: true), categories: categories)
        #expect(pending.sub == "饮食 · 待确认")
    }

    @Test func emojiOnlyAtTheStart() {
        #expect(ReceiptRow.isEmoji("🍽"))
        #expect(ReceiptRow.isEmoji("🍽️"))
        #expect(!ReceiptRow.isEmoji("1"))
        #expect(!ReceiptRow.isEmoji("#"))
        let plain = ReceiptRow.parts(Self.item("created", "event", "10 点开会"), categories: categories)
        #expect(plain.title == "10 点开会")
        #expect(plain.sub.isEmpty)
    }

    private static func item(_ action: String, _ kind: String, _ text: String, pending: Bool = false) -> API.ReceiptItem
    {
        decode(
            """
            {"action": "\(action)", "kind": "\(kind)", "entryId": 1, "text": "\(text)", "pending": \(pending)}
            """)
    }

    private static func decode<T: Decodable>(_ json: String) -> T {
        // swiftlint:disable:next force_try
        try! JSONDecoder().decode(T.self, from: Data(json.utf8))
    }
}
