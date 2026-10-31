import Foundation
import PourAPI

// MARK: - 改记录：做完重新拿这一天（AppModel.act）

extension AppModel {
    /// 对话里收据后面的「撤销」：这段话整理出的记录都撤掉，原话留着
    func undo(note id: Int) { act { client in try await client.undo(note: id) } }

    /// 没整理成的，点「重试」
    func retry(note id: Int) { act { client in try await client.retry(note: id) } }

    func confirm(_ entryId: Int) { act { client in try await client.confirm(entry: entryId) } }

    /// 详情里原地改（字段名照服务器：label、start、duration_min、metrics……）
    func update(_ entryId: Int, _ fields: [String: JSONValue]) {
        act { client in try await client.update(entry: entryId, fields: fields) }
    }

    func delete(_ entryId: Int) {
        detail = nil
        act { client in try await client.delete(entry: entryId) }
        // 轻提示上的「撤销」：删掉的放回来
        toast("已删除", action: "撤销") { [weak self] in
            self?.act { client in try await client.restore(entry: entryId) }
        }
    }

    /// 「连接大模型」上的「知道了，开始整理」：同意把原话发给大模型整理
    func acceptConsent() { act { client in try await client.acceptConsent() } }

    /// 「连接大模型」上的「跳过」：不再出现，以后在设置里填
    func dismissSetup() { act { client in try await client.dismissSetup() } }
}
