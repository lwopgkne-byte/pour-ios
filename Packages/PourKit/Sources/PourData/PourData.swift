public import Foundation
internal import GRDB
public import PourCore

/// 数据层：表结构、迁移、仓储（读写接口），以及 PourCore 值类型和表之间的转换（docs/03 第 4、6 节）。
/// 本机数据库是真正的数据库（ADR A05：SQLite + GRDB）；网关不存任何东西。同步（iCloud）以后再加
public final class PourStore: Sendable {
    let writer: any DatabaseWriter

    /// App 的数据库：Application Support/Pour/pour.sqlite
    public static func openDefault() throws -> PourStore {
        let folder = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Pour", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return try PourStore(path: folder.appendingPathComponent("pour.sqlite").path)
    }

    /// 测试、预览用：只在内存里
    public static func inMemory() throws -> PourStore { try PourStore(writer: DatabaseQueue()) }

    public convenience init(path: String) throws {
        var config = Configuration()
        config.foreignKeysEnabled = true
        try self.init(writer: DatabasePool(path: path, configuration: config))
    }

    init(writer: any DatabaseWriter) throws {
        self.writer = writer
        try Self.migrator.migrate(writer)
    }

    // MARK: - 迁移（只往后加，不改已经发出去的）

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1 原话、记录、类别、改动包") { db in
            try db.create(table: "note") { table in
                table.primaryKey("id", .text)
                table.column("text", .text).notNull()
                table.column("createdAt", .datetime).notNull()
                table.column("localTime", .text).notNull()
                table.column("timeZone", .text).notNull()
                table.column("day", .text).notNull().indexed()
                table.column("status", .text).notNull()
                table.column("problem", .text)
                table.column("reply", .text)
                table.column("attempts", .integer).notNull().defaults(to: 0)
                table.column("nextAttemptAt", .datetime)
                table.column("finishedAt", .datetime)
            }
            try db.create(table: "category") { table in
                table.primaryKey("key", .text)
                table.column("name", .text).notNull()
                table.column("emoji", .text).notNull()
                table.column("color", .text).notNull()
                table.column("parent", .text).references("category")
                table.column("measure", .text).notNull()
                table.column("synonyms", .jsonText).notNull()
                table.column("order", .integer).notNull()
                // 六个基础类别是所有统计的骨架，不许挂到别的类别下面（网页版第 18 版迁移的教训）
                table.check(sql: "key NOT IN ('sleep','exercise','diet','study','work','other') OR parent IS NULL")
            }
            try db.create(table: "entry") { table in
                table.primaryKey("id", .text)
                table.column("noteId", .text).notNull().indexed().references("note", onDelete: .cascade)
                table.column("day", .text).notNull().indexed()
                table.column("kind", .text).notNull()
                table.column("category", .text)
                table.column("data", .jsonText).notNull()
                table.column("span", .text).notNull().defaults(to: "")
                table.column("confidence", .double).notNull()
                table.column("question", .text)
                table.column("createdAt", .datetime).notNull()
                // 时间轴里排在哪：开始、结束，都没有就是说这句话的时刻
                table.column("sortKey", .text).notNull()
            }
            // 网关回的改动包原样存着：撤销、版本历史（M2b）照它来
            try db.create(table: "changePackage") { table in
                table.primaryKey("noteId", .text).references("note", onDelete: .cascade)
                table.column("appliedAt", .datetime).notNull()
                table.column("package", .jsonText).notNull()
            }
            for category in try Seed.categories() { try CategoryRow(category).insert(db) }
        }
        return migrator
    }
}

// MARK: - 写

extension PourStore {
    /// 说了一段话：马上存下、排队整理（原话先出现在「今天」，整理是后面的事）
    @discardableResult
    public func addNote(
        _ text: String, at date: Date = Date(), timeZone: TimeZone = .current,
        boundary: Int = PourDate.defaultBoundary
    ) throws -> Note {
        let local = PourDate.localDateTime(date, in: timeZone)
        let note = Note(
            text: text.trimmingCharacters(in: .whitespacesAndNewlines), createdAt: date, localTime: local,
            timeZone: timeZone.identifier, day: PourDate.logicalDay(of: local, boundary: boundary))
        try writer.write { db in try NoteRow(note).insert(db) }
        return note
    }

    /// 下一段该整理的原话：排着队的，或者到了重试时间的；先说的先整理
    public func nextNoteToOrganize(now: Date = Date()) throws -> Note? {
        try writer.read { db in
            try NoteRow
                .filter(
                    Column("status") == Note.Status.queued.rawValue
                        || Column("status") == Note.Status.waitingForNetwork.rawValue
                )
                .filter(Column("nextAttemptAt") == nil || Column("nextAttemptAt") <= now)
                .order(Column("createdAt"))
                .fetchOne(db)?.note
        }
    }

    /// 最早什么时候有原话到了重试时间（没有就是 nil）
    public func nextRetryDate() throws -> Date? {
        try writer.read { db in
            try Date.fetchOne(
                db,
                NoteRow.select(min(Column("nextAttemptAt")))
                    .filter(
                        Column("status") == Note.Status.queued.rawValue
                            || Column("status") == Note.Status.waitingForNetwork.rawValue))
        }
    }

    /// 这段原话试过几次了（重试的间隔照它拉长）
    public func attempts(of id: String) throws -> Int {
        try writer.read { db in try NoteRow.fetchOne(db, key: id)?.attempts ?? 0 }
    }

    public func markOrganizing(_ id: String) throws {
        try update(id) { row in
            row.status = Note.Status.organizing.rawValue
            row.attempts += 1
            row.problem = nil
        }
    }

    /// 整理好了：新记录、改动包、原话的状态在一个事务里写进去（要么全写进去，要么都没写）
    public func finish(noteId: String, creates: [NewEntry], reply: String, package: Data, at date: Date = Date())
        throws
    {
        try writer.write { db in
            guard var note = try NoteRow.fetchOne(db, key: noteId) else { return }
            for (index, new) in creates.enumerated() {
                // 同一段话里的记录：创建时刻依次差一毫秒，排序稳定
                let entry = Entry(
                    noteId: noteId, day: new.day, data: new.data, span: new.span, confidence: new.confidence,
                    question: new.question, createdAt: date.addingTimeInterval(Double(index) / 1000))
                try EntryRow(entry, said: note.localTime).insert(db)
            }
            let text = String(bytes: package, encoding: .utf8) ?? "{}"
            try ChangePackageRow(noteId: noteId, appliedAt: date, package: text).upsert(db)
            note.status = Note.Status.done.rawValue
            note.reply = reply.isEmpty ? nil : reply
            note.problem = nil
            note.nextAttemptAt = nil
            note.finishedAt = date
            try note.update(db)
        }
    }

    /// 连不上：到时候（或者一联网）自动再试
    public func markWaitingForNetwork(_ id: String, retryAt: Date) throws {
        try update(id) { row in
            row.status = Note.Status.waitingForNetwork.rawValue
            row.nextAttemptAt = retryAt
        }
    }

    /// 过一会儿自动再试（AI 这次没回应、被限流），界面上照样是「整理中」
    public func requeue(_ id: String, retryAt: Date) throws {
        try update(id) { row in
            row.status = Note.Status.queued.rawValue
            row.nextAttemptAt = retryAt
        }
    }

    /// 没整理成：说清楚发生了什么，等你点「再试一次」
    public func markFailed(_ id: String, problem: String) throws {
        try update(id) { row in
            row.status = Note.Status.failed.rawValue
            row.problem = problem
            row.nextAttemptAt = nil
        }
    }

    /// 「再试一次」：回到队里马上整理
    public func retry(_ id: String) throws {
        try update(id) { row in
            row.status = Note.Status.queued.rawValue
            row.problem = nil
            row.nextAttemptAt = nil
            row.attempts = 0
        }
    }

    /// 一联网：等网络的原话马上再试，不等到点
    public func retryWaitingNow() throws {
        try writer.write { db in
            _ = try NoteRow.filter(Column("status") == Note.Status.waitingForNetwork.rawValue)
                .updateAll(db, Column("nextAttemptAt").set(to: nil))
        }
    }

    /// App 被关掉时正在整理的：回到队里（启动时调用一次）
    public func recoverInterrupted() throws {
        try writer.write { db in
            _ = try NoteRow.filter(Column("status") == Note.Status.organizing.rawValue)
                .updateAll(db, Column("status").set(to: Note.Status.queued.rawValue))
        }
    }

    private func update(_ id: String, _ change: @escaping @Sendable (inout NoteRow) -> Void) throws {
        try writer.write { db in
            guard var row = try NoteRow.fetchOne(db, key: id) else { return }
            change(&row)
            try row.update(db)
        }
    }
}

// MARK: - 读

/// 一天的样子：这一天说的话、整理出的记录、类别表（「今天」页观察的就是它）
public struct DaySnapshot: Hashable, Sendable {
    public var day: DayString
    /// 这一天说的话，先说的在前
    public var notes: [Note]
    /// 这一天的记录，按时间轴排
    public var entries: [Entry]
    /// 这一天说的话整理出的全部记录（「昨天跑了五公里」记在昨天，收据里照样列出来）
    public var noteEntries: [Entry]
    public var categories: [LifeCategory]

    public init(
        day: DayString, notes: [Note] = [], entries: [Entry] = [], noteEntries: [Entry] = [],
        categories: [LifeCategory] = []
    ) {
        self.day = day
        self.notes = notes
        self.entries = entries
        self.noteEntries = noteEntries
        self.categories = categories
    }
}

extension PourStore {
    public func categories() throws -> [LifeCategory] {
        try writer.read { db in try Self.categories(db) }
    }

    public func snapshot(of day: DayString) throws -> DaySnapshot {
        try writer.read { db in try Self.snapshot(db, day: day) }
    }

    /// 整理一段话要给 AI 看的已有记录：那一天的全部记录，加上前后三天还没做完的待办
    public func existingEntries(around day: DayString) throws -> [Entry] {
        try writer.read { db in
            let sameDay = try EntryRow.filter(Column("day") == day).order(Column("sortKey"), Column("createdAt"))
                .fetchAll(db)
            let todos = try EntryRow.filter(Column("kind") == "todo")
                .filter(Column("day") >= PourDate.addDays(day, -3) && Column("day") <= PourDate.addDays(day, 3))
                .filter(Column("day") != day)
                .order(Column("day"), Column("createdAt"))
                .fetchAll(db)
            return try (sameDay + todos).map { try $0.entry() }.filter {
                if case .todo(let todo) = $0.data, $0.day != day { return !todo.done }
                return true
            }
        }
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
        let entries = try EntryRow.filter(Column("day") == day).order(Column("sortKey"), Column("createdAt"))
            .fetchAll(db).map { try $0.entry() }
        let noteEntries = try EntryRow.filter(notes.map(\.id).contains(Column("noteId"))).order(Column("createdAt"))
            .fetchAll(db).map { try $0.entry() }
        return DaySnapshot(
            day: day, notes: notes, entries: entries, noteEntries: noteEntries, categories: try categories(db))
    }
}
