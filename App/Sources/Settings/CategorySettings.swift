import PourAPI
import PourDesign
import SwiftUI

/// 设置页「类别」（网页版 TaxonomySettings.tsx 1 比 1）：整理建议（合并、重新归类、删除）、类别和子类别，
/// 点一个打开它的详情：改名、图标、上级、同义词、颜色、合并到另一个、删除
struct CategorySettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let client = model.client
        Loaded(
            load: { () async throws(APIError) in try await client.categoriesPage() },
            content: { page, reload in
                CategoryList(page: page, reload: reload)
            })
    }
}

private struct CategoryList: View {
    @Environment(AppModel.self) private var model
    let page: API.CategoriesPage
    let reload: () -> Void
    @State private var openKey: String?

    var body: some View {
        let categories = page.categories
        VStack(alignment: .leading, spacing: 0) {
            if let suggestions = page.suggestions, !suggestions.isEmpty {
                SetupBox {
                    Text("整理建议").font(Web.bodyMedium).foregroundStyle(Web.fg)
                    ForEach(suggestions, id: \.self) { suggestion($0, categories) }
                }
                .padding(.bottom, Web.space4)
            }
            ForEach(categories.filter { $0.parent == nil }, id: \.key) { top in
                row(top, child: false)
                ForEach(categories.filter { $0.parent == top.key }, id: \.key) { row($0, child: true) }
            }
            FieldMessage(text: "说到新的活动时，AI 会自动新建类别；这里可以改名、改图标和颜色、合并或删除。")
                .padding(.top, Web.space2)
        }
        .sheet(item: Binding(get: { openKey.map(Key.init) }, set: { openKey = $0?.id })) { key in
            if let category = categories.first(where: { $0.key == key.id }) {
                CategoryEditor(category: category, all: categories) {
                    openKey = nil
                } run: { work, done in
                    run(work, done: done)
                }
            }
        }
    }

    private struct Key: Identifiable {
        let id: String
    }

    /// 一个类别：表情、名字、几条、颜色点；子类别往里缩
    private func row(_ category: API.Category, child: Bool) -> some View {
        Button {
            openKey = category.key
        } label: {
            HStack(spacing: Web.space2) {
                Text(category.emoji).accessibilityHidden(true)
                Text(category.name).foregroundStyle(Web.fg).frame(maxWidth: .infinity, alignment: .leading)
                if let count = category.count, count > 0 {
                    Text("\(count) 条").font(Web.caption).foregroundStyle(Web.fgTertiary)
                }
                Circle().fill(Web.tag(category.color).solid).frame(width: Web.space2, height: Web.space2)
                    .accessibilityHidden(true)
            }
            .font(Web.body)
            .padding(.leading, child ? Web.space8 : Web.space2)
            .padding(.trailing, Web.space2)
            .frame(minHeight: Web.touch)
        }
        .buttonStyle(WebPressStyle(radius: Web.radiusControl))
        .padding(.horizontal, -Web.space2)
    }

    @ViewBuilder private func suggestion(_ item: API.CategorySuggestion, _ all: [API.Category]) -> some View {
        HStack(spacing: Web.space2) {
            Text(Show.spaced(item.text)).font(Web.body).foregroundStyle(Web.fgSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            switch item.kind {
            case "merge":
                WebTextButton("合并") { merge(item.keys, all) }
            case "tidy-other":
                WebTextButton("重新归类") {
                    run(done: "正在重新归类，完成后记录会自动更新") { try await $0.tidyOther() }
                }
            default:
                WebTextButton("删除") {
                    let key = item.keys.first ?? ""
                    run(done: "已删除这个类别") { try await $0.deleteCategory(key) }
                }
            }
        }
    }

    /// 合并建议：把用得少的合并到用得多的
    private func merge(_ keys: [String], _ all: [API.Category]) {
        let pair = keys.compactMap { key in all.first { $0.key == key } }
        guard pair.count == 2 else { return }
        let (from, into) = (pair[0].count ?? 0) >= (pair[1].count ?? 0) ? (pair[1], pair[0]) : (pair[0], pair[1])
        run(done: "已把「\(from.name)」合并到「\(into.name)」") { try await $0.mergeCategory(from.key, into: into.key) }
    }

    private func run(done: String, _ work: @escaping @Sendable (APIClient) async throws -> Void) {
        run(work, done: done)
    }

    private func run(_ work: @escaping @Sendable (APIClient) async throws -> Void, done: String) {
        let client = model.client
        Task {
            do {
                try await work(client)
                reload()
                await model.refreshAll()
                model.toast(done)
            } catch {
                model.toast(error.readable)
            }
        }
    }
}

/// 一个类别的详情（网页版 CategoryEditor，在 Peek 里）
private struct CategoryEditor: View {
    let category: API.Category
    let all: [API.Category]
    let close: () -> Void
    let run: (_ work: @escaping @Sendable (APIClient) async throws -> Void, _ done: String) -> Void
    @State private var into = ""

    var body: some View {
        WebPeek(title: "\(category.emoji) \(category.name)") {
            VStack(alignment: .leading, spacing: Web.space6) {
                fields
                colors
                mergeSection
                if category.key != "other" {
                    VStack(alignment: .leading, spacing: Web.space1) {
                        WebTextButton("删除这个类别", color: Web.danger) {
                            let key = category.key
                            run({ client in try await client.deleteCategory(key) }, "已删除这个类别")
                            close()
                        }
                        FieldMessage(text: "记录不会删掉，会归到\(category.parent == nil ? "「其他」" : "上级类别")。")
                    }
                }
            }
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 0) {
            PeekRow(label: "名称") {
                InlineEdit(label: "名称", value: category.name) { patch(["name": .string($0.trimmed)]) }
            }
            PeekRow(label: "图标") {
                InlineEdit(label: "图标（一个 emoji）", value: category.emoji) { patch(["emoji": .string($0.trimmed)]) }
            }
            PeekRow(label: "上级类别") {
                let parents = all.filter { $0.parent == nil && $0.key != category.key }
                Picker(
                    "上级类别",
                    selection: Binding(
                        get: { category.parent ?? "" },
                        set: { value in
                            patch(["parent": value.isEmpty ? .null : .string(value)])
                        })
                ) {
                    Text("（顶级类别）").tag("")
                    ForEach(parents, id: \.key) { Text("\($0.emoji) \($0.name)").tag($0.key) }
                }
                .disabled(all.contains { $0.parent == category.key })
            }
            PeekRow(label: "同义词") {
                InlineEdit(
                    label: "同义词（用逗号分开）", value: (category.synonyms ?? []).joined(separator: "，"), placeholder: "没有"
                ) { text in
                    let words = text.split { ",，、 \n".contains($0) }.map { JSONValue.string(String($0)) }
                    patch(["synonyms": .array(words)])
                }
            }
            PeekRow(label: "计量") {
                Text(["duration": "看时长", "count": "看次数"][category.measure] ?? "看\(category.measure)")
            }
        }
    }

    private var colors: some View {
        PeekSection(title: "颜色") {
            HStack(spacing: Web.space2) {
                ForEach(Web.tagNames, id: \.self) { name in
                    Button {
                        patch(["color": .string(name)])
                    } label: {
                        Circle().fill(Web.tag(name).solid).frame(width: Web.space6, height: Web.space6)
                            .padding(Web.space1)
                            .overlay {
                                if category.color == name {
                                    Circle().strokeBorder(Web.fgTertiary, lineWidth: 2)
                                }
                            }
                            .frame(minWidth: Web.touch, minHeight: Web.touch)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(name))
                    .accessibilityAddTraits(category.color == name ? [.isSelected] : [])
                }
            }
        }
    }

    private var mergeSection: some View {
        PeekSection(title: "合并到另一个类别") {
            HStack(spacing: Web.space3) {
                Picker("合并到", selection: $into) {
                    Text("选一个类别").tag("")
                    ForEach(all.filter { $0.key != category.key }, id: \.key) { other in
                        Text("\(other.parent == nil ? "" : "　")\(other.emoji) \(other.name)").tag(other.key)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                WebButton("合并", disabled: into.isEmpty) {
                    let (key, target) = (category.key, into)
                    let name = all.first { $0.key == target }?.name ?? ""
                    run({ client in try await client.mergeCategory(key, into: target) }, "已合并到「\(name)」")
                    close()
                }
            }
            FieldMessage(text: "它的记录会归到目标类别，「\(category.name)」会成为目标类别的同义词。")
        }
    }

    private func patch(_ fields: [String: JSONValue]) {
        let key = category.key
        run({ client in try await client.updateCategory(key, fields) }, "已修改")
    }
}

extension String {
    fileprivate var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
