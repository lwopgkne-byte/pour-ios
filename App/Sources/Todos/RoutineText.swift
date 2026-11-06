import PourAPI
import PourCore
import PourDesign

/// 作息写成字（时间线上那一行、作息弹框）
enum RoutineText {
    static let everyDay = [0, 1, 2, 3, 4, 5, 6]
    static let workdays = [0, 1, 2, 3, 4]
    static let weekend = [5, 6]
    private static let names = ["一", "二", "三", "四", "五", "六", "日"]

    /// 「睡觉 23:30–07:00 · 上班 09:30–18:30」；没设过：「还没设，睡觉先按 23:30–07:00 算」
    static func summary(_ routine: API.Routine) -> String {
        let parts = routine.blocks.map { "\($0.title) \($0.from)–\($0.to)" }
        guard routine.custom else {
            let sleep = routine.blocks.first { $0.sort == .sleep }.map { "，睡觉先按 \($0.from)–\($0.to) 算" } ?? ""
            return "还没设\(sleep)"
        }
        return parts.isEmpty ? "没有" : parts.joined(separator: " · ")
    }

    /// 「每天」「工作日」「周末」「周一、三、五」
    static func days(_ days: [Int]) -> String {
        let sorted = Array(Set(days)).sorted()
        if sorted == everyDay { return "每天" }
        if sorted == workdays { return "工作日" }
        if sorted == weekend { return "周末" }
        return "周" + sorted.map { names[$0] }.joined(separator: "、")
    }

    /// 一周七天的按钮上写的
    static func dayName(_ day: Int) -> String { names[day] }

    static func kind(_ kind: API.RoutineBlock.Kind) -> RoutineBand.Kind {
        switch kind {
        case .sleep: .sleep
        case .work: .work
        case .busy: .busy
        }
    }

    /// 加一段时点的常见的（作息弹框下面那一排）：名字、种类、几点到几点、哪几天
    static let presets: [API.RoutineBlock] = [
        API.RoutineBlock(title: "睡觉", kind: .sleep, from: "23:30", to: "07:00", days: everyDay),
        API.RoutineBlock(title: "上班", kind: .work, from: "09:00", to: "18:00", days: workdays),
        API.RoutineBlock(title: "上学", kind: .work, from: "08:00", to: "17:00", days: workdays),
        API.RoutineBlock(title: "午休", kind: .busy, from: "12:30", to: "13:30", days: workdays),
        API.RoutineBlock(title: "午饭", kind: .busy, from: "12:00", to: "13:00", days: everyDay),
        API.RoutineBlock(title: "通勤", kind: .busy, from: "08:00", to: "09:00", days: workdays),
        API.RoutineBlock(title: "健身", kind: .busy, from: "19:00", to: "20:00", days: [0, 2, 4]),
    ]
}
