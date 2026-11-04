import PourAPI
import PourDesign
import SwiftUI

/// 设置页「类别」：整理建议（合并、重新归类、删除）、类别和子类别，
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
        // 照原型：说明在最上面；整理建议一张浅蓝的卡；类别一张白卡，一行一个，中间细线
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            FieldMessage(text: "说到新的活动时，AI 会自动新建类别；这里可以改名、改图标和颜色、合并或删除。")
                .padding(.horizontal, Theme.Space.tight)
            if let suggestions = page.suggestions, !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Space.medium) {
                    Text("整理建议").font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                    ForEach(suggestions, id: \.self) { suggestion($0, categories) }
                }
                .padding(Theme.Space.regular)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Palette.remindFill, in: Theme.rounded(Theme.Corner.stat))
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows(categories).enumerated()), id: \.element.category.key) { index, item in
                    if index > 0 { Divider().padding(.leading, Self.textInset) }
                    row(item.category, child: item.child)
                }
            }
            .settingsCard()
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

    /// 顶级类别后面跟着它的子类别
    private func rows(_ all: [API.Category]) -> [(category: API.Category, child: Bool)] {
        all.filter { $0.parent == nil }.flatMap { top in
            [(top, false)] + all.filter { $0.parent == top.key }.map { ($0, true) }
        }
    }

    /// 名字从哪里开始（小方块 + 间距）：细线和子类别都从这里起
    private static let textInset = Theme.Size.tile + Theme.Space.medium

    /// 一个类别（照原型）：左边它颜色的实心小方块和白图标、名字、右边「41 条 ›」；
    /// 子类别没有小方块，「└ 跑步」灰一点、对齐上面的名字
    private func row(_ category: API.Category, child: Bool) -> some View {
        Button {
            openKey = category.key
        } label: {
            HStack(spacing: Theme.Space.medium) {
                if child {
                    Text("└ \(category.name)").font(Theme.Typeface.subheadline)
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    IconTile(
                        symbol: CategoryIcon.symbol(key: category.key, name: category.name), emoji: category.emoji,
                        color: Theme.tag(category.color))
                    Text(category.name).foregroundStyle(Theme.Palette.label)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let count = category.count {
                    Text("\(count) 条").font(Theme.Typeface.subheadline).monospacedDigit()
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                }
                Image(systemName: "chevron.right").font(Theme.Typeface.footnoteSemibold)
                    .foregroundStyle(Theme.Palette.tertiaryLabel).accessibilityHidden(true)
            }
            .font(Theme.Typeface.body)
            .padding(.leading, child ? Self.textInset : 0)
            .frame(minHeight: Theme.Size.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 一条建议（照原型）：一段话，下面一个浅蓝的小胶囊按钮（合并 / 重新归类 / 删除）
    @ViewBuilder private func suggestion(_ item: API.CategorySuggestion, _ all: [API.Category]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            Text(Show.spaced(item.text)).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.label)
                .lineSpacing(Theme.Leading.body).fixedSize(horizontal: false, vertical: true)
            switch item.kind {
            case "merge":
                chip("合并") { merge(item.keys, all) }
            case "tidy-other":
                chip("重新归类") { run(done: "正在重新归类，完成后记录会自动更新") { try await $0.tidyOther() } }
            default:
                chip("删除") {
                    let key = item.keys.first ?? ""
                    run(done: "已删除这个类别") { try await $0.deleteCategory(key) }
                }
            }
        }
    }

    private func chip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.accent)
                .padding(.horizontal, Theme.Space.medium).frame(minHeight: Theme.Size.capsule)
                .background(Theme.Palette.bubble, in: Capsule())
                .frame(minHeight: Theme.Size.touch).contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
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

/// 一个类别的详情（在 Peek 里）
private struct CategoryEditor: View {
    let category: API.Category
    let all: [API.Category]
    let close: () -> Void
    let run: (_ work: @escaping @Sendable (APIClient) async throws -> Void, _ done: String) -> Void
    @State private var into = ""

    var body: some View {
        DetailPeek(title: "\(category.emoji) \(category.name)") {
            VStack(alignment: .leading, spacing: Theme.Space.xLarge) {
                fields
                colors
                mergeSection
                if category.key != "other" {
                    VStack(alignment: .leading, spacing: Theme.Space.tight) {
                        ThemeTextButton("删除这个类别", font: Theme.Typeface.bodyMedium, color: Theme.Palette.bad) {
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
            HStack(spacing: Theme.Space.small) {
                ForEach(Theme.tagNames, id: \.self) { name in
                    Button {
                        patch(["color": .string(name)])
                    } label: {
                        Circle().fill(Theme.tag(name).solid).frame(
                            width: Theme.Space.xLarge, height: Theme.Space.xLarge
                        )
                        .padding(Theme.Space.tight)
                        .overlay {
                            if category.color == name {
                                Circle().strokeBorder(Theme.Palette.secondaryLabel, lineWidth: 2)
                            }
                        }
                        .frame(minWidth: Theme.Size.touch, minHeight: Theme.Size.touch)
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
            HStack(spacing: Theme.Space.medium) {
                Picker("合并到", selection: $into) {
                    Text("选一个类别").tag("")
                    ForEach(all.filter { $0.key != category.key }, id: \.key) { other in
                        Text("\(other.parent == nil ? "" : "　")\(other.emoji) \(other.name)").tag(other.key)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ThemeButton("合并", disabled: into.isEmpty) {
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
