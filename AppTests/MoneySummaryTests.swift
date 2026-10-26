import Testing

@testable import Pour

/// 钱卡上「花在哪几类」那一行（设计评审 2026-10-23：分段条没有图例、几类常是同一个颜色，改成写出来）
@Suite("钱卡：花在哪几类")
@MainActor
struct MoneySummaryTests {
    @Test func twoOrThreeKindsAllShown() {
        #expect(MoneySummary.breakdown([("购物", 69), ("饮食", 26)]) == "购物 ¥69 · 饮食 ¥26")
    }

    @Test func moreThanThreeKindsFoldIntoOther() {
        let parts: [(name: String, value: Double)] = [("购物", 69), ("饮食", 26), ("出行", 4), ("娱乐", 3)]
        #expect(MoneySummary.breakdown(parts) == "购物 ¥69 · 饮食 ¥26 · 其他 ¥7")
    }
}
