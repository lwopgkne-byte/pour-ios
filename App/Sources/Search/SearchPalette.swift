import PourAPI
import PourDesign
import SwiftUI

/// 全局搜索（规格第九章）：右上角的放大镜、「/找 三体」打开。不经过 AI，即时显示结果：
/// 同时找原话、感悟（关键词 + 按意思）、目标和日期。浮在页面上面的一张卡片，后面压暗，点暗处收起
struct SearchPalette: View {
    @Environment(AppModel.self) private var model
    @Environment(\.visibleHeight) private var visibleHeight
    @Environment(\.dynamicTypeSize) private var typeSize
    let initial: String
    @State private var text = ""
    @State private var searched = ""
    @State private var result: API.SearchResult?
    @State private var searching = false
    @FocusState private var typing: Bool
    /// 最近搜过的（只存在手机上）
    @State private var recent: [String] = SearchRecent.load()

    /// 没输入时「可以这样问」（点了就在对话里问 Pour，回答带来源和图）
    private static let questions = ["这个月外卖花了多少", "上次跑步是什么时候", "谁还欠我钱", "和儿子在一起的日子心情怎么样", "上周的周报"]

    /// 结果里的一项：哪一组、写什么、旁边的小字、点了去哪
    private struct Item: Identifiable {
        let id: String
        let group: String
        let label: String
        var meta: String?
        var similar = false
        let open: () -> Void
    }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.Palette.dim.ignoresSafeArea()
                .onTapGesture { close() }
                .accessibilityLabel(Text("关闭搜索"))
                .accessibilityAddTraits(.isButton)
            card.padding(.horizontal, Theme.Space.small).padding(.top, Theme.Space.small)
        }
        .onAppear {
            text = initial
            searched = initial.trimmingCharacters(in: .whitespaces)
            typing = true
        }
        .task(id: text) {
            // 停下来 0.15 秒再搜
            try? await Task.sleep(for: .milliseconds(150))
            if !Task.isCancelled { searched = text.trimmingCharacters(in: .whitespaces) }
        }
        .task(id: searched) { await load() }
    }

    private var card: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Space.small) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.Palette.secondaryLabel).accessibilityHidden(
                    true)
                TextField("找说过的话、感悟、目标，或者输入日期（9月3日）", text: $text, axis: .vertical)
                    .font(Theme.Typeface.section).foregroundStyle(Theme.Palette.label)
                    .focused($typing)
                    .submitLabel(.search)
                    // 能折行（字很大时提示不被截断），但回车不换行：打开第一项
                    .onChange(of: text) { _, now in
                        if now.contains("\n") {
                            text = now.replacing("\n", with: "")
                            items.first?.open()
                        }
                    }
                    .accessibilityLabel(Text("搜索"))
                if searching { Dots(label: "正在搜索").foregroundStyle(Theme.Palette.secondaryLabel) }
            }
            .padding(.vertical, Theme.Space.medium).padding(.horizontal, Theme.Space.regular)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.Palette.separator).frame(height: 1) }
            ScrollView {
                list.padding(Theme.Space.small)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxHeight: visibleHeight * 0.8, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
        .background(RoundedRectangle(cornerRadius: Theme.Corner.chip).fill(Theme.Palette.card))
        .shadow(color: Theme.Palette.shadowFar, radius: Theme.Space.regular, y: Theme.Space.tight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("搜索"))
        .accessibilityAddTraits(.isModal)
    }

    @ViewBuilder private var list: some View {
        let items = items
        VStack(alignment: .leading, spacing: 0) {
            if searched.isEmpty {
                start
            } else {
                // 回答在最上面：问 Pour 这一句（在对话里答，带来源编号和图）
                askRow("问 Pour：\(searched)") { ask(searched) }
                if result != nil && items.isEmpty { hint("没有找到相关的内容。") }
            }
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index == 0 || items[index - 1].group != item.group {
                    Text(item.group).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
                        .padding(.horizontal, Theme.Space.small).padding(.top, Theme.Space.small).padding(
                            .bottom, Theme.Space.tight
                        )
                        .accessibilityAddTraits(.isHeader)
                }
                row(item)
            }
            if result?.semantic?.state == "loading" {
                hint("第一次按意思搜索要准备一下本地模型，稍等片刻结果会更全。")
            }
            if result?.semantic?.state == "failed", let message = result?.semantic?.message { hint(message) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 没输入时：可以这样问、最近搜过
    @ViewBuilder private var start: some View {
        groupTitle("可以这样问")
        ForEach(Self.questions, id: \.self) { question in askRow(question) { ask(question) } }
        if !recent.isEmpty {
            groupTitle("最近搜过")
            PourFlowLayout(spacing: Theme.Space.small, lineSpacing: Theme.Space.small) {
                ForEach(recent, id: \.self) { word in
                    FilterChip("↺ \(word)", selected: false) { text = word }
                }
            }
            .padding(.horizontal, Theme.Space.small)
        }
        hint("按意思也能找到：搜「运动后的心情」，会找到「跑完步神清气爽」。")
    }

    private func groupTitle(_ title: String) -> some View {
        Text(title).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            .padding(.horizontal, Theme.Space.small).padding(.top, Theme.Space.small).padding(
                .bottom, Theme.Space.tight
            )
            .accessibilityAddTraits(.isHeader)
    }

    private func askRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: "bubble.left.and.text.bubble.right").font(Theme.Typeface.body)
                .foregroundStyle(Theme.Palette.accent).multilineTextAlignment(.leading)
                .padding(.vertical, Theme.Space.tight).padding(.horizontal, Theme.Space.small)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.touch, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("search.ask")
    }

    /// 在对话里问 Pour（就是「/问」）：关掉搜索，打开对话
    private func ask(_ question: String) {
        SearchRecent.add(question)
        close()
        model.draft = "/问 \(question)"
        model.send()
        model.chatOpen = true
    }

    private func hint(_ text: String) -> some View {
        Text(text).font(Theme.Typeface.footnote).foregroundStyle(Theme.Palette.secondaryLabel)
            .padding(.vertical, Theme.Space.medium).padding(.horizontal, Theme.Space.small)
    }

    private func row(_ item: Item) -> some View {
        Button {
            SearchRecent.add(searched)
            item.open()
        } label: {
            // 字很大时日期、「意思相近」换到下一行，原话不被挤成一条
            let layout =
                typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Space.tight))
                : AnyLayout(HStackLayout(spacing: Theme.Space.medium))
            layout {
                // 平时一行放不下用省略号；字很大时折行，不截断
                Text(item.label).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label).lineLimit(
                    typeSize > .large ? nil : 1
                )
                .accessibilityIdentifier("webOneLine")
                .frame(maxWidth: .infinity, alignment: .leading)
                if item.similar { MoneyTag(text: "意思相近") }
                if let meta = item.meta {
                    Text(meta).font(Theme.Typeface.body).foregroundStyle(Theme.Palette.secondaryLabel).fixedSize()
                }
            }
            .padding(.vertical, Theme.Space.tight).padding(.horizontal, Theme.Space.small)
            .frame(minHeight: Theme.Size.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var items: [Item] {
        guard let result, !searched.isEmpty else { return [] }
        var out: [Item] = []
        if let day = result.day {
            out.append(
                Item(id: "d\(day)", group: "日期", label: "打开 \(Show.dayTitle(day, today: model.today))") {
                    open(day: day)
                })
        }
        for goal in result.goals {
            out.append(
                Item(id: "g\(goal.id)", group: "目标", label: goal.title, meta: goal.status == "done" ? "已完成" : nil) {
                    close()
                    model.openGoal(goal.id)
                })
        }
        for hit in result.hits {
            let note = hit.kind == "note"
            out.append(
                Item(
                    id: "\(hit.kind)\(hit.entryId ?? hit.noteId ?? 0)", group: note ? "原话" : "感悟", label: hit.text,
                    meta: Show.dayTitle(hit.day, today: model.today), similar: hit.via == "semantic"
                ) {
                    if note, let id = hit.noteId {
                        close()
                        model.open("/library?note=\(id)")
                    } else {
                        open(day: hit.day)
                    }
                })
        }
        return out
    }

    private func open(day: String) {
        close()
        model.goHome()
        model.show(day)
    }

    private func close() { model.search = nil }
}

/// 最近搜过的几个词（只存在手机上，最多 8 个，新的在前）
enum SearchRecent {
    private static let key = "pour.search.recent"

    static func load() -> [String] { UserDefaults.standard.stringArray(forKey: key) ?? [] }

    static func add(_ word: String) {
        let word = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }
        UserDefaults.standard.set(Array(([word] + load().filter { $0 != word }).prefix(8)), forKey: key)
    }
}

extension SearchPalette {

    private func load() async {
        guard !searched.isEmpty else {
            result = nil
            return
        }
        searching = true
        defer { searching = false }
        if let fresh = try? await model.client.search(searched) { result = fresh }
    }
}
