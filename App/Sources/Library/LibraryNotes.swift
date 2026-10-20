import PourAPI
import PourCore
import PourDesign
import SwiftUI

/// 原话：搜索（按意思也能找到）、时间、类别、人物筛选；按天分组，每天一个清楚的标题，
/// 「看这一天」只出现一次；一页一页往前翻（「更早的」）
struct NotesView: View {
    @Environment(AppModel.self) private var model
    @Binding var focus: Int?
    @Binding var tag: String
    /// 滚到那一段（从来源原话跳过来时）
    let reveal: (Int) -> Void
    @State private var text = ""
    @State private var searched = ""
    @State private var category = ""
    @State private var range = "all"
    @State private var notes: [API.LibraryNote]?
    @State private var hasMore = false
    @State private var loadingMore = false
    @State private var problem: String?
    @State private var mentions: [API.Mention] = []
    @FocusState private var searching: Bool

    /// 时间范围的快捷选项：几天前起（nil 是全部）
    private struct Range {
        let key: String
        let label: String
        let days: Int?
    }

    private static let ranges = [
        Range(key: "all", label: "全部", days: nil), Range(key: "today", label: "今天", days: 0),
        Range(key: "7", label: "最近 7 天", days: 6), Range(key: "30", label: "最近 30 天", days: 29),
    ]
    /// 类别筛选里的一项
    private struct CategoryChip {
        let key: String
        let name: String
        let emoji: String
    }

    /// 人、物、地方、话题的小图标
    private static let icons = ["person": "👤", "thing": "📦", "place": "📍", "tag": "#"]

    private var filter: API.LibraryFilter {
        let days = Self.ranges.first { $0.key == range }?.days
        return .init(
            text: searched, category: category, tag: tag, from: days.map { PourDate.addDays(model.today, -$0) } ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            search
            filters
            notice
            list.padding(.top, Web.space6)
        }
        .padding(.top, Web.space6)
        .task(id: "\(filter)-\(focus ?? 0)-\(model.dataVersion)") { await load() }
        .task(id: model.dataVersion) { mentions = (try? await model.client.mentions()) ?? [] }
        .task(id: text) {
            // 停下来 0.3 秒再搜
            try? await Task.sleep(for: .milliseconds(300))
            if !Task.isCancelled { searched = text.trimmingCharacters(in: .whitespaces) }
        }
    }

    private var search: some View {
        HStack(spacing: Web.space2) {
            Image(systemName: "magnifyingglass").foregroundStyle(Web.fgTertiary).accessibilityHidden(true)
            TextField("搜索说过的话（按意思也能找到）", text: $text, axis: .vertical).font(Web.body).foregroundStyle(Web.fg)
                .submitLabel(.search)
                // 能折行（字很大时提示不被截断），但回车不换行：收起键盘
                .onChange(of: text) { _, now in
                    if now.contains("\n") {
                        text = now.replacing("\n", with: "")
                        searching = false
                    }
                }
                .focused($searching)
                .accessibilityLabel(Text("搜索笔记库"))
        }
        .padding(.horizontal, Web.space3)
        .frame(minHeight: Web.touch)
        .background(RoundedRectangle(cornerRadius: Web.radiusControl).fill(Web.bgSubtle))
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 0) {
            ChipRow(label: "时间") {
                ForEach(Self.ranges, id: \.key) { item in
                    WebChip(selected: range == item.key) {
                        range = item.key
                    } label: {
                        Text(item.label)
                    }
                }
            }
            ChipRow(label: "类别") {
                ForEach(categoryChips, id: \.key) { item in
                    WebChip(selected: category == item.key) {
                        category = category == item.key ? "" : item.key
                    } label: {
                        Text(item.emoji).accessibilityHidden(true)
                        Text(item.name)
                    }
                }
            }
            if !mentions.isEmpty {
                ChipRow(label: "人、物、地方") {
                    ForEach(mentions, id: \.self) { item in
                        WebChip(selected: tag == item.name) {
                            tag = tag == item.name ? "" : item.name
                        } label: {
                            Text(Self.icons[item.kind] ?? "").accessibilityHidden(true)
                            Text(item.name)
                            Text("\(item.count)").foregroundStyle(Web.fgTertiary)
                        }
                    }
                }
            }
        }
    }

    /// 类别只列出用过的顶级类别（子类别的记录也算上级的），加上感悟、待办、心情
    private var categoryChips: [CategoryChip] {
        let cats = model.categories
        func used(_ key: String) -> Int {
            (cats.first { $0.key == key }?.count ?? 0)
                + cats.filter { $0.parent == key }.reduce(0) { $0 + used($1.key) }
        }
        let tops = cats.filter { $0.parent == nil && used($0.key) > 0 }.map {
            CategoryChip(key: $0.key, name: $0.name, emoji: $0.emoji)
        }
        let kinds = ["insight", "todo", "mood"].map { key in
            let meta = Show.meta(key, cats)
            return CategoryChip(key: key, name: meta.name, emoji: meta.emoji)
        }
        return tops + kinds
    }

    @ViewBuilder private var notice: some View {
        if focus != nil {
            HStack(spacing: Web.space1) {
                Text("从一条来源原话跳过来的。")
                WebTextButton("看最新的", font: Web.captionMedium) { focus = nil }
            }
            .font(Web.caption).foregroundStyle(Web.fgTertiary)
            .padding(.top, Web.space4)
        }
        if !filter.isEmpty || range != "all", let notes {
            HStack(spacing: Web.space3) {
                Text(hasMore ? "找到 \(notes.count) 段以上" : "找到 \(notes.count) 段")
                WebTextButton("清除筛选", font: Web.captionMedium) {
                    text = ""
                    searched = ""
                    category = ""
                    tag = ""
                    range = "all"
                }
            }
            .font(Web.caption).foregroundStyle(Web.fgTertiary)
            .padding(.top, Web.space4)
        }
    }

    @ViewBuilder private var list: some View {
        if let notes {
            if notes.isEmpty {
                Text(filter.isEmpty ? "还没有说过话。在下面的输入框里说点什么吧。" : "没有找到。换个说法，或者清除筛选试试。")
                    .font(Web.body).foregroundStyle(Web.fgTertiary)
            } else {
                VStack(alignment: .leading, spacing: Web.space8) {
                    ForEach(Self.byDay(notes), id: \.day) { group in
                        DayNotes(day: group.day, notes: group.notes, focus: focus, highlight: searched)
                    }
                    if hasMore {
                        WebButton("更早的", variant: .ghost, loading: loadingMore) { Task { await more() } }
                    }
                }
            }
        } else if let problem {
            WebErrorState(problem) { Task { await load() } }
        } else {
            VStack(alignment: .leading, spacing: Web.space6) {
                WebSkeleton(height: Web.space4).containerRelativeFrame(.horizontal) { width, _ in width / 3 }
                WebSkeleton(height: Web.space4).containerRelativeFrame(.horizontal) { width, _ in width * 2 / 3 }
                WebSkeleton(height: Web.space4).containerRelativeFrame(.horizontal) { width, _ in width / 2 }
            }
            .accessibilityHidden(true)
        }
    }

    /// 按天分组：同一天永远只有一组；组按日期从新到旧，组里按说话的时间从新到旧
    static func byDay(_ notes: [API.LibraryNote]) -> [(day: String, notes: [API.LibraryNote])] {
        Dictionary(grouping: notes, by: \.day).sorted { $0.key > $1.key }
            .map { (day: $0.key, notes: $0.value.sorted { $0.createdAt > $1.createdAt }) }
    }

    private func load() async {
        do {
            // 从一条来源原话跳过来：从那一条开始往前看
            let page = try await model.client.library(filter, before: focus.map { $0 + 1 })
            notes = page.notes
            hasMore = page.hasMore
            problem = nil
            if let focus {
                try? await Task.sleep(for: .milliseconds(100))
                reveal(focus)
            }
        } catch {
            problem = error.readable
        }
    }

    private func more() async {
        guard let last = notes?.last?.id else { return }
        loadingMore = true
        defer { loadingMore = false }
        do {
            let page = try await model.client.library(filter, before: last)
            notes = (notes ?? []) + page.notes.filter { new in !(notes ?? []).contains { $0.id == new.id } }
            hasMore = page.hasMore
        } catch {
            model.toast(error.readable)
        }
    }
}

/// 一排能按下的小标签：放不下就横着滑
private struct ChipRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Web.space2) { content() }
                .padding(.vertical, (Web.touch - Web.control) / 2)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .padding(.top, Web.space3 - (Web.touch - Web.control) / 2)
        .padding(.bottom, -(Web.touch - Web.control) / 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(label))
    }
}
