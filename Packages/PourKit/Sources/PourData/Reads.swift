public import Foundation
internal import GRDB
public import PourCore

// 读：一天的样子（「今天」页一直观察着它）、给 AI 看的已有记录和最近的对话、一条记录的改动历史

/// 一天的样子：这一天说的话、整理出的记录、类别表
public struct DaySnapshot: Hashable, Sendable {
    public var day: DayString
    /// 这一天说的话，先说的在前
    public var notes: [Note]
    /// 这一天的记录（删掉的不算），按时间轴排
    public var entries: [Entry]
    /// 这一天说的话动到的每一条记录（收据要列出来）：记在别的日子的也在，删掉的是删之前的样子
    public var mentioned: [String: Entry]
    public var categories: [LifeCategory]
    /// 一句话总结（AI 写的，还没有就是 nil）
    public var summary: String?

    public init(
        day: DayString, notes: [Note] = [], entries: [Entry] = [], mentioned: [String: Entry] = [:],
        categories: [LifeCategory] = [], summary: String? = nil
    ) {
        self.day = day
        self.notes = notes
        self.entries = entries
        self.mentioned = mentioned
        self.categories = categories
        self.summary = summary
    }
}

extension PourStore {
    public func categories() throws -> [LifeCategory] {
        try writer.read { db in try Self.categories(db) }
    }

    public func snapshot(of day: DayString) throws -> DaySnapshot {
        try writer.read { db in try Self.snapshot(db, day: day) }
    }

    public func note(_ id: String) throws -> Note? {
        try writer.read { db in try NoteRow.fetchOne(db, key: id)?.note }
    }

    /// 一条记录（删掉的也拿得到：详情里看它是怎么没的）
    public func entry(_ id: String) throws -> Entry? {
        try writer.read { db in try EntryRow.fetchOne(db, key: id)?.entry() }
    }

    /// 一条记录的改动历史：先发生的在前
    public func history(of entryId: String) throws -> [EntryChange] {
        try writer.read { db in
            try EntryVersionRow.filter(Column("entryId") == entryId).order(Column("seq")).fetchAll(db).map(\.change)
        }
    }

    /// 整理一段话要给 AI 看的已有记录（照网页版 contextEntries）：这一天和前后一天的全部记录，
    /// 加上最近 30 条还没做完的待办（不管哪天的；删掉的不算）。
    /// 前后一天的也要：「昨天下馆子花了 216」再说一遍时认得出是同一件事，「昨天跑的是 8 公里」改得到昨天那条
    public func existingEntries(around day: DayString, openTodos limit: Int = 30) throws -> [Entry] {
        try writer.read { db in
            let alive = EntryRow.filter(Column("deletedAt") == nil)
            let near = try alive.filter(Column("day") >= PourDate.addDays(day, -1))
                .filter(Column("day") <= PourDate.addDays(day, 1))
                .order(Column("day"), Column("sortKey"), Column("createdAt"))
                .fetchAll(db)
            let nearIds = Set(near.map(\.id))
            let todos = try alive.filter(Column("kind") == "todo")
                .filter(sql: "json_extract(data, '$.done') = 0")
                .order(Column("createdAt").desc).limit(limit)
                .fetchAll(db)
                .filter { !nearIds.contains($0.id) }
                .sorted { ($0.day, $0.createdAt) < ($1.day, $1.createdAt) }
            return try (near + todos).map { try $0.entry() }
        }
    }

    /// 这段话之前的几段对话（一小时以内、最多 4 段，从早到晚）和它们动到的记录：AI 看得到刚才说了什么
    public func recentTurns(before note: Note, within window: TimeInterval = 3600, limit: Int = 4) throws
        -> (notes: [Note], mentioned: [String: Entry])
    {
        try writer.read { db in
            let notes = try NoteRow.filter(Column("createdAt") < note.createdAt)
                .filter(Column("createdAt") >= note.createdAt.addingTimeInterval(-window))
                .order(Column("createdAt").desc).limit(limit)
                .fetchAll(db).map(\.note).reversed()
            return (Array(notes), try Self.mentioned(db, by: Array(notes)))
        }
    }

    /// 一天的一句话总结和它的指纹（记录没变就不再问 AI）
    public func summary(of day: DayString) throws -> (text: String, inputHash: String)? {
        try writer.read { db in try SummaryRow.fetchOne(db, key: day).map { ($0.text, $0.inputHash) } }
    }

    public func saveSummary(_ text: String, of day: DayString, inputHash: String, at date: Date = Date()) throws {
        try writer.write { db in
            try SummaryRow(day: day, text: text, inputHash: inputHash, createdAt: date).upsert(db)
        }
    }

    /// 这一天没有可说的了（记录都删了）：总结也去掉
    public func removeSummary(of day: DayString) throws {
        try writer.write { db in _ = try SummaryRow.deleteOne(db, key: day) }
    }

    /// 一直看着某一天：数据一变就给新的样子（界面直接观察查询，ADR A05）
    public func observe(day: DayString) -> AsyncThrowingStream<DaySnapshot, any Error> {
        let observation = ValueObservation.tracking { db in try Self.snapshot(db, day: day) }.removeDuplicates()
        let writer = self.writer
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await snapshot in observation.values(in: writer) { continuation.yield(snapshot) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func categories(_ db: Database) throws -> [LifeCategory] {
        try CategoryRow.order(Column("order")).fetchAll(db).map(\.category)
    }

    static func snapshot(_ db: Database, day: DayString) throws -> DaySnapshot {
        let notes = try NoteRow.filter(Column("day") == day).order(Column("createdAt")).fetchAll(db).map(\.note)
        let entries = try EntryRow.filter(Column("day") == day && Column("deletedAt") == nil)
            .order(Column("sortKey"), Column("createdAt"))
            .fetchAll(db).map { try $0.entry() }
        return DaySnapshot(
            day: day, notes: notes, entries: entries, mentioned: try mentioned(db, by: notes),
            categories: try categories(db), summary: try SummaryRow.fetchOne(db, key: day)?.text)
    }

    /// 几段话动到的记录：现在的样子；删掉的是删之前的样子
    static func mentioned(_ db: Database, by notes: [Note]) throws -> [String: Entry] {
        let ids = Set(notes.flatMap { $0.actions.map(\.entryId) })
        guard !ids.isEmpty else { return [:] }
        var found: [String: Entry] = [:]
        for row in try EntryRow.filter(ids.contains(Column("id"))).fetchAll(db) {
            var entry = try row.entry()
            if row.deletedAt != nil,
                let before = try EntryVersionRow.filter(Column("entryId") == row.id && Column("action") == "deleted")
                    .order(Column("seq").desc).fetchOne(db)?.beforeState
            {
                entry.day = before.day
                entry.data = before.data
            }
            found[entry.id] = entry
        }
        return found
    }
}
