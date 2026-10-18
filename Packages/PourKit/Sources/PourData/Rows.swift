import Foundation
internal import GRDB
import PourCore

// 表和值类型之间的转换：表的样子只在这一层，别的层只认 PourCore 的值类型（docs/03 第 6 节）

struct NoteRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "note"
    var id: String
    var text: String
    var createdAt: Date
    var localTime: String
    var timeZone: String
    var day: String
    var status: String
    var problem: String?
    var reply: String?
    var attempts: Int
    var nextAttemptAt: Date?
    var finishedAt: Date?
    var actions: [NoteAction]
    var questions: [String]
    var awaitingDelete: [String]
    var undoneAt: Date?

    init(_ note: Note) {
        id = note.id
        text = note.text
        createdAt = note.createdAt
        localTime = note.localTime
        timeZone = note.timeZone
        day = note.day
        status = note.status.rawValue
        problem = note.problem
        reply = note.reply
        attempts = 0
        nextAttemptAt = nil
        finishedAt = note.finishedAt
        actions = note.actions
        questions = note.questions
        awaitingDelete = note.awaitingDelete
        undoneAt = note.undoneAt
    }

    var note: Note {
        Note(
            id: id, text: text, createdAt: createdAt, localTime: localTime, timeZone: timeZone, day: day,
            status: Note.Status(rawValue: status) ?? .queued, problem: problem, reply: reply, finishedAt: finishedAt,
            actions: actions, questions: questions, awaitingDelete: awaitingDelete, undoneAt: undoneAt)
    }
}

struct EntryRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "entry"
    var id: String
    var noteId: String
    var day: String
    var kind: String
    var category: String?
    var data: String
    var span: String
    var confidence: Double
    var question: String?
    var createdAt: Date
    var sortKey: String
    var deletedAt: Date?

    init(_ entry: Entry, said: LocalDateTime) throws {
        id = entry.id
        noteId = entry.noteId
        day = entry.day
        kind = entry.data.kind
        if case .event(let event) = entry.data { category = event.category } else { category = nil }
        data = String(bytes: try JSONEncoder.pour.encode(entry.data), encoding: .utf8) ?? "{}"
        span = entry.span
        confidence = entry.confidence
        question = entry.question
        createdAt = entry.createdAt
        sortKey = Self.sortKey(entry.data, said: said)
        deletedAt = nil
    }

    /// 时间轴里排在哪：开始、结束，都没有就是说这句话的时刻
    static func sortKey(_ data: RecordData, said: LocalDateTime) -> String {
        if case .event(let event) = data { return event.start ?? event.end ?? said }
        return said
    }

    /// 换成另一个样子（改、撤销时）：哪天、内容、把握、要不要问，排序跟着变
    mutating func set(_ state: EntryState, said: LocalDateTime) throws {
        day = state.day
        kind = state.data.kind
        if case .event(let event) = state.data { category = event.category } else { category = nil }
        data = String(bytes: try JSONEncoder.pour.encode(state.data), encoding: .utf8) ?? "{}"
        confidence = state.confidence
        question = state.question
        sortKey = Self.sortKey(state.data, said: said)
    }

    func entry() throws -> Entry {
        Entry(
            id: id, noteId: noteId, day: day, data: try JSONDecoder().decode(RecordData.self, from: Data(data.utf8)),
            span: span, confidence: confidence, question: question, createdAt: createdAt, deleted: deletedAt != nil)
    }
}

struct CategoryRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "category"
    var key: String
    var name: String
    var emoji: String
    var color: String
    var parent: String?
    var measure: String
    var synonyms: [String]
    var order: Int

    init(_ category: LifeCategory) {
        key = category.key
        name = category.name
        emoji = category.emoji
        color = category.color
        parent = category.parent
        measure = category.measure
        synonyms = category.synonyms
        order = category.order
    }

    var category: LifeCategory {
        LifeCategory(
            key: key, name: name, emoji: emoji, color: color, parent: parent, measure: measure, synonyms: synonyms,
            order: order)
    }
}

/// 一条记录的一次改动（改动历史、撤销照它来）
struct EntryVersionRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "entryVersion"
    var seq: Int64?
    var entryId: String
    var noteId: String?
    var action: String
    var span: String
    var before: String?
    var after: String?
    var changedAt: Date

    /// 表里的列名是 at（第 2 版迁移就是这么建的）
    enum CodingKeys: String, CodingKey {
        case seq, entryId, noteId, action, span, before, after
        case changedAt = "at"
    }

    init(
        _ entryId: String, _ action: NoteAction.Kind, noteId: String?, span: String, before: EntryState? = nil,
        after: EntryState? = nil, at changedAt: Date
    ) throws {
        self.entryId = entryId
        self.noteId = noteId
        self.action = action.rawValue
        self.span = span
        self.before = try before.map { String(bytes: try JSONEncoder.pour.encode($0), encoding: .utf8) ?? "{}" }
        self.after = try after.map { String(bytes: try JSONEncoder.pour.encode($0), encoding: .utf8) ?? "{}" }
        self.changedAt = changedAt
    }

    var beforeState: EntryState? { before.flatMap { try? JSONDecoder().decode(EntryState.self, from: Data($0.utf8)) } }
    var afterState: EntryState? { after.flatMap { try? JSONDecoder().decode(EntryState.self, from: Data($0.utf8)) } }

    var change: EntryChange {
        EntryChange(
            kind: NoteAction.Kind(rawValue: action) ?? .updated, noteId: noteId, changedAt: changedAt, span: span,
            before: beforeState, after: afterState)
    }
}

struct ChangePackageRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "changePackage"
    var noteId: String
    var appliedAt: Date
    var package: String
}

/// 预置类别：Resources/categories.json（网关的测试读同一份）
enum Seed {
    struct File: Decodable { let categories: [LifeCategory] }

    static func categories() throws -> [LifeCategory] {
        guard let url = Bundle.module.url(forResource: "categories", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(File.self, from: Data(contentsOf: url)).categories
    }
}

extension JSONEncoder {
    /// 存进数据库、发给网关的 JSON：键排好序，同样的内容每次一样
    static var pour: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}

/// 一天的一句话总结
struct SummaryRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "summary"
    var day: String
    var text: String
    var inputHash: String
    var createdAt: Date
}
