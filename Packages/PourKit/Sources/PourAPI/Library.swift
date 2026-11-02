public import Foundation

// 笔记库（LibraryNote、InsightItem、MomentItem，服务器 routes/library.ts），字段名一字不差
extension API {
    /// 笔记库里的一段原话：它整理出的记录（一句话写好的）、是不是按意思找到的
    public struct LibraryNote: Codable, Hashable, Sendable, Identifiable {
        public struct Made: Codable, Hashable, Sendable {
            public var id: Int
            public var kind: String
            public var category: String
            /// 「🍽 食堂午饭 ¥15 · 在公司食堂」
            public var text: String
        }

        public var id: Int
        public var text: String
        public var createdAt: String
        public var day: String
        /// pending、processing、done、confirm、failed
        public var status: String
        public var result: NoteResult?
        public var error: String?
        public var entries: [Made]
        /// 字面没有搜索词，是按意思找到的
        public var similar: Bool?

        /// 状态那一行要的原话（和对话里的原话一样显示状态）
        public var note: Note {
            Note(id: id, text: text, createdAt: createdAt, day: day, status: status, result: result, error: error)
        }
    }

    public struct LibraryPage: Codable, Hashable, Sendable {
        public var notes: [LibraryNote]
        public var hasMore: Bool
    }

    /// 人、物、地方、话题：常出现的，点一下筛出相关的原话
    public struct Mention: Codable, Hashable, Sendable {
        public var name: String
        /// person、thing、place、tag
        public var kind: String
        public var count: Int
    }

    struct Mentions: Codable {
        var items: [Mention]
    }

    /// 一条感悟（随笔集里的一篇）
    public struct InsightItem: Codable, Hashable, Sendable, Identifiable {
        public var id: Int
        public var day: String
        public var title: String
        public var quote: String
        public var tags: [String]
        public var noteId: Int?
        /// 3.0 语录 ★：收藏的或者「记一句」记的（服务器 2.13.0 起才有）
        public var starred: Bool?
        /// 「记一句」记的
        public var saying: Bool?

        public var isStarred: Bool { starred == true }

        public init(
            id: Int, day: String, title: String, quote: String, tags: [String], noteId: Int?, starred: Bool? = nil,
            saying: Bool? = nil
        ) {
            self.id = id
            self.day = day
            self.title = title
            self.quote = quote
            self.tags = tags
            self.noteId = noteId
            self.starred = starred
            self.saying = saying
        }
    }

    public struct InsightsPage: Codable, Hashable, Sendable {
        public struct TagCount: Codable, Hashable, Sendable {
            public var tag: String
            public var count: Int
        }

        public var insights: [InsightItem]
        public var tags: [TagCount]
        /// 语录几句（「语录 ★」胶囊后面的数）
        public var starred: Int?

        public init(insights: [InsightItem], tags: [TagCount] = [], starred: Int? = nil) {
            self.insights = insights
            self.tags = tags
            self.starred = starred
        }
    }

    /// 3.0 一句感悟带着你当时说的整段话、以前也说过类似的：今天重温（翻过来看）、一条感悟弹层都是它；
    /// ago 是「16 天前你说」。今天重温一句都没有时 insight 是 nil
    public struct InsightDetail: Codable, Hashable, Sendable {
        public var insight: InsightItem?
        public var ago: String?
        public var said: String?
        public var related: [Related]
    }

    /// 好时刻：一条心情记录，带着它来自哪段原话
    public struct Moment: Decodable, Hashable, Sendable, Identifiable {
        public var entry: Entry
        public var noteId: Int?
        public var id: Int { entry.id }

        enum CodingKeys: String, CodingKey { case noteId }

        public init(from decoder: any Decoder) throws {
            entry = try Entry(from: decoder)
            noteId = try decoder.container(keyedBy: CodingKeys.self).decodeIfPresent(Int.self, forKey: .noteId)
        }
    }

    struct Moments: Decodable {
        var moments: [Moment]
    }

    /// 笔记库的筛选：搜什么、哪个类别、哪个人物、从哪天起
    public struct LibraryFilter: Hashable, Sendable {
        public var text = ""
        public var category = ""
        public var tag = ""
        public var from = ""

        public init(text: String = "", category: String = "", tag: String = "", from: String = "") {
            self.text = text
            self.category = category
            self.tag = tag
            self.from = from
        }

        public var isEmpty: Bool { text.isEmpty && category.isEmpty && tag.isEmpty && from.isEmpty }
    }
}

extension APIClient {
    /// 一页原话（新的在前）；before 是往前翻：比这一段早的
    public func library(_ filter: API.LibraryFilter, before: Int?) async throws(APIError) -> API.LibraryPage {
        var query: [URLQueryItem] = []
        if !filter.text.isEmpty { query.append(.init(name: "q", value: filter.text)) }
        if !filter.category.isEmpty { query.append(.init(name: "category", value: filter.category)) }
        if !filter.tag.isEmpty { query.append(.init(name: "tag", value: filter.tag)) }
        if !filter.from.isEmpty { query.append(.init(name: "from", value: filter.from)) }
        if let before { query.append(.init(name: "before", value: String(before))) }
        var parts = URLComponents()
        parts.queryItems = query
        return try await get("/api/library\(query.isEmpty ? "" : "?\(parts.percentEncodedQuery ?? "")")")
    }

    public func mentions() async throws(APIError) -> [API.Mention] {
        let page: API.Mentions = try await get("/api/library/people")
        return page.items
    }

    /// 3.0 感悟页：全部感悟（标签、语录在手机上筛）；query 是搜（关键词 + 按意思，服务器的本地向量）
    public func insights(query: String = "") async throws(APIError) -> API.InsightsPage {
        try await get(Self.insightsPath(query: query))
    }

    /// 「/api/insights」「/api/insights?q=专注」（缓存也按这个地址存）
    public static func insightsPath(query: String = "") -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "/api/insights" }
        let allowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&+=?#"))
        return "/api/insights?q=\(trimmed.addingPercentEncoding(withAllowedCharacters: allowed) ?? trimmed)"
    }

    /// 今天重温的一句；next 是「换一句」
    public func insightToday(next: Bool = false) async throws(APIError) -> API.InsightDetail {
        try await get(next ? "/api/insights/today?next=1" : "/api/insights/today")
    }

    /// 一条感悟：原话、以前也说过类似的
    public func insight(_ id: Int) async throws(APIError) -> API.InsightDetail {
        try await get("/api/insights/\(id)")
    }

    public func moments() async throws(APIError) -> [API.Moment] {
        let page: API.Moments = try await get("/api/moments")
        return page.moments
    }

    /// 改原话：服务器自动重新整理
    public func edit(note id: Int, text: String) async throws(APIError) {
        let _: Empty = try await request("PATCH", "/api/notes/\(id)", body: ["text": text])
    }

    /// 删掉这段话和它的记录（能撤销）
    public func delete(note id: Int) async throws(APIError) {
        let _: Empty = try await request("DELETE", "/api/notes/\(id)")
    }

    public func restore(note id: Int) async throws(APIError) {
        let _: Empty = try await request("POST", "/api/notes/\(id)/restore")
    }
}
