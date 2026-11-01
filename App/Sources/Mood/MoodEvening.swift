import Foundation
import PourAPI
import PourCore
import PourPlatform

/// 晚上问一句心情（docs/3.0/01-需求文档.md 6.4、07 开发任务清单 4.7）：设置 → 提醒和推送里打开（默认关），只记在这台手机上。
/// 每天晚上（默认 21:30）问一句，和「晚上的倾倒提醒」合成一种：今天没说过话问「今天过得怎么样？」，说过话、没说心情问
/// 「今天心情怎么样？」，都说过了不问。按住通知直接选一档或者说两句，不用打开 App
enum MoodEvening {
    static let key = "pour.mood.evening"
    static let timeKey = "pour.mood.evening.time"
    /// 打开这一项时电脑上的倾倒提醒是开着的（关这一项时再打开它）
    static let mergedKey = "pour.mood.evening.merged"
    static let defaultTime = "21:30"
    /// 排几个晚上（今天和以后几天；每次打开、记录变了都重排）
    static let days = 7

    static var asking: Bool { UserDefaults.standard.bool(forKey: key) }
    static var time: String { UserDefaults.standard.string(forKey: timeKey) ?? defaultTime }

    /// 这几个晚上问什么：今天按说过什么定；以后的先写「今天过得怎么样？」（那天说了话再重排）
    static func evenings(today: String, talked: Bool, moodSaid: Bool) -> [EveningMood.Evening] {
        (0..<days).compactMap { offset in
            let day = PourDate.addDays(today, offset)
            if offset == 0 {
                if moodSaid { return nil }
                return .init(day: day, title: talked ? "今天心情怎么样？" : "今天过得怎么样？")
            }
            return .init(day: day, title: "今天过得怎么样？")
        }
    }

    /// 通知上选了什么：App 开着交给 AppModel（今天里马上多一刻）；没开着直接发到电脑上的 Pour，连不上先存在手机上
    static func handle(_ answer: EveningMood.Answer) async {
        let text: String
        switch answer {
        case .level(let level): text = MoodText.said(level: level, emotions: [], because: "")
        case .said(let said): text = said
        case .open:
            await MainActor.run { QuickActions.shared.pendingPath = "/mood" }
            return
        }
        if let model = await TodoNotifications.model {
            await MainActor.run {
                let now = PourDate.localDateTime(Date(), in: .current)
                let level = (1...5).first { text == MoodText.said(level: $0, emotions: [], because: "") } ?? 3
                model.record(
                    mood: text,
                    pending: PendingMood(
                        clientId: UUID().uuidString, level: level, emotions: [], because: nil, day: model.today,
                        time: String(now.suffix(5))))
            }
            return
        }
        let client = ServerConfiguration.client(arguments: ProcessInfo.processInfo.arguments)
        do throws(APIError) {
            try await client.send(text, clientId: UUID().uuidString, context: "mood")
        } catch {
            SharedStore.addPendingShare(text)
        }
    }
}

extension AppModel {
    /// 照今天说过什么重排晚上那一问（开着这一项才排；关了撤掉）
    func syncEveningMood() async {
        guard MoodEvening.asking else {
            await EveningMood.clear()
            return
        }
        let today = self.today
        let talked = chat.contains { $0.day == today } || !mood.pending.isEmpty
        let moodSaid =
            mood.pending.contains { $0.day == today }
            || (shownDay == today && day?.entries.contains { $0.kind == "mood" } == true)
        await EveningMood.sync(
            MoodEvening.evenings(today: today, talked: talked, moodSaid: moodSaid), time: MoodEvening.time)
    }
}
