/// 我的卡片和语录（docs/模块/产品优化.md R3、R4）：卡片平常是说一句建、改；画布上长按也能改名字、挪到最前、不要了
extension APIClient {
    public func renameCard(_ id: Int, to title: String) async throws(APIError) {
        let _: Empty = try await request("PATCH", "/api/cards/\(id)", json: .object(["title": .string(title)]))
    }

    /// to：first 放到最前 · last 放到最后
    public func moveCard(_ id: Int, to place: String) async throws(APIError) {
        let _: Empty = try await request("PATCH", "/api/cards/\(id)", json: .object(["to": .string(place)]))
    }

    public func deleteCard(_ id: Int) async throws(APIError) {
        let _: Empty = try await request("DELETE", "/api/cards/\(id)")
    }

    /// 不要了的放回来（轻提示上的「撤销」）
    public func restoreCard(_ id: Int) async throws(APIError) {
        let _: Empty = try await request("POST", "/api/cards/\(id)/restore")
    }

    /// 全部语录：新的在前
    public func quotes() async throws(APIError) -> [API.MyQuote] {
        let page: API.MyQuotes = try await get("/api/quotes")
        return page.quotes
    }

    /// 不放进语录（hidden: false 放回来）；记录本身不动
    @discardableResult
    public func hideQuote(_ entryId: Int, _ hidden: Bool = true) async throws(APIError) -> [API.MyQuote] {
        let body: JSONValue = .object(["entryId": .number(Double(entryId)), "hidden": .bool(hidden)])
        let page: API.MyQuotes = try await request("PUT", "/api/quotes/hidden", json: body)
        return page.quotes
    }
}
