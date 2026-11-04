import PourAPI
import PourDesign
import SwiftUI

/// 笔记库（3.0 第 9 步，docs/3.0/01-需求文档.md 第 11 章、06 交互细节 10.7）：所有原话，新的在前，按天分组的卡片、
/// 组头吸顶（「今天 · 10月27日 周二　看这一天 ›」）；搜索（关键词 + 按意思）；右上角筛选（时间、类别、人、状态，带条数）
/// → 一排胶囊 + 清除筛选；原话 · 好时刻两栏（感悟搬到了「我的 → 感悟」）
struct LibraryPage3: View {
    @Environment(AppModel.self) private var model
    @State private var view: String
    /// 从一条来源原话跳过来（回顾、详情里的「原话」）：从那一段开始往前看
    @State private var focus: Int?
    @State private var filter: API.LibraryFilter
    @State private var text = ""
    @State private var notes: [API.LibraryNote]?
    @State private var hasMore = false
    @State private var loadingMore = false
    @State private var problem: String?
    @State private var filtering = false
    @State private var open: Int?
    @State private var editing: API.LibraryNote?

    /// 地址里带着的（「/library?note=12」「/library?view=moments」「/library?tag=小王」「/library?q=儿子」）
    init(ask: LibraryAsk) {
        _view = State(initialValue: ask.view)
        _focus = State(initialValue: ask.note)
        _filter = State(initialValue: API.LibraryFilter(text: ask.query, tag: ask.tag))
        _text = State(initialValue: ask.query)
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                header.listRowBackground(Color.clear).listRowSeparator(.hidden)
                    .listRowInsets(
                        EdgeInsets(top: 0, leading: Theme.Space.screen, bottom: 0, trailing: Theme.Space.screen))
                if view == "moments" {
                    MomentsView { id in
                        view = "notes"
                        focus = id
                    }
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                } else {
                    notesSections
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: notes?.count ?? 0) {
                guard let focus, notes?.contains(where: { $0.id == focus }) == true else { return }
                withAnimation(Theme.Motion.standard) { proxy.scrollTo(focus, anchor: .center) }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    filtering = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease").font(Theme.Typeface.toolbarIcon)
                }
                .accessibilityLabel(Text("筛选"))
                .accessibilityIdentifier("library.filter")
            }
        }
        .sheet(isPresented: $filtering) { LibraryFilterSheet(filter: $filter) }
        .sheet(item: $editing) { NoteEditSheet(note: $0) }
        .refreshable { await load() }
        .task(id: "\(filter)-\(focus ?? 0)-\(model.dataVersion)") { await load() }
    }

    // MARK: - 上面：两栏、去感悟、搜索框、筛选的胶囊

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Picker("看哪一栏", selection: $view) {
                Text("原话").tag("notes")
                Text("好时刻").tag("moments")
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("library.view")
            HStack(spacing: Theme.Space.tight) {
                Text("感悟搬到了「我的 → 感悟」").font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                LinkButton("去看 ›", identifier: "library.insights") { model.open("/insights") }
            }
            if view == "notes" {
                search
                if !filter.isEmpty { activeFilters }
                // 从一段来源原话跳过来的：从那一段开始往前看，点了回到最新的
                if focus != nil {
                    LinkButton("看最新的", identifier: "library.latest") { focus = nil }
                }
            }
        }
        .padding(.bottom, Theme.Space.small)
    }

    private var search: some View {
        HStack(spacing: Theme.Space.small) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.Palette.secondaryLabel).accessibilityHidden(true)
            TextField("搜说过的话（按意思也能找到）", text: $text).font(Theme.Typeface.body)
                .submitLabel(.search)
                .onSubmit { filter.text = text.trimmingCharacters(in: .whitespaces) }
                .accessibilityIdentifier("library.search")
            if !text.isEmpty {
                Button {
                    text = ""
                    filter.text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.Palette.tertiaryLabel)
                        .frame(width: Theme.Size.touch, height: Theme.Size.touch)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("清空搜索"))
            }
        }
        .padding(.leading, Theme.Space.medium)
        .frame(minHeight: Theme.Size.touch)
        .background(Theme.Palette.fill, in: RoundedRectangle(cornerRadius: Theme.Corner.chip, style: .continuous))
    }

    /// 筛了什么：一排胶囊（点一个去掉它）+ 清除筛选
    private var activeFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.small) {
                ForEach(LibraryFilterSheet.labels(filter, model.categories), id: \.key) { item in
                    FilterChip("\(item.label) ✕", selected: true) {
                        filter = LibraryFilterSheet.clear(item.key, in: filter)
                    }
                }
                LinkButton("清除筛选", identifier: "library.clear") {
                    text = ""
                    filter = API.LibraryFilter()
                }
            }
        }
    }

    // MARK: - 原话：按天分组的卡片

    @ViewBuilder private var notesSections: some View {
        if let notes {
            if notes.isEmpty {
                Text(filter.isEmpty ? "还没有说过话。在下面的输入框里说点什么吧。" : "没有找到。换个说法，或者清除筛选试试。")
                    .font(Theme.Typeface.body).foregroundStyle(Theme.Palette.secondaryLabel)
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            ForEach(Self.byDay(notes), id: \.day) { group in
                Section {
                    ForEach(Array(group.notes.enumerated()), id: \.element.id) { index, note in
                        row(note, first: index == 0, last: index == group.notes.count - 1)
                    }
                } header: {
                    dayHeader(group.day)
                }
            }
            if hasMore {
                ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear).listRowSeparator(.hidden)
                    .task { await more() }
            }
        } else if let problem {
            ErrorState(problem.contains("连") ? .serverOff : .other) { Task { await load() } }
                .listRowBackground(Color.clear).listRowSeparator(.hidden)
        } else {
            ProgressView().frame(maxWidth: .infinity, minHeight: Theme.Size.goalCard)
                .listRowBackground(Color.clear).listRowSeparator(.hidden)
        }
    }

    private func row(_ note: API.LibraryNote, first: Bool, last: Bool) -> some View {
        LibraryRow3(
            note: note, highlight: filter.text, open: open == note.id,
            toggle: { withAnimation(Theme.Motion.standard) { open = open == note.id ? nil : note.id } },
            edit: { editing = note }
        )
        .overlay(alignment: .top) { if !first { Divider() } }
        .listRowInsets(
            EdgeInsets(
                top: 0, leading: Theme.Space.screen + Theme.Space.inset, bottom: last ? Theme.Space.small : 0,
                trailing: Theme.Space.screen + Theme.Space.inset)
        )
        .listRowBackground(LibraryRowCard(first: first, last: last))
        .listRowSeparator(.hidden)
        .id(note.id)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                LibraryRow3.remove(note, model)
            } label: {
                Label("删除", systemImage: "trash")
            }
            .tint(Theme.Palette.bad)
            Button {
                LibraryRow3.reorganize(note, model)
            } label: {
                Label("重新整理", systemImage: "arrow.clockwise")
            }
            .tint(Theme.Palette.accent)
        }
        .contextMenu {
            Button("复制", systemImage: "doc.on.doc") { UIPasteboard.general.string = note.text }
            Button("改原话", systemImage: "pencil") { editing = note }
            Button("看这一天", systemImage: "calendar") { LibraryRow3.showDay(note.day, model) }
            if let first = note.entries.first {
                Button("看整理出的", systemImage: "list.bullet.rectangle") { model.openEntry(first.id, day: note.day) }
            }
        }
    }

    /// 组头（吸顶）：「今天 · 10月27日 周二」+「看这一天 ›」
    private func dayHeader(_ day: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(
                ([Show.relative(day, today: model.today)].compactMap { $0 } + [Show.dayTitle(day, today: model.today)])
                    .joined(separator: " · ")
            )
            .font(Theme.Typeface.footnoteSemibold).foregroundStyle(Theme.Palette.label)
            .accessibilityAddTraits(.isHeader)
            Spacer()
            LinkButton("看这一天 ›", identifier: "library.day.\(day)") { LibraryRow3.showDay(day, model) }
        }
        .padding(.horizontal, Theme.Space.screen)
        .frame(maxWidth: .infinity)
        .background(Theme.Palette.background)
        .listRowInsets(EdgeInsets())
    }

    static func byDay(_ notes: [API.LibraryNote]) -> [(day: String, notes: [API.LibraryNote])] {
        var out: [(day: String, notes: [API.LibraryNote])] = []
        for note in notes {
            if let last = out.indices.last, out[last].day == note.day {
                out[last].notes.append(note)
            } else {
                out.append((note.day, [note]))
            }
        }
        return out
    }

    private func load() async {
        do throws(APIError) {
            let page = try await model.client.library(filter, before: focus.map { $0 + 1 })
            notes = page.notes
            hasMore = page.hasMore
            problem = nil
        } catch {
            if notes == nil { problem = error.message }
        }
    }

    private func more() async {
        guard !loadingMore, let last = notes?.last?.id else { return }
        loadingMore = true
        defer { loadingMore = false }
        if let page = try? await model.client.library(filter, before: last) {
            notes = (notes ?? []) + page.notes.filter { new in !(notes ?? []).contains { $0.id == new.id } }
            hasMore = page.hasMore
        }
    }
}
