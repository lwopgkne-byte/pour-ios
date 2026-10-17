import PourCore
import Testing

@Suite("jsRound：和 JavaScript 的 Math.round 一致")
struct JSRoundTests {
    // 右边的值都是在 Node 里实际跑 Math.round 得到的
    @Test(
        arguments: [
            (2.5, 3.0), (-2.5, -2.0), (1.5, 2.0), (-1.5, -1.0),
            (0.4, 0.0), (0.5, 1.0), (2.4999, 2.0), (-2.5001, -3.0),
            (0.49999999999999994, 0.0), (4503599627370495.5, 4503599627370496.0),
            (1e300, 1e300), (-7.0, -7.0),
        ])
    func matchesJavaScript(input: Double, expected: Double) {
        #expect(jsRound(input) == expected)
    }

    @Test func negativeHalfGivesNegativeZero() {
        // Math.round(-0.5) 和 Math.round(-0.4) 都是 -0
        #expect(jsRound(-0.5).sign == .minus)
        #expect(jsRound(-0.4).sign == .minus)
        #expect(jsRound(-0.5) == 0)
    }

    @Test func nonFiniteValuesPassThrough() {
        #expect(jsRound(.infinity) == .infinity)
        #expect(jsRound(-.infinity) == -.infinity)
        #expect(jsRound(.nan).isNaN)
    }
}
