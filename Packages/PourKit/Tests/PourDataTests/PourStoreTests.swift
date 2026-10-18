import Foundation
import PourCore
import PourData
import Testing

@Suite("本机数据库")
struct PourStoreTests {
    let shanghai = TimeZone(identifier: "Asia/Shanghai") ?? .gmt

    /// 上海时间某一刻
    func at(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = shanghai
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.date(from: text) ?? .distantPast
    }

    @Test func seedsTheBaseCategoriesFromTheWebVersion() throws {
        let categories = try PourStore.inMemory().categories()
        #expect(
            categories.map(\.key) == ["sleep", "exercise", "run", "strength", "yoga", "diet", "study", "work", "other"])
        #expect(categories.first { $0.key == "run" }?.parent == "exercise")
        #expect(categories.first { $0.key == "diet" }?.synonyms.contains("外卖") == true)
        // 颜色按规范 01「默认给」：运动是苔、睡眠是藤
        #expect(categories.color(of: "run") == "moss")
        #expect(categories.color(of: "sleep") == "wisteria")
    }

    @Test func aNoteBelongsToItsLogicalDay() throws {
        let store = try PourStore.inMemory()
        // 凌晨 2 点说的话算前一天（日界线 4:00）
        let late = try store.addNote("  刚加完班  ", at: at("2026-10-18T02:30"), timeZone: shanghai)
        #expect(late.text == "刚加完班")
        #expect(late.localTime == "2026-10-18T02:30")
        #expect(late.day == "2026-10-17")
        #expect(late.status == .queued)
        let morning = try store.addNote("早上跑了五公里", at: at("2026-10-18T07:10"), timeZone: shanghai)
        #expect(morning.day == "2026-10-18")
    }

    @Test func organizesNotesInTheOrderTheyWereSaid() throws {
        let store = try PourStore.inMemory()
        let first = try store.addNote("第一句", at: at("2026-10-18T08:00"), timeZone: shanghai)
        try store.addNote("第二句", at: at("2026-10-18T08:01"), timeZone: shanghai)
        #expect(try store.nextNoteToOrganize()?.id == first.id)
        // 等网络的：没到重试时间不拿出来，到了才拿
        try store.markWaitingForNetwork(first.id, retryAt: at("2026-10-18T08:10"))
        #expect(try store.nextNoteToOrganize(now: at("2026-10-18T08:05"))?.text == "第二句")
        #expect(try store.nextNoteToOrganize(now: at("2026-10-18T08:11"))?.id == first.id)
        #expect(try store.nextRetryDate() == at("2026-10-18T08:10"))
        // 一联网就马上再试
        try store.retryWaitingNow()
        #expect(try store.nextNoteToOrganize(now: at("2026-10-18T08:05"))?.id == first.id)
    }

    @Test func finishingWritesRecordsAndStatusTogether() throws {
        let store = try PourStore.inMemory()
        let note = try store.addNote("早上七点跑了五公里 中午和小王吃面三十二", at: at("2026-10-18T12:40"), timeZone: shanghai)
        try store.markOrganizing(note.id)
        let run = NewEntry(
            day: "2026-10-18",
            data: .event(
                .init(
                    category: "run", label: "跑步", start: "2026-10-18T07:00",
                    metrics: [.init(name: "距离", value: 5, unit: "公里")])),
            span: "早上七点跑了五公里", confidence: 0.95)
        let lunch = NewEntry(
            day: "2026-10-18",
            data: .event(
                .init(category: "diet", label: "吃面", metrics: [.init(name: "花费", value: 32, unit: "元")], people: ["小王"])
            ),
            span: "中午和小王吃面三十二", confidence: 0.6, question: "三十二是花了 32 块吗？")
        try store.apply(
            NoteChanges(creates: [lunch, run]), toNote: note.id, package: Data("{}".utf8), at: at("2026-10-18T12:41"))

        let day = try store.snapshot(of: "2026-10-18")
        #expect(day.notes.map(\.status) == [.done])
        #expect(day.notes.first?.finishedAt == at("2026-10-18T12:41"))
        // 时间轴：有钟点的按钟点排，说不出几点的排在说这句话的时刻
        #expect(day.entries.map(\.span) == ["早上七点跑了五公里", "中午和小王吃面三十二"])
        #expect(day.entries.last?.needsConfirmation == true)
        #expect(day.entries.last?.data == lunch.data)
    }

    @Test func failedNotesWaitForYouToRetry() throws {
        let store = try PourStore.inMemory()
        let note = try store.addNote("你好", at: at("2026-10-18T09:00"), timeZone: shanghai)
        try store.markOrganizing(note.id)
        try store.markFailed(note.id, problem: "没整理成：大模型账户余额不足。")
        #expect(try store.nextNoteToOrganize() == nil)
        #expect(try store.snapshot(of: "2026-10-18").notes.first?.problem == "没整理成：大模型账户余额不足。")
        try store.retry(note.id)
        #expect(try store.nextNoteToOrganize()?.id == note.id)
        #expect(try store.attempts(of: note.id) == 0)
    }

    @Test func interruptedOrganizingGoesBackToTheQueue() throws {
        let store = try PourStore.inMemory()
        let note = try store.addNote("你好", at: at("2026-10-18T09:00"), timeZone: shanghai)
        try store.markOrganizing(note.id)
        #expect(try store.nextNoteToOrganize() == nil)
        try store.recoverInterrupted()
        #expect(try store.nextNoteToOrganize()?.id == note.id)
    }

    @Test func theAIseesTheDaysRecordsAndNearbyOpenTodos() throws {
        let store = try PourStore.inMemory()
        let yesterday = try store.addNote("明天交房租 买猫粮", at: at("2026-10-17T21:00"), timeZone: shanghai)
        try store.apply(
            NoteChanges(creates: [
                NewEntry(day: "2026-10-17", data: .todo(.init(content: "交房租", due: "2026-10-18"))),
                NewEntry(day: "2026-10-17", data: .todo(.init(content: "买猫粮", done: true))),
                NewEntry(day: "2026-10-17", data: .event(.init(category: "work", label: "开会"))),
            ]), toNote: yesterday.id, package: Data("{}".utf8))
        let today = try store.addNote("跑步", at: at("2026-10-18T07:00"), timeZone: shanghai)
        try store.apply(
            NoteChanges(creates: [NewEntry(day: "2026-10-18", data: .event(.init(category: "run", label: "跑步")))]),
            toNote: today.id, package: Data("{}".utf8))
        let existing = try store.existingEntries(around: "2026-10-18")
        // 今天的全部；前几天的只要没做完的待办
        #expect(existing.map(\.day) == ["2026-10-18", "2026-10-17"])
        if case .todo(let todo) = existing.last?.data { #expect(todo.content == "交房租") } else { Issue.record("应该是待办") }
    }

    @Test func observingADayDeliversEveryChange() async throws {
        let store = try PourStore.inMemory()
        var iterator = store.observe(day: "2026-10-18").makeAsyncIterator()
        #expect(try await iterator.next()?.notes.isEmpty == true)
        try store.addNote("早上跑了五公里", at: at("2026-10-18T07:10"), timeZone: shanghai)
        #expect(try await iterator.next()?.notes.map(\.text) == ["早上跑了五公里"])
    }

    @Test func persistsAcrossLaunches() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("pour-\(UUID().uuidString).sqlite")
            .path
        defer { try? FileManager.default.removeItem(atPath: path) }
        try PourStore(path: path).addNote("早上跑了五公里", at: at("2026-10-18T07:10"), timeZone: shanghai)
        let reopened = try PourStore(path: path)
        #expect(try reopened.snapshot(of: "2026-10-18").notes.map(\.text) == ["早上跑了五公里"])
        #expect(try reopened.categories().count == 9)
    }
}
