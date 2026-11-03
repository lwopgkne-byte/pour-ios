import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 笔记库的筛选（docs/3.0/01-需求文档.md 第 11 章、06 交互细节「人物地方带条数」）：时间、类别、人和地方、状态，
/// 每一样后面写几段（照别的筛选条件算）；
/// 下面「看 N 段」。筛了的在笔记库上面是一排胶囊，点一个去掉它
struct LibraryFilterSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: API.LibraryFilter
    @State private var draft = API.LibraryFilter()
    @State private var facets: API.LibraryFacets?
    /// 人在前、地方在后（旧 App 就能按地方筛；3.0 收尾补上）
    @State private var mentions: [API.Mention] = []

    /// 时间：从哪天起（空是全部）
    private var ranges: [(key: String, label: String)] {
        [
            ("", "全部"), (PourDate.addDays(model.today, -6), "最近 7 天"), (PourDate.addDays(model.today, -29), "最近 30 天"),
            (String(model.today.prefix(4)) + "-01-01", "今年"),
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.regular) {
                    group("时间") {
                        ForEach(ranges, id: \.key) { range in
                            FilterChip(range.label, selected: draft.from == range.key) { draft.from = range.key }
                        }
                    }
                    if let facets, !facets.categories.isEmpty {
                        group("类别") {
                            FilterChip("全部", selected: draft.category.isEmpty) { draft.category = "" }
                            ForEach(facets.categories, id: \.key) { item in
                                FilterChip("\(item.name)", count: item.count, selected: draft.category == item.key) {
                                    draft.category = draft.category == item.key ? "" : item.key
                                }
                            }
                        }
                    }
                    if !mentions.isEmpty {
                        group("人和地方") {
                            FilterChip("全部", selected: draft.tag.isEmpty) { draft.tag = "" }
                            ForEach(mentions, id: \.name) { item in
                                FilterChip(item.name, count: item.count, selected: draft.tag == item.name) {
                                    draft.tag = draft.tag == item.name ? "" : item.name
                                }
                            }
                        }
                    }
                    if let facets {
                        group("状态") {
                            FilterChip("全部", selected: draft.status.isEmpty) { draft.status = "" }
                            ForEach(facets.status, id: \.key) { item in
                                FilterChip(item.label, count: item.count, selected: draft.status == item.key) {
                                    draft.status = draft.status == item.key ? "" : item.key
                                }
                            }
                        }
                    }
                }
                .padding(Theme.Space.screen)
            }
            .background(Theme.Palette.background)
            .navigationTitle("筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("清除") { draft = API.LibraryFilter(text: filter.text) }.accessibilityIdentifier(
                        "filter.clear")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(facets.map { "看 \($0.total) 段" } ?? "好") {
                        filter = draft
                        dismiss()
                    }
                    .accessibilityIdentifier("filter.done")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task {
            draft = filter
            let all = (try? await model.client.mentions()) ?? []
            mentions =
                Array(all.filter { $0.kind == "person" }.prefix(12)) + all.filter { $0.kind == "place" }.prefix(8)
        }
        .task(id: draft) { facets = try? await model.client.libraryFacets(draft) }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Text(title).font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.secondaryLabel)
                .accessibilityAddTraits(.isHeader)
            PourFlowLayout(spacing: Theme.Space.small, lineSpacing: Theme.Space.small) { content() }
        }
    }

    /// 筛了什么（笔记库上面那排胶囊）：key 是哪一样
    static func labels(_ filter: API.LibraryFilter, _ categories: [API.Category]) -> [(key: String, label: String)] {
        var out: [(key: String, label: String)] = []
        if !filter.text.isEmpty { out.append(("text", "「\(filter.text)」")) }
        if !filter.from.isEmpty { out.append(("from", "\(Show.monthDay(filter.from))起")) }
        if !filter.category.isEmpty { out.append(("category", Show.meta(filter.category, categories).name)) }
        if !filter.tag.isEmpty { out.append(("tag", filter.tag)) }
        if !filter.status.isEmpty {
            let names = ["done": "已整理", "confirm": "待确认", "pending": "待处理", "failed": "失败"]
            out.append(("status", names[filter.status] ?? filter.status))
        }
        return out
    }

    /// 去掉一样
    static func clear(_ key: String, in filter: API.LibraryFilter) -> API.LibraryFilter {
        var out = filter
        switch key {
        case "text": out.text = ""
        case "from": out.from = ""
        case "category": out.category = ""
        case "tag": out.tag = ""
        default: out.status = ""
        }
        return out
    }
}

/// 改原话：改完自动重新整理（以前整理出的撤掉）
struct NoteEditSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let note: API.LibraryNote
    @State private var text = ""
    @FocusState private var typing: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Space.medium) {
                TextField("原话", text: $text, axis: .vertical).font(Theme.Typeface.quote).lineLimit(3...12)
                    .focused($typing)
                    .padding(Theme.Space.medium)
                    .background(
                        Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Corner.chip, style: .continuous)
                    )
                    .accessibilityIdentifier("note.edit.field")
                Text("改完会照新的原话重新整理，以前整理出的记录撤掉。").font(Theme.Typeface.footnote)
                    .foregroundStyle(Theme.Palette.secondaryLabel)
                Spacer()
            }
            .padding(Theme.Space.screen)
            .background(Theme.Palette.background)
            .navigationTitle("改原话")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text == note.text)
                        .accessibilityIdentifier("note.edit.save")
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            text = note.text
            typing = true
        }
    }

    private func save() {
        let client = model.client
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        dismiss()
        Task {
            do throws(APIError) {
                try await client.edit(note: note.id, text: value)
                model.dataChanged()
                model.toast("已修改，正在重新整理")
            } catch {
                model.toast(error.message)
            }
        }
    }
}
