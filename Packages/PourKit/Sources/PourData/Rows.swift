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
    }

    var note: Note {
        Note(
            id: id, text: text, createdAt: createdAt, localTime: localTime, timeZone: timeZone, day: day,
            status: Note.Status(rawValue: status) ?? .queued, problem: problem, reply: reply, finishedAt: finishedAt)
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
        if case .event(let event) = entry.data { sortKey = event.start ?? event.end ?? said } else { sortKey = said }
    }

    func entry() throws -> Entry {
        Entry(
            id: id, noteId: noteId, day: day, data: try JSONDecoder().decode(RecordData.self, from: Data(data.utf8)),
            span: span, confidence: confidence, question: question, createdAt: createdAt)
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
