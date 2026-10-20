public import Foundation
internal import GRDB
public import PourCore

// 详情里直接改：改完的样子由界面算好，这里整体写入、留着改之前的样子

extension PourStore {
    /// 详情里改了一条：哪天、内容换成新的；改过就不再待确认。改动历史记一笔「修改」（不算哪段话改的）
    public func edit(_ entryId: String, day: DayString, data: RecordData, at date: Date = Date()) throws {
        try writer.write { db in
            guard var row = try EntryRow.fetchOne(db, key: entryId), row.deletedAt == nil else { return }
            let before = try row.entry().state
            var after = before
            after.day = day
            after.data = data
            after.question = nil
            after.confidence = 1
            guard after != before else { return }
            try row.set(after, said: try Self.said(db, row))
            try row.update(db)
            try EntryVersionRow(entryId, .updated, noteId: nil, span: "", before: before, after: after, at: date)
                .insert(db)
        }
    }

    /// 某几天的全部记录（删掉的不算）：详情里画最近 7 天
    public func entries(from first: DayString, through last: DayString) throws -> [Entry] {
        try writer.read { db in
            try EntryRow.filter(Column("deletedAt") == nil)
                .filter(Column("day") >= first && Column("day") <= last)
                .order(Column("day"), Column("sortKey"))
                .fetchAll(db).map { try $0.entry() }
        }
    }
}
