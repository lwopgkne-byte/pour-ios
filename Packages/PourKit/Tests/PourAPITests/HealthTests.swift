import Foundation
import PourAPI
import Testing

/// 健康 App 的步数、睡眠、锻炼（docs/模块/产品优化.md R5）：服务器给的照着解码；有步数时画布上一定有运动卡
@Suite("健康")
struct HealthTests {
    @Test func decodesTheDay() throws {
        let day = try JSONDecoder().decode(
            API.DayView.self,
            from: Data(
                #"""
                {"day":"2026-10-26","summary":null,"goals":[],"health":{"steps":8234},"entries":[
                {"id":-12345,"day":"2026-10-26","kind":"event","category":"run","confidence":1,"status":"ok",
                 "sources":[],"origin":"health",
                 "data":{"label":"跑步","start":"2026-10-26T07:02","end":"2026-10-26T07:35","durationMin":33,
                 "metrics":[{"name":"距离","value":5.1,"unit":"公里"}]}},
                {"id":7,"day":"2026-10-26","kind":"event","category":"sleep","confidence":1,"status":"ok","sources":[],
                 "fromHealth":["时间","时长"],"data":{"label":"睡觉","start":"2026-10-25T23:41","end":"2026-10-26T07:05"}}]}
                """#.utf8))
        #expect(day.health?.steps == 8234)
        #expect(day.entries[0].fromHealthApp)
        #expect(!day.entries[1].fromHealthApp)
        #expect(day.entries[1].fromHealth == ["时间", "时长"])
        let old = try JSONDecoder().decode(
            API.DayView.self, from: Data(#"{"day":"2026-10-26","summary":null,"goals":[],"entries":[]}"#.utf8))
        #expect(old.health == nil)
    }

    @Test func stepsAloneStillMakeAnExerciseCard() {
        let cards = CanvasPlan.cards([], [], steps: 8234)
        #expect(cards.map(\.id) == [CanvasPlan.exerciseKey])
        #expect(cards.first?.entries.isEmpty == true)
        #expect(CanvasPlan.cards([], []).isEmpty)
    }

    @Test func uploadEncodesWhatTheServerReads() throws {
        let upload = API.HealthUpload(
            from: "2026-10-19T00:00:00Z", to: "2026-10-26T13:00:00Z",
            steps: [.init(start: "2026-10-26T00:00:00Z", count: 3000)],
            sleep: [.init(start: "2026-10-25T15:41:00Z", end: "2026-10-25T23:05:00Z", stage: "asleep")],
            workouts: [
                .init(
                    id: "w", activity: "running", start: "2026-10-25T23:02:00Z", end: "2026-10-25T23:35:00Z",
                    durationMin: 33, kilometers: nil)
            ])
        let json = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(upload)) as? [String: Any])
        #expect(Set(json.keys) == ["from", "to", "steps", "sleep", "workouts"])
        let workout = try #require((json["workouts"] as? [[String: Any]])?.first)
        #expect(workout["durationMin"] as? Double == 33)
        #expect(workout["km"] == nil)
        #expect(API.HealthUpload.stamp(Date(timeIntervalSince1970: 0)) == "1970-01-01T00:00:00Z")
    }
}
