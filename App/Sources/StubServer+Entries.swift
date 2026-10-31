#if DEBUG
    import Foundation

    /// 假服务器的一条记录：确认、打勾、改、删、放回来（PATCH / DELETE /api/entries/:id、POST …/restore）
    extension StubServer.State {
        mutating func patch(entry id: Int, _ body: [String: Any]) -> [String: Any] {
            guard let index = entries.firstIndex(where: { $0["id"] as? Int == id }) else { return [:] }
            if body["confirm"] as? Bool == true {
                entries[index]["status"] = "ok"
                entries[index]["question"] = nil
            }
            if let done = body["done"] as? Bool { todoDone(index, done) }
            if let fields = body["fields"] as? [String: Any], var data = entries[index]["data"] as? [String: Any] {
                if let label = fields["label"] as? String { data["label"] = label }
                for key in ["people", "things", "places"] {
                    if let words = fields[key] as? [String] { data[key] = words }
                }
                entries[index]["data"] = data
            }
            return entries[index]
        }

        mutating func delete(entry id: Int) -> [String: Any] {
            if let index = entries.firstIndex(where: { $0["id"] as? Int == id }) {
                trash.append(entries.remove(at: index))
            }
            return ["ok": true]
        }

        mutating func restore(entry id: Int) -> [String: Any] {
            if let index = trash.firstIndex(where: { $0["id"] as? Int == id }) {
                entries.append(trash.remove(at: index))
            }
            return ["ok": true]
        }
    }
#endif
