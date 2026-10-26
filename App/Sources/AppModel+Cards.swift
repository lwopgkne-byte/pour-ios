import Foundation
import PourAPI

// MARK: - 我的卡片：长按改名字、放到最前、不要了（docs/模块/产品优化.md R3）

extension AppModel {
    func renameCard(_ id: Int, to title: String) {
        let name = title.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        act { client in try await client.renameCard(id, to: name) }
    }

    func moveCardFirst(_ id: Int) {
        act { client in try await client.moveCard(id, to: "first") }
    }

    /// 不要了：轻提示上能撤销（放回来）
    func deleteCard(_ card: API.CardView) {
        let id = card.id
        act { client in try await client.deleteCard(id) }
        toast("「\(card.title)」不要了", action: "撤销") { [weak self] in
            self?.act { client in try await client.restoreCard(id) }
        }
    }
}
