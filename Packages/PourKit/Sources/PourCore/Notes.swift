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
    /// 那句话是程序写的（「这句话刚才已经说过了」）：不标「AI」
    public var replyByProgram: Bool
    /// 整理好的时刻：收据「刚凝结」的高亮、撤销条从这里算
    public var finishedAt: Date?
    /// 这段话做了什么（收据一行一件）：记下、改了、删了、之前已记过……
    public var actions: [NoteAction]
    /// 问你的话（拿不准删哪条时先问）
    public var questions: [String]
    /// 问了要不要删、在等你回答的那几条：下一句说「对」就删它们
    public var awaitingDelete: [String]
    /// 撤销了：这段话整理出的改动都退回去了，原话还在
    public var undoneAt: Date?

    public init(
        id: String = UUID().uuidString, text: String, createdAt: Date, localTime: LocalDateTime, timeZone: String,
        day: DayString, status: Status = .queued, problem: String? = nil, reply: String? = nil,
        replyByProgram: Bool = false, finishedAt: Date? = nil, actions: [NoteAction] = [], questions: [String] = [],
        awaitingDelete: [String] = [],
        undoneAt: Date? = nil
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
        self.replyByProgram = replyByProgram
        self.finishedAt = finishedAt
        self.actions = actions
        self.questions = questions
        self.awaitingDelete = awaitingDelete
        self.undoneAt = undoneAt
    }
}

/// 一段话对一条记录做了什么（收据的一行、对话里说给 AI 听的一句）
public struct NoteAction: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Hashable, Sendable {
        case created, updated, duplicate, completed, confirmed, deleted

        /// 收据里的说法（记下的不用说）
        public var word: String {
            switch self {
            case .created: "记下"
            case .updated: "修改"
            case .duplicate: "之前已记过"
            case .completed: "完成"
            case .confirmed: "确认"
            case .deleted: "删掉"
            }
        }
    }

    public var kind: Kind
    public var entryId: String

    public init(_ kind: Kind, entryId: String) {
        self.kind = kind
        self.entryId = entryId
    }
}

/// 一条记录在某一刻的样子（改动历史、撤销用）
public struct EntryState: Codable, Hashable, Sendable {
    public var day: DayString
    public var data: RecordData
    public var confidence: Double
    public var question: String?

    public init(day: DayString, data: RecordData, confidence: Double, question: String? = nil) {
        self.day = day
        self.data = data
        self.confidence = confidence
        self.question = question
    }
}

/// 一条记录的一次改动：哪段话改的（详情里自己改的没有）、改之前和改之后
public struct EntryChange: Hashable, Sendable {
    public var kind: NoteAction.Kind
    public var noteId: String?
    public var changedAt: Date
    public var span: String
    public var before: EntryState?
    public var after: EntryState?

    public init(
        kind: NoteAction.Kind, noteId: String?, changedAt: Date, span: String = "", before: EntryState? = nil,
        after: EntryState? = nil
    ) {
        self.kind = kind
        self.noteId = noteId
        self.changedAt = changedAt
        self.span = span
        self.before = before
        self.after = after
    }
}

/// 整理好的一段话要写进数据库的全部改动（网关的改动包，契约 v2）
public struct NoteChanges: Hashable, Sendable {
    /// 改了的一条：改完的样子
    public struct Updated: Codable, Hashable, Sendable {
        public var id: String
        public var action: NoteAction.Kind
        public var day: DayString
        public var data: RecordData
        public var span: String
        public var confidence: Double
        public var question: String?

        public init(
            id: String, action: NoteAction.Kind, day: DayString, data: RecordData, span: String = "",
            confidence: Double = 1, question: String? = nil
        ) {
            self.id = id
            self.action = action
            self.day = day
            self.data = data
            self.span = span
            self.confidence = confidence
            self.question = question
        }
    }

    /// 删掉的、之前已记过的：哪条、原话里哪一段
    public struct Mention: Codable, Hashable, Sendable {
        public var id: String
        public var span: String

        public init(id: String, span: String = "") {
            self.id = id
            self.span = span
        }
    }

    public var creates: [NewEntry]
    public var updates: [Updated]
    public var deletes: [Mention]
    public var duplicates: [Mention]
    public var questions: [String]
    /// 问了要不要删的那几条（下一句回答「对」时照着删）
    public var awaitingDelete: [String]
    public var reply: String
    /// 那句话是程序写的：不标「AI」
    public var replyByProgram: Bool
    /// 这段话新建的类别（生活领域、新活动）：先建类别、再写记录
    public var newCategories: [LifeCategory]

    public init(
        creates: [NewEntry] = [], updates: [Updated] = [], deletes: [Mention] = [], duplicates: [Mention] = [],
        questions: [String] = [], awaitingDelete: [String] = [], reply: String = "", replyByProgram: Bool = false,
        newCategories: [LifeCategory] = []
    ) {
        self.creates = creates
        self.updates = updates
        self.deletes = deletes
        self.duplicates = duplicates
        self.questions = questions
        self.awaitingDelete = awaitingDelete
        self.reply = reply
        self.replyByProgram = replyByProgram
        self.newCategories = newCategories
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
    /// 删掉了（留着能撤销；时间轴上不再出现）
    public var deleted: Bool

    public init(
        id: String = UUID().uuidString, noteId: String, day: DayString, data: RecordData, span: String = "",
        confidence: Double = 1, question: String? = nil, createdAt: Date, deleted: Bool = false
    ) {
        self.id = id
        self.noteId = noteId
        self.day = day
        self.data = data
        self.span = span
        self.confidence = confidence
        self.question = question
        self.createdAt = createdAt
        self.deleted = deleted
    }

    public var needsConfirmation: Bool { question != nil }

    /// 现在的样子（改动历史、撤销用）
    public var state: EntryState { EntryState(day: day, data: data, confidence: confidence, question: question) }
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
