/// 名字表（docs/模块/产品优化.md R2）：「说到的」里长按名字「改名字…」「不再显示」，关于我里恢复。
/// 原话和记录里的字不改；服务器算「说到的」「关于我」、笔记库筛选时照它换、藏
extension APIClient {
    public func names() async throws(APIError) -> [API.NameRule] {
        let page: API.NameRules = try await get("/api/names")
        return page.rules
    }

    /// 改名字（改成已经有的名字就是合成一个）；改成自己就是不改了
    @discardableResult
    public func rename(kind: String, name: String, to canonical: String) async throws(APIError) -> [API.NameRule] {
        let body: JSONValue = .object(["kind": .string(kind), "name": .string(name), "canonical": .string(canonical)])
        let page: API.NameRules = try await request("PUT", "/api/names", json: body)
        return page.rules
    }

    /// 不再显示（hidden: false 是放回来）
    @discardableResult
    public func hideName(kind: String, name: String, _ hidden: Bool = true) async throws(APIError) -> [API.NameRule] {
        let body: JSONValue = .object(["kind": .string(kind), "name": .string(name), "hidden": .bool(hidden)])
        let page: API.NameRules = try await request("PUT", "/api/names", json: body)
        return page.rules
    }

    /// 恢复原样：不改名字、也不藏
    @discardableResult
    public func forgetName(kind: String, name: String) async throws(APIError) -> [API.NameRule] {
        let body: JSONValue = .object(["kind": .string(kind), "name": .string(name)])
        let page: API.NameRules = try await request("DELETE", "/api/names", json: body)
        return page.rules
    }
}
