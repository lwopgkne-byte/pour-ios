import Foundation
import PourCore
import PourData
import Testing

/// 改、删、撤销、改动历史（M2b）
@Suite("本机数据库：改动和撤销")
struct ChangesTests {
    let shanghai = TimeZone(identifier: "Asia/Shanghai") ?? .gmt
    let noon = Date(timeIntervalSince1970: 1_792_299_600)  // 上海 2026-10-18 13:00

    /// 先记下一条吃面 ¥28（待确认），返回数据库、这条记录
    func lunch() throws -> (PourStore, Entry) {
        let store = try PourStore.inMemory()
        let note = try store.addNote("中午和小王吃面二十八", at: noon, timeZone: shanghai)
        let data = RecordData.event(
            .init(category: "diet", label: "吃面", metrics: [.init(name: "花费", value: 28, unit: "元")], people: ["小王"]))
        try store.apply(
            NoteChanges(creates: [NewEntry(day: "2026-10-18", data: data, span: "吃面二十八", question: "二十八是 28 块吗？")]),
            toNote: note.id, package: Data("{}".utf8), at: noon)
        return (store, try #require(try store.snapshot(of: "2026-10-18").entries.first))
    }

    @Test func correctionsChangeTheRecordAndKeepTheOldVersion() throws {
        let (store, entry) = try lunch()
        let fix = try store.addNote("刚才那个是 38 不是 28", at: noon.addingTimeInterval(60), timeZone: shanghai)
        guard case .event(var event) = entry.data else { return }
        event.metrics = [.init(name: "花费", value: 38, unit: "元")]
        try store.apply(
            NoteChanges(updates: [
                .init(id: entry.id, action: .updated, day: entry.day, data: .event(event), span: "是 38")
            ]),
            toNote: fix.id, package: Data("{}".utf8), at: noon.addingTimeInterval(61))

        let day = try store.snapshot(of: "2026-10-18")
        #expect(day.entries.count == 1)
        #expect(day.entries.first?.data == .event(event))
        #expect(day.entries.first?.needsConfirmation == false)
        #expect(day.notes.last?.actions == [NoteAction(.updated, entryId: entry.id)])
        let history = try store.history(of: entry.id)
        #expect(history.map(\.kind) == [.created, .updated])
        #expect(history.last?.before?.data == entry.data)
        #expect(history.last?.span == "是 38")
    }

    @Test func deletingKeepsItForUndoAndTheReceipt() throws {
        let (store, entry) = try lunch()
        let remove = try store.addNote("吃面那条删掉", at: noon.addingTimeInterval(60), timeZone: shanghai)
        try store.apply(
            NoteChanges(deletes: [.init(id: entry.id, span: "删掉")]), toNote: remove.id, package: Data("{}".utf8))
        let day = try store.snapshot(of: "2026-10-18")
        #expect(day.entries.isEmpty)
        // 收据里还列得出删掉的是哪条
        #expect(day.mentioned[entry.id]?.data == entry.data)
        #expect(try store.existingEntries(around: "2026-10-18").isEmpty)
    }

    @Test func undoPutsEverythingBack() throws {
        let (store, entry) = try lunch()
        let later = try store.addNote("吃面那条删掉 晚上跑步", at: noon.addingTimeInterval(60), timeZone: shanghai)
        try store.apply(
            NoteChanges(
                creates: [NewEntry(day: "2026-10-18", data: .event(.init(category: "run", label: "跑步")))],
                deletes: [.init(id: entry.id)]),
            toNote: later.id, package: Data("{}".utf8))
        #expect(try store.snapshot(of: "2026-10-18").entries.map(\.span) == [""])

        try store.undo(later.id, at: noon.addingTimeInterval(65))
        let day = try store.snapshot(of: "2026-10-18")
        #expect(day.entries.map(\.id) == [entry.id], "删掉的放回来、新建的去掉")
        #expect(day.entries.first?.question == "二十八是 28 块吗？")
        #expect(day.notes.last?.undoneAt == noon.addingTimeInterval(65))
        #expect(day.notes.last?.text == "吃面那条删掉 晚上跑步", "原话留着")
        #expect(try store.history(of: entry.id).map(\.kind) == [.created])
    }

    @Test func recentTurnsGiveTheAIWhatWasJustSaid() throws {
        let (store, entry) = try lunch()
        let answer = try store.addNote("对", at: noon.addingTimeInterval(90), timeZone: shanghai)
        let (notes, mentioned) = try store.recentTurns(before: answer)
        #expect(notes.map(\.text) == ["中午和小王吃面二十八"])
        #expect(notes.first?.actions == [NoteAction(.created, entryId: entry.id)])
        #expect(mentioned[entry.id]?.question == "二十八是 28 块吗？")
        // 一个小时以前的不算
        let tomorrow = try store.addNote("早", at: noon.addingTimeInterval(3 * 3600), timeZone: shanghai)
        #expect(try store.recentTurns(before: tomorrow).notes.isEmpty)
    }

    @Test func aDeleteQuestionRemembersWhichRecords() throws {
        let (store, entry) = try lunch()
        let remove = try store.addNote("删除吃面", at: noon.addingTimeInterval(60), timeZone: shanghai)
        try store.apply(
            NoteChanges(questions: ["要删的是「吃面」吗？"], awaitingDelete: [entry.id]), toNote: remove.id,
            package: Data("{}".utf8))
        // 下一句说「对」时，对话里带着在等的是哪几条
        let answer = try store.addNote("对", at: noon.addingTimeInterval(90), timeZone: shanghai)
        let turns = try store.recentTurns(before: answer).notes
        #expect(turns.last?.awaitingDelete == [entry.id])
        #expect(turns.first?.awaitingDelete == [])
    }

    @Test func newCategoriesComeWithTheirRecords() throws {
        let store = try PourStore.inMemory()
        let note = try store.addNote("带娃去公园", at: noon, timeZone: shanghai)
        let parenting = LifeCategory(
            key: "c-1a2b3c4d", name: "育儿", emoji: "🍼", color: "sakura", measure: "count", order: 500)
        try store.apply(
            NoteChanges(
                creates: [NewEntry(day: "2026-10-18", data: .event(.init(category: parenting.key, label: "带娃去公园")))],
                newCategories: [parenting]),
            toNote: note.id, package: Data("{}".utf8))
        let day = try store.snapshot(of: "2026-10-18")
        #expect(day.categories.first { $0.key == parenting.key } == parenting)
        #expect(day.categories.color(of: parenting.key) == "sakura")
        // 再来一次同一个类别（网关以为没有）：不重复建、不出错
        let again = try store.addNote("陪孩子拼图", at: noon.addingTimeInterval(60), timeZone: shanghai)
        try store.apply(NoteChanges(newCategories: [parenting]), toNote: again.id, package: Data("{}".utf8))
        #expect(try store.categories().filter { $0.name == "育儿" }.count == 1)
    }
}
