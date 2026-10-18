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
        migrator.registerMigration("v2 改动历史、收据、撤销") { db in
            // 一条记录的每一次改动：哪段话改的（详情里自己改的没有）、改之前、改之后——撤销和改动历史都照它来
            try db.create(table: "entryVersion") { table in
                table.autoIncrementedPrimaryKey("seq")
                table.column("entryId", .text).notNull().indexed()
                table.column("noteId", .text).indexed()
                table.column("action", .text).notNull()
                table.column("span", .text).notNull().defaults(to: "")
                table.column("before", .jsonText)
                table.column("after", .jsonText)
                table.column("at", .datetime).notNull()
            }
            try db.alter(table: "note") { table in
                // 这段话做了什么（收据一行一件）、问你的话、撤销的时刻
                table.add(column: "actions", .jsonText).notNull().defaults(to: "[]")
                table.add(column: "questions", .jsonText).notNull().defaults(to: "[]")
                table.add(column: "undoneAt", .datetime)
            }
            // 删掉的记录留着（可以撤销），不再出现
            try db.alter(table: "entry") { table in table.add(column: "deletedAt", .datetime) }
        }
        migrator.registerMigration("v3 一句话总结") { db in
            // 「今天」日子头下面那句话：按这一天记录的指纹缓存，记录没变就不再问 AI
            try db.create(table: "summary") { table in
                table.primaryKey("day", .text)
                table.column("text", .text).notNull()
                table.column("inputHash", .text).notNull()
                table.column("createdAt", .datetime).notNull()
            }
        }
        migrator.registerMigration("v4 在等回答要不要删") { db in
            // 问了要不要删的那几条：下一句说「对」时网关照着删（接口契约 v4）
            try db.alter(table: "note") { table in
                table.add(column: "awaitingDelete", .jsonText).notNull().defaults(to: "[]")
            }
        }
        return migrator
    }
}
