import AppIntents
import Foundation
import PourAPI
import PourPlatform
import WidgetKit

/// 小组件上点一个表情就记下现在的心情（docs/3.0/01-需求文档.md 6.3、07 开发任务清单 4.6）：不用打开 App，
/// 直接发一句「心情挺好」给电脑上的 Pour（带上是在心情那里记的，整理时不编那一刻、不编情绪词）；
/// 连不上先存在手机上，Pour 打开时再发。记下的那一档和时刻写进 App 组，小组件上写「刚记下：挺好 21:30」
struct MoodCheckinIntent: AppIntent {
    static let title: LocalizedStringResource = "记心情"
    static let isDiscoverable = false

    @Parameter(title: "哪一档（1 很差 … 5 很好）")
    var level: Int

    init() {}

    init(level: Int) {
        self.level = level
    }

    func perform() async throws -> some IntentResult {
        let level = min(5, max(1, level))
        let text = "心情\(Show.moodWords[level - 1])"
        do {
            try await SharedClient.make().send(text, clientId: UUID().uuidString, context: "mood")
        } catch {
            SharedStore.addPendingShare(text)
        }
        MoodCheckinMark.save(level: level)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// 小组件上刚记下的那一档（App 组里）：今天记过的才写
enum MoodCheckinMark {
    static let key = "mood.checkin.last"

    static func save(level: Int, at date: Date = Date()) {
        SharedStore.defaults?.set(["level": level, "at": date.timeIntervalSince1970], forKey: key)
    }

    /// 今天刚记下的：「挺好 21:30」；今天没记是 nil
    static func today(now: Date = Date()) -> String? {
        guard let mark = SharedStore.defaults?.dictionary(forKey: key), let level = mark["level"] as? Int,
            let at = (mark["at"] as? Double).map(Date.init(timeIntervalSince1970:)),
            Calendar.current.isDate(at, inSameDayAs: now)
        else { return nil }
        let clock = at.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        return "\(Show.moodWords[min(5, max(1, level)) - 1]) \(clock)"
    }
}
