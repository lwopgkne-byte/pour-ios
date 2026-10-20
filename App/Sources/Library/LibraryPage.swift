import PourAPI
import PourDesign
import SwiftUI

/// 笔记库（规格 11）：所有原话，新的在前；能搜、按时间、类别、人物筛；
/// 每段原话下面是它整理出的记录和处理状态；能原地改（自动重新整理）、删。
/// 「感悟」像一本会自己整理的随笔集；「好时刻」是你说过觉得好的那一刻
struct LibraryPage: View {
    @Environment(AppModel.self) private var model
    @State private var view = "notes"
    /// 从一条来源原话跳过来（回顾、详情里的「原话」）：从那一段开始往前看
    @State private var focus: Int?
    /// 从「关于我」跳过来带着的人物
    @State private var tag = ""

    private static let views = [
        (key: "notes", label: "原话"), (key: "insights", label: "感悟"), (key: "moments", label: "好时刻"),
    ]

    var body: some View {
        ScrollViewReader { proxy in
            page { id in withAnimation(Web.panel) { proxy.scrollTo(id, anchor: .center) } }
        }
        .onAppear { follow(model.pagePath) }
        .onChange(of: model.pagePath) { _, path in follow(path) }
    }

    private func page(reveal: @escaping (Int) -> Void) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("笔记库").font(Web.title).foregroundStyle(Web.fg).accessibilityAddTraits(.isHeader)
                WebSegmented("视图", options: Self.views, selected: view) { picked in
                    withAnimation(Web.fast) { view = picked }
                }
                .padding(.top, Web.space4)
                switch view {
                case "insights": InsightsView { open(note: $0) }
                case "moments": MomentsView { open(note: $0) }
                default: NotesView(focus: $focus, tag: $tag, reveal: reveal)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Web.space4)
            .padding(.top, Web.space4)
            .padding(.bottom, Web.space12)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    /// 「原话」：回到原话那一栏，从那一段开始看
    private func open(note id: Int) {
        withAnimation(Web.fast) {
            view = "notes"
            focus = id
        }
    }

    /// 「/library?note=12」「/library?view=insights」「/library?tag=小王」
    private func follow(_ path: String?) {
        guard let path, path.hasPrefix("/library") else { return }
        model.pagePath = nil
        let query = URLComponents(string: path)?.queryItems ?? []
        let value = { (name: String) in query.first { $0.name == name }?.value }
        view = value("view").flatMap { ["insights", "moments"].contains($0) ? $0 : nil } ?? "notes"
        focus = value("note").flatMap(Int.init)
        tag = value("tag") ?? ""
    }
}

/// 一个月一组的标题（「2026年10月」）：感悟、好时刻按月分组
struct LibraryMonth: View {
    let title: String

    var body: some View {
        Text(title).font(Web.body).foregroundStyle(Web.fg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, Web.space2)
            .overlay(alignment: .bottom) { Rectangle().fill(Web.line).frame(height: 1) }
            .padding(.bottom, Web.space1)
            .accessibilityAddTraits(.isHeader)
    }

    /// 「2026-10-15」→「2026年10月」
    static func of(_ day: String) -> String { "\(day.prefix(4))年\(Int(day.dropFirst(5).prefix(2)) ?? 0)月" }

    /// 按月分组，保持原来的顺序（新的在前）
    static func group<Item>(_ items: [Item], day: (Item) -> String) -> [(month: String, items: [Item])] {
        var out: [(month: String, items: [Item])] = []
        for item in items {
            let month = of(day(item))
            if let last = out.indices.last, out[last].month == month {
                out[last].items.append(item)
            } else {
                out.append((month, [item]))
            }
        }
        return out
    }
}

/// 感悟：按标签浏览所有感悟，像一本会自己整理的随笔集
private struct InsightsView: View {
    @Environment(AppModel.self) private var model
    let openNote: (Int) -> Void
    @State private var tag: String?
    @State private var page: API.InsightsPage?
    @State private var problem: String?

    var body: some View {
        Group {
            if let page {
                if page.insights.isEmpty && tag == nil {
                    LibraryEmpty(text: "还没有感悟。说说你的想法和体会，它们会被收在这里。")
                } else {
                    content(page)
                }
            } else if let problem {
                WebErrorState(problem) { Task { await load() } }.padding(.top, Web.space6)
            } else {
                WebSkeleton(height: Web.space16).padding(.top, Web.space6)
            }
        }
        .task(id: "\(tag ?? "")-\(model.dataVersion)") { await load() }
    }

    private func content(_ page: API.InsightsPage) -> some View {
        VStack(alignment: .leading, spacing: Web.space8) {
            PourFlowLayout(spacing: Web.space2, lineSpacing: Web.space2) {
                WebChip(selected: tag == nil) {
                    tag = nil
                } label: {
                    Text("全部")
                }
                ForEach(page.tags, id: \.tag) { item in
                    WebChip(selected: tag == item.tag) {
                        tag = item.tag == tag ? nil : item.tag
                    } label: {
                        Text(item.tag)
                        Text("\(item.count)").foregroundStyle(Web.fgTertiary)
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("按标签看"))
            VStack(alignment: .leading, spacing: Web.space12) {
                ForEach(LibraryMonth.group(page.insights, day: \.day), id: \.month) { group in
                    VStack(alignment: .leading, spacing: Web.space8) {
                        LibraryMonth(title: group.month)
                        ForEach(group.items) { essay($0) }
                    }
                }
            }
        }
        .padding(.top, Web.space6)
    }

    private func essay(_ item: API.InsightItem) -> some View {
        VStack(alignment: .leading, spacing: Web.space2) {
            EssayQuote(text: item.quote)
            PourFlowLayout(spacing: Web.space2, lineSpacing: Web.space1) {
                Text(item.title)
                Text("·")
                Text(Show.monthDay(item.day))
                ForEach(item.tags, id: \.self) { name in
                    // 看得见的是小标签，能点的是盖在上面的 44 点（和 WebTextButton 一样）
                    YellowTag(text: name).accessibilityHidden(true)
                        .overlay {
                            Button {
                                tag = name
                            } label: {
                                Color.clear.frame(minWidth: Web.touch, minHeight: Web.touch).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(name))
                            .accessibilityHint(Text("只看这个标签的感悟"))
                        }
                }
                if let note = item.noteId {
                    WebTextButton("原话", font: Web.captionMedium) { openNote(note) }
                }
            }
            .font(Web.caption).foregroundStyle(Web.fgTertiary)
        }
    }

    private func load() async {
        do {
            page = try await model.client.insights(tag: tag)
            problem = nil
        } catch {
            problem = error.readable
        }
    }
}

/// 好时刻（docs/prd-mood.md 5.7）：你说过觉得好的那一刻，按月分组、新的在前。不显示总数、不排名。
/// 点那一刻打开这条心情的详情；「原话」打开那一整段原话。不好的时刻不单独列
private struct MomentsView: View {
    @Environment(AppModel.self) private var model
    let openNote: (Int) -> Void
    @State private var moments: [API.Moment]?
    @State private var problem: String?

    var body: some View {
        Group {
            if let moments {
                if moments.isEmpty {
                    LibraryEmpty(text: "还没有好时刻。说到哪一刻觉得挺好，它会被收在这里。")
                } else {
                    content(moments)
                }
            } else if let problem {
                WebErrorState(problem) { Task { await load() } }.padding(.top, Web.space6)
            } else {
                WebSkeleton(height: Web.space16).padding(.top, Web.space6)
            }
        }
        .task(id: model.dataVersion) { await load() }
    }

    private func content(_ moments: [API.Moment]) -> some View {
        VStack(alignment: .leading, spacing: Web.space8) {
            Text("你说过觉得好的那一刻。心情是 AI 听出来的，点开可以改。").font(Web.caption).foregroundStyle(Web.fgTertiary)
            VStack(alignment: .leading, spacing: Web.space12) {
                ForEach(LibraryMonth.group(moments, day: \.entry.day), id: \.month) { group in
                    VStack(alignment: .leading, spacing: Web.space8) {
                        LibraryMonth(title: group.month)
                        ForEach(group.items) { moment($0) }
                    }
                }
            }
        }
        .padding(.top, Web.space6)
    }

    @ViewBuilder private func moment(_ item: API.Moment) -> some View {
        if case .mood(let mood) = item.entry.data {
            let emotions = mood.emotions.reduce(into: [String]()) {
                if !$0.contains($1) && $0.count < 3 { $0.append($1) }
            }
            VStack(alignment: .leading, spacing: Web.space2) {
                Button {
                    model.openEntry(item.entry.id, day: item.entry.day)
                } label: {
                    EssayQuote(text: mood.moment ?? "").padding(.vertical, Web.space1).padding(.horizontal, Web.space2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(WebPressStyle(radius: Web.radiusControl))
                .padding(.horizontal, -Web.space2)
                PourFlowLayout(spacing: Web.space2, lineSpacing: Web.space1) {
                    Text(Show.monthDay(item.entry.day))
                    Text("·")
                    Text(Show.moodWord(mood.mood))
                    if !emotions.isEmpty {
                        Text("·")
                        Text(emotions.joined(separator: "、"))
                    }
                    if let note = item.noteId {
                        WebTextButton("原话", font: Web.captionMedium) { openNote(note) }
                    }
                }
                .font(Web.caption).foregroundStyle(Web.fgTertiary)
            }
        }
    }

    private func load() async {
        do {
            moments = try await model.client.moments()
            problem = nil
        } catch {
            problem = error.readable
        }
    }
}

/// 随笔集里的一段：左边一条细线，小节那么大，行高 1.9
struct EssayQuote: View {
    let text: String

    var body: some View {
        Text(Show.spaced(text)).font(Web.section).foregroundStyle(Web.fg).lineSpacing(Web.essayLineSpacing)
            .padding(.leading, Web.space3)
            .overlay(alignment: .leading) { Rectangle().fill(Web.lineStrong).frame(width: Web.space1 / 2) }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 什么都还没有：一句话
struct LibraryEmpty: View {
    let text: String

    var body: some View {
        Text(text).font(Web.body).foregroundStyle(Web.fgTertiary).padding(.top, Web.space6)
    }
}
