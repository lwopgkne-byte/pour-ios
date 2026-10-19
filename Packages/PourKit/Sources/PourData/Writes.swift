public import Foundation
internal import GRDB
public import PourCore

// 写：说一段话、排队整理、把改动包写进去、撤销（每一种都在一个事务里，要么全写进去，要么都没写）

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

    /// 整理好了：新建、改、删的记录（改之前的样子都留着）、改动包、原话的状态，在一个事务里写进去
    public func apply(_ changes: NoteChanges, toNote noteId: String, package: Data, at date: Date = Date()) throws {
        try writer.write { db in
            guard var note = try NoteRow.fetchOne(db, key: noteId) else { return }
            var actions: [NoteAction] = []
            try Self.insert(changes.newCategories, db)
            for (index, new) in changes.creates.enumerated() {
                // 同一段话里的记录：创建时刻依次差一毫秒，排序稳定
                let entry = Entry(
                    noteId: noteId, day: new.day, data: new.data, span: new.span, confidence: new.confidence,
                    question: new.question, createdAt: date.addingTimeInterval(Double(index) / 1000))
                try EntryRow(entry, said: note.localTime).insert(db)
                try EntryVersionRow(entry.id, .created, noteId: noteId, span: new.span, after: entry.state, at: date)
                    .insert(db)
                actions.append(NoteAction(.created, entryId: entry.id))
            }
            for change in changes.updates {
                guard var row = try EntryRow.fetchOne(db, key: change.id), row.deletedAt == nil else { continue }
                let before = try row.entry().state
                let after = EntryState(
                    day: change.day, data: change.data, confidence: change.confidence, question: change.question)
                try row.set(after, said: note.localTime)
                try row.update(db)
                try EntryVersionRow(
                    change.id, change.action, noteId: noteId, span: change.span, before: before, after: after, at: date
                ).insert(db)
                actions.append(NoteAction(change.action, entryId: change.id))
            }
            for removed in changes.deletes {
                guard var row = try EntryRow.fetchOne(db, key: removed.id), row.deletedAt == nil else { continue }
                row.deletedAt = date
                try row.update(db)
                try EntryVersionRow(
                    removed.id, .deleted, noteId: noteId, span: removed.span, before: try row.entry().state, at: date
                ).insert(db)
                actions.append(NoteAction(.deleted, entryId: removed.id))
            }
            for duplicate in changes.duplicates where try EntryRow.exists(db, key: duplicate.id) {
                actions.append(NoteAction(.duplicate, entryId: duplicate.id))
            }
            let text = String(bytes: package, encoding: .utf8) ?? "{}"
            try ChangePackageRow(noteId: noteId, appliedAt: date, package: text).upsert(db)
            try Self.finish(&note, with: changes, actions: actions, at: date, db)
        }
    }

    /// 这段话整理好了：收据（做了什么）、回你的话、问你的话、在等回答要不要删的那几条
    static func finish(
        _ note: inout NoteRow, with changes: NoteChanges, actions: [NoteAction], at date: Date, _ db: Database
    ) throws {
        note.status = Note.Status.done.rawValue
        note.reply = changes.reply.isEmpty ? nil : changes.reply
        note.replyByProgram = changes.replyByProgram
        note.problem = nil
        note.nextAttemptAt = nil
        note.finishedAt = date
        note.actions = actions
        note.questions = changes.questions
        note.awaitingDelete = changes.awaitingDelete
        note.undoneAt = nil
        try note.update(db)
    }

    /// 先建这段话新建的类别（记录要用到它们）；已经有了的不重复建
    static func insert(_ categories: [LifeCategory], _ db: Database) throws {
        for category in categories where try !CategoryRow.exists(db, key: category.key) {
            try CategoryRow(category).insert(db)
        }
    }

    /// 撤销一段话整理出的改动：新建的删掉、改了的改回去、删了的放回来；原话留着，标「已撤销」
    public func undo(_ noteId: String, at date: Date = Date()) throws {
        try writer.write { db in
            guard var note = try NoteRow.fetchOne(db, key: noteId), note.undoneAt == nil else { return }
            let versions = try EntryVersionRow.filter(Column("noteId") == noteId).order(Column("seq").desc)
                .fetchAll(db)
            for version in versions {
                switch NoteAction.Kind(rawValue: version.action) {
                case .created:
                    _ = try EntryRow.deleteOne(db, key: version.entryId)
                case .updated, .confirmed, .completed, .deleted:
                    guard var row = try EntryRow.fetchOne(db, key: version.entryId), let before = version.beforeState
                    else { continue }
                    try row.set(before, said: note.localTime)
                    row.deletedAt = nil
                    try row.update(db)
                case .duplicate, .none:
                    continue
                }
            }
            _ = try EntryVersionRow.filter(Column("noteId") == noteId).deleteAll(db)
            note.undoneAt = date
            try note.update(db)
        }
    }

    /// 详情里点「对」：确认，不再待确认（改动历史记一笔，不算哪段话改的）
    public func confirm(_ entryId: String, at date: Date = Date()) throws {
        try writer.write { db in
            guard var row = try EntryRow.fetchOne(db, key: entryId), row.deletedAt == nil, row.question != nil else {
                return
            }
            let before = try row.entry().state
            var after = before
            after.question = nil
            after.confidence = 1
            try row.set(after, said: try Self.said(db, row))
            try row.update(db)
            try EntryVersionRow(entryId, .confirmed, noteId: nil, span: "", before: before, after: after, at: date)
                .insert(db)
        }
    }

    /// 画布上给待办打勾、取消打勾（改动历史记一笔，不算哪段话改的）
    public func setDone(_ entryId: String, _ done: Bool, at date: Date = Date()) throws {
        try writer.write { db in
            guard var row = try EntryRow.fetchOne(db, key: entryId), row.deletedAt == nil else { return }
            let before = try row.entry().state
            guard case .todo(var todo) = before.data, todo.done != done else { return }
            todo.done = done
            var after = before
            after.data = .todo(todo)
            try row.set(after, said: try Self.said(db, row))
            try row.update(db)
            try EntryVersionRow(
                entryId, done ? .completed : .updated, noteId: nil, span: "", before: before, after: after, at: date
            )
            .insert(db)
        }
    }

    /// 详情里点「删除」：删掉（留着，撤销条上能放回来）
    public func delete(_ entryId: String, at date: Date = Date()) throws {
        try writer.write { db in
            guard var row = try EntryRow.fetchOne(db, key: entryId), row.deletedAt == nil else { return }
            row.deletedAt = date
            try row.update(db)
            try EntryVersionRow(entryId, .deleted, noteId: nil, span: "", before: try row.entry().state, at: date)
                .insert(db)
        }
    }

    /// 撤销详情里的删除：放回来，删除那一笔从改动历史里去掉
    public func restore(_ entryId: String) throws {
        try writer.write { db in
            guard var row = try EntryRow.fetchOne(db, key: entryId), row.deletedAt != nil else { return }
            row.deletedAt = nil
            try row.update(db)
            if let last = try EntryVersionRow.filter(Column("entryId") == entryId && Column("action") == "deleted")
                .order(Column("seq").desc).fetchOne(db), let seq = last.seq
            {
                _ = try EntryVersionRow.deleteOne(db, key: seq)
            }
        }
    }

    /// 一条记录是在哪一刻说的（排序用）：它来自的那段原话
    static func said(_ db: Database, _ row: EntryRow) throws -> LocalDateTime {
        try NoteRow.fetchOne(db, key: row.noteId)?.localTime ?? row.sortKey
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
