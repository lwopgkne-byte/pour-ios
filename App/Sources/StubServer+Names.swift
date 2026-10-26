#if DEBUG
    import Foundation

    extension StubServer.State {
        /// 名字表（docs/模块/产品优化.md R2）：改名字、不再显示、恢复；「说到的」照它换、藏
        mutating func namesReply(_ method: String, _ path: String, _ body: [String: Any]) -> Any? {
            guard path == "/api/names" else { return nil }
            let kind = body["kind"] as? String ?? ""
            let name = body["name"] as? String ?? ""
            switch method {
            case "GET": break
            case "PUT":
                var rule =
                    names.first { $0["kind"] as? String == kind && $0["name"] as? String == name }
                    ?? ["kind": kind, "name": name, "canonical": NSNull(), "hidden": false]
                if let canonical = body["canonical"] as? String {
                    rule["canonical"] = canonical == name ? NSNull() : canonical
                }
                if let hidden = body["hidden"] as? Bool { rule["hidden"] = hidden }
                rule["updatedAt"] = ISO8601DateFormatter().string(from: Date())
                names.removeAll { $0["kind"] as? String == kind && $0["name"] as? String == name }
                if rule["canonical"] is String || rule["hidden"] as? Bool == true { names.insert(rule, at: 0) }
            case "DELETE":
                names.removeAll { $0["kind"] as? String == kind && $0["name"] as? String == name }
            default: return nil
            }
            return ["rules": names]
        }

        /// 这一天「说到的」：样张有自己的；别的日子照记录收（和服务器一样，按说的先后），再照名字表换、藏
        func mentionsOfDay(_ day: String, sample: [[String: Any]]?) -> [[String: Any]] {
            let fields = [
                NameField(kind: "person", field: "people", kinds: ["event", "todo"]),
                NameField(kind: "thing", field: "things", kinds: ["event", "todo"]),
                NameField(kind: "place", field: "places", kinds: ["event", "todo"]),
                NameField(kind: "tag", field: "tags", kinds: ["event", "insight"]),
            ]
            var list = sample ?? []
            if sample == nil {
                for entry in entries where entry["day"] as? String == day {
                    let data = entry["data"] as? [String: Any] ?? [:]
                    for item in fields where item.kinds.contains(entry["kind"] as? String ?? "") {
                        for name in data[item.field] as? [String] ?? [] {
                            list.append(["kind": item.kind, "name": name, "weekDays": 1, "firstTime": false])
                        }
                    }
                }
            }
            var seen = Set<String>()
            return list.compactMap { item in
                let kind = item["kind"] as? String ?? ""
                var name = item["name"] as? String ?? ""
                let rule = { (wanted: String) in
                    names.first { $0["kind"] as? String == kind && $0["name"] as? String == wanted }
                }
                if let canonical = rule(name)?["canonical"] as? String { name = canonical }
                guard rule(name)?["hidden"] as? Bool != true, seen.insert("\(kind)|\(name)").inserted else {
                    return nil
                }
                var out = item
                out["name"] = name
                return out
            }
        }
    }

    /// 「说到的」四类各从记录的哪个字段来、哪几种记录有它（和服务器 shared/src/mentions.ts 一样）
    private struct NameField {
        let kind: String
        let field: String
        let kinds: Set<String>
    }
#endif
