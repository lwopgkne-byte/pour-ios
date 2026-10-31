import PourDesign
import Testing

/// 记一笔的数字键盘：按下去以后金额怎么变（06 交互细节 3.4）
@Suite("数字键盘")
struct KeypadTests {
    private func type(_ keys: [NumberKeypad.Key]) -> String {
        keys.reduce("") { KeypadAmount.apply($1, to: $0) }
    }

    @Test func typing() {
        #expect(type([.digit(2), .digit(5)]) == "25")
        #expect(type([.digit(1), .digit(2), .dot, .digit(5)]) == "12.5")
        #expect(type([.dot, .digit(5)]) == "0.5")
        // 只能有一个点、最多两位小数
        #expect(type([.digit(3), .dot, .dot, .digit(1), .digit(2), .digit(9)]) == "3.12")
        // 开头的 0 不重复；整数最多 7 位
        #expect(type([.digit(0), .digit(0), .digit(8)]) == "8")
        #expect(type(Array(repeating: .digit(9), count: 9)) == "9999999")
        // 删掉一位
        #expect(type([.digit(2), .digit(5), .delete]) == "2")
        #expect(type([.delete]) == "")
    }
}
