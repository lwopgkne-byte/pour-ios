import Foundation
import PourAPI

/// 写操作队列（docs/3.0/07-开发任务清单.md 1.12、01 需求文档 3.3）：先改界面再发。
/// 没连上：排在手机上（存下来，关了 App 也在），连上了按顺序发；服务器不收：退回刚才改的样子，说一句
struct PendingWrite: Codable, Hashable, Identifiable {
    let id: UUID
    let method: String
    let path: String
    let body: Data?
    let createdAt: Date
}

/// 排着的写操作存在这台手机上（和发件箱一样；界面测试用自己的一份，不和真的混）
enum WriteStore {
    static var key: String {
        ProcessInfo.processInfo.arguments.contains("-uiTest") ? "pour.writes.uiTest" : "pour.writes"
    }

    static func load() -> [PendingWrite] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([PendingWrite].self, from: data)) ?? []
    }

    static func save(_ writes: [PendingWrite]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(writes), forKey: key)
    }
}

extension AppModel {
    /// 发一个写操作：界面已经先改好了（调用的地方改），这里只管送到服务器。
    /// 没连上：排起来、说一句「连上了自动发」；服务器不收：revert 退回刚才的样子、说服务器给的那句话
    func write(_ method: String, _ path: String, json: JSONValue? = nil, revert: @escaping @MainActor () -> Void) {
        let item = PendingWrite(
            id: UUID(), method: method, path: path, body: json.flatMap { try? JSONEncoder().encode($0) },
            createdAt: Date())
        // 前面还有没发出去的：排在它们后面，保证先后
        if !writes.isEmpty {
            queue(item)
            return
        }
        let client = self.client
        Task {
            do throws(APIError) {
                try await client.write(item.method, item.path, body: item.body)
                // 服务器那边可能连带着变了别的（目标的进度、提醒）：各页重新拿
                dataChanged()
            } catch .unreachable {
                queue(item)
            } catch {
                revert()
                toast(error.message)
            }
        }
    }

    private func queue(_ item: PendingWrite) {
        writes.append(item)
        WriteStore.save(writes)
        toast("没连上电脑上的 Pour，先记在手机上，连上了自动发")
    }

    /// 连上了：排着的按顺序发；又没连上就停下等下次；服务器不收的扔掉、说一句（界面下次拿新的就对了）
    func flushWrites() async {
        guard !writes.isEmpty else { return }
        while let item = writes.first {
            do {
                try await client.write(item.method, item.path, body: item.body)
            } catch .unreachable {
                return
            } catch {
                toast(error.message)
            }
            writes.removeFirst()
            WriteStore.save(writes)
        }
        dataChanged()
    }
}
