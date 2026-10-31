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
            Web.overlay.ignoresSafeArea()
                .onTapGesture { close() }
                .accessibilityLabel(Text("关闭搜索"))
                .accessibilityAddTraits(.isButton)
            card.padding(.horizontal, Web.space2).padding(.top, Web.space2)
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
            HStack(spacing: Web.space2) {
                Image(systemName: "magnifyingglass").foregroundStyle(Web.fgTertiary).accessibilityHidden(true)
                TextField("找说过的话、感悟、目标，或者输入日期（9月3日）", text: $text, axis: .vertical)
                    .font(Web.section).foregroundStyle(Web.fg)
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
                if searching { Dots(label: "正在搜索").foregroundStyle(Web.fgTertiary) }
            }
            .padding(.vertical, Web.space3).padding(.horizontal, Web.space4)
            .overlay(alignment: .bottom) { Rectangle().fill(Web.line).frame(height: 1) }
            ScrollView {
                list.padding(Web.space2)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxHeight: visibleHeight * 0.8, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
        .background(RoundedRectangle(cornerRadius: Web.radiusPanel).fill(Web.bg))
        .shadow(color: Web.shadow, radius: Web.space4, y: Web.space1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("搜索"))
        .accessibilityAddTraits(.isModal)
    }

    @ViewBuilder private var list: some View {
        let items = items
        VStack(alignment: .leading, spacing: 0) {
            if searched.isEmpty {
                hint("按意思也能找到：搜「运动后的心情」，会找到「跑完步神清气爽」。")
            } else if result != nil && items.isEmpty {
                hint("没有找到相关的内容。")
            }
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index == 0 || items[index - 1].group != item.group {
                    Text(item.group).font(Web.caption).foregroundStyle(Web.fgTertiary)
                        .padding(.horizontal, Web.space2).padding(.top, Web.space2).padding(.bottom, Web.space1)
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

    private func hint(_ text: String) -> some View {
        Text(text).font(Web.caption).foregroundStyle(Web.fgTertiary)
            .padding(.vertical, Web.space3).padding(.horizontal, Web.space2)
    }

    private func row(_ item: Item) -> some View {
        Button(action: item.open) {
            // 字很大时日期、「意思相近」换到下一行，原话不被挤成一条
            let layout =
                typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Web.space1))
                : AnyLayout(HStackLayout(spacing: Web.space3))
            layout {
                // 平时一行放不下用省略号；字很大时折行，不截断
                Text(item.label).font(Web.body).foregroundStyle(Web.fg).lineLimit(typeSize > .large ? nil : 1)
                    .accessibilityIdentifier("webOneLine")
                    .frame(maxWidth: .infinity, alignment: .leading)
                if item.similar { MoneyTag(text: "意思相近") }
                if let meta = item.meta { Text(meta).font(Web.body).foregroundStyle(Web.fgTertiary).fixedSize() }
            }
            .padding(.vertical, Web.space1).padding(.horizontal, Web.space2)
            .frame(minHeight: Web.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(WebPressStyle(radius: Web.radiusControl))
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
