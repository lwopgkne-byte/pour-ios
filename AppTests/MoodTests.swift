import Foundation
import PourPlatform
import Testing

@testable import Pour

/// 3.0 心情（docs/3.0/01-需求文档.md 6.3–6.4）：记心情生成的原话（情绪词只写你点的，只点一档就只写「心情挺好」）；
/// 晚上那一问问什么（今天没说过话、说过话没说心情、说过心情不问）
@Suite("3.0 心情：原话、晚上问一句")
struct MoodTests {
    @Test func saidText() {
        #expect(MoodText.said(level: 4, emotions: [], because: "") == "心情挺好")
        #expect(MoodText.said(level: 2, emotions: ["烦躁"], because: "方案又改了") == "心情不太好，烦躁，因为方案又改了")
        #expect(MoodText.said(level: 5, emotions: ["开心", "放松"], because: "  ") == "心情很好，开心，放松")
        #expect(MoodText.said(level: 9, emotions: [], because: "") == "心情很好")
    }

    @Test func eveningQuestions() {
        let quiet = MoodEvening.evenings(today: "2026-11-01", talked: false, moodSaid: false)
        #expect(quiet.count == MoodEvening.days)
        #expect(quiet.first == EveningMood.Evening(day: "2026-11-01", title: "今天过得怎么样？"))
        #expect(quiet.last?.day == "2026-11-07")
        let talked = MoodEvening.evenings(today: "2026-11-01", talked: true, moodSaid: false)
        #expect(talked.first?.title == "今天心情怎么样？")
        #expect(talked.dropFirst().allSatisfy { $0.title == "今天过得怎么样？" })
        // 今天说过心情了：今天不问，明天照问
        let said = MoodEvening.evenings(today: "2026-11-01", talked: true, moodSaid: true)
        #expect(said.first?.day == "2026-11-02" && said.count == MoodEvening.days - 1)
    }
}
