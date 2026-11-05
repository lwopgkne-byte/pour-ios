import PourAPI
import PourDesign
import SwiftUI

/// 全局搜索（规格第九章）：右上角的放大镜、「/找 三体」打开。不经过 AI，即时显示结果：
/// 同时找原话、感悟（关键词 + 按意思）、目标和日期。照可交互原型是盖住整屏的一页：左上返回、白色圆角的搜索框
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
        VStack(spacing: 0) {
            top
            ScrollView {
                list.padding(.horizontal, Theme.Space.screen).padding(.bottom, Theme.Space.section)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("搜索"))
        .accessibilityAddTraits(.isModal)
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

    /// 顶上一行（原型）：玻璃圆的返回、白色圆角的搜索框（放大镜、输入、在搜的小点、有字时清空）
    private var top: some View {
        HStack(spacing: Theme.Space.small) {
            GlassCircleButton("chevron.left", label: "关闭搜索") { close() }
            HStack(spacing: Theme.Space.small) {
                Image(systemName: "magnifyingglass").font(Theme.Typeface.bodyMedium)
                    .foregroundStyle(Theme.Palette.tertiaryLabel).accessibilityHidden(true)
                TextField("找说过的话，或者问一句", text: $text, axis: .vertical)
                    .font(Theme.Typeface.body).foregroundStyle(Theme.Palette.label)
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
                if !text.isEmpty {
                    Button {
                        text = ""
                        typing = true
                    } label: {
                        Image(systemName: "xmark").font(Theme.Typeface.footnoteSemibold)
                            .foregroundStyle(Theme.Palette.secondaryLabel)
                            .frame(
                                width: Theme.Space.section - Theme.Space.tight,
                                height: Theme.Space.section - Theme.Space.tight
                            )
                            .background(Theme.Palette.fillStrong, in: Circle())
                            .frame(width: Theme.Size.touch, height: Theme.Size.touch).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    // 点的范围 44，但不把框撑高（框照原型 44 高）
                    .padding(.vertical, -Theme.Space.small)
                    .padding(.trailing, -Theme.Space.small)
                    .accessibilityLabel(Text("清空"))
                }
            }
            .padding(.horizontal, Theme.Space.inset)
            .padding(.vertical, Theme.Space.small)
            .frame(minHeight: Theme.Size.touch)
            .background(Theme.Palette.card, in: Theme.rounded(Theme.Size.touch / 2))
            .overlay { Theme.rounded(Theme.Size.touch / 2).strokeBorder(Theme.Palette.separator, lineWidth: 0.5) }
        }
        .padding(.horizontal, Theme.Space.screen).padding(.top, Theme.Space.tight).padding(.bottom, Theme.Space.small)
    }

    @ViewBuilder private var list: some View {
        let items = items
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            if searched.isEmpty {
                start
            } else {
                // 回答在最上面：问 Pour 这一句（在对话里答，带来源编号和图）
                askRow("问 Pour：\(searched)") { ask(searched) }
                if result != nil && items.isEmpty { hint("没有找到「\(searched)」。换个说法试试，或者直接问一句") }
            }
            ForEach(groups(items), id: \.name) { group in
                groupTitle(group.name, meta: group.name == "原话" ? "\(group.items.count) 条" : nil)
                VStack(spacing: 0) {
                    ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Divider().padding(.leading, Theme.Space.regular) }
                        row(item)
                    }
                }
                .background(Theme.Palette.card, in: Theme.rounded(Theme.Corner.smallCard))
            }
            if result?.semantic?.state == "loading" {
                hint("第一次按意思搜索要准备一下本地模型，稍等片刻结果会更全。")
            }
            if result?.semantic?.state == "failed", let message = result?.semantic?.message { hint(message) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 结果按组排（日期、目标、原话、感悟）：组按第一次出现的先后，同一组的合在一起（服务器给的原话、感悟是交错的）
    private func groups(_ items: [Item]) -> [(name: String, items: [Item])] {
        var out: [(name: String, items: [Item])] = []
        for item in items {
            if let index = out.firstIndex(where: { $0.name == item.group }) {
                out[index].items.append(item)
            } else {
                out.append((item.group, [item]))
            }
        }
        return out
    }

    /// 没输入时（原型）：可以这样问（一行一个白胶囊）、最近搜过（带小钟的胶囊）
    @ViewBuilder private var start: some View {
        groupTitle("可以这样问")
        ForEach(Self.questions, id: \.self) { question in askRow(question) { ask(question) } }
        if !recent.isEmpty {
            groupTitle("最近搜过")
            ChipFlow {
                ForEach(recent, id: \.self) { word in
                    Button {
                        text = word
                    } label: {
                        Label(word, systemImage: "clock.arrow.circlepath").font(Theme.Typeface.subheadline)
                            .foregroundStyle(Theme.Palette.label)
                            .padding(.horizontal, Theme.Space.medium).frame(minHeight: Theme.Size.capsule)
                            .background(Theme.Palette.fillStrong, in: Capsule())
                            .frame(minHeight: Theme.Size.touch).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        hint("按意思也能找到：搜「运动后的心情」，会找到「跑完步神清气爽」。")
    }

    private func groupTitle(_ title: String, meta: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(Theme.Typeface.bodySemibold).foregroundStyle(Theme.Palette.label)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            if let meta {
                Text(meta).font(Theme.Typeface.footnote).monospacedDigit().foregroundStyle(Theme.Palette.secondaryLabel)
            }
        }
        .padding(.horizontal, Theme.Space.tight).padding(.top, Theme.Space.medium)
    }

    /// 问一句（原型）：白色的胶囊，左边蓝色的对话图标、字是黑的
    private func askRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.small) {
                Image(systemName: "bubble.left.and.text.bubble.right").font(Theme.Typeface.subheadline)
                    .foregroundStyle(Theme.Palette.accent).accessibilityHidden(true)
                Text(title).font(Theme.Typeface.subheadline).foregroundStyle(Theme.Palette.label)
                    .multilineTextAlignment(.leading)
            }
            .padding(.vertical, Theme.Space.small).padding(.horizontal, Theme.Space.inset)
            .frame(maxWidth: .infinity, minHeight: Theme.Size.touch, alignment: .leading)
            .background(Theme.Palette.card, in: Theme.rounded(Theme.Size.touch / 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
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
            .padding(.vertical, Theme.Space.small).padding(.horizontal, Theme.Space.tight)
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
                Text(item.label).font(
                    item.group == "原话" || item.group == "感悟" ? Theme.Typeface.quote : Theme.Typeface.body
                )
                .foregroundStyle(Theme.Palette.label).lineLimit(typeSize > .large ? nil : 1)
                .accessibilityIdentifier("webOneLine")
                .frame(maxWidth: .infinity, alignment: .leading)
                if item.similar { MoneyTag(text: "意思相近") }
                if let meta = item.meta {
                    Text(meta).font(Theme.Typeface.footnote).monospacedDigit().foregroundStyle(
                        Theme.Palette.secondaryLabel
                    )
                    .fixedSize()
                }
            }
            .padding(.vertical, Theme.Space.small).padding(.horizontal, Theme.Space.regular)
            .frame(minHeight: Theme.Size.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
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
