import Foundation

/// 一条记录在时间轴、收据里的那一行（规范 10：收据「事实，一行一件」「跑步 5 公里 · 32 分钟」）。
/// 界面只管摆：字怎么写、数怎么写都在这里定，时间轴和收据同一种写法
public struct RecordLine: Hashable, Sendable {
    /// 「跑步 5 公里」「吃面」「交房租」
    public var title: String
    /// 右侧的数：钱「¥32」，没有钱时是时长「32 分钟」
    public var value: String?
    /// 认出的人（青色）：「小王」
    public var person: String?
    /// 时间轴左边的时刻「07:10」；说不出几点的没有
    public var time: String?
    /// 领域色（stone、moss……）
    public var color: String
    /// 心情的级别（心情那一行画心情格子）
    public var moodLevel: Int?
    /// 心情的感受、待办的期限这类小字
    public var detail: String?
    /// 时间轴里排在哪：开始、结束，都没有就用说这句话的时刻
    public var sortKey: LocalDateTime

    public init(_ data: RecordData, categories: [LifeCategory], said: LocalDateTime, today: DayString) {
        sortKey = said
        moodLevel = nil
        detail = nil
        person = nil
        value = nil
        time = nil
        switch data {
        case .event(let event):
            let money = event.metrics.filter(\.isMoney)
            let others = event.metrics.filter { !$0.isMoney }
            // 不是钱的数有两个以上时写上名字（「卧推 80 公斤、组数 5 组」），只有一个时不啰嗦（「5 公里」）
            let named = others.count > 1
            let amounts = others.map { named ? "\($0.name) \($0.display)" : $0.display }
            let duration = event.durationMin.map { PourFormat.duration(minutes: $0) }
            var parts = [event.label] + amounts
            if !money.isEmpty, let duration { parts.append(duration) }
            title = parts.joined(separator: " ")
            value = money.isEmpty ? duration : money.map(\.display).joined(separator: " ")
            let people = event.people.filter { !event.label.contains($0) }
            person = people.isEmpty ? nil : people.joined(separator: "、")
            time = (event.start ?? event.end).map(PourFormat.clock)
            sortKey = event.start ?? event.end ?? said
            color = categories.color(of: event.category)
        case .mood(let mood):
            title = PourFormat.moodWord(mood.level)
            moodLevel = mood.level
            let feelings = mood.emotions + (mood.energy.map { [PourFormat.energyWord($0)] } ?? [])
            detail = feelings.isEmpty ? nil : feelings.joined(separator: " · ")
            color = "stone"
        case .todo(let todo):
            title = todo.content
            detail = todo.due.map { "\(PourFormat.dayTitle($0, today: today))前" }
            let people = todo.people.filter { !todo.content.contains($0) }
            person = people.isEmpty ? nil : people.joined(separator: "、")
            color = "stone"
        case .insight(let insight):
            title = insight.title
            detail = insight.quote
            color = "stone"
        }
    }
}
