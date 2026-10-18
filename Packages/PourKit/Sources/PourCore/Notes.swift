public import Foundation

/// 原话：你说的一段话，原样保存。发出去 100 毫秒内就出现在「今天」，整理完凝结成记录（规范 12 第 1 节）
public struct Note: Hashable, Sendable, Identifiable {
    /// 整理到哪一步了
    public enum Status: String, Codable, Hashable, Sendable {
        /// 排着队、马上整理
        case queued
        /// 正在整理（等 AI）
        case organizing
        /// 连不上：联网后自动整理
        case waitingForNetwork
        /// 整理好了
        case done
        /// 没整理成：problem 说了发生了什么，可以再试一次
        case failed
    }

    public let id: String
    public var text: String
    /// 说这句话的时刻
    public var createdAt: Date
    /// 说这句话的地方墙上的钟点
    public var localTime: LocalDateTime
    public var timeZone: String
    /// 按日界线算的那一天
    public var day: DayString
    public var status: Status
    /// 没整理成：发生了什么 + 你能做什么（规范 10 第 5 节）
    public var problem: String?
    /// 整理时顺口回你的一句话（聊天的回应）
    public var reply: String?
    /// 整理好的时刻：收据「刚凝结」的高亮、撤销条从这里算
    public var finishedAt: Date?

    public init(
        id: String = UUID().uuidString, text: String, createdAt: Date, localTime: LocalDateTime, timeZone: String,
        day: DayString, status: Status = .queued, problem: String? = nil, reply: String? = nil,
        finishedAt: Date? = nil
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.localTime = localTime
        self.timeZone = timeZone
        self.day = day
        self.status = status
        self.problem = problem
        self.reply = reply
        self.finishedAt = finishedAt
    }
}

/// 一条记录：从原话整理出来的一件事
public struct Entry: Hashable, Sendable, Identifiable {
    public let id: String
    /// 来自哪段原话（点开看原话，对应的那一段荧光标出）
    public var noteId: String
    public var day: DayString
    public var data: RecordData
    /// 原话里对应的那一段
    public var span: String
    public var confidence: Double
    /// 拿不准时要问你的话：有它就是「待确认」
    public var question: String?
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString, noteId: String, day: DayString, data: RecordData, span: String = "",
        confidence: Double = 1, question: String? = nil, createdAt: Date
    ) {
        self.id = id
        self.noteId = noteId
        self.day = day
        self.data = data
        self.span = span
        self.confidence = confidence
        self.question = question
        self.createdAt = createdAt
    }

    public var needsConfirmation: Bool { question != nil }
}

/// 整理出来的一条新记录（网关改动包里的 creates，契约 v1 的 NewRecord）
public struct NewEntry: Codable, Hashable, Sendable {
    public var day: DayString
    public var data: RecordData
    public var span: String
    public var confidence: Double
    public var question: String?

    public init(day: DayString, data: RecordData, span: String = "", confidence: Double = 1, question: String? = nil) {
        self.day = day
        self.data = data
        self.span = span
        self.confidence = confidence
        self.question = question
    }
}
