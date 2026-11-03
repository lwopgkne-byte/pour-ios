import PourCore
import Testing

/// 中文和数字、英文挨着时留的空：和服务器 shared/src/format.ts 一样
@Suite("中文和数字之间的空")
struct WebTextTests {
    @Test func spacesBetweenHanAndLatin() {
        let gap = "\u{2006}"
        #expect(WebText.spaced("10月15日") == "10\(gap)月\(gap)15\(gap)日")
        #expect(WebText.spaced("跑步1小时") == "跑步\(gap)1\(gap)小时")
        #expect(WebText.spaced("用AI记") == "用\(gap)AI\(gap)记")
        // 已经有空格的不再加
        #expect(WebText.spaced("10 月") == "10 月")
        #expect(WebText.spaced("abc") == "abc")
        #expect(WebText.spaced("") == "")
    }
}
