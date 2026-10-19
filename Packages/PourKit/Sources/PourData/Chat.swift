public import Foundation
internal import GRDB
public import PourCore

/// 对话面板的样子（照网页版 ChatPanel）：最近说过的话（不分哪天，从早到晚）、它们动到的记录、类别表
public struct ChatSnapshot: Hashable, Sendable {
    public var notes: [Note]
    /// 这些话动到的每一条记录（收据要写出来）：删掉的是删之前的样子
    public var mentioned: [String: Entry]
    public var categories: [LifeCategory]

    public init(notes: [Note] = [], mentioned: [String: Entry] = [:], categories: [LifeCategory] = []) {
        self.notes = notes
        self.mentioned = mentioned
        self.categories = categories
    }
}

extension PourStore {
    /// 一直看着最近说的话：有新的话、整理好了、撤销了都会送来新的样子
    public func observeChat(limit: Int = 100) -> AsyncThrowingStream<ChatSnapshot, any Error> {
        let observation = ValueObservation.tracking { db in try Self.chat(db, limit: limit) }.removeDuplicates()
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

    static func chat(_ db: Database, limit: Int) throws -> ChatSnapshot {
        let notes = try NoteRow.order(Column("createdAt").desc).limit(limit).fetchAll(db).map(\.note).reversed()
        let list = Array(notes)
        return ChatSnapshot(notes: list, mentioned: try mentioned(db, by: list), categories: try categories(db))
    }
}
